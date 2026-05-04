import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/meal.dart';

class AIService {
  String get _provider => dotenv.get('AI_PROVIDER', fallback: 'gemini');
  String get _geminiApiKey {
    final key = dotenv.get('GEMINI_API_KEY', fallback: '').trim();
    return key.startsWith('sk-or-') ? '' : key;
  }

  String get _geminiModel =>
      dotenv.get('GEMINI_MODEL', fallback: 'gemini-2.0-flash');
  String get _openRouterApiKey {
    final key = dotenv.get('OPENROUTER_API_KEY', fallback: '').trim();
    if (key.isNotEmpty) return key;

    final legacyKey = dotenv.get('GEMINI_API_KEY', fallback: '').trim();
    return legacyKey.startsWith('sk-or-') ? legacyKey : '';
  }

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

    final provider = _provider.toLowerCase();

    final attempts = provider == 'openrouter'
        ? [_getOpenRouterRecommendations, _getGeminiRecommendations]
        : [_getGeminiRecommendations, _getOpenRouterRecommendations];

    for (final attempt in attempts) {
      final meals = await attempt(prompt);
      if (meals != null && meals.isNotEmpty) return meals;
    }

    debugPrint('AI fallback lokal dipakai karena provider AI gagal.');
    return _getLocalRecommendations(
      budget: budget,
      targetCalories: targetCalories,
      dietType: dietType,
    );
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

