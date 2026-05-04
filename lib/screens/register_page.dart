import 'package:flutter/material.dart';
import '../services/database_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  // Regex untuk validasi Email
  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Fungsi untuk menangani registrasi
  void _handleRegister() async {
    final String user = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String pass = _passwordController.text.trim();

    // 1. Cek Empty Field
    if (user.isEmpty || email.isEmpty || pass.isEmpty) {
      _showSnackBar("Semua kolom wajib diisi!", Colors.orange);
      return;
    }

    // 2. Error Handling: Validasi Email
    if (!_isValidEmail(email)) {
      _showSnackBar("Format email salah!", Colors.redAccent);
      return;
    }

    // 3. Error Handling: Panjang Password
    if (pass.length < 6) {
      _showSnackBar("Password minimal 6 karakter!", Colors.orange);
      return;
    }

    try {
      // Register User
      await _dbService.registerUser(user, email, pass);
      if (mounted) {
        _showSnackBar("Registrasi Berhasil!", Colors.green);
        Navigator.pop(context); // Kembali ke halaman sebelumnya
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Username atau Email sudah terdaftar!", Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daftar Akun"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            const Text("Mulai Hidup Sehat", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: "Username",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _handleRegister, // Menghubungkan dengan fungsi registrasi
                child: const Text("DAFTAR SEKARANG", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}