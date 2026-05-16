class NutritionChatMessage {
  final String role;
  final String text;
  final DateTime createdAt;

  const NutritionChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NutritionChatMessage.fromJson(Map<String, dynamic> json) {
    return NutritionChatMessage(
      role: json['role']?.toString() ?? 'assistant',
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
