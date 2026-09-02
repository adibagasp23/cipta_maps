import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cipta_debug_badges/flutter_debug_badges.dart';
import 'package:cipta_overlay_toast/overlay_toast.dart';
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

  /// Jika true dan [initial] kosong, coba ambil lokasi GPS device saat ini
  /// sebagai titik awal peta; fallback ke defaultCenter bila gagal.
  final bool startAtCurrentLocation;

  const CiptaMapPicker({
    super.key,
    this.initial,
    this.initialConfig,
    this.title = 'Pilih Lokasi',
    this.startAtCurrentLocation = false,
  });

  @override
  State<CiptaMapPicker> createState() => _CiptaMapPickerState();
}

class _CiptaMapPickerState extends State<CiptaMapPicker> {
  late LatLng _center;
  late LatLng _marker;
  double _zoomLevel = 20;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig ?? CiptaMapsConfig.defaultCenter;
    _marker = widget.initial ?? LatLng(c.lat, c.lng);
    _center = _marker;
    _resolveInitial();
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

  /// Tentukan titik awal: initial → GPS (jika diminta & kosong) → default.
  Future<void> _resolveInitial() async {
    final c = widget.initialConfig ?? CiptaMapsConfig.defaultCenter;
    LatLng start = widget.initial ?? LatLng(c.lat, c.lng);

    if (widget.initial == null && widget.startAtCurrentLocation) {
      final pos = await _tryGetCurrentPosition(showToast: false);
      if (pos != null) start = pos;
      // gagal/izin ditolak → fallback ke default
    }

    if (!mounted) return;
    setState(() {
      _marker = start;
      _center = start;
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
    final next = (current + delta).clamp(2.0, 22.0);
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
  /// Request permission eksplisit — supaya opsi "Location" muncul di
  /// Settings iOS (app dianggap pernah meminta izin lokasi).
  Future<void> _goToCurrentPosition() async {
    final pos = await _tryGetCurrentPosition(showToast: true);
    if (pos == null || !mounted) return;
    setState(() {
      _marker = pos;
      _center = pos;
    });
    setState(() => _zoomLevel = 20);
    _mapController.move(pos, 20);
  }

  /// Helper: cek GPS aktif → request izin → ambil posisi.
  /// [showToast] = true → tampilkan toast error (untuk tombol GPS).
  /// Return LatLng? (null = gagal/izin ditolak).
  Future<LatLng?> _tryGetCurrentPosition({bool showToast = false}) async {
    try {
      // 1. Cek GPS aktif
      final gpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!gpsEnabled) {
        if (showToast && mounted) {
          CiptaToastService.show(
            context,
            message: 'GPS tidak aktif. Nyalakan layanan lokasi terlebih dahulu.',
            icon: Icons.location_off_rounded,
          );
        }
        return null;
      }

      // 2. Cek / minta izin lokasi
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showToast && mounted) {
          CiptaToastService.show(
            context,
            message: 'Izin lokasi ditolak. Aktifkan di Settings > Location.',
            icon: Icons.location_off_rounded,
          );
        }
        return null;
      }

      // 3. Ambil posisi
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      if (showToast && mounted) {
        CiptaToastService.show(
          context,
          message: 'Gagal mendapatkan lokasi. Pastikan GPS & izin lokasi aktif.',
          icon: Icons.location_off_rounded,
        );
      }
      return null;
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
      body: CiptaDebugSection(
        fileName: 'map_picker_page.dart',
        fullPage: true,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 20,
                onTap: (tapPos, latlng) {
                  setState(() => _marker = latlng);
                },
              ),
              children: [
              TileLayer(
                urlTemplate: _tileUrl(),
                userAgentPackageName: 'com.cipta.antrikuy',
                maxZoom: 22,
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
                // GPS — langsung ke lokasi saat ini
                _zoomButton(Icons.gps_fixed, _goToCurrentPosition),
                const SizedBox(height: 4),
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
  bool startAtCurrentLocation = false,
}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      builder: (_) => CiptaMapPicker(
        initial: initial,
        initialConfig: initialConfig,
        title: title,
        startAtCurrentLocation: startAtCurrentLocation,
      ),
    ),
  );
}
