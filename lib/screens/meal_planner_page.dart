import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  double _exchangeRate = 1.0; 

  final Map<String, Map<String, dynamic>> _savedMealsStore = {};
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
    String apiKey = dotenv.get('CURRENCY_API_KEY', fallback: "");
    
    double rate = 1.0;

    // Fetch Kurs API jika mata uang bukan IDR
    if (currency != 'IDR' && apiKey.isNotEmpty) {
      try {
        final url = Uri.parse('https://v6.exchangerate-api.com/v6/$apiKey/pair/IDR/$currency');
        final response = await http.get(url).timeout(const Duration(seconds: 10));

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
        _exchangeRate = rate;
      });
      _recalculateAllStoredMeals();
      _loadWeekData();
    }
  }

  void _recalculateAllStoredMeals() {
    _savedMealsStore.forEach((dateKey, meals) {
      meals.forEach((type, mealData) {
        if (mealData != null) {
          var logic = _calculateLogic(null, mealData['nama'], isRecalculating: true, oldCal: mealData['cal']);
          mealData['harga'] = logic['price'];
        }
      });
    });
  }

  void _loadWeekData() {
    setState(() {
      _isLoading = true;
      _weeklyMeals = List.generate(7, (index) {
        DateTime date = _getStartOfTargetWeek().add(Duration(days: index));
        String dateKey = DateFormat('yyyy-MM-dd').format(date);

        Map<String, dynamic> existingData = _savedMealsStore[dateKey] ?? {
          'Breakfast': null, 'Lunch': null, 'Dinner': null,
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
      
      for (var i = 0; i < 7; i++) { _calculateTotalsLocally(i); }
      _isLoading = false;
    });
  }

  DateTime _getStartOfTargetWeek() {
    DateTime now = DateTime.now();
    int daysToSubtract = now.weekday % 7; 
    return now.subtract(Duration(days: daysToSubtract)).add(Duration(days: _weekOffset * 7));
  }

  Map<String, dynamic> _calculateLogic(String? category, String mealName, {bool isRecalculating = false, int? oldCal}) {
    double basePriceIdr = 30000.0;
    int cal = oldCal ?? 450;

    if (!isRecalculating) {
      Map<String, List<dynamic>> baseData = {
        'Beef': [650, 55000.0], 'Chicken': [500, 35000.0],
        'Dessert': [350, 25000.0], 'Lamb': [700, 65000.0],
        'Pasta': [550, 40000.0], 'Seafood': [450, 60000.0],
        'Vegetarian': [350, 30000.0], 'Breakfast': [400, 20000.0],
      };
      List<dynamic> values = baseData[category] ?? [450, 30000.0];
      cal = values[0];
      basePriceIdr = values[1];
    } else {
      basePriceIdr = 35000.0; 
    }
    
    double finalPrice = (basePriceIdr + (mealName.length * 150)) * _exchangeRate;
    return {'cal': cal, 'price': finalPrice};
  }

  void _addMeal(int dayIndex, String type, Map<String, dynamic> selected) {
    var logic = _calculateLogic(selected['strCategory'], selected['strMeal']);
    String dateKey = _weeklyMeals[dayIndex]['dateKey'];

    setState(() {
      if (!_savedMealsStore.containsKey(dateKey)) {
        _savedMealsStore[dateKey] = {'Breakfast': null, 'Lunch': null, 'Dinner': null};
      }
      
      var mealData = {
        'id': selected['idMeal'],
        'nama': selected['strMeal'],
        'cal': logic['cal'],
        'harga': logic['price'],
        'image_url': selected['strMealThumb'],
      };

      _savedMealsStore[dateKey]![type] = mealData;
      _weeklyMeals[dayIndex]['meals'][type] = mealData;
      _calculateTotalsLocally(dayIndex);
    });
  }

  void _calculateTotalsLocally(int dayIndex) {
    int cal = 0; double price = 0;
    _weeklyMeals[dayIndex]['meals'].forEach((k, v) {
      if (v != null) { cal += v['cal'] as int; price += v['harga'] as double; }
    });
    _weeklyMeals[dayIndex]['total_cal'] = cal;
    _weeklyMeals[dayIndex]['total_harga'] = price;
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: _currentCurrency == 'IDR' ? 'id_ID' : 'en_US',
      symbol: _currentCurrency == 'IDR' ? 'Rp ' : (_currentCurrency == 'USD' ? '\$ ' : '€ '),
      decimalDigits: _currentCurrency == 'IDR' ? 0 : 2,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Meal Planner", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.sync, color: Colors.white), onPressed: _loadUserPreferences)
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF00C853), Color(0xFF2979FF)])
          )
        ),
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
                  itemBuilder: (context, index) => _buildDayCard(index, currencyFormat),
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
          IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () {
            setState(() { _weekOffset--; _loadWeekData(); });
          }),
          Column(children: [
            Text(_weekOffset == 0 ? "Minggu Ini" : "Minggu $_weekOffset", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              _weeklyMeals.isNotEmpty ? "${_weeklyMeals[0]['tanggal']} - ${_weeklyMeals[6]['tanggal']}" : "Memuat...", 
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]),
          IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 20), onPressed: () {
            setState(() { _weekOffset++; _loadWeekData(); });
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
        color: Colors.white, borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(children: [
        ListTile(
          title: Text(data['hari'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(data['tanggal']),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text("${data['total_cal']} kcal", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(cur.format(data['total_harga']), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
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

  Widget _buildMealRow(int dayIdx, String type, dynamic meal, NumberFormat cur) {
    return Row(children: [
      SizedBox(width: 75, child: Text(type, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: meal == null 
        ? OutlinedButton(onPressed: () => _showSearch(dayIdx, type), child: const Text("+ Tambah", style: TextStyle(fontSize: 12)))
        : Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.network(meal['image_url'], width: 35, height: 35, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meal['nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text("${meal['cal']} kcal • ${cur.format(meal['harga'])}", style: const TextStyle(fontSize: 10)),
              ])),
              GestureDetector(
                onTap: () { setState(() { _weeklyMeals[dayIdx]['meals'][type] = null; _calculateTotalsLocally(dayIdx); }); },
                child: const Icon(Icons.cancel, size: 18, color: Colors.redAccent),
              )
            ]),
          )
      ),
    ]);
  }

  void _showSearch(int dayIdx, String type) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: _SearchWidget(onSelect: (s) => _addMeal(dayIdx, type, s)),
      ),
    );
  }
}

class _SearchWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _SearchWidget({required this.onSelect});
  @override
  State<_SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<_SearchWidget> {
  List _results = [];
  bool _loading = false;
  final TextEditingController _ctrl = TextEditingController();

  void _search() async {
    if (_ctrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/search.php?s=${_ctrl.text}'));
      if (res.statusCode == 200) setState(() { _results = json.decode(res.body)['meals'] ?? []; });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: "Cari menu (Inggris)...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
        ),
        onSubmitted: (_) => _search(),
      ),
      const SizedBox(height: 20),
      Expanded(
        child: _loading 
          ? const Center(child: CircularProgressIndicator()) 
          : _results.isEmpty 
            ? const Center(child: Text("Hasil tidak ditemukan"))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) => ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.network(_results[i]['strMealThumb'], width: 45)),
                  title: Text(_results[i]['strMeal'], style: const TextStyle(fontSize: 14)),
                  subtitle: Text(_results[i]['strCategory'] ?? ""),
                  onTap: () { widget.onSelect(_results[i]); Navigator.pop(context); },
                ),
              ),
      ),
    ]);
  }
}