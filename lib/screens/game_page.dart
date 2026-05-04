import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/meal.dart';
import '../services/meal_storage_service.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _mealStorage = MealStorageService();
  final _rng = Random();
  final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  List<Meal> _savedMeals = [];
  List<Meal> _pickedMeals = [];
  bool _isLoading = true;
  int _targetBudget = 75000;
  int _targetCalories = 1200;

  @override
  void initState() {
    super.initState();
    _loadSavedMeals();
  }

  Future<void> _loadSavedMeals() async {
    final meals = await _mealStorage.getSavedMeals();
    if (!mounted) return;
    setState(() {
      _savedMeals = meals;
      _isLoading = false;
    });
  }

  void _startBudgetSprint() {
    if (_savedMeals.isEmpty) return;
    final shuffled = [..._savedMeals]..shuffle(_rng);
    final count = min(3, shuffled.length);
    setState(() {
      _targetBudget = 50000 + _rng.nextInt(70001);
      _targetCalories = 900 + _rng.nextInt(701);
      _pickedMeals = shuffled.take(count).toList();
    });
  }

  double get _totalPrice =>
      _pickedMeals.fold(0, (sum, meal) => sum + meal.price);

  int get _totalCalories =>
      _pickedMeals.fold(0, (sum, meal) => sum + meal.calories);

  bool get _isWinning =>
      _pickedMeals.isNotEmpty &&
      _totalPrice <= _targetBudget &&
      _totalCalories >= _targetCalories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        title: const Text(
          "Meal Games",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSavedMeals,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 16),
                  _buildChallengeCard(),
                  const SizedBox(height: 16),
                  _buildResultCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_score, color: Colors.green.shade700),
              const SizedBox(width: 10),
              const Text(
                "Budget Sprint",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _savedMeals.isEmpty
                ? "Simpan menu dari halaman Saran dulu supaya game ini bisa dimainkan."
                : "Game ini mengacak menu tersimpan dan menilai apakah kombinasi harianmu hemat tapi tetap cukup kalori.",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Target Challenge",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statTile("Budget", _money.format(_targetBudget)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile("Kalori", "$_targetCalories kcal"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savedMeals.isEmpty ? null : _startBudgetSprint,
              icon: const Icon(Icons.shuffle),
              label: const Text("Mulai Sprint"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (_pickedMeals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text("Tekan Mulai Sprint untuk mengacak menu."),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isWinning ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isWinning ? "Challenge berhasil" : "Belum lolos challenge",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color:
                  _isWinning ? Colors.green.shade700 : Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ..._pickedMeals.map(
            (meal) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: const Icon(Icons.restaurant_menu, color: Colors.green),
              ),
              title: Text(meal.name),
              subtitle: Text("${meal.calories} kcal"),
              trailing: Text(_money.format(meal.price)),
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: _statTile("Total", _money.format(_totalPrice))),
              const SizedBox(width: 10),
              Expanded(child: _statTile("Kalori", "$_totalCalories kcal")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
