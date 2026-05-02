import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isLoading = false;
  bool _obscureText = true;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  // Cek apakah user sudah mengaktifkan biometrik sebelumnya
  Future<void> _checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('use_biometric') ?? false;
    });

    // Opsional: Jika biometrik aktif, tunggu sebentar lalu picu otomatis
    // if (_isBiometricEnabled) {
    //   Future.delayed(const Duration(milliseconds: 500), () {
    //     _handleBiometricLogin();
    //   });
    // }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- LOGIKA LOGIN MANUAL ---
  void _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Email dan password wajib diisi!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    var user = await _dbService.loginUser(email, password);

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      // Simpan ID user agar biometrik tahu siapa yang masuk nanti
      await prefs.setString('last_user_id', user['id'].toString());
      
      await _authService.saveSession(user['id'].toString());
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } else {
      if (mounted) _showSnackBar("Email atau Password salah!", Colors.redAccent);
    }

    setState(() => _isLoading = false);
  }

  // --- LOGIKA LOGIN BIOMETRIK ---
  Future<void> _handleBiometricLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedUserId = prefs.getString('last_user_id');

      // Jika belum pernah login manual, biometrik tidak bisa menentukan user ID
      if (savedUserId == null) {
        _showSnackBar("Silakan login manual terlebih dahulu", Colors.blueGrey);
        return;
      }

      bool canCheckBiometrics = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheckBiometrics) {
        _showSnackBar("Perangkat tidak mendukung biometrik", Colors.grey);
        return;
      }

      bool authenticated = await _auth.authenticate(
        localizedReason: 'Gunakan sidik jari atau wajah untuk masuk',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        await _authService.saveSession(savedUserId);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
      _showSnackBar("Autentikasi gagal", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade400, Colors.blue.shade900],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu, size: 80, color: Colors.blue),
                    const Text(
                      "Smart Meal",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 40),
                    
                    // Input Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Input Password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureText = !_obscureText),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else ...[
                      // Tombol Login Manual
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: _handleLogin,
                          child: const Text("LOGIN", 
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      // Opsi Biometrik
                      if (_isBiometricEnabled) ...[
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text("Atau", style: TextStyle(color: Colors.grey)),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Tombol Biometrik yang Lebih Cantik
                        InkWell(
                          onTap: _handleBiometricLogin,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fingerprint, size: 30, color: Colors.blue),
                                SizedBox(width: 10),
                                Text("Masuk dengan Biometrik", 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      child: const Text("Belum punya akun? Daftar Sekarang"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}