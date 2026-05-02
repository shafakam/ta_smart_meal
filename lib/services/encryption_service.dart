import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionService {
  // Fungsi untuk melakukan hashing password (SHA-256)
  // Menghapus 'static' agar bisa dipanggil melalui instance di AccountSettingsPage
  String hashPassword(String password) {
    var bytes = utf8.encode(password); // Ubah password ke bytes
    var digest = sha256.convert(bytes); // Lakukan hashing SHA-256
    return digest.toString();
  }

  // Fungsi untuk memverifikasi apakah password input sama dengan di DB
  bool verifyPassword(String inputPassword, String storedHash) {
    return hashPassword(inputPassword) == storedHash;
  }
}