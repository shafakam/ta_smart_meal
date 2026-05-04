import 'package:smart_meal_ta/models/meal.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/budget.dart';
import '../models/expense.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'smart_meal_planner.db');

    return await openDatabase(path,
        version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        email TEXT UNIQUE,
        password TEXT, 
        profile_image TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY,
        weeklyLimit REAL,
        spent REAL,
        remaining REAL,
        userId INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        price REAL,
        date TEXT,
        userId INTEGER,
        isWeekly INTEGER DEFAULT 0 
      )
    ''');

    await db.execute('''
      CREATE TABLE planner(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day TEXT,
        mealName TEXT,
        calories INTEGER,
        price REAL
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planner(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          day TEXT,
          mealName TEXT,
          calories INTEGER,
          price REAL
        )
      ''');
    }
  }

  // --- FUNGSI USER ---
  Future<int> registerUser(
      String username, String email, String password) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ? OR username = ?',
      whereArgs: [email, username],
    );

    if (result.isNotEmpty) {
      throw Exception("Email atau username sudah terdaftar.");
    }

    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);

    return await db.insert('users', {
      'username': username,
      'email': email,
      'password': digest.toString(),
    });
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    Database db = await database;
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    String hashedPassword = digest.toString();

    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword],
    );

    if (results.isNotEmpty) return results.first;
    throw Exception("Email atau password salah.");
  }

  // --- FUNGSI BUDGET ---
  Future<List<Budget>> getBudgetsByUserId(int userId) async {
    final db = await database;
    var result = await db.query(
      'budgets',
      where: 'userId = ?', // SUDAH DIPERBAIKI: userId (tanpa underscore)
      whereArgs: [userId],
    );

    return result.isNotEmpty
        ? result.map((e) => Budget.fromMap(e)).toList()
        : [];
  }

  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return await db.insert('budgets', budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  // --- FUNGSI EXPENSE ---
  Future<List<Expense>> getExpensesByUserId(int userId) async {
    final db = await database;
    var result = await db.query(
      'expenses',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return result.isNotEmpty
        ? result.map((e) => Expense.fromMap(e)).toList()
        : [];
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // FUNGSI PENTING: Untuk ganti status mingguan (Tambah/Hapus)
  Future<int> updateExpenseStatus(int id, int isWeekly) async {
    final db = await database;
    return await db.update(
      'expenses',
      {'isWeekly': isWeekly},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tambahkan di dalam class DatabaseService
  Future<bool> checkIfDayIsFull(String day) async {
    final db = await database;
    // Contoh: dianggap penuh jika sudah ada 3 jadwal makan (Breakfast, Lunch, Dinner)
    final List<Map<String, dynamic>> maps = await db.query(
      'planner',
      where: 'day = ?',
      whereArgs: [day],
    );
    return maps.length >= 3;
  }

  Future<void> insertToPlanner(String day, Meal meal) async {
    final db = await database;
    await db.insert('planner', {
      'day': day,
      'mealName': meal.name,
      'calories': meal.calories,
      'price': meal.price,
    });
  }
}
