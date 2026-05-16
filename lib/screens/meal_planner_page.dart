import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  bool _tiltNavigationEnabled = false;
  StreamSubscription<GyroscopeEvent>? _tiltSubscription;
  StreamSubscription<AccelerometerEvent>? _tiltPositionSubscription;
  DateTime _lastTiltAt = DateTime.fromMillisecondsSinceEpoch(0);

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

  @override
  void dispose() {
    _tiltSubscription?.cancel();
    _tiltPositionSubscription?.cancel();
    super.dispose();
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

  void _changeWeek(int delta) {
    _weekOffset += delta;
    _loadWeekData();
  }

  void _toggleTiltNavigation() {
    setState(() => _tiltNavigationEnabled = !_tiltNavigationEnabled);

    if (_tiltNavigationEnabled) {
      _tiltSubscription ??= gyroscopeEventStream().listen(_handleTilt);
      _tiltPositionSubscription ??=
          accelerometerEventStream().listen(_handleTiltPosition);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tilt navigation aktif")),
      );
    } else {
      _tiltSubscription?.cancel();
      _tiltSubscription = null;
      _tiltPositionSubscription?.cancel();
      _tiltPositionSubscription = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tilt navigation nonaktif")),
      );
    }
  }

  void _handleTilt(GyroscopeEvent event) {
    if (!_tiltNavigationEnabled || _isLoading) return;

    final canTiltAgain = DateTime.now().difference(_lastTiltAt) >
        const Duration(milliseconds: 900);
    final strongestTurn = event.y.abs() >= event.x.abs() ? event.y : -event.x;
    if (!canTiltAgain || strongestTurn.abs() < 1.1) return;

    _lastTiltAt = DateTime.now();
    _changeWeek(strongestTurn > 0 ? -1 : 1);
  }

  void _handleTiltPosition(AccelerometerEvent event) {
    if (!_tiltNavigationEnabled || _isLoading) return;

    final canTiltAgain = DateTime.now().difference(_lastTiltAt) >
        const Duration(milliseconds: 900);
    if (!canTiltAgain || event.x.abs() < 5.5) return;

    _lastTiltAt = DateTime.now();
    _changeWeek(event.x > 0 ? -1 : 1);
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
              tooltip: _tiltNavigationEnabled
                  ? "Matikan tilt navigation"
                  : "Aktifkan tilt navigation",
              icon: Icon(
                Icons.screen_rotation_alt,
                color:
                    _tiltNavigationEnabled ? Colors.yellowAccent : Colors.white,
              ),
              onPressed: _toggleTiltNavigation),
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
              onPressed: () => _changeWeek(-1)),
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
              onPressed: () => _changeWeek(1)),
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
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
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
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showPlannerRecipe(meal),
                    child: Row(children: [
                      _buildMealThumbnail(meal['image_url']?.toString() ?? ''),
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
                  ),
                )),
    ]);
  }

  Widget _buildMealThumbnail(String imageUrl) {
    final safeUrl = imageUrl.trim().isEmpty || imageUrl.contains('example.com')
        ? ''
        : imageUrl.trim();
    final fallback = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          Icon(Icons.restaurant_menu, size: 20, color: Colors.green.shade700),
    );

    if (safeUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        safeUrl,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  void _showPlannerRecipe(Map<String, dynamic> meal) {
    final ingredients = _stringListFromPlanner(meal['ingredients']);
    final steps = _stringListFromPlanner(meal['steps']);

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
              Text(meal['nama']?.toString() ?? 'Menu',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "${meal['cal']} kcal - ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format((meal['harga'] as num).toDouble())}",
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w600),
              ),
              if ((meal['description']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(meal['description'].toString(),
                    style: const TextStyle(color: Colors.grey)),
              ],
              const SizedBox(height: 18),
              const Text("Bahan",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (ingredients.isEmpty)
                const Text("Belum ada detail bahan.")
              else
                ...ingredients.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, size: 18),
                      title: Text(item),
                    )),
              const SizedBox(height: 16),
              const Text("Cara Masak",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (steps.isEmpty)
                const Text("Belum ada langkah resep.")
              else
                ...steps.asMap().entries.map((entry) => ListTile(
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

  List<String> _stringListFromPlanner(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    return [];
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
  final List<Meal> _mealDbMeals = [];
  Meal? _randomMeal;
  bool _shakeMode = false;
  bool _includeOnlineSearch = false;
  bool _isSearchingMealDb = false;
  String? _mealDbError;
  String? _randomMealError;
  Timer? _searchDebounce;
  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _shakeSubscription = accelerometerEventStream().listen((event) {
      final force = event.x.abs() + event.y.abs() + event.z.abs();
      final canShakeAgain =
          DateTime.now().difference(_lastShakeAt) > const Duration(seconds: 1);
      if (_shakeMode && force > 28 && canShakeAgain) {
        _lastShakeAt = DateTime.now();
        _pickRandomSavedMeal();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _shakeSubscription?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _pickRandomSavedMeal() {
    if (widget.savedMeals.isEmpty) {
      setState(() {
        _randomMeal = null;
        _randomMealError =
            'Belum ada menu tersimpan. Simpan menu dari AI dulu.';
      });
      return;
    }

    final shuffled = [...widget.savedMeals]..shuffle();
    setState(() {
      _randomMeal = shuffled.first;
      _randomMealError = null;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (_includeOnlineSearch) {
      _searchDebounce = Timer(const Duration(milliseconds: 450), () {
        _searchMealDb(value);
      });
    }
    setState(() {});
  }

  Future<void> _searchMealDb(String rawQuery) async {
    final query = rawQuery.trim();
    final token = ++_searchToken;

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _mealDbMeals.clear();
        _mealDbError = null;
        _isSearchingMealDb = false;
      });
      return;
    }

    setState(() {
      _isSearchingMealDb = true;
      _mealDbError = null;
    });

    try {
      final url = Uri.https(
        'www.themealdb.com',
        '/api/json/v1/1/search.php',
        {'s': query},
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (token != _searchToken || !mounted) return;
      if (response.statusCode != 200) {
        throw Exception('MealDB gagal merespons');
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final mealsRaw = decoded['meals'] as List?;
      final meals = mealsRaw == null
          ? <Meal>[]
          : mealsRaw
              .whereType<Map>()
              .map((item) => _mealFromMealDb(Map<String, dynamic>.from(item)))
              .where((meal) => meal.name.isNotEmpty)
              .toList();

      setState(() {
        _mealDbMeals
          ..clear()
          ..addAll(meals);
        _isSearchingMealDb = false;
      });
    } catch (e) {
      if (token != _searchToken || !mounted) return;
      setState(() {
        _mealDbMeals.clear();
        _mealDbError = e.toString().replaceFirst('Exception: ', '');
        _isSearchingMealDb = false;
      });
    }
  }

  Meal _mealFromMealDb(Map<String, dynamic> json) {
    final name = json['strMeal']?.toString() ?? '';
    final category = json['strCategory']?.toString() ?? '';
    final area = json['strArea']?.toString() ?? '';
    final ingredients = _mealDbIngredients(json);
    final calories = _estimateCalories(
      name: name,
      category: category,
      ingredients: ingredients,
    );
    final price = _estimatePrice(
      name: name,
      category: category,
      area: area,
      ingredients: ingredients,
    );
    final description = [
      if (category.isNotEmpty) category,
      if (area.isNotEmpty) area,
    ].join(' - ');

    return Meal(
      id: json['idMeal']?.toString() ?? name,
      name: name,
      description: description.isEmpty ? 'Menu dari TheMealDB' : description,
      price: price,
      calories: calories,
      dietType: category,
      imageUrl:
          json['strMealThumb']?.toString() ?? 'https://via.placeholder.com/150',
      matchPercentage: 100,
      ingredients: ingredients,
      steps: _mealDbSteps(json['strInstructions']),
    );
  }

  List<String> _mealDbIngredients(Map<String, dynamic> json) {
    final ingredients = <String>[];
    for (var i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i']?.toString().trim() ?? '';
      final measure = json['strMeasure$i']?.toString().trim() ?? '';
      if (ingredient.isNotEmpty) {
        ingredients
            .add(measure.isEmpty ? ingredient : '$measure $ingredient'.trim());
      }
    }
    return ingredients;
  }

  int _estimateCalories({
    required String name,
    required String category,
    required List<String> ingredients,
  }) {
    var calories = 120 + (ingredients.length * 18);
    final text = '$name $category ${ingredients.join(' ')}'.toLowerCase();

    final calorieRules = <String, int>{
      'beef': 130,
      'pork': 130,
      'lamb': 140,
      'chicken': 95,
      'salmon': 110,
      'fish': 80,
      'tuna': 75,
      'egg': 45,
      'cheese': 70,
      'cream': 65,
      'butter': 55,
      'oil': 55,
      'rice': 95,
      'pasta': 105,
      'noodle': 100,
      'potato': 65,
      'bread': 70,
      'flour': 60,
      'sugar': 45,
      'chocolate': 95,
      'cake': 135,
      'dessert': 125,
      'vegetarian': -45,
      'vegan': -55,
      'salad': -70,
      'soup': -35,
      'seafood': 80,
    };

    calorieRules.forEach((keyword, value) {
      if (text.contains(keyword)) calories += value;
    });

    return calories.clamp(180, 700).round();
  }

  double _estimatePrice({
    required String name,
    required String category,
    required String area,
    required List<String> ingredients,
  }) {
    var price = 12000.0 + (ingredients.length * 1800);
    final text = '$name $category $area ${ingredients.join(' ')}'.toLowerCase();

    final priceRules = <String, double>{
      'beef': 18000,
      'pork': 16000,
      'lamb': 22000,
      'salmon': 26000,
      'seafood': 18000,
      'shrimp': 16000,
      'prawn': 16000,
      'fish': 12000,
      'tuna': 12000,
      'chicken': 9000,
      'cheese': 7000,
      'cream': 6000,
      'butter': 5000,
      'pasta': 5000,
      'rice': 3000,
      'potato': 3000,
      'dessert': 6000,
      'cake': 8000,
      'vegetarian': -3000,
      'vegan': -4000,
      'salad': -3000,
    };

    priceRules.forEach((keyword, value) {
      if (text.contains(keyword)) price += value;
    });

    return price.clamp(15000, 85000).roundToDouble();
  }

  List<String> _mealDbSteps(dynamic value) {
    final instructions = value?.toString().trim() ?? '';
    if (instructions.isEmpty) return [];
    return instructions
        .split(RegExp(r'\r?\n|\. '))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final query = _ctrl.text.trim().toLowerCase();
    final localMeals = query.isEmpty
        ? widget.savedMeals
        : widget.savedMeals
            .where((meal) =>
                meal.name.toLowerCase().contains(query) ||
                meal.description.toLowerCase().contains(query) ||
                meal.dietType.toLowerCase().contains(query))
            .toList();
    final filteredMeals = <String, Meal>{};
    final combinedMeals = _includeOnlineSearch
        ? [...localMeals, ..._mealDbMeals]
        : [...localMeals];
    for (final meal in combinedMeals) {
      filteredMeals[meal.id.isNotEmpty ? meal.id : meal.name.toLowerCase()] =
          meal;
    }
    final searchResults = filteredMeals.values.toList();

    return Column(children: [
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _shakeMode = true;
                  _randomMeal = null;
                  _randomMealError = null;
                });
              },
              icon: const Icon(Icons.casino_outlined),
              label:
                  Text(_shakeMode ? "Shake Menu Tersimpan" : "Aktifkan Shake"),
            ),
          ),
        ],
      ),
      if (_shakeMode && _randomMeal == null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                "Gerakkan HP untuk memilih random dari menu yang kamu simpan.",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (_randomMealError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _randomMealError!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
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
            hintText: "Cari dari menu tersimpan...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearchingMealDb
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
        onChanged: _onSearchChanged,
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _includeOnlineSearch = !_includeOnlineSearch;
                  _mealDbMeals.clear();
                  _mealDbError = null;
                });
                if (_includeOnlineSearch && _ctrl.text.trim().isNotEmpty) {
                  _searchMealDb(_ctrl.text);
                }
              },
              icon: Icon(_includeOnlineSearch
                  ? Icons.cloud_done_outlined
                  : Icons.travel_explore_outlined),
              label: Text(_includeOnlineSearch
                  ? 'Pencarian online aktif'
                  : 'Cari juga dari MealDB'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Expanded(
        child: widget.savedMeals.isEmpty
            ? const Center(
                child: Text(
                  "Belum ada menu tersimpan. Simpan menu dari AI Nutrition Assistant dulu.",
                  textAlign: TextAlign.center,
                ),
              )
            : _isSearchingMealDb
                ? const Center(child: CircularProgressIndicator())
                : _mealDbError != null
                    ? Center(child: Text(_mealDbError!))
                    : searchResults.isEmpty
                        ? const Center(
                            child: Text("Menu tersimpan tidak ditemukan"))
                        : ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, i) {
                              final meal = searchResults[i];
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
                                subtitle: Text(
                                  "${meal.description} - ${meal.calories} kcal - ${rupiah.format(meal.price)}",
                                ),
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
