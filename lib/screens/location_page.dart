import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart'; // Jalankan: flutter pub add url_launcher
import '../services/location_service.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(-7.7265, 110.6019); // Default Klaten
  List<dynamic> _markets = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initLocationAndPlaces();
  }

  Future<void> _initLocationAndPlaces() async {
    try {
      Position pos = await LocationService().getCurrentLocation();
      final latLng = LatLng(pos.latitude, pos.longitude);

      // Ambil data asli dari API
      final places =
          await LocationService().getNearbyMarkets(pos.latitude, pos.longitude);

      setState(() {
        _currentPosition = latLng;
        _markets = places;
        _isLoading = false;
        _errorMessage = null;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    } catch (e) {
      debugPrint("Error: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Fungsi buka Google Maps untuk Navigasi
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse(
          "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Lokasi Belanja",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. MAPS
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _currentPosition, zoom: 15),
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  markers: _markets.map((m) {
                    return Marker(
                      markerId: MarkerId(m['place_id']),
                      position: LatLng(m['geometry']['location']['lat'],
                          m['geometry']['location']['lng']),
                      infoWindow: InfoWindow(title: m['name']),
                    );
                  }).toSet(),
                ),

          // 2. GRADIENT OVERLAY ATAS
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900.withOpacity(0.7),
                  Colors.transparent
                ],
              ),
            ),
          ),

          // 3. BOTTOM PANEL (PASAR TERDEKAT)
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildNearbyMarketsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyMarketsPanel() {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 15),
          const Text("Pasar & Supermarket Terdekat",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 15),
          Expanded(
            child: _markets.isEmpty && !_isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _errorMessage == null
                            ? "Tidak ditemukan pasar di sekitar anda"
                            : "Belum bisa memuat lokasi belanja.\n$_errorMessage",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _markets.length,
                    itemBuilder: (context, index) {
                      final m = _markets[index];
                      final lat = m['geometry']['location']['lat'];
                      final lng = m['geometry']['location']['lng'];

                      return _buildMarketItem(
                          m['name'], m['vicinity'], lat, lng);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketItem(String name, String address, double lat, double lng) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: Colors.greenAccent.shade100,
              child:
                  const Icon(Icons.storefront, color: Colors.green, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(address,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.directions_outlined, color: Colors.blue),
            onPressed: () => _openGoogleMaps(lat, lng),
          ),
        ],
      ),
    );
  }
}
