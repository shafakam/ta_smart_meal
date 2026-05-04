class Meal {
  final String id;
  final String name;
  final String description;
  final double price;
  final int calories;
  final String dietType;
  final String imageUrl;
  final int matchPercentage;
  final List<String> ingredients;
  final List<String> steps;
  final String mealTime;

  Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.calories,
    required this.dietType,
    required this.imageUrl,
    required this.matchPercentage,
    this.ingredients = const [],
    this.steps = const [],
    this.mealTime = '',
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: _number(json['price']).toDouble(),
      calories: _number(json['calories']).toInt(),
      dietType: json['dietType']?.toString() ?? '',
      imageUrl: _imageUrl(json['imageUrl']),
      matchPercentage: _number(json['matchPercentage'], fallback: 100).toInt(),
      ingredients: _stringList(json['ingredients']),
      steps: _stringList(json['steps']),
      mealTime: json['mealTime']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'calories': calories,
      'dietType': dietType,
      'imageUrl': imageUrl,
      'matchPercentage': matchPercentage,
      'ingredients': ingredients,
      'steps': steps,
      'mealTime': mealTime,
    };
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    return [];
  }

  static num _number(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    if (value is String)
      return num.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? fallback;
    return fallback;
  }

  static String _imageUrl(dynamic value) {
    final url = value?.toString().trim() ?? '';
    return url.isEmpty ? 'https://via.placeholder.com/150' : url;
  }
}
