import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../services/ai_service.dart';
import '../services/meal_storage_service.dart';

class RecommendationProvider with ChangeNotifier {
  final AIService _aiService = AIService();
  final MealStorageService _mealStorage = MealStorageService();
  List<Meal> _recommendedMeals = [];
  List<Meal> _weeklyPlan = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Meal> get recommendedMeals => _recommendedMeals;
  List<Meal> get weeklyPlan => _weeklyPlan;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRecommendations(
      {required double budget,
      required double targetCalories,
      required String dietType}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _recommendedMeals = await _aiService.getSmartRecommendations(
        budget: budget,
        targetCalories: targetCalories,
        dietType: dietType,
      );
      generateWeeklyPlan();
    } catch (e) {
      _recommendedMeals = [];
      _weeklyPlan = [];
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }

  void generateWeeklyPlan() {
    final byTime = <String, Meal>{};
    for (final meal in _recommendedMeals) {
      final time = _normalizeMealTime(meal.mealTime);
      byTime.putIfAbsent(time, () => meal);
    }
    _weeklyPlan = [
      if (byTime['Breakfast'] != null) byTime['Breakfast']!,
      if (byTime['Lunch'] != null) byTime['Lunch']!,
      if (byTime['Dinner'] != null) byTime['Dinner']!,
      ..._recommendedMeals.where((meal) => !byTime.containsValue(meal)).take(4),
    ].take(7).toList();
    notifyListeners();
  }

  Future<void> saveMeal(Meal meal) async {
    await _mealStorage.saveMeal(meal);
  }

  Future<int> applyWeeklyPlan() async {
    for (final meal in _weeklyPlan) {
      await _mealStorage.saveMeal(meal);
    }
    return _mealStorage.applyMealsToFirstEmptySlots(_weeklyPlan);
  }

  String _normalizeMealTime(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('breakfast') || lower.contains('pagi')) {
      return 'Breakfast';
    }
    if (lower.contains('lunch') || lower.contains('siang')) {
      return 'Lunch';
    }
    if (lower.contains('dinner') ||
        lower.contains('malam') ||
        lower.contains('sore')) {
      return 'Dinner';
    }
    return 'Lunch';
  }
}
