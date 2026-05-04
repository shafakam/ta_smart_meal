import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/budget_providers.dart';
import '../models/expense.dart';
import 'location_page.dart'; // Pastikan import ini ada

class BudgetPage extends StatefulWidget {
  final int userId;
  const BudgetPage({super.key, required this.userId});

  @override
  _BudgetPageState createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  String? _selectedCategory;
  String _currentCurrency = 'IDR';
  String _selectedTimeZone = 'WIB';
  double _exchangeRate = 1.0;

  @override
  void initState() {
    super.initState();
    // Load data saat halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadData(widget.userId);
      _loadRegionalSettings();
    });
  }

  Future<void> _loadRegionalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final currency = prefs.getString('user_currency') ?? 'IDR';
    final timeZone = prefs.getString('user_timezone') ?? 'WIB';
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
      _selectedTimeZone = timeZone;
      _exchangeRate = rate;
    });
  }

  NumberFormat get _formatter => NumberFormat.currency(
        locale: _currentCurrency == 'IDR' ? 'id_ID' : 'en_US',
        symbol: _currentCurrency == 'IDR'
            ? 'Rp '
            : (_currentCurrency == 'USD' ? '\$ ' : 'EUR '),
        decimalDigits: _currentCurrency == 'IDR' ? 0 : 2,
      );

  String _formatMoney(double amountIdr) {
    return _formatter.format(amountIdr * _exchangeRate);
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

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BudgetProvider>();

    // Logika Filter
    final displayList = _selectedCategory == null
        ? prov.recentExpenses
        : prov.recentExpenses
            .where((e) => e.category == _selectedCategory)
            .toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // TOMBOL TAMBAH BELANJAAN
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseModal(context, widget.userId),
        backgroundColor: const Color(0xFF1DE9B6),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // 1. HEADER (Saldo & Edit)
          _buildHeader(prov),

          // 2. KONTEN UTAMA
          Padding(
            padding: const EdgeInsets.only(top: 280),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Spending by Category",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 15),

                  // GRID KATEGORI
                  _buildCategoryGrid(prov),

                  const SizedBox(height: 30),

                  // JUDUL LIST & FILTER INFO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          _selectedCategory == null
                              ? "Recent Expenses"
                              : "Filter: $_selectedCategory",
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E))),
                      if (_selectedCategory != null)
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedCategory = null),
                          child: const Text("Clear Filter"),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),

                  // LIST BELANJAAN
                  _buildExpenseList(displayList, prov),
                  const SizedBox(height: 100), // Spasi agar tidak tertutup FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildHeader(BudgetProvider prov) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.greenAccent.shade400, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Budget Tracker",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.location_on, color: Colors.white),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LocationPage())),
              )
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Sisa Saldo",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(_formatMoney(prov.remaining),
                            style: const TextStyle(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _showBudgetModal(
                          context, widget.userId, prov.weeklyLimit),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(15)),
                        child: const Text("Edit",
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // INFO SPENT VS LIMIT
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Terpakai: ${_formatMoney(prov.spent)}",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12)),
                    Text("Limit: ${_formatMoney(prov.weeklyLimit)}",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: prov.progress,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BudgetProvider prov) {
    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: [
        _categoryCard(
            "Groceries", Icons.shopping_cart_outlined, Colors.orange, prov),
        _categoryCard("Protein", Icons.kebab_dining, Colors.redAccent, prov),
        _categoryCard("Fruits", Icons.apple_outlined, Colors.green, prov),
      ],
    );
  }

  Widget _categoryCard(
      String title, IconData icon, Color color, BudgetProvider prov) {
    bool isSelected = _selectedCategory == title;
    double amount = prov.getWeeklyTotalByCategory(title);

    return GestureDetector(
      onTap: () =>
          setState(() => _selectedCategory = isSelected ? null : title),
      child: Container(
        width: (MediaQuery.of(context).size.width / 2) - 28,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: color, width: 2) : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_formatMoney(amount),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList(List<Expense> list, BudgetProvider prov) {
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("Belum ada data belanjaan.",
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        bool isWeekly = item.isWeekly == 1;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // BAGIAN ATAS: INFO BARANG
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child:
                          Icon(Icons.receipt_long, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${item.date} • ${item.category}",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(_formatMoney(item.price),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
                const Divider(height: 20),

                // BAGIAN BAWAH: TOMBOL AKSI
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // TOMBOL DELETE
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 22),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Hapus Data?"),
                            content: const Text(
                                "Catatan belanjaan ini akan dihapus permanen."),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Batal")),
                              TextButton(
                                onPressed: () {
                                  prov.deleteExpense(item.id, widget.userId);
                                  Navigator.pop(context);
                                },
                                child: const Text("Hapus",
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),

                    // TOMBOL EDIT
                    TextButton.icon(
                      onPressed: () =>
                          _showEditExpenseModal(context, item, widget.userId),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text("Edit"),
                    ),
                    const SizedBox(width: 8),

                    // TOMBOL TAMBAH/HAPUS MINGGUAN
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isWeekly
                            ? Colors.orange.shade400
                            : Colors.blue.shade600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (isWeekly) {
                          prov.removeFromWeeklyList(
                              item.id, item.price, widget.userId);
                        } else {
                          prov.addToWeeklyList(
                              item.id, item.price, widget.userId);
                        }
                      },
                      child: Text(
                        isWeekly ? "Batal" : "Tambah ke Minggu Ini",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- MODAL POPUP (ADD & EDIT) ---

  void _showExpenseModal(BuildContext context, int userId) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String category = "Groceries";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Tambah Belanjaan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Nama Barang")),
            TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: "Harga"),
                keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: category,
              items: ["Groceries", "Protein", "Fruits"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => category = v!,
              decoration: const InputDecoration(labelText: "Kategori"),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final exp = Expense(
                    id: DateTime.now().millisecondsSinceEpoch,
                    name: nameCtrl.text,
                    category: category,
                    price: double.parse(priceCtrl.text),
                    date: DateFormat('yyyy-MM-dd')
                        .format(_nowForSelectedTimeZone()),
                    userId: userId,
                    isWeekly: 0,
                  );
                  context.read<BudgetProvider>().addExpense(exp, userId, false);
                  Navigator.pop(context);
                },
                child: const Text("Simpan"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- FUNGSI MODAL UNTUK EDIT (PASTE DI BAWAH _showExpenseModal) ---
  void _showEditExpenseModal(BuildContext context, Expense item, int userId) {
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl =
        TextEditingController(text: item.price.toInt().toString());
    String category = item.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Belanjaan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Nama Barang")),
            TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: "Harga"),
                keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: category,
              items: ["Groceries", "Protein", "Fruits"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => category = v!,
              decoration: const InputDecoration(labelText: "Kategori"),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final updatedExp = Expense(
                    id: item.id, // Pakai ID lama supaya tidak jadi data baru
                    name: nameCtrl.text,
                    category: category,
                    price: double.parse(priceCtrl.text),
                    date: item.date,
                    userId: userId,
                    isWeekly: item.isWeekly,
                  );
                  context
                      .read<BudgetProvider>()
                      .updateExpense(updatedExp, userId);
                  Navigator.pop(context);
                },
                child: const Text("Simpan Perubahan"),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showBudgetModal(BuildContext context, int userId, double currentLimit) {
    final limitCtrl =
        TextEditingController(text: currentLimit.toInt().toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // WAJIB AGAR BISA NAIK KE ATAS
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom +
                20, // NAIK SESUAI KEYBOARD
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Batas Budget Mingguan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: limitCtrl,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: "Batas Budget (Rp)"),
              keyboardType: TextInputType.number,
              autofocus: true, // Langsung fokus saat buka
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context
                      .read<BudgetProvider>()
                      .updateWeeklyLimit(double.parse(limitCtrl.text), userId);
                  Navigator.pop(context);
                },
                child: const Text("Update Budget"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
