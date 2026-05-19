import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> scheduleMealReminders({
    int breakfastHour = 7,
    int breakfastMinute = 0,
    int lunchHour = 12,
    int lunchMinute = 0,
    int dinnerHour = 19,
    int dinnerMinute = 0,
  }) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_breakfast_h', breakfastHour);
    await prefs.setInt('reminder_breakfast_m', breakfastMinute);
    await prefs.setInt('reminder_lunch_h', lunchHour);
    await prefs.setInt('reminder_lunch_m', lunchMinute);
    await prefs.setInt('reminder_dinner_h', dinnerHour);
    await prefs.setInt('reminder_dinner_m', dinnerMinute);
    await prefs.setBool('meal_reminders_enabled', true);

    await _scheduleDaily(
      2001,
      breakfastHour,
      breakfastMinute,
      'Waktunya sarapan',
      'Jaga energi pagimu dengan makanan bergizi.',
    );
    await _scheduleDaily(
      2002,
      lunchHour,
      lunchMinute,
      'Waktunya makan siang',
      'Istirahat sejenak dan konsumsi makanan bergizi.',
    );
    await _scheduleDaily(
      2003,
      dinnerHour,
      dinnerMinute,
      'Waktunya makan malam',
      'Pilih makanan ringan dan mudah dicerna untuk malam.',
    );
  }

  Future<void> cancelMealReminders() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('meal_reminders_enabled', false);
    await _plugin.cancel(2001);
    await _plugin.cancel(2002);
    await _plugin.cancel(2003);
  }

  Future<void> _scheduleDaily(
    int id,
    int hour,
    int minute,
    String title,
    String body,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'meal_reminder_channel',
        'Meal Reminders',
        channelDescription: 'Pengingat waktu makan',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> showExpenseRejected({
    required int userId,
    required double price,
    required double remaining,
  }) async {
    await initialize();
    await _plugin.show(
      3000 + userId,
      'Budget tidak cukup',
      'Harga item Rp ${price.round()} lebih besar dari sisa budget Rp ${remaining.round()}.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_warning_channel',
          'Budget Warning',
          channelDescription:
              'Peringatan saat pengeluaran melewati sisa budget.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
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
