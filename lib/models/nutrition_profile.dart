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
}
