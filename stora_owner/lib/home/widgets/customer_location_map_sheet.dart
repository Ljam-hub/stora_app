import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../stores/store_status_store.dart';
import '../theme/home_colors.dart';
import '../screens/owner_chat_screen.dart';

class CustomerLocationMapSheet extends StatefulWidget {
  final int orderId;
  final String customerName;
  final String customerAddress;
  final String? customerPhone;
  final int? customerId;
  final String? customerEmail;
  final String? customerAvatarUrl;

  const CustomerLocationMapSheet({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerAddress,
    this.customerPhone,
    this.customerId,
    this.customerEmail,
    this.customerAvatarUrl,
  });

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required int orderId,
    required String customerName,
    required String customerAddress,
    String? customerPhone,
    int? customerId,
    String? customerEmail,
    String? customerAvatarUrl,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CustomerLocationMapSheet(
          orderId: orderId,
          customerName: customerName,
          customerAddress: customerAddress,
          customerPhone: customerPhone,
          customerId: customerId,
          customerEmail: customerEmail,
          customerAvatarUrl: customerAvatarUrl,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<CustomerLocationMapSheet> createState() => _CustomerLocationMapSheetState();
}

class _CustomerLocationMapSheetState extends State<CustomerLocationMapSheet> {
  final _mapController = MapController();
  bool _isResolving = true;
  String? _resolveError;
  LatLng? _customerPoint;
  LatLng? _storePoint;
  double? _distanceKm;
  List<LatLng> _roadRoutePoints = [];
  double? _drivingDistanceKm;
  int? _drivingDurationMinutes;

