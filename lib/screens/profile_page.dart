import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
      if (result.isNotEmpty)
        setState(() {
          _userData = result.first;
          _isLoading = false;
        });
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
                    _buildDropdownTile(
                      icon: Icons.monetization_on_outlined,
                      title: "Mata Uang",
                      value: _selectedCurrency,
                      items: ['IDR', 'USD', 'EUR'],
                      onChanged: _updateCurrency,
                    ),
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
                child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.camera_alt,
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
          activeColor: Colors.blue.shade900),
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
