import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

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
    // Mendapatkan path direktori database pada perangkat
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'smart_meal_planner.db');

    // MENCETAK LOKASI DATABASE KE CONSOLE (Cek Debug Console VS Code)
    // Ini membantu kamu menemukan lokasi file di Device Explorer
    print("-----------------------------------------");
    print("LOKASI DATABASE KAMU: $path");
    print("-----------------------------------------");

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // Tabel User
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        email TEXT UNIQUE,
        password TEXT, 
        profile_image TEXT
      )
    ''');

    // Tabel Budget
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        weekly_limit REAL,
        spent REAL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Tabel Meal Planner
    await db.execute('''
      CREATE TABLE meal_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        meal_name TEXT,
        calories INTEGER,
        price REAL,
        date TEXT,
        type TEXT, 
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  // Registrasi: Simpan password yang sudah di-hash
  Future<int> registerUser(String username, String email, String password) async {
    final db = await database;
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    
    return await db.insert('users', {
      'username': username,
      'email': email,
      'password': digest.toString(),
    });
  }

  // Login: Mencocokkan EMAIL & password yang dimasukkan
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    Database db = await database;

    // 1. Ubah password input menjadi hash untuk dibandingkan dengan yang ada di DB
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    String hashedPassword = digest.toString();

    // 2. Cari berdasarkan email dan password yang sudah di-hash
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedPassword],
    );

    return results.isNotEmpty ? results.first : null;
  }
}
