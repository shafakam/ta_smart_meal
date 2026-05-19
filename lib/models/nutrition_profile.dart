class NutritionProfile {
  final double budget;
  final double targetCalories;
  final String dietType;
  final String activityLevel;
  final String goalType;
  final String eatingPreference;
  final double currentWeight;
  final double targetWeight;
  final double dailyWaterIntake;
  final double sleepDuration;

  const NutritionProfile({
    required this.budget,
    required this.targetCalories,
    required this.dietType,
    required this.activityLevel,
    required this.goalType,
    required this.eatingPreference,
    required this.currentWeight,
    required this.targetWeight,
    required this.dailyWaterIntake,
    required this.sleepDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'budget': budget,
      'targetCalories': targetCalories,
      'dietType': dietType,
      'activityLevel': activityLevel,
      'goalType': goalType,
      'eatingPreference': eatingPreference,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'dailyWaterIntake': dailyWaterIntake,
      'sleepDuration': sleepDuration,
    };
  }

  factory NutritionProfile.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return NutritionProfile(
      budget: number('budget', 50000),
      targetCalories: number('targetCalories', 600),
      dietType: json['dietType']?.toString() ?? 'Balanced',
      activityLevel: json['activityLevel']?.toString() ?? 'Lightly Active',
      goalType: json['goalType']?.toString() ?? 'Maintain Weight',
      eatingPreference: json['eatingPreference']?.toString() ?? 'Balanced',
      currentWeight: number('currentWeight', 60),
      targetWeight: number('targetWeight', 58),
      dailyWaterIntake: number('dailyWaterIntake', 2),
      sleepDuration: number('sleepDuration', 7),
    );
  }
}
