import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/meal_storage_service.dart';
import '../../../services/nutrition_ml_service.dart';
import '../../../models/nutrition_profile.dart';
import '../services/ml_service.dart';

class AiNutritionProvider extends ChangeNotifier {
  Map<String, dynamic>? analysis;
  bool loading = false;
  final MlService _ml;
  final MealStorageService _storage = MealStorageService();
  final NutritionMLService _localMl = NutritionMLService();

  AiNutritionProvider()
      : _ml = MlService(backendUrl: dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080');

  Future<void> analyze(Map<String, dynamic> payload) async {
    loading = true;
    notifyListeners();
    try {
      // prefer local analysis using stored meals
      final saved = await _storage.getSavedMeals();
      // build a NutritionProfile-like object for local ML service
      final pseudoProfile = {
        'budget': payload['budgetPerMeal'] ?? 0,
        'targetCalories': payload['targetCalories'] ?? 2000,
        'dietType': payload['diet'] ?? 'Balanced',
        'activityLevel': payload['activity'] ?? 'Sedentary',
        'goalType': payload['goal'] ?? 'Maintain Weight',
        'eatingPreference': payload['eatingPref'] ?? 'Balanced',
        'currentWeight': payload['currentWeight'] ?? 0,
        'targetWeight': payload['targetWeight'] ?? 0,
        'dailyWaterIntake': payload['waterAvg'] ?? 0,
        'sleepDuration': payload['sleepAvg'] ?? 0,
      };

      // The existing NutritionMLService expects strongly typed classes; to reuse it,
      // we will call its analyze by creating a minimal NutritionProfile model.
      // But to avoid importing model here, do a simple local analysis fallback.
      final NutritionProfile np = NutritionProfile(
        budget: (pseudoProfile['budget'] as num).toDouble(),
        targetCalories: (pseudoProfile['targetCalories'] as num).toDouble(),
        dietType: pseudoProfile['dietType'] as String,
        activityLevel: pseudoProfile['activityLevel'] as String,
        goalType: pseudoProfile['goalType'] as String,
        eatingPreference: pseudoProfile['eatingPreference'] as String,
        currentWeight: (pseudoProfile['currentWeight'] as num).toDouble(),
        targetWeight: (pseudoProfile['targetWeight'] as num).toDouble(),
        dailyWaterIntake: (pseudoProfile['dailyWaterIntake'] as num).toDouble(),
        sleepDuration: (pseudoProfile['sleepDuration'] as num).toDouble(),
      );

      final localInsight = _localMl.analyze(profile: np, savedMeals: saved);
      // If localInsight is returned, map it to our analysis map
      analysis = {
        'avgDailyCalories': localInsight.averageCalories,
        'predictedWeeklyChange': localInsight.predictedWeightChange,
        'topFoods': [localInsight.mostFrequentFood],
        'dailyCalories': localInsight.dailyCalories,
        'weightProgress': localInsight.weightProgress,
        'habitWarnings': localInsight.habitWarnings,
        'recommendations': localInsight.recommendations,
        'overeating': localInsight.habitWarnings.any((w) => w.toLowerCase().contains('overeating')),
        'highSugar': localInsight.habitWarnings.any((w) => w.toLowerCase().contains('gula') || w.toLowerCase().contains('sugar')),
      };
    } catch (e) {
      // fallback: call backend analyze endpoint
      try {
        final res = await _ml.analyze(payload);
        if (res['ok'] == true && res.containsKey('analysis')) {
          analysis = res['analysis'] as Map<String, dynamic>;
        } else {
          analysis = res;
        }
      } catch (e2) {
        debugPrint('Analyze error fallback: $e2');
        analysis = null;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> recommendations = [];
  bool recLoading = false;

  Future<void> getRecommendations(Map<String, dynamic> userProfile, List<Map<String, dynamic>> candidates) async {
    recLoading = true;
    notifyListeners();
    try {
      final res = await _ml.recommend(userProfile, candidates);
      if (res['ok'] == true && res.containsKey('recommendations')) {
        final list = res['recommendations'] as List;
        recommendations = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
      } else {
        recommendations = [];
      }
    } catch (e) {
      debugPrint('Recommend error: $e');
      recommendations = [];
    } finally {
      recLoading = false;
      notifyListeners();
    }
  }
}
