/// Konfigurasi global untuk Cipta Maps (MapTiler API key & default center).
class CiptaMapsConfig {
  /// MapTiler API key — di-set via [CiptaMapsConfig.configure] dari app host.
  static String? apiKey;

  /// Default lokasi awal peta saat belum ada marker (Jakarta).
  static LatLngConfig defaultCenter = const LatLngConfig(lat: -6.2088, lng: 106.8456);

  static bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  /// Panggil sekali di `main()` host app.
  static void configure({
    required String apiKey,
    LatLngConfig? defaultCenter,
  }) {
    CiptaMapsConfig.apiKey = apiKey;
    if (defaultCenter != null) CiptaMapsConfig.defaultCenter = defaultCenter;
  }
}

/// Nilai koordinat sederhana (tanpa dependensi latlong2 di config layer).
class LatLngConfig {
  final double lat;
  final double lng;

  const LatLngConfig({required this.lat, required this.lng});
}
