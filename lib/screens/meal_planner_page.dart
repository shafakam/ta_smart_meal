import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../models/meal.dart';
import '../services/meal_storage_service.dart';

class MealPlannerPage extends StatefulWidget {
  const MealPlannerPage({super.key});

  @override
  State<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage> {
  // --- STATE ---
  int _weekOffset = 0;
  bool _isLoading = true;
  String _currentCurrency = 'IDR';
  String _selectedTimeZone = 'WIB';
  double _exchangeRate = 1.0;

  final MealStorageService _mealStorage = MealStorageService();
  Map<String, Map<String, dynamic>> _savedMealsStore = {};
  List<Meal> _savedMealsLibrary = [];
  List<Map<String, dynamic>> _weeklyMeals = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadUserPreferences();
    });
  }

  // --- LOGIKA LOAD DATA & KONVERSI ---
  Future<void> _loadUserPreferences() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Ambil data kurensi terbaru dari SharedPreferences

    String currency = prefs.getString('user_currency') ?? 'IDR';
    String timeZone = prefs.getString('user_timezone') ?? 'WIB';
    String apiKey = dotenv.get('CURRENCY_API_KEY', fallback: "");

    double rate = 1.0;

    // Fetch Kurs API jika mata uang bukan IDR
    if (currency != 'IDR' && apiKey.isNotEmpty) {
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
        debugPrint("API Error: $e");
        // Fallback jika API gagal
        rate = (currency == 'USD') ? 0.000062 : 0.000057;
      }
    }

    if (mounted) {
      setState(() {
        _currentCurrency = currency;
        _selectedTimeZone = timeZone;
        _exchangeRate = rate;
      });
      _savedMealsStore = await _mealStorage.getPlannerStore();
      _savedMealsLibrary = await _mealStorage.getSavedMeals();
      _loadWeekData();
    }
  }

  void _loadWeekData() {
    setState(() {
      _isLoading = true;
      _weeklyMeals = List.generate(7, (index) {
        DateTime date = _getStartOfTargetWeek().add(Duration(days: index));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        Map<String, dynamic> existingData = _savedMealsStore[dateKey] ??
            {
              'Breakfast': null,
              'Lunch': null,
              'Dinner': null,
            };

        return {
          'hari': DateFormat('EEEE', 'id_ID').format(date),
          'tanggal': DateFormat('dd MMMM', 'id_ID').format(date),
          'dateKey': dateKey,
          'total_cal': 0,
          'total_harga': 0.0,
          'meals': Map<String, dynamic>.from(existingData),
        };
      });

      for (var i = 0; i < 7; i++) {
        _calculateTotalsLocally(i);
      }
      _isLoading = false;
    });
  }

  DateTime _getStartOfTargetWeek() {
    DateTime now = _nowForSelectedTimeZone();
    int daysToSubtract = now.weekday % 7;
    return now
        .subtract(Duration(days: daysToSubtract))
        .add(Duration(days: _weekOffset * 7));
  }

  DateTime _nowForSelectedTimeZone() {
    final utc = DateTime.now().toUtc();
    final offsetHours = switch (_selectedTimeZone) {
      'WITA' => 8,
      'WIT' => 9,
      'London' => 1,
      _ => 7,
    };
    return utc.add(Duration(hours: offsetHours));
  }

  Future<void> _persistPlanner() async {
    await _mealStorage.savePlannerStore(_savedMealsStore);
  }

  void _addSavedMeal(int dayIndex, String type, Meal meal) {
    String dateKey = _weeklyMeals[dayIndex]['dateKey'];
    final mealData = _mealStorage.mealToPlannerMap(meal);

    setState(() {
      if (!_savedMealsStore.containsKey(dateKey)) {
        _savedMealsStore[dateKey] = {
          'Breakfast': null,
          'Lunch': null,
          'Dinner': null
        };
      }

      _savedMealsStore[dateKey]![type] = mealData;
      _weeklyMeals[dayIndex]['meals'][type] = mealData;
      _calculateTotalsLocally(dayIndex);
    });
    _persistPlanner();
  }

  void _calculateTotalsLocally(int dayIndex) {
    int cal = 0;
    double price = 0;
    _weeklyMeals[dayIndex]['meals'].forEach((k, v) {
      if (v != null) {
        cal += (v['cal'] as num).toInt();
        price += (v['harga'] as num).toDouble() * _exchangeRate;
      }
    });
    _weeklyMeals[dayIndex]['total_cal'] = cal;
    _weeklyMeals[dayIndex]['total_harga'] = price;
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: _currentCurrency == 'IDR' ? 'id_ID' : 'en_US',
      symbol: _currentCurrency == 'IDR'
          ? 'Rp '
          : (_currentCurrency == 'USD' ? '\$ ' : '€ '),
      decimalDigits: _currentCurrency == 'IDR' ? 0 : 2,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Meal Planner",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: _loadUserPreferences)
        ],
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF2979FF)]))),
      ),
      body: Column(
        children: [
          _buildWeekNavigator(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _weeklyMeals.length,
                    itemBuilder: (context, index) =>
                        _buildDayCard(index, currencyFormat),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () {
                setState(() {
                  _weekOffset--;
                  _loadWeekData();
                });
              }),
          Column(children: [
            Text(_weekOffset == 0 ? "Minggu Ini" : "Minggu $_weekOffset",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              _weeklyMeals.isNotEmpty
                  ? "${_weeklyMeals[0]['tanggal']} - ${_weeklyMeals[6]['tanggal']}"
                  : "Memuat...",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]),
          IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20),
              onPressed: () {
                setState(() {
                  _weekOffset++;
                  _loadWeekData();
                });
              }),
        ],
      ),
    );
  }

  Widget _buildDayCard(int index, NumberFormat cur) {
    final data = _weeklyMeals[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Column(children: [
        ListTile(
          title: Text(data['hari'],
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(data['tanggal']),
          trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${data['total_cal']} kcal",
                    style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(cur.format(data['total_harga']),
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildMealRow(index, "Breakfast", data['meals']['Breakfast'], cur),
            const SizedBox(height: 12),
            _buildMealRow(index, "Lunch", data['meals']['Lunch'], cur),
            const SizedBox(height: 12),
            _buildMealRow(index, "Dinner", data['meals']['Dinner'], cur),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMealRow(
      int dayIdx, String type, dynamic meal, NumberFormat cur) {
    return Row(children: [
      SizedBox(
          width: 75,
          child: Text(type,
              style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(
          child: meal == null
              ? OutlinedButton(
                  onPressed: () => _showSearch(dayIdx, type),
                  child: const Text("+ Tambah", style: TextStyle(fontSize: 12)))
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(meal['image_url'],
                            width: 35, height: 35, fit: BoxFit.cover)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(meal['nama'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                              "${meal['cal']} kcal - ${cur.format((meal['harga'] as num).toDouble() * _exchangeRate)}",
                              style: const TextStyle(fontSize: 10)),
                        ])),
                    GestureDetector(
                      onTap: () {
                        final dateKey = _weeklyMeals[dayIdx]['dateKey'];
                        setState(() {
                          _weeklyMeals[dayIdx]['meals'][type] = null;
                          if (_savedMealsStore[dateKey] != null) {
                            _savedMealsStore[dateKey]![type] = null;
                          }
                          _calculateTotalsLocally(dayIdx);
                        });
                        _persistPlanner();
                      },
                      child: const Icon(Icons.cancel,
                          size: 18, color: Colors.redAccent),
                    )
                  ]),
                )),
    ]);
  }

  Future<void> _showSearch(int dayIdx, String type) async {
    _savedMealsLibrary = await _mealStorage.getSavedMeals();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: _SearchWidget(
          savedMeals: _savedMealsLibrary,
          onSelectSavedMeal: (meal) => _addSavedMeal(dayIdx, type, meal),
        ),
      ),
    );
  }
}

class _SearchWidget extends StatefulWidget {
  final List<Meal> savedMeals;
  final Function(Meal) onSelectSavedMeal;
  const _SearchWidget({
    required this.savedMeals,
    required this.onSelectSavedMeal,
  });
  @override
  State<_SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<_SearchWidget> {
  final TextEditingController _ctrl = TextEditingController();
  Meal? _randomMeal;
  bool _shakeMode = false;
  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _shakeSubscription = accelerometerEvents.listen((event) {
      final force = event.x.abs() + event.y.abs() + event.z.abs();
      final canShakeAgain =
          DateTime.now().difference(_lastShakeAt) > const Duration(seconds: 1);
      if (_shakeMode &&
          force > 28 &&
          canShakeAgain &&
          widget.savedMeals.isNotEmpty) {
        _lastShakeAt = DateTime.now();
        _shakeRandomMenu();
      }
    });
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _shakeRandomMenu() {
    if (widget.savedMeals.isEmpty) return;
    setState(() {
      _randomMeal =
          widget.savedMeals[Random().nextInt(widget.savedMeals.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim().toLowerCase();
    final filteredMeals = query.isEmpty
        ? widget.savedMeals
        : widget.savedMeals
            .where((meal) =>
                meal.name.toLowerCase().contains(query) ||
                meal.description.toLowerCase().contains(query) ||
                meal.dietType.toLowerCase().contains(query))
            .toList();

    return Column(children: [
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.savedMeals.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _shakeMode = true;
                        _randomMeal = null;
                      });
                    },
              icon: const Icon(Icons.casino_outlined),
              label: Text(_shakeMode ? "Shake HP Sekarang" : "Aktifkan Shake"),
            ),
          ),
        ],
      ),
      if (_shakeMode && _randomMeal == null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            "Gerakkan HP untuk memilih menu random.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      if (_randomMeal != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_randomMeal!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              TextButton(
                onPressed: () {
                  widget.onSelectSavedMeal(_randomMeal!);
                  Navigator.pop(context);
                },
                child: const Text("Pilih"),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _ctrl,
        decoration: InputDecoration(
            hintText: "Cari menu yang sudah disimpan...",
            prefixIcon: const Icon(Icons.search),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 20),
      Expanded(
        child: widget.savedMeals.isEmpty
            ? const Center(
                child: Text(
                    "Belum ada menu tersimpan. Simpan dulu dari halaman Saran Menu."),
              )
            : filteredMeals.isEmpty
                ? const Center(child: Text("Menu tersimpan tidak ditemukan"))
                : ListView.builder(
                    itemCount: filteredMeals.length,
                    itemBuilder: (context, i) {
                      final meal = filteredMeals[i];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(
                            meal.imageUrl,
                            width: 45,
                            height: 45,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.restaurant_menu),
                          ),
                        ),
                        title: Text(meal.name,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text("${meal.calories} kcal"),
                        onTap: () {
                          widget.onSelectSavedMeal(meal);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
      ),
    ]);
  }
}
