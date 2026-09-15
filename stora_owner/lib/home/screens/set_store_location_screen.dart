import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../data/api/api_client.dart';
import '../../stora_login/theme/app_colors.dart';
import '../stores/store_status_store.dart';
import '../theme/home_colors.dart';

class SetStoreLocationScreen extends StatefulWidget {
  const SetStoreLocationScreen({super.key});

  @override
  State<SetStoreLocationScreen> createState() => _SetStoreLocationScreenState();
}

class _SetStoreLocationScreenState extends State<SetStoreLocationScreen> {
  final _addressController = TextEditingController();
  final _latController = TextEditingController(text: '14.5995');
  final _lngController = TextEditingController(text: '120.9842');

  final _mapController = MapController();
  LatLng _currentMapPosition = const LatLng(14.5995, 120.9842);

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDetectingLocation = false;
  bool _isGeocodingAddress = false;
  String? _message;
  bool _isError = false;

  // Preset location quick picks in the Philippines for easy testing/setup
  final List<Map<String, dynamic>> _quickLocations = [
    {
      'label': 'Manila (City Center)',
      'address': 'Rizal Ave, Santa Cruz, Manila, Metro Manila',
      'lat': 14.5995,
      'lng': 120.9842,
    },
    {
      'label': 'Quezon City',
      'address': 'Diliman, Quezon City, Metro Manila',
      'lat': 14.6538,
      'lng': 121.0685,
    },
    {
      'label': 'Makati (Poblacion)',
      'address': 'Poblacion, Makati, Metro Manila',
      'lat': 14.5647,
      'lng': 121.0336,
    },
    {
      'label': 'Pasig (Kapitolyo)',
      'address': 'Kapitolyo, Pasig, Metro Manila',
      'lat': 14.5746,
      'lng': 121.0583,
    },
    {
      'label': 'Cebu City',
      'address': 'Colon St, Cebu City, Cebu',
      'lat': 10.3157,
      'lng': 123.8854,
    },
    {
      'label': 'Davao City',
      'address': 'San Pedro St, Davao City, Davao del Sur',
      'lat': 7.1907,
      'lng': 125.4553,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.instance.getStoreLocation();
      if (mounted) {
        final lat = (data['latitude'] is num)
            ? (data['latitude'] as num).toDouble()
            : (double.tryParse(data['latitude']?.toString() ?? '14.5995') ?? 14.5995);
        final lng = (data['longitude'] is num)
            ? (data['longitude'] as num).toDouble()
            : (double.tryParse(data['longitude']?.toString() ?? '120.9842') ?? 120.9842);
        setState(() {
          _currentMapPosition = LatLng(lat, lng);
          _latController.text = lat.toString();
          _lngController.text = lng.toString();
          _addressController.text = (data['address'] ?? '').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveLocation() async {
    if (_isSaving) return;
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final address = _addressController.text.trim();

    if (lat == null || lng == null) {
      setState(() {
        _isError = true;
        _message = 'Please enter valid numeric latitude and longitude.';
      });
      return;
    }

    if (address.isEmpty) {
      setState(() {
        _isError = true;
        _message = 'Please enter a physical store address.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await ApiClient.instance.updateStoreLocation(
        latitude: lat,
        longitude: lng,
        address: address,
      );
      StoreStatusStore.instance.updateLocalCoordinates(
        latitude: lat,
        longitude: lng,
        address: address,
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isError = false;
          _message = 'Store location pinned successfully! Customers can now find you on their map.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: HomeColors.successBg,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: HomeColors.successText),
                const SizedBox(width: 10),
                Text('Location saved and visible on map!', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isError = true;
          _message = e.toString().replaceAll('ApiException: ', '');
        });
      }
    }
  }

  void _applyQuickLocation(Map<String, dynamic> loc) {
    final newPos = LatLng(loc['lat'] as double, loc['lng'] as double);
    setState(() {
      _currentMapPosition = newPos;
      _latController.text = loc['lat'].toString();
      _lngController.text = loc['lng'].toString();
      _addressController.text = loc['address'].toString();
    });
    _mapController.move(newPos, 15.0);
  }

  Future<void> _detectLocation() async {
    if (_isDetectingLocation) return;
    setState(() {
      _isDetectingLocation = true;
      _message = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isDetectingLocation = false);
        if (!mounted) return;
        _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isDetectingLocation = false;
            _isError = true;
            _message = 'Location permission was denied. Please allow location access to detect your GPS.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isDetectingLocation = false);
        if (!mounted) return;
        _showPermissionPermanentlyDeniedDialog();
        return;
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
        setState(() {
          _isDetectingLocation = false;
          _isError = true;
          _message = 'Could not acquire GPS signal. You can tap anywhere on the map above to place your store pin.';
        });
        return;
      }

      final newPos = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentMapPosition = newPos;
          _latController.text = newPos.latitude.toStringAsFixed(6);
          _lngController.text = newPos.longitude.toStringAsFixed(6);
          _isDetectingLocation = false;
          _isError = false;
          _message = 'GPS location detected! Pin updated on map.';
        });
        _mapController.move(newPos, 16.0);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: HomeColors.successBg,
            content: Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, color: HomeColors.successText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'GPS locked: ${newPos.latitude.toStringAsFixed(5)}, ${newPos.longitude.toStringAsFixed(5)}',
                    style: TextStyle(color: HomeColors.successText, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );

        _tryReverseGeocode(newPos.latitude, newPos.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
          _isError = true;
          _message = 'GPS detection error: ${e.toString().replaceAll('Exception: ', '')}. You can tap the map to place your pin.';
        });
      }
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: HomeColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Color(0xFFFFA726), size: 24),
            const SizedBox(width: 10),
            Text('Location Is Turned Off', style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Your device Location (GPS) is currently disabled. Please turn it on in device settings so Stora can detect your store coordinates.',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: HomeColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFFFFA726), size: 24),
            const SizedBox(width: 10),
            Text('Permission Needed', style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Location permission is permanently denied for Stora. Please enable Location in Android App Settings.',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text('Open App Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _tryReverseGeocode(double lat, double lng, {bool force = true}) async {
    if (mounted) setState(() => _isGeocodingAddress = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'StoraApp/1.0 (com.example.stora)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String resolvedAddress = '';

        if (data['address'] is Map<String, dynamic>) {
          final addr = data['address'] as Map<String, dynamic>;
          final parts = <String>[];
          final street = addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? addr['suburb'];
          if (street != null && street.toString().isNotEmpty) parts.add(street.toString());
          final village = addr['village'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['residential'];
          if (village != null && village.toString().isNotEmpty && !parts.contains(village.toString())) parts.add(village.toString());
          final city = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['county'];
          if (city != null && city.toString().isNotEmpty && !parts.contains(city.toString())) parts.add(city.toString());
          final state = addr['state'] ?? addr['region'] ?? addr['province'];
          if (state != null && state.toString().isNotEmpty && !parts.contains(state.toString())) parts.add(state.toString());
          final country = addr['country'];
          if (country != null && country.toString().isNotEmpty && !parts.contains(country.toString())) parts.add(country.toString());

          if (parts.isNotEmpty) {
            resolvedAddress = parts.join(', ');
          }
        }

        if (resolvedAddress.isEmpty) {
          resolvedAddress = (data['display_name'] as String?) ?? '';
        }

        if (resolvedAddress.isNotEmpty && mounted) {
          if (force || _addressController.text.trim().isEmpty) {
            setState(() {
              _addressController.text = resolvedAddress;
            });
          }
        }
      }
    } catch (_) {
      // Non-critical, ignore
    } finally {
      if (mounted) {
        setState(() => _isGeocodingAddress = false);
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _currentMapPosition = point;
      _latController.text = point.latitude.toStringAsFixed(6);
      _lngController.text = point.longitude.toStringAsFixed(6);
    });
    _tryReverseGeocode(point.latitude, point.longitude, force: true);
  }

  void _onLatLngChanged(String value) {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat != null && lng != null) {
      final newPos = LatLng(lat, lng);
      setState(() {
        _currentMapPosition = newPos;
      });
      _mapController.move(newPos, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: HomeColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: AppColors.purpleLight, size: 20),
            const SizedBox(width: 8),
            Text(
              'Set Store Location',
              style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.purpleLight))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Interactive Map Preview Card
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161224),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: HomeColors.cardBorderLight.withValues(alpha: 0.6)),
                      boxShadow: HomeColors.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentMapPosition,
                            initialZoom: 15.0,
                            onTap: _onMapTap,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.stora',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _currentMapPosition,
                                  width: 120,
                                  height: 80,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.purpleLight, width: 1),
                                        ),
                                        child: const Text(
                                          'Your Store Pin',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: HomeColors.purpleGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: HomeColors.glowShadow(AppColors.purple, opacity: 0.6),
                                        ),
                                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                                      ),
                                      Container(
                                        width: 4,
                                        height: 8,
                                        color: AppColors.purpleLight,
                                      ),
                                      Container(
                                        width: 12,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Overlay badge at top-left
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.public_rounded, color: AppColors.purpleLight, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'GPS Coordinate Mapping',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Detect My GPS Location Button
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isDetectingLocation ? null : _detectLocation,
                      icon: _isDetectingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: AppColors.purpleLight, strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, color: AppColors.purpleLight, size: 18),
                      label: Text(
                        _isDetectingLocation ? 'Detecting Location...' : 'Detect My GPS Location',
                        style: const TextStyle(color: AppColors.purpleLight, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.purpleLight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HomeColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HomeColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, color: AppColors.purpleLight, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Customers browsing the Stora Customer app will see your store marker and can order directly from you.',
                            style: TextStyle(color: HomeColors.textSecondary, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick City Presets
                  Text(
                    'QUICK PRESETS (PHILIPPINES)',
                    style: TextStyle(
                      color: HomeColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickLocations.length,
                      itemBuilder: (context, index) {
                        final loc = _quickLocations[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            avatar: const Icon(Icons.place_rounded, size: 14, color: AppColors.purpleLight),
                            label: Text(loc['label'] as String),
                            backgroundColor: HomeColors.cardBackground,
                            side: BorderSide(color: HomeColors.cardBorder),
                            labelStyle: TextStyle(color: HomeColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onPressed: () => _applyQuickLocation(loc),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Address Input
                  Text(
                    'STORE PHYSICAL ADDRESS',
                    style: TextStyle(
                      color: HomeColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g., 123 Bgy. Santo Cristo, Sari-Sari Store Row',
                      hintStyle: TextStyle(color: HomeColors.textMuted),
                      prefixIcon: const Icon(Icons.home_work_outlined, color: AppColors.purpleLight),
                      suffixIcon: _isGeocodingAddress
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purpleLight),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: HomeColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: HomeColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: HomeColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.purpleLight, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Lat & Lng Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LATITUDE',
                              style: TextStyle(color: HomeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _latController,
                              onChanged: _onLatLngChanged,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: HomeColors.cardBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: HomeColors.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: HomeColors.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.purpleLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LONGITUDE',
                              style: TextStyle(color: HomeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _lngController,
                              onChanged: _onLatLngChanged,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: HomeColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: HomeColors.cardBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: HomeColors.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: HomeColors.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.purpleLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isError ? HomeColors.dangerBg : HomeColors.successBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isError ? AppColors.error : HomeColors.successText,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _isError ? AppColors.error : HomeColors.successText,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveLocation,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      label: Text(
                        _isSaving ? 'Saving Location...' : 'Pin & Save Store Location',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
