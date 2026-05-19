import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatStorageService {
  static const _key = 'ai_chat_history';

  Future<List<Map<String,dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw==null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e)=> Map<String,dynamic>.from(e)).toList();
  }

  Future<void> save(List<Map<String,dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }
}
