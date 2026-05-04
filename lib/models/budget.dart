class Budget {
  final int id;
  final double weeklyLimit;
  final double spent;
  final double remaining;
  final int userId; // Tambahkan ini

  Budget({
    required this.id,
    required this.weeklyLimit,
    required this.spent,
    required this.remaining,
    required this.userId, // Tambahkan ini
  });

  // Pastikan toMap dan fromMap juga diupdate
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weeklyLimit': weeklyLimit,
      'spent': spent,
      'remaining': remaining,
      'userId': userId, // Tambahkan ini
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      weeklyLimit: map['weeklyLimit'],
      spent: map['spent'],
      remaining: map['remaining'],
      userId: map['userId'], // Tambahkan ini
    );
  }
}