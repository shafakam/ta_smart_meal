import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiChatClient {
  final String backendBaseUrl;
  GeminiChatClient({required this.backendBaseUrl});

  Future<Map<String, dynamic>> sendChat(String userId, String question, Map<String, dynamic> summary) async {
    final resp = await http.post(Uri.parse('$backendBaseUrl/api/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'question': question, 'summary': summary}));
    if (resp.statusCode != 200) throw Exception('AI request failed: ${resp.statusCode}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
