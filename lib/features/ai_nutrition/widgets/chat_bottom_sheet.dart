import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/chat_storage_service.dart';
import '../services/ml_service.dart';

void showChatBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _ChatSheet(),
  );
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet();

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  final ChatStorageService _store = ChatStorageService();
  late final MlService _ml;

  @override
  void initState() {
    super.initState();
    _ml = MlService(
        backendUrl: dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080');
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await _store.load();
    setState(() => _messages.addAll(h));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildSummary() {
    final userTexts = _messages
        .where((m) => m['role'] == 'user')
        .map((m) => m['text'] as String)
        .join(' | ');
    final assistantTexts = _messages
        .where((m) => m['role'] == 'assistant')
        .map((m) => m['text'] as String)
        .join(' | ');
    final userMax = userTexts.length > 800 ? 800 : userTexts.length;
    final assistantMax =
        assistantTexts.length > 800 ? 800 : assistantTexts.length;
    return {
      'recentUser': userTexts.substring(0, userMax),
      'recentAssistant': assistantTexts.substring(0, assistantMax),
      'messageCount': _messages.length,
    };
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'createdAt': DateTime.now().toIso8601String()
      });
      _controller.clear();
      _isTyping = true;
    });

    try {
      final res = await _ml.sendChat('local', text, _buildSummary(), _messages);
      final data = res['data'] ?? res;
      final assistant = {
        'role': 'assistant',
        'text': data['reply'] ?? data['replyText'] ?? data.toString(),
        'reasons': data['reasons'] ?? [],
        'actions': data['actions'] ?? [],
        'createdAt': DateTime.now().toIso8601String(),
      };
      setState(() {
        _isTyping = false;
        _messages.add(assistant);
      });
      await _store.save(_messages);
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'assistant',
          'text': 'Server error: $e',
          'createdAt': DateTime.now().toIso8601String()
        });
      });
      await _store.save(_messages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SafeArea(
      child: SizedBox(
        height: mq.size.height * 0.7,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.health_and_safety)),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('AI Nutrition Assistant',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length && _isTyping) {
                            return const Text('AI is typing...');
                          }
                          final msg = _messages[i];
                          final role = (msg['role'] as String?) ?? 'user';
                          final text = (msg['text'] as String?) ?? '';
                          final isUser = role == 'user';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.75,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Colors.blueAccent
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(text,
                                        style: TextStyle(
                                            color: isUser
                                                ? Colors.white
                                                : Colors.black87)),
                                    if (!isUser && msg['reasons'] != null) ...[
                                      const SizedBox(height: 8),
                                      const Text('Reasons:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      Text((msg['reasons'] as List).join(' • '),
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12)),
                                    ],
                                    if (!isUser && msg['actions'] != null) ...[
                                      const SizedBox(height: 8),
                                      const Text('Actions:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      Text((msg['actions'] as List).join(', '),
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                            hintText: 'Tanyakan sesuatu tentang nutrisi...'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: _send,
                      child: const Icon(Icons.send),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy, size: 56, color: Colors.blueAccent),
          SizedBox(height: 12),
          Text('Hi! I am your AI Nutrition Assistant.'),
          SizedBox(height: 8),
          Text('Contoh: "Apa menu yang cocok hari ini?"',
              style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
