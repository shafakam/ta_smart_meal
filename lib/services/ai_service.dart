import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/meal.dart';

class AIService {
  String get _provider => dotenv.get('AI_PROVIDER', fallback: 'gemini');
  String get _geminiApiKey => dotenv.get('GEMINI_API_KEY', fallback: '');
  String get _geminiModel =>
      dotenv.get('GEMINI_MODEL', fallback: 'gemini-2.0-flash');
  String get _openRouterApiKey =>
      dotenv.get('OPENROUTER_API_KEY', fallback: _geminiApiKey);
  String get _openRouterModel => dotenv.get('OPENROUTER_MODEL',
      fallback: 'liquid/lfm-2.5-1.2b-instruct:free');

  Future<List<Meal>> getSmartRecommendations({
    required double budget,
    required double targetCalories,
    required String dietType,
  }) async {
    final prompt = _buildPrompt(
      budget: budget,
      targetCalories: targetCalories,
      dietType: dietType,
    );

    if (_provider.toLowerCase() == 'openrouter') {
      return _getOpenRouterRecommendations(prompt);
    }

    return _getGeminiRecommendations(prompt);
  }

  String _buildPrompt({
    required double budget,
    required double targetCalories,
    required String dietType,
  }) {
    return '''
Buat 6 rekomendasi menu sehat untuk aplikasi Smart Meal.
Kriteria:
- Budget maksimal Rp ${budget.toInt()} per menu
- Target kalori sekitar ${targetCalories.toInt()} kcal
- Tipe diet: $dietType
- Konteks Indonesia, bahan mudah dicari di pasar/supermarket
- Buat menu yang berbeda setiap kali preferensi berubah. Jangan mengulang nama menu yang sama.
- Variasi seed: ${DateTime.now().millisecondsSinceEpoch}

Balas hanya JSON array valid tanpa markdown. Setiap item wajib punya:
id, name, description, price, calories, dietType, imageUrl, matchPercentage, ingredients, steps, mealTime.
mealTime hanya salah satu dari: Breakfast, Lunch, Dinner.
ingredients dan steps harus array string singkat.
Gunakan imageUrl kosong string jika tidak punya gambar.
''';
  }

  Future<List<Meal>> _getGeminiRecommendations(String prompt) async {
    if (_geminiApiKey.isEmpty) {
      throw Exception('Gemini API key belum tersedia di .env');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey',
    );

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.7,
                'responseMimeType': 'application/json',
              }
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint('Gemini Error ${response.statusCode}: ${response.body}');
        throw Exception(_readGeminiError(response.statusCode, response.body));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
              ?.toString() ??
          '';
      final parsed = jsonDecode(_cleanJson(text));
      final list = parsed is List ? parsed : parsed['meals'] as List? ?? [];
      final meals = list
          .whereType<Map>()
          .map((item) => Meal.fromJson(Map<String, dynamic>.from(item)))
          .where((meal) => meal.name.isNotEmpty)
          .toList();

      if (meals.isEmpty) {
        throw Exception('Gemini tidak mengirim menu yang valid');
      }
      return meals;
    } catch (e) {
      debugPrint('AI Error: $e');
      throw Exception('Gagal mengambil rekomendasi AI: $e');
    }
  }

  Future<List<Meal>> _getOpenRouterRecommendations(String prompt) async {
    if (_openRouterApiKey.isEmpty) {
      throw Exception('OpenRouter API key belum tersedia di .env');
    }

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $_openRouterApiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://smart-meal-ta.local',
              'X-OpenRouter-Title': 'Smart Meal TA',
            },
            body: jsonEncode({
              'model': _openRouterModel,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Kamu adalah AI rekomendasi menu sehat. Balas hanya JSON valid.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.8,
              'max_tokens': 1800,
            }),
          )
          .timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) {
        debugPrint('OpenRouter Error ${response.statusCode}: ${response.body}');
        throw Exception(
            _readOpenRouterError(response.statusCode, response.body));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          data['choices']?[0]?['message']?['content']?.toString() ?? '';
      return _parseMealList(text);
    } catch (e) {
      debugPrint('OpenRouter AI Error: $e');
      throw Exception('Gagal mengambil rekomendasi AI: $e');
    }
  }

  String _readGeminiError(int statusCode, String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final message = data['error']?['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return 'Gemini gagal ($statusCode): $message';
      }
    } catch (_) {}
    return 'Gemini gagal ($statusCode). Cek GEMINI_API_KEY dan GEMINI_MODEL di .env.';
  }

  String _readOpenRouterError(int statusCode, String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final error = data['error'];
      final message = error is Map ? error['message']?.toString() : null;
      if (message != null && message.isNotEmpty) {
        return 'OpenRouter gagal ($statusCode): $message';
      }
    } catch (_) {}
    return 'OpenRouter gagal ($statusCode). Cek OPENROUTER_API_KEY dan OPENROUTER_MODEL di .env.';
  }

  List<Meal> _parseMealList(String text) {
    final parsed = jsonDecode(_cleanJson(text));
    final list = parsed is List ? parsed : parsed['meals'] as List? ?? [];
    final meals = list
        .whereType<Map>()
        .map((item) => Meal.fromJson(Map<String, dynamic>.from(item)))
        .where((meal) => meal.name.isNotEmpty)
        .toList();

    if (meals.isEmpty) {
      throw Exception('AI tidak mengirim menu yang valid');
    }
    return meals;
  }

  String _cleanJson(String text) {
    final trimmed =
        text.trim().replaceAll('```json', '').replaceAll('```', '').trim();
    final start = trimmed.indexOf('[');
    final end = trimmed.lastIndexOf(']');
    if (start >= 0 && end > start) return trimmed.substring(start, end + 1);
    return trimmed;
  }
}
