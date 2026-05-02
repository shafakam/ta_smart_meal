import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();

  // Menggunakan FlutterSecureStorage untuk penyimpanan ID yang terenkripsi
  final storage = const FlutterSecureStorage();

  // --- FITUR BIOMETRIK ---

  Future<bool> authenticateBiometric() async {
    try {
      // Cek apakah perangkat mendukung hardware biometrik
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) return false;

      // Proses autentikasi
      return await auth.authenticate(
        localizedReason: 'Silakan scan sidik jari untuk login ke Smart Meal',
        options: const AuthenticationOptions(
          biometricOnly: true, // Hanya mengizinkan sidik jari/wajah, bukan PIN
          stickyAuth: true, // Tetap mencoba jika aplikasi pindah ke background
        ),
      );
    } catch (e) {
      print("Error Biometrik: $e");
      return false;
    }
  }

  // --- FITUR SESSION (TUGAS SI A) ---

  // Simpan ID User setelah login berhasil
  Future<void> saveSession(String userId) async {
    await storage.write(key: 'user_id', value: userId);
  }

  // Ambil ID User untuk ProfilePage (Gunakan nama getUserId agar cocok dengan ProfilePage)
  Future<String?> getUserId() async {
    return await storage.read(key: 'user_id');
  }

  // Hapus Session saat Logout
  Future<void> logout() async {
    await storage.delete(key: 'user_id');
  }

  // Cek apakah user sudah login (untuk auto-login di splash screen)
  Future<bool> isLoggedIn() async {
    String? userId = await storage.read(key: 'user_id');
    return userId != null;
  }
}
