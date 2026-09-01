import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cipta_debug_badges/flutter_debug_badges.dart';

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
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig ?? CiptaMapsConfig.defaultCenter;
    _marker = widget.initial ?? LatLng(c.lat, c.lng);
    _center = _marker;
  }

  String _tileUrl() {
    final key = CiptaMapsConfig.apiKey ?? '';
    return 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$key';
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
            icon: const Icon(Icons.my_location),
            tooltip: 'Kembali ke marker',
            onPressed: () {
              _mapController.move(_marker, 16);
            },
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
