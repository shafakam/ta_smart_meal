import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart'; // Import service enkripsi kamu

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _encryptionService = EncryptionService(); // Instance service enkripsi

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); // Controller baru

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    String? userId = await _authService.getUserId();
    if (userId != null) {
      final db = await _dbService.database;
      var result =
          await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (result.isNotEmpty) {
        setState(() {
          _nameController.text = result.first['username'].toString();
          _emailController.text = result.first['email'].toString();
        });
      }
    }
  }

  void _updateProfile() async {
    setState(() => _isLoading = true);
    String? userId = await _authService.getUserId();
    final db = await _dbService.database;

    // Data yang akan diupdate
    Map<String, dynamic> updateData = {
      'username': _nameController.text.trim(),
      'email': _emailController.text.trim(),
    };

    // Jika password diisi, enkripsi lalu tambahkan ke data update
    if (_passwordController.text.isNotEmpty) {
      // Gunakan logic dari encryption_service kamu
      String hashedPassword =
          _encryptionService.hashPassword(_passwordController.text.trim());
      updateData['password'] = hashedPassword;
    }

    await db.update(
      'users',
      updateData,
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil & Password diperbarui!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = Colors.blue.shade900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Pengaturan Akun"),
        backgroundColor: Colors.white,
        foregroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "Informasi Akun",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("Username"),
                  _buildTextField(
                    controller: _nameController,
                    hint: "Username baru",
                    icon: Icons.person_outline,
                    primaryColor: primaryBlue,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("Email"),
                  _buildTextField(
                    controller: _emailController,
                    hint: "Email baru",
                    icon: Icons.email_outlined,
                    primaryColor: primaryBlue,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel(
                      "Password Baru (Kosongkan jika tidak ingin ganti)"),
                  _buildTextField(
                    controller: _passwordController,
                    hint: "Password baru",
                    icon: Icons.lock_outline,
                    primaryColor: primaryBlue,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggleVisible: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: const Text("Simpan Perubahan",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisible,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey),
                onPressed: onToggleVisible,
              )
            : null,
        filled: true,
        fillColor: Colors.blue.shade50.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }
}
