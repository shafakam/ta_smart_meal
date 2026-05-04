class Expense {
  final int id;
  final String name;
  final String category;
  final double price;
  final String date;
  final int userId; // <--- PASTIKAN ADA INI
  int isWeekly;

  Expense({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.date,
    required this.userId, // <--- DAN INI
    this.isWeekly = 0,
  });

  // Pastikan toMap juga mengirim userId
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'date': date,
      'userId': userId, // <--- DAN INI
      'isWeekly': isWeekly,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      price: map['price'],
      date: map['date'],
      userId: map['userId'], // <--- DAN INI
      isWeekly: map['isWeekly'] ?? 0,
    );
  }
}