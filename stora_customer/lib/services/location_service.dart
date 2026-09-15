import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final bool success;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? errorMessage;

  const LocationResult({
    required this.success,
    this.address,
    this.latitude,
    this.longitude,
    this.errorMessage,
  });

  factory LocationResult.ok({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    return LocationResult(
      success: true,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory LocationResult.error(String message) {
    return LocationResult(
      success: false,
      errorMessage: message,
    );
  }
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  /// Requests permissions and retrieves the user's current GPS position
  Future<Position?> getCurrentPosition({
    void Function(String error)? onError,
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('Location services are turned off. Please enable GPS in your device settings.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError?.call('Location permission was denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError?.call('Location permission is permanently denied. Please allow it in app settings.');
        return null;
      }

      Position? position;
      // 1. Try high/medium accuracy with 8s timeout
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // 2. Fallback: cached last known position
        position = await Geolocator.getLastKnownPosition();
        // 3. Fallback: low accuracy with 5s timeout
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 5),
              ),
            );
          } catch (_) {}
        }
      }

      if (position == null) {
        onError?.call('Unable to detect current GPS location. Please check your signal and try again.');
        return null;
      }

      return position;
    } catch (e) {
      onError?.call('Location error: ${e.toString()}');
      return null;
    }
  }

  /// Reverse geocodes coordinates to a human-readable street address
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'StoraCustomerApp/1.0 (com.example.stora)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['address'] is Map<String, dynamic>) {
          final addr = data['address'] as Map<String, dynamic>;
          final parts = <String>[];

          final street = addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? addr['suburb'];
          if (street != null && street.toString().isNotEmpty) parts.add(street.toString());

          final village = addr['village'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['residential'] ?? addr['suburb'];
          if (village != null && village.toString().isNotEmpty && !parts.contains(village.toString())) {
            parts.add(village.toString());
          }

          final city = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['county'];
          if (city != null && city.toString().isNotEmpty && !parts.contains(city.toString())) {
            parts.add(city.toString());
          }

          final state = addr['state'] ?? addr['region'] ?? addr['province'];
          if (state != null && state.toString().isNotEmpty && !parts.contains(state.toString())) {
            parts.add(state.toString());
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        if (data is Map<String, dynamic> && data['display_name'] is String && (data['display_name'] as String).isNotEmpty) {
          return data['display_name'] as String;
        }
      }
    } catch (_) {
      // Fallback below
    }

    return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
  }

  /// Convenience method: acquires position and resolves readable address
  Future<LocationResult> detectCurrentAddress() async {
    String? capturedError;
    final position = await getCurrentPosition(onError: (err) => capturedError = err);
    if (position == null) {
      return LocationResult.error(capturedError ?? 'Unable to detect current location.');
    }

    final address = await reverseGeocode(position.latitude, position.longitude);
    return LocationResult.ok(
      address: address,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
