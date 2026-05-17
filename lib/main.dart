import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_ta/providers/budget_providers.dart';
import 'package:smart_meal_ta/providers/recommendation_providers.dart';

// Import Services
import 'services/database_service.dart';
import 'services/notification_service.dart';
// Import Providers
import 'providers/login_providers.dart';

// Import Screens
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/account_setting_page.dart';
import 'screens/register_page.dart';
import 'screens/feedback_page.dart';
import 'screens/splash_page.dart';

Future<void> main() async {
  // 1. WAJIB: Pastikan binding mesin Flutter sudah siap sebelum akses plugin (Native)
  // Ini adalah obat utama untuk PlatformException / Channel Error
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load Environment Variables (.env)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Environment loaded successfully");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }

  // 3. Inisialisasi Database (SQLite)
  // Pastikan database siap sebelum UI dibangun
  final dbService = DatabaseService();
  await dbService.database;
  await NotificationService.instance.initialize();

  // 4. Jalankan Aplikasi dengan MultiProvider
  runApp(
    MultiProvider(
      providers: [
        // Inisialisasi LoginProvider
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),

        /* 
           Si B bisa menambahkan provider di sini nanti, contoh:
           ChangeNotifierProvider(create: (_) => MealProvider()),
        */
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartBite',

      // Tema Aplikasi
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        // Tambahkan font atau styling tambahan di sini jika perlu
      ),

      // Routing
      // Tip: Gunakan konstanta String untuk rute jika aplikasi semakin besar
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/account_settings': (context) => const AccountSettingsPage(),
        '/feedback': (context) => const FeedbackPage(),
      },
    );
  }
}
