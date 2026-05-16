import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../models/nutrition_chat_message.dart';
import '../models/nutrition_insight.dart';
import '../models/nutrition_profile.dart';
import '../services/ai_service.dart';
import '../services/meal_storage_service.dart';
import '../services/nutrition_ml_service.dart';

class RecommendationProvider with ChangeNotifier {
  final AIService _aiService = AIService();
  final MealStorageService _mealStorage = MealStorageService();
  final NutritionMLService _mlService = NutritionMLService();
  List<Meal> _recommendedMeals = [];
  List<Meal> _weeklyPlan = [];
  List<Meal> _savedMeals = [];
  List<NutritionChatMessage> _chatHistory = [];
  NutritionInsight? _insight;
  bool _isLoading = false;
  bool _isChatLoading = false;
  String? _errorMessage;

  List<Meal> get recommendedMeals => _recommendedMeals;
  List<Meal> get weeklyPlan => _weeklyPlan;
  List<NutritionChatMessage> get chatHistory => _chatHistory;
  NutritionInsight? get insight => _insight;
  bool get isLoading => _isLoading;
  bool get isChatLoading => _isChatLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRecommendations({required NutritionProfile profile}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _savedMeals = await _mealStorage.getSavedMeals();
      _insight = _mlService.analyze(profile: profile, savedMeals: _savedMeals);
      _recommendedMeals = await _aiService.getSmartRecommendations(
        profile: profile,
        contextSummary: _buildContextSummary(),
        avoidMeals: _savedMeals,
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

  Future<void> refreshInsight(NutritionProfile profile) async {
    _savedMeals = await _mealStorage.getSavedMeals();
    _insight = _mlService.analyze(profile: profile, savedMeals: _savedMeals);
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
      ..._recommendedMeals.where((meal) => !byTime.containsValue(meal)).take(2),
    ].take(3).toList();
    notifyListeners();
  }

  Future<void> saveMeal(Meal meal) async {
    await _mealStorage.saveMeal(meal);
    _savedMeals = await _mealStorage.getSavedMeals();
    notifyListeners();
  }

  Future<int> applyDailyPlan() async {
    for (final meal in _weeklyPlan) {
      await _mealStorage.saveMeal(meal);
    }
    return _mealStorage.applyDayPlanToFirstEmptyDay(_weeklyPlan);
  }

  Future<void> askAssistant({
    required NutritionProfile profile,
    required String question,
  }) async {
    if (question.trim().isEmpty) return;
    _isChatLoading = true;
    _chatHistory = [
      ..._chatHistory,
      NutritionChatMessage(
        role: 'user',
        text: question.trim(),
        createdAt: DateTime.now(),
      ),
    ];
    notifyListeners();

    _savedMeals = await _mealStorage.getSavedMeals();
    _insight ??= _mlService.analyze(profile: profile, savedMeals: _savedMeals);
    final answer = await _aiService.askNutritionAssistant(
      profile: profile,
      meals: _savedMeals,
      history: _chatHistory,
      question: question,
      insightSummary: _insight?.summary ?? _buildContextSummary(),
    );

    _chatHistory = [
      ..._chatHistory,
      NutritionChatMessage(
        role: 'assistant',
        text: answer,
        createdAt: DateTime.now(),
      ),
    ];
    _isChatLoading = false;
    notifyListeners();
  }

  String _buildContextSummary() {
    if (_insight == null) return 'Belum ada insight tersimpan.';
    return '${_insight!.summary} Makanan sering: ${_insight!.mostFrequentFood}. Warning: ${_insight!.habitWarnings.join(', ')}.';
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
