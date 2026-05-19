import 'dart:convert';
import 'package:http/http.dart' as http;

class MlService {
  final String backendUrl;
  MlService({required this.backendUrl});

  Future<Map<String, dynamic>> analyze(Map<String, dynamic> payload) async {
    final r = await http.post(Uri.parse('$backendUrl/api/ai/analyze'), headers: {'Content-Type':'application/json'}, body: jsonEncode(payload));
    if (r.statusCode!=200) throw Exception('Analyze failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recommend(Map<String, dynamic> userProfile, List<Map<String, dynamic>> candidates) async {
    final r = await http.post(Uri.parse('$backendUrl/api/ai/recommend'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'userProfile': userProfile, 'candidates': candidates}));
    if (r.statusCode!=200) throw Exception('Recommend failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendChat(String userId, String question, Map<String, dynamic> summary, List<Map<String, dynamic>> history) async {
    final r = await http.post(
      Uri.parse('$backendUrl/api/ai/chat'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({'userId': userId, 'question': question, 'summary': summary, 'history': history}),
    );
    if (r.statusCode != 200) throw Exception('Chat request failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
