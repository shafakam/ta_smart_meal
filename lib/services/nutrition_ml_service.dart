import 'dart:math';
import '../models/meal.dart';
import '../models/nutrition_insight.dart';
import '../models/nutrition_profile.dart';

class NutritionMLService {
  NutritionInsight analyze({
    required NutritionProfile profile,
    required List<Meal> savedMeals,
  }) {
    final meals = savedMeals.isEmpty ? _sampleMeals(profile) : savedMeals;
    final baseDaily = meals.fold<int>(0, (sum, meal) => sum + meal.calories);
    final averageCalories = meals.isEmpty
        ? profile.targetCalories
        : baseDaily / max(1, meals.length);
    final activityAdjustment = switch (profile.activityLevel) {
      'Sedentary' => -150,
      'Lightly Active' => 0,
      'Active' => 150,
      'Very Active' => 300,
      _ => 0,
    };
    final maintenance = profile.targetCalories + activityAdjustment;
    final calorieDelta = averageCalories - maintenance;
    final predictedWeightChange = (calorieDelta * 7) / 7700;
    final dailyCalories = List.generate(7, (index) {
      final wave = ((index % 3) - 1) * 80;
      return max(0, (averageCalories + wave).round());
    });
    final weightDirection = profile.targetWeight - profile.currentWeight;
    final weightProgress = List.generate(6, (index) {
      final progress = index / 5;
      return profile.currentWeight + (weightDirection * progress * 0.35);
    });

    final warnings = <String>[];
    if (calorieDelta > 250) warnings.add('Overeating terdeteksi minggu ini.');
    if (profile.sleepDuration < 6) warnings.add('Durasi tidur masih rendah.');
    if (profile.dailyWaterIntake < 1.8) warnings.add('Asupan air belum ideal.');
    if (_likelyLowProtein(meals, profile)) {
      warnings.add('Protein tampak kurang untuk goal kamu.');
    }
    if (_likelyHighSugar(meals)) {
      warnings.add('Pola gula/snack manis perlu dikurangi.');
    }
    if (warnings.isEmpty) warnings.add('Pola makan cukup stabil minggu ini.');

    final recommendations = <String>[
      if (profile.goalType == 'Weight Loss')
        'Jaga defisit ringan 300-500 kcal dan pilih lauk tinggi protein.',
      if (profile.goalType == 'Muscle Gain')
        'Tambahkan protein di setiap makan dan kalori surplus secukupnya.',
      if (profile.eatingPreference == 'Sugar Control')
        'Ganti minuman manis dengan air putih atau infused water.',
      if (profile.eatingPreference == 'Low Carb')
        'Prioritaskan sayur, protein, dan karbohidrat kompleks porsi kecil.',
      'Pertahankan jam makan konsisten dan hindari snack berat malam.',
    ];

    return NutritionInsight(
      averageCalories: averageCalories,
      calorieDelta: calorieDelta,
      dailyCalories: dailyCalories,
      weightProgress: weightProgress,
      mostFrequentFood: _mostFrequentFood(meals),
      habitWarnings: warnings,
      recommendations: recommendations.take(4).toList(),
      summary:
          'Kalori mingguan kamu ${calorieDelta >= 0 ? 'surplus' : 'defisit'} sekitar ${calorieDelta.abs().round()} kcal dari target. Fokus perbaikan utama: ${warnings.first.toLowerCase()}',
      predictedWeightChange: predictedWeightChange,
    );
  }

  List<Meal> _sampleMeals(NutritionProfile profile) {
    return [
      Meal(
        id: 'sample-breakfast',
        name: 'Oat Telur Pisang',
        description: 'Sarapan seimbang untuk energi pagi.',
        price: 18000,
        calories: 420,
        dietType: profile.dietType,
        imageUrl: '',
        matchPercentage: 88,
        mealTime: 'Breakfast',
      ),
      Meal(
        id: 'sample-lunch',
        name: 'Nasi Ayam Sayur',
        description: 'Makan siang tinggi protein.',
        price: 28000,
        calories: 560,
        dietType: profile.dietType,
        imageUrl: '',
        matchPercentage: 90,
        mealTime: 'Lunch',
      ),
      Meal(
        id: 'sample-dinner',
        name: 'Sup Tahu Jamur',
        description: 'Makan malam ringan.',
        price: 22000,
        calories: 360,
        dietType: profile.dietType,
        imageUrl: '',
        matchPercentage: 85,
        mealTime: 'Dinner',
      ),
    ];
  }

  bool _likelyLowProtein(List<Meal> meals, NutritionProfile profile) {
    final names = meals.map((meal) => meal.name.toLowerCase()).join(' ');
    final hasProtein = names.contains('ayam') ||
        names.contains('telur') ||
        names.contains('ikan') ||
        names.contains('tahu') ||
        names.contains('tempe') ||
        names.contains('protein');
    return !hasProtein ||
        profile.goalType == 'Muscle Gain' ||
        profile.eatingPreference == 'High Protein';
  }

  bool _likelyHighSugar(List<Meal> meals) {
    final names = meals.map((meal) => meal.name.toLowerCase()).join(' ');
    return names.contains('gula') ||
        names.contains('manis') ||
        names.contains('snack') ||
        names.contains('dessert');
  }

  String _mostFrequentFood(List<Meal> meals) {
    if (meals.isEmpty) return 'Belum ada data';
    final counts = <String, int>{};
    for (final meal in meals) {
      counts[meal.name] = (counts[meal.name] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