  Future<List<Meal>?> _getGeminiRecommendations(String prompt) async {
    if (_geminiApiKey.isEmpty) {
      debugPrint('Gemini dilewati: API key belum tersedia di .env');
      return null;
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
        debugPrint(_readGeminiError(response.statusCode, response.body));
        return null;
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
        debugPrint('Gemini tidak mengirim menu yang valid');
        return null;
      }
      return meals;
    } catch (e) {
      debugPrint('AI Error: $e');
      return null;
    }
  }

  Future<List<Meal>?> _getOpenRouterRecommendations(String prompt) async {
    if (_openRouterApiKey.isEmpty) {
      debugPrint('OpenRouter dilewati: API key belum tersedia di .env');
      return null;
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
        debugPrint(_readOpenRouterError(response.statusCode, response.body));
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          data['choices']?[0]?['message']?['content']?.toString() ?? '';
      final meals = _parseMealList(text);
      if (meals.isEmpty) {
        debugPrint('OpenRouter tidak mengirim menu yang valid');
        return null;
      }
      return meals;
    } catch (e) {
      debugPrint('OpenRouter AI Error: $e');
      return null;
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
    try {
      final parsed = jsonDecode(_cleanJson(text));
      final list = parsed is List ? parsed : parsed['meals'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((item) => Meal.fromJson(Map<String, dynamic>.from(item)))
          .where((meal) => meal.name.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Gagal parse JSON menu AI: $e');
      return [];
    }
  }

  String _cleanJson(String text) {
    final trimmed =
        text.trim().replaceAll('```json', '').replaceAll('```', '').trim();
    final start = trimmed.indexOf('[');
    final end = trimmed.lastIndexOf(']');
    if (start >= 0 && end > start) return trimmed.substring(start, end + 1);
    return trimmed;
  }

  List<Meal> _getLocalRecommendations({
    required double budget,
    required double targetCalories,
    required String dietType,
  }) {
    const templates = [
      _MealTemplate(
        name: 'Nasi Ayam Panggang Sayur',
        description: 'Menu balanced dengan protein ayam dan sayuran tumis.',
        dietType: 'Balanced',
        mealTime: 'Lunch',
        basePrice: 28000,
        baseCalories: 520,
        ingredients: ['Nasi', 'Dada ayam', 'Buncis', 'Wortel', 'Bawang putih'],
        steps: [
          'Panggang ayam dengan sedikit minyak.',
          'Tumis sayuran sampai matang.',
          'Sajikan bersama nasi hangat.'
        ],
      ),
      _MealTemplate(
        name: 'Oat Pisang Kacang',
        description: 'Sarapan praktis dengan oat, buah, dan lemak sehat.',
        dietType: 'Balanced',
        mealTime: 'Breakfast',
        basePrice: 18000,
        baseCalories: 390,
        ingredients: ['Oat', 'Pisang', 'Susu rendah lemak', 'Kacang almond'],
        steps: [
          'Masak oat dengan susu.',
          'Tambahkan irisan pisang.',
          'Taburi kacang sebelum disajikan.'
        ],
      ),
      _MealTemplate(
        name: 'Tumis Tahu Tempe Brokoli',
        description: 'Menu vegan tinggi protein nabati dan mudah dibuat.',
        dietType: 'Vegan',
        mealTime: 'Dinner',
        basePrice: 22000,
        baseCalories: 430,
        ingredients: ['Tahu', 'Tempe', 'Brokoli', 'Kecap rendah gula'],
        steps: [
          'Potong tahu dan tempe.',
          'Tumis bersama brokoli.',
          'Bumbui secukupnya lalu sajikan.'
        ],
      ),
      _MealTemplate(
        name: 'Salad Telur Alpukat',
        description: 'Menu low carb ringan dengan telur dan alpukat.',
        dietType: 'Low Carb',
        mealTime: 'Lunch',
        basePrice: 30000,
        baseCalories: 460,
        ingredients: ['Telur rebus', 'Alpukat', 'Selada', 'Tomat', 'Lemon'],
        steps: [
          'Rebus telur sampai matang.',
          'Potong alpukat dan sayuran.',
          'Campur dengan perasan lemon.'
        ],
      ),
      _MealTemplate(
        name: 'Ikan Kukus Jahe',
        description: 'Menu tinggi protein dengan rasa ringan dan segar.',
        dietType: 'Balanced',
        mealTime: 'Dinner',
        basePrice: 35000,
        baseCalories: 410,
        ingredients: ['Ikan fillet', 'Jahe', 'Daun bawang', 'Sawi'],
        steps: [
          'Kukus ikan dengan jahe.',
          'Tambahkan daun bawang.',
          'Sajikan dengan sayur rebus.'
        ],
      ),
      _MealTemplate(
        name: 'Omelet Keju Jamur',
        description: 'Pilihan keto sederhana dengan telur, jamur, dan keju.',
        dietType: 'Keto',
        mealTime: 'Breakfast',
        basePrice: 26000,
        baseCalories: 480,
        ingredients: ['Telur', 'Keju', 'Jamur', 'Bayam'],
        steps: [
          'Kocok telur dan campur keju.',
          'Masak bersama jamur dan bayam.',
          'Lipat omelet lalu sajikan.'
        ],
      ),
      _MealTemplate(
        name: 'Soba Sayur Edamame',
        description: 'Menu vegan bernutrisi dengan mie soba dan edamame.',
        dietType: 'Vegan',
        mealTime: 'Lunch',
        basePrice: 32000,
        baseCalories: 500,
        ingredients: ['Mie soba', 'Edamame', 'Wortel', 'Timun', 'Wijen'],
        steps: [
          'Rebus soba sampai matang.',
          'Campur dengan sayuran dan edamame.',
          'Tambahkan saus ringan.'
        ],
      ),
      _MealTemplate(
        name: 'Ayam Selada Wrap',
        description: 'Wrap rendah karbo dengan ayam dan sayur segar.',
        dietType: 'Low Carb',
        mealTime: 'Dinner',
        basePrice: 29000,
        baseCalories: 380,
        ingredients: ['Dada ayam', 'Selada', 'Timun', 'Yogurt plain'],
        steps: [
          'Masak ayam sampai matang.',
          'Isi daun selada dengan ayam dan timun.',
          'Tambahkan saus yogurt.'
        ],
      ),
    ];

    final preferred = templates.where((item) {
      if (dietType == 'Balanced') return true;
      return item.dietType.toLowerCase() == dietType.toLowerCase();
    }).toList();
    final source = preferred.length >= 6 ? preferred : templates;

    return source.take(6).map((item) {
      final price =
          item.basePrice > budget && budget >= 15000 ? budget : item.basePrice;
      final calories = ((item.baseCalories + targetCalories) / 2).round();

      return Meal(
        id: 'local-${item.name.toLowerCase().replaceAll(' ', '-')}',
        name: item.name,
        description: item.description,
        price: price.toDouble(),
        calories: calories.clamp(250, 700),
        dietType: item.dietType,
        imageUrl: 'https://via.placeholder.com/150',
        matchPercentage: 88,
        ingredients: item.ingredients,
        steps: item.steps,
        mealTime: item.mealTime,
      );
    }).toList();
  }
}

class _MealTemplate {
  final String name;
  final String description;
  final String dietType;
  final String mealTime;
  final int basePrice;
  final int baseCalories;
  final List<String> ingredients;
  final List<String> steps;

  const _MealTemplate({
    required this.name,
    required this.description,
    required this.dietType,
    required this.mealTime,
    required this.basePrice,
    required this.baseCalories,
    required this.ingredients,
    required this.steps,
  });
}
