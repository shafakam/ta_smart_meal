import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_ta/features/ai_nutrition/services/chat_storage_service.dart';

void main() {
  test('ChatStorageService saves and loads history', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = ChatStorageService();
    final messages = [
      {'role': 'user', 'text': 'Hello', 'createdAt': '2026-05-19T00:00:00Z'},
      {'role': 'assistant', 'text': 'Hi there', 'createdAt': '2026-05-19T00:00:01Z'},
    ];

    await storage.save(messages);
    final loaded = await storage.load();

    expect(loaded, messages);
  });
}
