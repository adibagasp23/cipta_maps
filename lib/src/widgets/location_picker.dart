import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cipta_debug_badges/flutter_debug_badges.dart';
import 'package:geolocator/geolocator.dart';

import '../config/map_config.dart';

/// Peta dengan marker draggable untuk memilih lokasi (latitude/longitude).
///
/// Pemakaian:
/// ```dart
/// final result = await showCiptaMapPicker(
///   context: context,
///   initial: LatLng(-6.2088, 106.8456),
/// );
/// if (result != null) { /* result.latitude, result.longitude */ }
/// ```
class CiptaMapPicker extends StatefulWidget {
  final LatLng? initial;
  final LatLngConfig? initialConfig;
  final String? title;

  const CiptaMapPicker({
    super.key,
    this.initial,
    this.initialConfig,
    this.title = 'Pilih Lokasi',
  });

  @override
  State<CiptaMapPicker> createState() => _CiptaMapPickerState();
}

class _CiptaMapPickerState extends State<CiptaMapPicker> {
  late LatLng _center;
  late LatLng _marker;
  double _zoomLevel = 15;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig ?? CiptaMapsConfig.defaultCenter;
    _marker = widget.initial ?? LatLng(c.lat, c.lng);
    _center = _marker;
    // Update badge zoom level saat peta di-pan/zoom (pakai MapEventMove).
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventDoubleTapZoom) {
        final z = _mapController.camera.zoom;
        if ((z - _zoomLevel).abs() > 0.05) {
          setState(() => _zoomLevel = z);
        }
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _tileUrl() {
    final key = CiptaMapsConfig.apiKey ?? '';
    return 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$key';
  }

  void _zoomChange(int delta) {
    final current = _mapController.camera.zoom;
    final next = (current + delta).clamp(2.0, 19.0);
    setState(() => _zoomLevel = next);
    _mapController.move(_mapController.camera.center, next);
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: const Color(0xFF1F2937)),
        ),
      ),
    );
  }

  /// Badge zoom level (misal "15x") di antara tombol +/-.
  Widget _zoomLevelBadge() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${_zoomLevel.round()}x',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }

  /// Ambil posisi GPS device saat ini, pindahkan peta & marker ke sana.
  Future<void> _goToCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final latlng = LatLng(position.latitude, position.longitude);
      setState(() {
        _marker = latlng;
        _center = latlng;
      });
      setState(() => _zoomLevel = 16);
      _mapController.move(latlng, 16);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mendapatkan lokasi. Pastikan GPS & izin lokasi aktif.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CiptaMapsConfig.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? '')),
        body: const Center(
          child: Text('CiptaMapsConfig.configure() belum dipanggil (apiKey kosong).'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            tooltip: 'Posisi saya',
            onPressed: _goToCurrentPosition,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onTap: (tapPos, latlng) {
                setState(() => _marker = latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl(),
                userAgentPackageName: 'com.cipta.antrikuy',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _marker,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Zoom controls (kanan tengah)
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _zoomButton(Icons.add_rounded, () => _zoomChange(1)),
                const SizedBox(height: 4),
                _zoomLevelBadge(),
                const SizedBox(height: 4),
                _zoomButton(Icons.remove_rounded, () => _zoomChange(-1)),
              ],
            ),
          ),
          // Floating card koordinat
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: CiptaDebugSection(
              fileName: 'map_coordinates_card.dart',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location,
                            size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lat: ${_marker.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.explore,
                            size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lng: ${_marker.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(_marker);
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Gunakan Lokasi Ini'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper membuka map picker sebagai halaman penuh.
Future<LatLng?> showCiptaMapPicker({
  required BuildContext context,
  LatLng? initial,
  LatLngConfig? initialConfig,
  String title = 'Pilih Lokasi',
}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      builder: (_) => CiptaMapPicker(
        initial: initial,
        initialConfig: initialConfig,
        title: title,
      ),
    ),
  );
}
