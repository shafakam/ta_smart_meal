import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal.dart';

class MealStorageService {
  static const _savedMealsKey = 'saved_ai_meals';
  static const _plannerKey = 'meal_planner_store';

  Future<List<Meal>> getSavedMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedMealsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List;
    return decoded
        .whereType<Map>()
        .map((item) => Meal.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveMeal(Meal meal) async {
    final meals = await getSavedMeals();
    final index = meals.indexWhere((item) =>
        item.id == meal.id ||
        item.name.toLowerCase() == meal.name.toLowerCase());
    if (index >= 0) {
      meals[index] = meal;
    } else {
      meals.add(meal);
    }
    await _saveMeals(meals);
  }

  Future<void> _saveMeals(List<Meal> meals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedMealsKey,
        jsonEncode(meals.map((meal) => meal.toJson()).toList()));
  }

  Future<Map<String, Map<String, dynamic>>> getPlannerStore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plannerKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((date, meals) {
      return MapEntry(date, Map<String, dynamic>.from(meals as Map));
    });
  }

  Future<void> savePlannerStore(Map<String, Map<String, dynamic>> store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plannerKey, jsonEncode(store));
  }

  Future<int> applyMealsToFirstEmptySlots(List<Meal> meals,
      {DateTime? weekStart}) async {
    final store = await getPlannerStore();
    final start = weekStart ?? _startOfCurrentWeek();
    var added = 0;

    for (final meal in meals) {
      final preferredType = _normalizeMealTime(meal.mealTime);
      var placed = false;

      for (var day = 0; day < 7 && !placed; day++) {
        final dateKey =
            DateFormat('yyyy-MM-dd').format(start.add(Duration(days: day)));
        final dayMeals = store.putIfAbsent(
            dateKey, () => {'Breakfast': null, 'Lunch': null, 'Dinner': null});
        final candidateTypes = [
          preferredType,
          'Breakfast',
          'Lunch',
          'Dinner',
        ].where((type) => type.isNotEmpty).toSet();

        for (final type in candidateTypes) {
          if (dayMeals[type] == null) {
            dayMeals[type] = mealToPlannerMap(meal);
            added++;
            placed = true;
            break;
          }
        }
      }
    }

    if (added > 0) await savePlannerStore(store);
    return added;
  }

  Map<String, dynamic> mealToPlannerMap(Meal meal) {
    return {
      'id': meal.id,
      'nama': meal.name,
      'cal': meal.calories,
      'harga': meal.price,
      'image_url': meal.imageUrl,
      'description': meal.description,
      'ingredients': meal.ingredients,
      'steps': meal.steps,
    };
  }

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday % 7;
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysToSubtract));
  }

  String _normalizeMealTime(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('breakfast') || lower.contains('pagi'))
      return 'Breakfast';
    if (lower.contains('lunch') || lower.contains('siang')) return 'Lunch';
    if (lower.contains('dinner') ||
        lower.contains('malam') ||
        lower.contains('sore')) return 'Dinner';
    return '';
  }
}
