import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {
  String get apiKey => dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permission denied forever. Aktifkan izin lokasi dari Settings.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<List<dynamic>> getNearbyMarkets(double lat, double lng) async {
    if (apiKey.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY belum diisi di .env');
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=$lat,$lng'
        '&radius=5000'
        '&keyword=pasar%20OR%20supermarket%20OR%20minimarket%20OR%20grocery%20store'
        '&key=$apiKey');

    final response = await http.get(url).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final status = data['status']?.toString() ?? 'UNKNOWN';
      if (status == 'OK' || status == 'ZERO_RESULTS') {
        return data['results'] as List? ?? [];
      }
      throw Exception(data['error_message'] ?? 'Google Places error: $status');
    }

    throw Exception('Failed to load places (${response.statusCode})');
  }
}
