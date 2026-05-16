class NutritionInsight {
  final double averageCalories;
  final double calorieDelta;
  final List<int> dailyCalories;
  final List<double> weightProgress;
  final String mostFrequentFood;
  final List<String> habitWarnings;
  final List<String> recommendations;
  final String summary;
  final double predictedWeightChange;

  const NutritionInsight({
    required this.averageCalories,
    required this.calorieDelta,
    required this.dailyCalories,
    required this.weightProgress,
    required this.mostFrequentFood,
    required this.habitWarnings,
    required this.recommendations,
    required this.summary,
    required this.predictedWeightChange,
  });
}
