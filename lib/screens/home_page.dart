import 'package:flutter/material.dart';
// Import semua halaman yang diperlukan
import 'profile_page.dart';
import 'meal_planner_page.dart';
import 'budget_page.dart';
import 'ai_recommendation_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Set ke 1 agar saat pertama buka langsung tampil Meal Planner (Tugas Si B)
  int _selectedIndex = 1;

  // List ini HARUS memiliki 4 item karena BottomNav punya 4 item
  final List<Widget> _pages = [
    const ProfilePage(), // Index 0
    const MealPlannerPage(), // Index 1
    // const BudgetPage(),           // Index 2
    // const AiRecommendationsPage(), // Index 3
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack menjaga state halaman agar tidak reload saat pindah tab
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        // Warna hijau sesuai tema Smart Meal
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Saran',
          ),
        ],
      ),
    );
  }
}
