import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showBudgetWarning({
    required int userId,
    required double weeklyLimit,
    required double spent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget_warning_level_$userId';

    if (weeklyLimit <= 0 || spent <= 0) {
      await prefs.remove(key);
      return;
    }

    await initialize();

    final progress = spent / weeklyLimit;
    final level = _warningLevel(progress);

    if (level == 0) {
      await prefs.remove(key);
      return;
    }

    final lastLevel = prefs.getInt(key) ?? 0;
    if (level < lastLevel) {
      await prefs.setInt(key, level);
      return;
    }
    if (level <= lastLevel) return;

    await _plugin.show(
      1000 + userId,
      _titleForLevel(level),
      _bodyForLevel(level, progress),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_warning_channel',
          'Budget Warning',
          channelDescription:
              'Peringatan saat pengeluaran mingguan mendekati batas budget.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    await prefs.setInt(key, level);
  }

  int _warningLevel(double progress) {
    if (progress >= 0.9) return 2;
    if (progress >= 0.8) return 1;
    return 0;
  }

  String _titleForLevel(int level) {
    if (level == 2) return 'Budget mingguan sudah 90%';
    return 'Budget mingguan hampir habis';
  }

  String _bodyForLevel(int level, double progress) {
    final percent = (progress * 100).round();
    if (level == 2) {
      return 'Pengeluaranmu sudah $percent% dari limit. Cek lagi belanja berikutnya.';
    }
    return 'Pengeluaranmu sudah $percent% dari limit. Yuk mulai lebih hemat.';
  }
}
