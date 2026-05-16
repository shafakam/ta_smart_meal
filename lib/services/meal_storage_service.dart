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
      final dayMeals = Map<String, dynamic>.from(meals as Map);
      for (final type in ['Breakfast', 'Lunch', 'Dinner']) {
        final meal = dayMeals[type];
        if (meal is Map) {
          dayMeals[type] =
              _normalizePlannerMeal(Map<String, dynamic>.from(meal));
        }
      }
      return MapEntry(date, dayMeals);
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

  Future<int> applyDayPlanToFirstEmptyDay(List<Meal> meals,
      {DateTime? weekStart}) async {
    final dayPlan = <String, Meal>{};
    final leftovers = <Meal>[];

    for (final meal in meals) {
      final type = _normalizeMealTime(meal.mealTime);
      if (type.isNotEmpty && !dayPlan.containsKey(type)) {
        dayPlan[type] = meal;
      } else {
        leftovers.add(meal);
      }
    }

    for (final type in ['Breakfast', 'Lunch', 'Dinner']) {
      if (!dayPlan.containsKey(type) && leftovers.isNotEmpty) {
        dayPlan[type] = leftovers.removeAt(0);
      }
    }

    if (dayPlan.isEmpty) return 0;

    final store = await getPlannerStore();
    final start = weekStart ?? _startOfCurrentWeek();

    for (var day = 0; day < 7; day++) {
      final dateKey =
          DateFormat('yyyy-MM-dd').format(start.add(Duration(days: day)));
      final dayMeals = store.putIfAbsent(
          dateKey, () => {'Breakfast': null, 'Lunch': null, 'Dinner': null});
      final canUseDay = dayPlan.keys.every((type) => dayMeals[type] == null);

      if (!canUseDay) continue;

      for (final entry in dayPlan.entries) {
        dayMeals[entry.key] = mealToPlannerMap(entry.value);
      }
      await savePlannerStore(store);
      return dayPlan.length;
    }

    return 0;
  }

  Map<String, dynamic> mealToPlannerMap(Meal meal) {
    return {
      'id': meal.id,
      'nama': meal.name,
      'cal': meal.calories,
      'harga': _normalizePrice(meal.price),
      'image_url': _safeImageUrl(meal.imageUrl),
      'description': meal.description,
      'ingredients': meal.ingredients,
      'steps': meal.steps,
    };
  }

  Map<String, dynamic> _normalizePlannerMeal(Map<String, dynamic> meal) {
    meal['harga'] = _normalizePrice((meal['harga'] as num?)?.toDouble() ?? 0);
    meal['image_url'] = _safeImageUrl(meal['image_url']?.toString() ?? '');
    return meal;
  }

  double _normalizePrice(double price) {
    if (price > 0 && price < 1000) return price * 1000;
    return price;
  }

  String _safeImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed.contains('example.com')) return '';
    return trimmed;
  }

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday % 7;
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysToSubtract));
  }

  String _normalizeMealTime(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('breakfast') || lower.contains('pagi')) {
      return 'Breakfast';
    }
    if (lower.contains('lunch') || lower.contains('siang')) return 'Lunch';
    if (lower.contains('dinner') ||
        lower.contains('malam') ||
        lower.contains('sore')) {
      return 'Dinner';
    }
    return '';
  }
}
