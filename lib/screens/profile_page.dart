import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feedback_page.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();
  final LocalAuthentication _auth = LocalAuthentication();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isPickerActive = false;
  bool _isBiometricEnabled = false;

  // Variabel baru untuk Currency dan Time
  String _selectedCurrency = 'IDR';
  String _selectedTimeZone = 'WIB';
  List<_CurrencyQuote> _currencyQuotes = [];
  bool _isLoadingCurrencies = false;

  static const List<_CurrencyOption> _currencyOptions = [
    _CurrencyOption('IDR', 'Indonesian Rupiah'),
    _CurrencyOption('USD', 'US Dollar'),
    _CurrencyOption('EUR', 'Euro'),
    _CurrencyOption('GBP', 'British Pound'),
    _CurrencyOption('JPY', 'Japanese Yen'),
    _CurrencyOption('CNY', 'Chinese Yuan'),
    _CurrencyOption('AUD', 'Australian Dollar'),
    _CurrencyOption('CAD', 'Canadian Dollar'),
    _CurrencyOption('CHF', 'Swiss Franc'),
    _CurrencyOption('SGD', 'Singapore Dollar'),
    _CurrencyOption('INR', 'Indian Rupee'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadSettings(); // Memuat semua setting termasuk biometrik, kurensi, dan waktu
  }

  // Memuat pengaturan dari SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('use_biometric') ?? false;
      _selectedCurrency = prefs.getString('user_currency') ?? 'IDR';
      _selectedTimeZone = prefs.getString('user_timezone') ?? 'WIB';
    });
  }

  // Simpan Currency
  Future<void> _updateCurrency(String? newValue) async {
    if (newValue == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_currency', newValue);
    setState(() => _selectedCurrency = newValue);
    _showSnackBar("Mata uang diubah ke $newValue");
  }

  // Simpan Timezone
  Future<void> _updateTimeZone(String? newValue) async {
    if (newValue == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_timezone', newValue);
    setState(() => _selectedTimeZone = newValue);
    _showSnackBar("Zona waktu diubah ke $newValue");
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

  Future<void> _openCurrencyPicker() async {
    await _loadCurrencyQuotes();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              minChildSize: 0.42,
              maxChildSize: 0.92,
              builder: (_, controller) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pilih Mata Uang',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            setModalState(() => _isLoadingCurrencies = true);
                            await _loadCurrencyQuotes(forceRefresh: true);
                            setModalState(() => _isLoadingCurrencies = false);
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child: Text('Pair',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey))),
                        Expanded(
                            child: Text('Harga',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey))),
                        Expanded(
                            child: Text('Hari',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey))),
                      ],
                    ),
                    const Divider(),
                    if (_isLoadingCurrencies)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ..._currencyQuotes.map(
                        (quote) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          selected: quote.code == _selectedCurrency,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: quote.code == _selectedCurrency
                                ? Colors.green.shade100
                                : Colors.grey.shade100,
                            child: Text(
                              quote.code.substring(0, 1),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            quote.code == 'IDR' ? 'IDR' : 'IDR${quote.code}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(quote.name),
                          trailing: SizedBox(
                            width: 132,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    quote.rateText,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 54,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        quote.diff > 0
                                            ? Icons.arrow_drop_up
                                            : quote.diff < 0
                                                ? Icons.arrow_drop_down
                                                : Icons.remove,
                                        color: quote.diff > 0
                                            ? Colors.green
                                            : quote.diff < 0
                                                ? Colors.red
                                                : Colors.grey,
                                      ),
                                      Flexible(
                                        child: Text(
                                          quote.diffText,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () async {
                            await _updateCurrency(quote.code);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadCurrencyQuotes({bool forceRefresh = false}) async {
    if (_currencyQuotes.isNotEmpty && !forceRefresh) return;
    setState(() => _isLoadingCurrencies = true);
    final prefs = await SharedPreferences.getInstance();
    final apiKey = dotenv.get('CURRENCY_API_KEY', fallback: '');
    final quotes = <_CurrencyQuote>[];

    for (final option in _currencyOptions) {
      var rate = option.code == 'IDR' ? 1.0 : 0.0;
      final previous = prefs.getDouble('last_rate_${option.code}');
      if (option.code != 'IDR' && apiKey.isNotEmpty) {
        try {
          final url = Uri.parse(
              'https://v6.exchangerate-api.com/v6/$apiKey/pair/IDR/${option.code}');
          final response =
              await http.get(url).timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) {
            final data = json.decode(response.body) as Map<String, dynamic>;
            rate = (data['conversion_rate'] as num).toDouble();
          }
        } catch (_) {}
      }
      if (rate == 0.0) {
        rate = _fallbackRate(option.code);
      }
      await prefs.setDouble('last_rate_${option.code}', rate);
      quotes.add(_CurrencyQuote(
        code: option.code,
        name: option.name,
        rate: rate,
        previousRate: previous,
      ));
    }

    if (!mounted) return;
    setState(() {
      _currencyQuotes = quotes;
      _isLoadingCurrencies = false;
    });
  }

  double _fallbackRate(String code) {
    return switch (code) {
      'USD' => 0.000062,
      'EUR' => 0.000057,
      'GBP' => 0.000049,
      'JPY' => 0.0096,
      'CNY' => 0.00045,
      'AUD' => 0.000095,
      'CAD' => 0.000085,
      'CHF' => 0.000055,
      'SGD' => 0.000084,
      'INR' => 0.0053,
      _ => 1.0,
    };
  }

  // --- FUNGSI BIOMETRIK & LOGOUT (TETAP SAMA) ---
  Future<void> _toggleBiometric(bool value) async {
    if (value == true) {
      try {
        bool canCheck =
            await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
        if (!canCheck) {
          _showSnackBar("Perangkat tidak mendukung biometrik");
          return;
        }
        bool authenticated = await _auth.authenticate(
          localizedReason:
              'Konfirmasi sidik jari untuk mengaktifkan Login Biometrik',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false,
            useErrorDialogs: true,
          ),
        );
        if (authenticated) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_biometric', true);
          setState(() => _isBiometricEnabled = true);
          _showSnackBar("Biometrik berhasil diaktifkan!");
        }
      } catch (e) {
        _showSnackBar("Error: $e");
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_biometric', false);
      setState(() => _isBiometricEnabled = false);
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Konfirmasi Keluar"),
              content: const Text("Apakah Anda yakin ingin keluar?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal")),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                    child: const Text("Keluar",
                        style: TextStyle(color: Colors.red))),
              ],
            ));
  }

  Future<void> _loadUserProfile() async {
    String? userId = await _authService.getUserId();
    if (userId != null) {
      final db = await _dbService.database;
      List<Map<String, dynamic>> result =
          await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (result.isNotEmpty) {
        setState(() {
          _userData = result.first;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isPickerActive) return;
    setState(() => _isPickerActive = true);
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 50);
      if (image != null) {
        String? userId = await _authService.getUserId();
        final db = await _dbService.database;
        await db.update('users', {'profile_image': image.path},
            where: 'id = ?', whereArgs: [userId]);
        _loadUserProfile();
      }
    } catch (e) {
      debugPrint("Gagal: $e");
    } finally {
      if (mounted) setState(() => _isPickerActive = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = Colors.blue.shade900;
    ImageProvider profileImageProvider =
        (_userData != null && _userData!['profile_image'] != null)
            ? FileImage(File(_userData!['profile_image']))
            : const NetworkImage('https://via.placeholder.com/150')
                as ImageProvider;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Profil Saya"),
          backgroundColor: Colors.white,
          foregroundColor: primaryBlue,
          elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileHeader(profileImageProvider, primaryBlue),
                    const SizedBox(height: 30),

                    // --- SECTION 1: AKUN ---
                    _buildSectionTitle("Pengaturan Utama"),
                    _buildMenuItem(Icons.person_outline, "Pengaturan Akun", () {
                      Navigator.pushNamed(context, '/account_settings')
                          .then((_) => _loadUserProfile());
                    }),
                    _buildBiometricTile(),

                    const SizedBox(height: 20),

                    // --- SECTION 2: KONVERSI (FITUR BARU) ---
                    _buildSectionTitle("Konversi & Regional"),
                    _buildCurrencyPickerTile(primaryBlue),
                    _buildTimePreviewTile(primaryBlue),
                    _buildDropdownTile(
                      icon: Icons.access_time_outlined,
                      title: "Zona Waktu",
                      value: _selectedTimeZone,
                      items: ['WIB', 'WITA', 'WIT', 'London'],
                      onChanged: _updateTimeZone,
                    ),

                    const SizedBox(height: 20),

                    // --- SECTION 3: LAINNYA ---
                    _buildSectionTitle("Lainnya"),
                    _buildMenuItem(
                        Icons.chat_bubble_outline, "Saran & Kesan Kuliah TPM",
                        () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const FeedbackPage()));
                    }, isSpecial: true),

                    const SizedBox(height: 40),
                    _buildLogoutButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700)),
      ),
    );
  }

  Widget _buildProfileHeader(ImageProvider img, Color color) {
    return Column(children: [
      Stack(children: [
        CircleAvatar(
            radius: 55,
            backgroundColor: color,
            child: CircleAvatar(radius: 52, backgroundImage: img)),
        Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
                onTap: _pickImage,
                child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.camera_alt,
                        color: Colors.white, size: 18)))),
      ]),
      const SizedBox(height: 15),
      Text(_userData?['username'] ?? "User",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(_userData?['email'] ?? "email@user.com",
          style: const TextStyle(color: Colors.grey)),
    ]);
  }

  Widget _buildBiometricTile() {
    return ListTile(
      leading: _buildIconContainer(
          Icons.fingerprint, Colors.blue.shade50, Colors.blue.shade800),
      title: const Text("Login Biometrik"),
      trailing: Switch(
          value: _isBiometricEnabled,
          onChanged: _toggleBiometric,
          activeThumbColor: Colors.blue.shade900),
    );
  }

  Widget _buildCurrencyPickerTile(Color primaryBlue) {
    return ListTile(
      leading: _buildIconContainer(
          Icons.monetization_on_outlined, Colors.green.shade50, Colors.green),
      title: const Text("Mata Uang"),
      subtitle: Text("Aktif: $_selectedCurrency"),
      trailing: const Icon(Icons.chevron_right),
      onTap: _openCurrencyPicker,
    );
  }

  Widget _buildTimePreviewTile(Color primaryBlue) {
    final nowText =
        DateFormat('HH:mm, dd MMM yyyy').format(_nowForSelectedTimeZone());
    return ListTile(
      leading: _buildIconContainer(
          Icons.access_time_outlined, Colors.blue.shade50, primaryBlue),
      title: Text("Jam $_selectedTimeZone"),
      subtitle: Text(nowText),
    );
  }

  Widget _buildDropdownTile(
      {required IconData icon,
      required String title,
      required String value,
      required List<String> items,
      required Function(String?) onChanged}) {
    return ListTile(
      leading: _buildIconContainer(
          icon, Colors.purple.shade50, Colors.purple.shade700),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: items
            .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e,
                    style: const TextStyle(fontWeight: FontWeight.bold))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color bg, Color iconCol) {
    return Container(
        padding: const EdgeInsets.all(8),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconCol));
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap,
      {bool isSpecial = false}) {
    return ListTile(
      leading: _buildIconContainer(
          icon,
          isSpecial ? Colors.orange.shade50 : Colors.blue.shade50,
          isSpecial ? Colors.orange.shade700 : Colors.blue.shade800),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
          minimumSize: const Size(double.infinity, 55),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      onPressed: _showLogoutConfirmation,
      icon: const Icon(Icons.logout),
      label: const Text("Keluar dari Akun"),
    );
  }
}

class _CurrencyOption {
  const _CurrencyOption(this.code, this.name);

  final String code;
  final String name;
}

class _CurrencyQuote {
  const _CurrencyQuote({
    required this.code,
    required this.name,
    required this.rate,
    required this.previousRate,
  });

  final String code;
  final String name;
  final double rate;
  final double? previousRate;

  double get diff => previousRate == null ? 0 : rate - previousRate!;

  String get rateText {
    if (code == 'IDR') return '1.0000';
    if (rate >= 1) return rate.toStringAsFixed(4);
    return rate.toStringAsFixed(6);
  }

  String get diffText {
    final value = diff.abs();
    if (value == 0) return '0';
    if (value >= 1) return value.toStringAsFixed(3);
    return value.toStringAsFixed(6);
  }
}
