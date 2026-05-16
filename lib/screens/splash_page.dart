import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, loggedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00A878), Color(0xFF087CA7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset(
                'assets/images/smartbite_logo.png',
                width: 132,
                height: 132,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'SmartBite',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI nutrition and meal planner',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
