import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/recommendation_providers.dart';
import '../models/meal.dart';

class SaranMenuPage extends StatefulWidget {
  const SaranMenuPage({super.key});

  @override
  State<SaranMenuPage> createState() => _SaranMenuPageState();
}

class _SaranMenuPageState extends State<SaranMenuPage> {
  double _budget = 50000;
  double _calories = 600;
  String _dietType = 'Balanced';
  String _currentCurrency = 'IDR';
  double _exchangeRate = 1.0;

  NumberFormat get formatter => NumberFormat.currency(
        locale: _currentCurrency == 'IDR' ? 'id_ID' : 'en_US',
        symbol: _currentCurrency == 'IDR'
            ? 'Rp '
            : (_currentCurrency == 'USD' ? '\$ ' : 'EUR '),
        decimalDigits: _currentCurrency == 'IDR' ? 0 : 2,
      );

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final currency = prefs.getString('user_currency') ?? 'IDR';
    var rate = 1.0;

    if (currency != 'IDR') {
      final apiKey = dotenv.get('CURRENCY_API_KEY', fallback: '');
      if (apiKey.isNotEmpty) {
        try {
          final url = Uri.parse(
              'https://v6.exchangerate-api.com/v6/$apiKey/pair/IDR/$currency');
          final response =
              await http.get(url).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            rate = (data['conversion_rate'] as num).toDouble();
          }
        } catch (e) {
          debugPrint("Currency API Error: $e");
          rate = currency == 'USD' ? 0.000062 : 0.000057;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _currentCurrency = currency;
      _exchangeRate = rate;
    });
  }

  String _formatMoney(double amountIdr) {
    return formatter.format(amountIdr * _exchangeRate);
  }

  @override
  Widget build(BuildContext context) {
    final recProv = context.watch<RecommendationProvider>();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER PINK
            _buildHeader(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CARD PREFERENCES
                  _buildPreferenceCard(recProv),

                  const SizedBox(height: 30),
                  const Text("Recommended for You",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  // LIST MEAL RECOMMENDED
                  if (recProv.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (recProv.recommendedMeals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        recProv.errorMessage ??
                            "Belum ada rekomendasi. Atur preferensi lalu generate menu.",
                        style: TextStyle(
                          color: recProv.errorMessage == null
                              ? Colors.grey
                              : Colors.redAccent,
                        ),
                      ),
                    )
                  else
                    ...recProv.recommendedMeals
                        .map((meal) => _buildMealCard(meal)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text("AI Recommendations",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Text("Personalized meal suggestions based on your preferences",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildPreferenceCard(RecommendationProvider prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: Colors.orange),
              SizedBox(width: 10),
              Text("Your Preferences",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSlider("Budget per meal", _budget, 100000,
              (v) => setState(() => _budget = v)),
          _buildSlider("Target calories", _calories, 1500,
              (v) => setState(() => _calories = v)),
          DropdownButtonFormField<String>(
            initialValue: _dietType,
            items: ["Balanced", "Vegan", "Keto", "Low Carb"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _dietType = v!),
            decoration: const InputDecoration(labelText: "Diet Type"),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () async {
                // 1. Ambil akses ke Provider
                final recProv = context.read<RecommendationProvider>();

                // 2. Jalankan fungsi ambil rekomendasi (pastikan nama parameter sama dengan di Provider)
                await recProv.fetchRecommendations(
                  budget: _budget,
                  targetCalories: _calories,
                  dietType: _dietType,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      recProv.recommendedMeals.isEmpty
                          ? recProv.errorMessage ?? "AI belum memberi hasil."
                          : "Rekomendasi menu sudah dibuat.",
                    ),
                  ),
                );
              },
              child: const Text("Generate New Recommendations",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
      String label, double val, double max, Function(double) onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(
                label.contains("Budget")
                    ? _formatMoney(val)
                    : "${val.toInt()} cal",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
            value: val,
            min: 0,
            max: max,
            activeColor: const Color(0xFF8B5CF6),
            onChanged: onChanged),
      ],
    );
  }

  Widget _buildMealCard(Meal meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  meal.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.green.shade50,
                    child:
                        const Icon(Icons.restaurant_menu, color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(meal.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                    Text(meal.description,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 2),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text("${meal.calories} cal",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(_formatMoney(meal.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showRecipe(meal),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text(
                "Lihat Resep",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showRecipe(Meal meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(22),
            children: [
              Text(meal.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(meal.description,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 18),
              const Text("Bahan",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (meal.ingredients.isEmpty)
                const Text("Belum ada detail bahan dari AI.")
              else
                ...meal.ingredients.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, size: 18),
                      title: Text(item),
                    )),
              const SizedBox(height: 16),
              const Text("Cara Masak",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (meal.steps.isEmpty)
                const Text("Belum ada langkah resep dari AI.")
              else
                ...meal.steps.asMap().entries.map((entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                          radius: 12,
                          child: Text("${entry.key + 1}",
                              style: const TextStyle(fontSize: 11))),
                      title: Text(entry.value),
                    )),
            ],
          ),
        );
      },
    );
  }
}
