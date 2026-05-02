import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CurrencyService {
  // Ambil API Key saja dari .env
  final String? _apiKey = dotenv.env['CURRENCY_API_KEY'];

  Future<Map<String, dynamic>> fetchExchangeRates(String baseCurrency) async {
    try {
      // Masukkan alamat API langsung di sini (Hardcoded URL)
      // Struktur: https://v6.exchangerate-api.com/v6/[API_KEY]/latest/[MATA_UANG]
      final String url = 'https://v6.exchangerate-api.com/v6/$_apiKey/latest/$baseCurrency';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Gagal mengambil data kurs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Terjadi kesalahan jaringan: $e');
    }
  }
}