  @override
  void initState() {
    super.initState();
    _initCoordinates();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initCoordinates() async {
    final storeStore = StoreStatusStore.instance;
    _storePoint = LatLng(storeStore.latitude, storeStore.longitude);

    final addr = widget.customerAddress.trim();
    if (addr.isEmpty) {
      _isResolving = false;
      _resolveError = 'Customer has not specified a delivery address.';
      _customerPoint = _storePoint;
      return;
    }

    // 1. Check if the address string directly contains coordinates (e.g., "14.5995, 120.9842")
    final coordRegex = RegExp(r'(-?\d+\.\d{3,})\s*,\s*(-?\d+\.\d{3,})');
    final match = coordRegex.firstMatch(addr);
    if (match != null) {
      final g1 = match.group(1);
      final g2 = match.group(2);
      if (g1 != null && g2 != null) {
        final lat = double.tryParse(g1);
        final lng = double.tryParse(g2);
        if (lat != null && lng != null) {
          _setPoints(LatLng(lat, lng));
          return;
        }
      }
    }

    // 2. Geocode address via OpenStreetMap Nominatim (with store-proximity viewbox bias)
    final storeLat = _storePoint!.latitude;
    final storeLng = _storePoint!.longitude;
    const bias = 0.5; // ~55 km viewbox around the store
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(addr)}'
        '&format=json&countrycodes=ph&limit=1'
        '&viewbox=${storeLng - bias},${storeLat + bias},${storeLng + bias},${storeLat - bias}'
        '&bounded=0',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'StoraOwnerApp/1.0 (support@stora.ph)'},
      ).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty && data[0] is Map) {
          final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
          final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            _setPoints(LatLng(lat, lon));
            return;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback: Photon API (Komoot) geocoder with store-proximity bias
    try {
      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(addr)}'
        '&lat=$storeLat&lon=$storeLng&limit=1',
      );
      final photonRes = await http.get(
        photonUri,
        headers: {'User-Agent': 'StoraOwnerApp/1.0 (support@stora.ph)'},
      ).timeout(const Duration(seconds: 7));

      if (photonRes.statusCode == 200) {
        final data = jsonDecode(photonRes.body);
        if (data is Map && data['features'] is List) {
          final features = data['features'] as List;
          if (features.isNotEmpty && features[0] is Map) {
            final geometry = features[0]['geometry'];
            if (geometry is Map && geometry['coordinates'] is List) {
              final coords = geometry['coordinates'] as List;
              if (coords.length >= 2) {
                final lon = (coords[0] is num) ? (coords[0] as num).toDouble() : null;
                final lat = (coords[1] is num) ? (coords[1] as num).toDouble() : null;
                if (lat != null && lon != null) {
                  _setPoints(LatLng(lat, lon));
                  return;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: If all geocoders failed, place pin near store
    final store = _storePoint ?? LatLng(StoreStatusStore.instance.latitude, StoreStatusStore.instance.longitude);
    final fallback = LatLng(store.latitude + 0.003, store.longitude + 0.003);
    _setPoints(fallback, isEstimate: true);
  }

  void _setPoints(LatLng customer, {bool isEstimate = false}) {
    if (!mounted) return;
    final store = _storePoint ?? LatLng(StoreStatusStore.instance.latitude, StoreStatusStore.instance.longitude);
    final dist = _calculateDistanceKm(store, customer);
    setState(() {
      _customerPoint = customer;
      _distanceKm = dist;
      _isResolving = false;
      if (isEstimate) {
        _resolveError = 'Pin approximated from address text. Verify with customer.';
      }
    });

    _fetchRoadRoute(store, customer);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitMapBounds();
    });
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': 'StoraOwnerApp/1.0 (support@stora.ph)'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coords = geometry['coordinates'] as List;
          final points = coords.map<LatLng>((c) {
            final lon = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();

          final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;

          if (mounted && points.isNotEmpty) {
            setState(() {
              _roadRoutePoints = points;
              _drivingDistanceKm = double.parse((distanceMeters / 1000.0).toStringAsFixed(1));
              _drivingDurationMinutes = (durationSeconds / 60.0).round();
            });
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback: straight line
    if (mounted) {
      setState(() {
        _roadRoutePoints = [start, end];
      });
    }
  }

  Future<void> _openNavigation() async {
    if (_customerPoint == null) return;
    final lat = _customerPoint!.latitude;
    final lon = _customerPoint!.longitude;

    // 1. Native turn-by-turn navigation intent
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
    try {
      final launched = await launchUrl(googleNavUri, mode: LaunchMode.externalNonBrowserApplication);
      if (launched) return;
    } catch (_) {}

    // 2. Generic geo: intent with marker label
    final geoUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon(Delivery%20Location)');
    try {
      final launched = await launchUrl(geoUri, mode: LaunchMode.externalNonBrowserApplication);
      if (launched) return;
    } catch (_) {}

    // 3. Google Maps directions URL in external app/browser
    final mapsDirUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving');
    try {
      final launched = await launchUrl(mapsDirUrl, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 4. Platform default fallback
    try {
      final launched = await launchUrl(mapsDirUrl, mode: LaunchMode.platformDefault);
      if (launched) return;
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map navigation app.')),
      );
    }
  }

  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    const r = 6371.0; // Earth's radius in km
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * (math.pi / 180.0)) *
            math.cos(p2.latitude * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return double.parse((r * c).toStringAsFixed(2));
  }

  void _fitMapBounds() {
    if (_storePoint == null || _customerPoint == null) return;
    try {
      // Guard against identical points which cause infinite zoom
      if (_storePoint!.latitude == _customerPoint!.latitude &&
          _storePoint!.longitude == _customerPoint!.longitude) {
        _mapController.move(_storePoint!, 15.0);
        return;
      }
      final bounds = LatLngBounds.fromPoints([_storePoint!, _customerPoint!]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {}
  }


  Future<void> _callCustomer() async {
    final phone = widget.customerPhone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    if (phone.isEmpty) return;
    final telUri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sheet Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: HomeColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HomeColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delivery_dining_rounded, color: HomeColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Location • Order #${widget.orderId}',
                        style: TextStyle(
                          color: HomeColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.customerName,
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: HomeColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Warning / Estimate Banner
          if (_resolveError != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: HomeColors.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HomeColors.warningText.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: HomeColors.warningText, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resolveError!,
                      style: TextStyle(color: HomeColors.warningText, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Map View Area
          Expanded(
            child: Stack(
              children: [
                if (_customerPoint != null && _storePoint != null)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _customerPoint!,
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.stora_owner',
                      ),
                      // Road Route Polyline (or straight dashed line while loading/fallback)
                      PolylineLayer(
                        polylines: [
                          if (_roadRoutePoints.isNotEmpty) ...[
                            // Contrast outline/casing
                            Polyline(
                              points: _roadRoutePoints,
                              color: const Color(0xFF0F172A),
                              strokeWidth: 6.5,
                            ),
                            // Vibrant road line
                            Polyline(
                              points: _roadRoutePoints,
                              color: const Color(0xFF38BDF8),
                              strokeWidth: 4.5,
                            ),
                          ] else ...[
                            Polyline(
                              points: [_storePoint!, _customerPoint!],
                              color: const Color(0xFF0F172A),
                              strokeWidth: 4.5,
                            ),
                            Polyline(
                              points: [_storePoint!, _customerPoint!],
                              color: const Color(0xFF38BDF8),
                              strokeWidth: 3.0,
                              pattern: StrokePattern.dashed(segments: const [8, 6]),
                            ),
                          ],
                        ],
                      ),
                      // Markers
                      MarkerLayer(
                        markers: [
                          // Store Marker
                          Marker(
                            point: _storePoint!,
                            width: 100,
                            height: 60,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '🏪 Your Store',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                          // Customer Delivery Marker
                          Marker(
                            point: _customerPoint!,
                            width: 130,
                            height: 66,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: HomeColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '📍 ${widget.customerName}',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                if (_isResolving)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(color: HomeColors.primary),
                    ),
                  ),

                // Floating Map Controls
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _MapIconButton(
                        icon: Icons.fit_screen_rounded,
                        tooltip: 'Fit route in view',
                        onTap: _fitMapBounds,
                      ),
                      const SizedBox(height: 8),
                      _MapIconButton(
                        icon: Icons.storefront_rounded,
                        tooltip: 'Center store',
                        onTap: () {
                          if (_storePoint != null) {
                            _mapController.move(_storePoint!, 15.0);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapIconButton(
                        icon: Icons.person_pin_circle_rounded,
                        tooltip: 'Center customer',
                        onTap: () {
                          if (_customerPoint != null) {
                            _mapController.move(_customerPoint!, 15.0);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Distance Badge Overlay
                if (_drivingDistanceKm != null || _distanceKm != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _drivingDurationMinutes != null
                                ? Icons.directions_car_rounded
                                : Icons.straighten_rounded,
                            color: const Color(0xFF38BDF8),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _drivingDistanceKm != null && _drivingDurationMinutes != null
                                ? '$_drivingDistanceKm km by road • ~$_drivingDurationMinutes min'
                                : '$_distanceKm km straight-line distance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Detail Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: HomeColors.cardElevated,
              border: Border(top: BorderSide(color: HomeColors.cardBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, color: HomeColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery Address',
                              style: TextStyle(color: HomeColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.customerAddress.isNotEmpty ? widget.customerAddress : 'No address provided',
                              style: TextStyle(
                                color: HomeColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy_rounded, color: HomeColors.textMuted, size: 18),
                        tooltip: 'Copy address',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.customerAddress));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Address copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Open in Google Maps Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: _customerPoint != null ? _openNavigation : null,
                      icon: const Icon(Icons.navigation_rounded, size: 20, color: Colors.black),
                      label: const Text(
                        'Start Road Navigation (Google Maps)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Actions: Call customer & Message about order
                  Row(
                    children: [
                      if (widget.customerPhone != null && widget.customerPhone!.trim().isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HomeColors.textPrimary,
                              side: BorderSide(color: HomeColors.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _callCustomer,
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HomeColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          onPressed: widget.customerId != null
                              ? () {
                                  final nav = Navigator.of(context);
                                  nav.pop(); // close the bottom sheet
                                  nav.push(
                                    MaterialPageRoute(
                                      builder: (_) => OwnerChatThreadScreen(
                                        customerId: widget.customerId!,
                                        customerName: widget.customerName,
                                        customerEmail: widget.customerEmail ?? '',
                                        customerAvatarUrl: widget.customerAvatarUrl,
                                        orderId: widget.orderId,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: const Text(
                            'Message customer about this order',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.white24),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}
