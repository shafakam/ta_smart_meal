import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/meal.dart';
import '../models/nutrition_chat_message.dart';
import '../models/nutrition_profile.dart';

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
    required NutritionProfile profile,
    String contextSummary = '',
    List<Meal> avoidMeals = const [],
  }) async {
    final prompt = _buildPrompt(
      profile: profile,
      contextSummary: contextSummary,
      avoidMeals: avoidMeals,
    );

    final provider = _provider.toLowerCase();

    final attempts = provider == 'openrouter'
        ? [_getOpenRouterRecommendations, _getGeminiRecommendations]
        : [_getGeminiRecommendations, _getOpenRouterRecommendations];

    for (final attempt in attempts) {
      final meals = await attempt(prompt);
      if (meals != null && meals.isNotEmpty) {
        return _postProcessMeals(meals, profile).take(3).toList();
      }
    }

    debugPrint('AI fallback lokal dipakai karena provider AI gagal.');
    return _getLocalRecommendations(
      profile: profile,
    );
  }

  String _buildPrompt({
    required NutritionProfile profile,
    required String contextSummary,
    required List<Meal> avoidMeals,
  }) {
    final avoidNames = avoidMeals
        .map((meal) => meal.name)
        .where((name) => name.trim().isNotEmpty)
        .take(12)
        .join(', ');
    final variationSeed =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    return '''
Buat tepat 3 rekomendasi menu sehat untuk 1 hari di aplikasi SmartBite.
Kriteria:
- Budget maksimal Rp ${profile.budget.toInt()} per menu
- Target kalori sekitar ${profile.targetCalories.toInt()} kcal
- Tipe diet: ${profile.dietType}
- Activity level: ${profile.activityLevel}
- Goal: ${profile.goalType}
- Eating preference: ${profile.eatingPreference}
- Current weight: ${profile.currentWeight} kg
- Target weight: ${profile.targetWeight} kg
- Daily water intake: ${profile.dailyWaterIntake} liter
- Sleep duration: ${profile.sleepDuration} jam
- Ringkasan pola user: $contextSummary
- Hindari nama menu ini agar hasil tidak berulang: ${avoidNames.isEmpty ? 'tidak ada' : avoidNames}
- Konteks Indonesia, bahan mudah dicari di pasar/supermarket
- Buat menu Indonesia yang spesifik, natural, dan berbeda setiap generate.
- Jangan gunakan nama generik seperti "nasi ayam sehat" berulang-ulang.
- Variasi seed: $variationSeed

Balas hanya JSON array valid tanpa markdown. Setiap item wajib punya:
id, name, description, price, calories, dietType, imageUrl, matchPercentage, ingredients, steps, mealTime, reason.
mealTime hanya salah satu dari: Breakfast, Lunch, Dinner.
ingredients dan steps harus array string singkat.
description wajib memuat alasan personal singkat kenapa menu cocok untuk goal user.
Gunakan imageUrl kosong string jika tidak punya gambar.
''';
  }

  Future<String> askNutritionAssistant({
    required NutritionProfile profile,
    required List<Meal> meals,
    required List<NutritionChatMessage> history,
    required String question,
    required String insightSummary,
  }) async {
    if (!_isNutritionScope(question)) {
      return 'Aku bisa bantu seputar makanan, nutrisi, diet, olahraga, hidrasi, tidur, berat badan, meal plan, dan budget makan. Untuk topik di luar itu aku belum bisa jawab di SmartBite. Coba tanya misalnya: "menu tinggi protein apa yang cocok buat aku?"';
    }

    final recentHistory = history.length > 1
        ? history.sublist(max(0, history.length - 9), history.length - 1)
        : <NutritionChatMessage>[];
    final context = '''
Profil user: ${jsonEncode(profile.toJson())}
Insight: $insightSummary
Riwayat/menu tersimpan: ${meals.map((meal) => '${meal.name} (${meal.calories} kcal, Rp${meal.price.round()}, ${meal.mealTime})').join('; ')}
PERTANYAAN USER YANG HARUS DIJAWAB LANGSUNG: "$question"

Kamu adalah AI Nutrition Assistant untuk aplikasi SmartBite.
Tugasmu hanya menjawab topik makanan, nutrisi, diet, olahraga, hidrasi, tidur, berat badan, meal plan, dan budget makan.
Jika pertanyaan keluar dari topik itu, tolak singkat dan arahkan user balik ke kesehatan makanan/olahraga.
Jawab dalam Bahasa Indonesia yang natural, personal, dan langsung sesuai pertanyaan user.
Jangan memberi jawaban generik yang sama untuk semua pertanyaan.
Mulai jawaban dengan jawaban inti untuk pertanyaan user, bukan rangkuman insight.
Contoh: kalau user tanya "pisang boleh ga", jawab tentang pisang dulu.
Gunakan angka/data user kalau relevan, misalnya kalori, goal, aktivitas, tidur, air, dan menu tersimpan.
Berikan saran actionable secukupnya, tidak harus selalu format bullet. Jangan memberi diagnosis medis.
Kalau data belum cukup, bilang data apa yang perlu ditambah dan tetap beri saran praktis.
''';

    final provider = _provider.toLowerCase();
    final answer = provider == 'openrouter'
        ? await _chatOpenRouter(context, recentHistory)
        : await _chatGemini(context, recentHistory);
    return answer ??
        _localChatAnswer(question: question, insightSummary: insightSummary);
  }

  bool _isNutritionScope(String question) {
    final lower = question.toLowerCase();
    final allowed = [
      'makan',
      'menu',
      'nutrisi',
      'gizi',
      'diet',
      'kalori',
      'protein',
      'karbo',
      'lemak',
      'gula',
      'snack',
      'sarapan',
      'siang',
      'malam',
      'berat',
      'turun',
      'naik',
      'otot',
      'olahraga',
      'workout',
      'jalan',
      'lari',
      'aktivitas',
      'air',
      'minum',
      'hidrasi',
      'tidur',
      'meal',
      'plan',
      'budget',
      'sehat',
      'obes',
      'bmi',
      'buah',
      'sayur',
      'pisang',
      'apel',
      'nasi',
      'ayam',
      'telur',
      'ikan',
      'tahu',
      'tempe',
      'susu',
      'yogurt',
      'oat',
      'roti',
      'mie',
      'kopi',
      'teh',
      'boleh',
      'aman',
      'bagus',
    ];
    return allowed.any(lower.contains);
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
                'temperature': 0.95,
                'topP': 0.92,
                'topK': 40,
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

  Future<String?> _chatGemini(
    String prompt,
    List<NutritionChatMessage> history,
  ) async {
    if (_geminiApiKey.isEmpty) return null;
    final historyText = history.isEmpty
        ? 'Belum ada riwayat chat.'
        : history
            .map((message) =>
                '${message.role == 'user' ? 'User' : 'Assistant'}: ${message.text}')
            .join('\n');
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
                  'role': 'user',
                  'parts': [
                    {
                      'text': 'Riwayat chat terakhir:\n$historyText\n\n$prompt',
                    }
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.75,
                'topP': 0.9,
              },
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        debugPrint(
            'Gemini chat error ${response.statusCode}: ${response.body}');
        if (response.statusCode == 429) {
          return 'Gemini API lagi kena limit/kuota (429 Too Many Requests), jadi AI asli belum bisa menjawab sekarang. Coba tunggu beberapa menit, pakai API key/project lain, atau aktifkan billing/cek quota Gemini.';
        }
        if (response.statusCode == 400 || response.statusCode == 403) {
          return 'Gemini API belum bisa dipakai. Cek API key, model Gemini, dan permission project di Google AI Studio.';
        }
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['candidates']?[0]?['content']?['parts']?[0]?['text']
          ?.toString();
    } catch (e) {
      debugPrint('Gemini chat failed: $e');
      return null;
    }
  }

  Future<String?> _chatOpenRouter(
    String prompt,
    List<NutritionChatMessage> history,
  ) async {
    if (_openRouterApiKey.isEmpty) return null;
    try {
      final response = await http
          .post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_openRouterApiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://smartbite.local',
              'X-OpenRouter-Title': 'SmartBite',
            },
            body: jsonEncode({
              'model': _openRouterModel,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Kamu AI Nutrition Assistant. Jawab singkat, suportif, dan tidak memberi diagnosis medis.',
                },
                ...history.map((message) => {
                      'role': message.role,
                      'content': message.text,
                    }),
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.6,
              'max_tokens': 600,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['choices']?[0]?['message']?['content']?.toString();
    } catch (e) {
      debugPrint('OpenRouter chat failed: $e');
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
    required NutritionProfile profile,
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
      if (profile.dietType == 'Balanced') return true;
      return item.dietType.toLowerCase() == profile.dietType.toLowerCase();
    }).toList();
    final source = [...(preferred.length >= 3 ? preferred : templates)];
    source.shuffle(Random(DateTime.now().millisecondsSinceEpoch));

    return source.take(3).map((item) {
      final price = item.basePrice > profile.budget && profile.budget >= 15000
          ? profile.budget
          : item.basePrice;
      final calories =
          ((item.baseCalories + profile.targetCalories) / 2).round();

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
        reason:
            'Cocok untuk ${profile.goalType} karena porsinya mengikuti target kalori, budget, dan preferensi ${profile.eatingPreference}.',
      );
    }).toList();
  }

  List<Meal> _postProcessMeals(List<Meal> meals, NutritionProfile profile) {
    final seen = <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final processed = <Meal>[];

    for (var i = 0; i < meals.length; i++) {
      final meal = meals[i];
      final key = meal.name.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      processed.add(
        Meal(
          id: '${meal.id.isEmpty ? key : meal.id}-$now-$i',
          name: meal.name,
          description: meal.description,
          price: meal.price,
          calories: meal.calories,
          dietType: meal.dietType,
          imageUrl: meal.imageUrl,
          matchPercentage: meal.matchPercentage,
          ingredients: meal.ingredients,
          steps: meal.steps,
          mealTime: meal.mealTime,
          reason: meal.reason.isNotEmpty
              ? meal.reason
              : 'Direkomendasikan karena sesuai budget, target kalori, goal ${profile.goalType}, dan preferensi ${profile.eatingPreference}.',
        ),
      );
    }
    return processed;
  }

  String _localChatAnswer({
    required String question,
    required String insightSummary,
  }) {
    final lower = question.toLowerCase();
    final foodAnswer = _foodSpecificFallback(lower);
    if (foodAnswer != null) return foodAnswer;

    if (lower.contains('kalori')) {
      return '$insightSummary\n\nLangkah praktis:\n1. Bandingkan rata-rata kalori dengan target harianmu.\n2. Simpan menu yang benar-benar kamu makan supaya perhitungannya makin akurat.\n3. Kalau surplus, kecilkan porsi karbo/minyak dulu sebelum menghapus lauk protein.';
    }
    if (lower.contains('berat') || lower.contains('turun')) {
      return 'Berat badan bisa stagnan karena surplus kecil, kurang tidur, aktivitas rendah, atau retensi air.\n\nCoba mulai dari 3 hal: jaga defisit ringan, makan protein di tiap waktu makan, dan tidur mendekati 7-8 jam.';
    }
    if (lower.contains('kurangi')) {
      return 'Yang paling aman dikurangi dulu: minuman manis, snack malam, gorengan, dan saus tinggi gula.\n\nGantinya pilih air putih, buah utuh, telur/tahu/tempe/ayam, dan sayur supaya tetap kenyang.';
    }
    return '$insightSummary\n\nSaran cepat: makan protein di tiap waktu makan, minum cukup air, dan jaga kalori mendekati target harian. Simpan menu harianmu agar rekomendasi berikutnya lebih personal.';
  }

  String? _foodSpecificFallback(String lower) {
    if (lower.contains('pisang')) {
      return 'Boleh. Pisang itu sehat dan aman buat kebanyakan orang karena ada karbohidrat, kalium, dan serat.\n\nKalau goal kamu weight loss, cukup 1 buah sedang sebagai snack atau sebelum olahraga. Kalau dimakan banyak, kalorinya tetap bisa numpuk, jadi jangan sampai mengganti porsi protein utama.';
    }
    if (lower.contains('nasi')) {
      return 'Boleh makan nasi, tapi porsinya perlu disesuaikan. Untuk weight loss, mulai dari 1/2 sampai 1 centong per makan lalu tambah lauk protein dan sayur supaya kenyang lebih lama.';
    }
    if (lower.contains('telur')) {
      return 'Telur boleh dan bagus untuk protein. Bisa jadi sarapan atau lauk praktis. Kalau sedang jaga kalori, rebus atau dadar dengan sedikit minyak lebih aman daripada digoreng banyak minyak.';
    }
    if (lower.contains('ayam')) {
      return 'Ayam boleh, terutama bagian dada atau ayam tanpa kulit kalau kamu mau tinggi protein dan lebih rendah lemak. Cara masak panggang, rebus, atau tumis sedikit minyak biasanya lebih cocok.';
    }
    if (lower.contains('kopi')) {
      return 'Kopi boleh, tapi perhatikan gula dan krimer. Kopi hitam atau sedikit susu lebih aman untuk kalori. Hindari minum terlalu malam supaya tidur tidak terganggu.';
    }
    if (lower.contains('buah')) {
      return 'Buah boleh dan bagus untuk serat serta mikronutrien. Tetap atur porsi, terutama buah yang manis, dan lebih baik buah utuh daripada jus manis.';
    }
    return null;
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
