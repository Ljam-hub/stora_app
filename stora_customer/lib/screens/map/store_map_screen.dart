import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/store_model.dart';
import '../../providers/catalog_provider.dart';
import '../../services/location_service.dart';
import '../../storage/session_manager.dart';
import '../../theme/app_theme.dart';

class StoreMapScreen extends StatefulWidget {
  final Function(StoreModel store) onSelectStoreAndShop;

  const StoreMapScreen({
    super.key,
    required this.onSelectStoreAndShop,
  });

  @override
  State<StoreMapScreen> createState() => _StoreMapScreenState();
}

class _StoreMapScreenState extends State<StoreMapScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final PageController _pageController;
  final MapController _mapController = MapController();

  StoreModel? _selectedStore;
  String _searchFilter = '';

  bool _isRecentering = false;
  bool _isShowingStoresSheet = false;

  // Road route state
  List<LatLng> _roadRoutePoints = [];
  double? _roadDistanceKm;
  int? _roadDurationMinutes;
  bool _isLoadingRoute = false;

  // Radar beacon pulse animation
  late final AnimationController _pulseAnim;

  // Customer GPS coordinates (Central Manila default)
  double _userLat = 14.5995;
  double _userLng = 120.9842;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadCachedLocation();
    _acquireLocation();
  }

  Future<void> _saveCachedLocation(double lat, double lng) async {
    try {
      final db = await SessionManager.instance.database;
      await db.insert(
        'app_settings',
        {'key': 'last_lat', 'value': lat.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'app_settings',
        {'key': 'last_lng', 'value': lng.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<void> _loadCachedLocation() async {
    try {
      final db = await SessionManager.instance.database;
      final latRows = await db.query('app_settings', where: 'key = ?', whereArgs: ['last_lat']);
      final lngRows = await db.query('app_settings', where: 'key = ?', whereArgs: ['last_lng']);
      if (latRows.isNotEmpty && lngRows.isNotEmpty) {
        final lat = double.tryParse(latRows.first['value'] as String);
        final lng = double.tryParse(lngRows.first['value'] as String);
        if (lat != null && lng != null && mounted) {
          setState(() {
            _userLat = lat;
            _userLng = lng;
          });
          try {
            _mapController.move(LatLng(_userLat, _userLng), 15.0);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _acquireLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fetchStores();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _fetchStores();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _fetchStores();
        return;
      }

      Position? position;
      // 1. Try high accuracy with 8s timeout for maximum map precision
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // 2. Fallback: cached last known position
        position = await Geolocator.getLastKnownPosition();
        // 3. Fallback: medium/low accuracy with 5s timeout
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 5),
              ),
            );
          } catch (_) {}
        }
      }

      if (position != null && mounted) {
        final pos = position;
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        });
        _saveCachedLocation(_userLat, _userLng);
        try {
          _mapController.move(LatLng(_userLat, _userLng), 15.0);
        } catch (_) {}
      }
    } catch (_) {
      // Fallback
    } finally {
      _fetchStores();
    }
  }

  void _fetchStores() {
    if (mounted) {
      context.read<CatalogProvider>().fetchStores(lat: _userLat, lng: _userLng);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _pulseAnim.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() async {
    if (_isRecentering) return;
    _isRecentering = true;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Locating your GPS position...'),
          ],
        ),
      ),
    );

    try {
      String? errorMessage;
      final position = await LocationService.instance.getCurrentPosition(
        onError: (err) => errorMessage = err,
      );

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      if (position != null) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
        });
        _saveCachedLocation(_userLat, _userLng);
        try {
          _mapController.move(LatLng(_userLat, _userLng), 16.0);
        } catch (_) {}
        if (_selectedStore != null && _selectedStore!.hasValidLocation) {
          _fetchRoadRoute(
            LatLng(_userLat, _userLng),
            LatLng(_selectedStore!.latitude, _selectedStore!.longitude),
          );
        }
        _fetchStores();
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            content: Text('Centered to your location!'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
            content: Text(errorMessage ?? 'Could not determine your location. Please enable GPS.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecentering = false;
        });
      } else {
        _isRecentering = false;
      }
    }
  }

  void _zoom(double delta) {
    try {
      final newZoom = (_mapController.camera.zoom + delta).clamp(1.0, 20.0);
      _mapController.move(_mapController.camera.center, newZoom);
    } catch (_) {}
  }

  void _fitRouteBounds(LatLng p1, LatLng p2) {
    try {
      if (p1.latitude == p2.latitude && p1.longitude == p2.longitude) {
        _mapController.move(p1, 15.0);
        return;
      }
      final bounds = _roadRoutePoints.isNotEmpty
          ? LatLngBounds.fromPoints(_roadRoutePoints)
          : LatLngBounds.fromPoints([p1, p2]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 160, 40, 240),
        ),
      );
    } catch (_) {}
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end, {bool fitCamera = false}) async {
    _isLoadingRoute = true;
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': 'StoraCustomerApp/1.0 (support@stora.ph)'},
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
              _roadDistanceKm = double.parse((distanceMeters / 1000.0).toStringAsFixed(1));
              _roadDurationMinutes = (durationSeconds / 60.0).round();
              _isLoadingRoute = false;
            });
            if (fitCamera) {
              _fitRouteBounds(start, end);
            }
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback: straight line
    if (mounted) {
      setState(() {
        _roadRoutePoints = [start, end];
        _roadDistanceKm = null;
        _roadDurationMinutes = null;
        _isLoadingRoute = false;
      });
      if (fitCamera) {
        _fitRouteBounds(start, end);
      }
    }
  }

  Future<void> _openGoogleMapsDirections(StoreModel store) async {
    if (!store.hasValidLocation) return;
    final lat = store.latitude;
    final lon = store.longitude;

    // 1. Native turn-by-turn navigation intent
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
    try {
      final launched = await launchUrl(googleNavUri, mode: LaunchMode.externalNonBrowserApplication);
      if (launched) return;
    } catch (_) {}

    // 2. Generic geo: intent with store title
    final geoUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon(${Uri.encodeComponent(store.displayName)})');
    try {
      final launched = await launchUrl(geoUri, mode: LaunchMode.externalNonBrowserApplication);
      if (launched) return;
    } catch (_) {}

    // 3. Google Maps directions URL in external browser/app
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

  void _onStoreSelected(StoreModel store, int index, {bool animatePage = true, bool fitCamera = false}) {
    setState(() {
      _selectedStore = store;
    });
    if (store.hasValidLocation) {
      _fetchRoadRoute(
        LatLng(_userLat, _userLng),
        LatLng(store.latitude, store.longitude),
        fitCamera: fitCamera,
      );
    } else {
      setState(() {
        _roadRoutePoints = [];
        _roadDistanceKm = null;
        _roadDurationMinutes = null;
      });
    }
    try {
      final zoom = _mapController.camera.zoom;
      _mapController.move(LatLng(store.latitude, store.longitude), zoom);
    } catch (_) {}
    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showAllStoresSheet(BuildContext context, List<StoreModel> stores) async {
    if (_isShowingStoresSheet) return;
    _isShowingStoresSheet = true;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'All Nearby Stores (${stores.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: stores.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No stores found.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: stores.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 68),
                        itemBuilder: (ctx, i) {
                          final s = stores[i];
                          final dist = !s.hasValidLocation
                              ? 'Location not set'
                              : (s.distanceKm != null
                                  ? '${s.distanceKm!.toStringAsFixed(1)} km away'
                                  : 'Nearby');
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: AppColors.purpleGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: s.isOpen
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : AppColors.danger.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s.isOpen ? 'Open' : 'Closed',
                                    style: TextStyle(
                                      color: s.isOpen ? AppColors.success : AppColors.danger,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              s.address.isNotEmpty ? s.address : dist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onSelectStoreAndShop(s);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Shop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _onStoreSelected(s, i);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
    } finally {
      _isShowingStoresSheet = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CustomerThemeController>();
    final catalog = context.watch<CatalogProvider>();
    final allStores = List<StoreModel>.from(catalog.stores);
    // Sort nearest-first: located stores first sorted by distance, unlocated stores at end
    allStores.sort((a, b) {
      if (a.hasValidLocation && !b.hasValidLocation) return -1;
      if (!a.hasValidLocation && b.hasValidLocation) return 1;
      return (a.distanceKm ?? 999999).compareTo(b.distanceKm ?? 999999);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredStores = allStores.where((s) {
      if (_searchFilter.trim().isEmpty) return true;
      final q = _searchFilter.trim().toLowerCase();
      return s.displayName.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q);
    }).toList();

    final activeStore = (_selectedStore != null && filteredStores.any((s) => s.id == _selectedStore!.id))
        ? _selectedStore
        : (filteredStores.isNotEmpty ? filteredStores.first : null);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0B14) : const Color(0xFFE2E8F0),
      body: Stack(
        children: [
          // 1. FlutterMap (replaces CustomPaint vector map)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_userLat, _userLng),
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.stora_customer',
              ),
              // Road Route Polyline Layer
              if (_roadRoutePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Contrast casing outline
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
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (int i = 0; i < filteredStores.length; i++)
                    if (filteredStores[i].hasValidLocation)
                      Marker(
                        point: LatLng(filteredStores[i].latitude, filteredStores[i].longitude),
                        width: 140,
                        height: 100,
                        alignment: Alignment.topCenter,
                        child: _buildStorePin(
                          store: filteredStores[i],
                          isSelected: activeStore?.id == filteredStores[i].id,
                          index: i,
                        ),
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_userLat, _userLng),
                    width: 80,
                    height: 80,
                    child: _UserBeacon(pulseAnim: _pulseAnim),
                  ),
                ],
              ),
            ],
          ),

          // 2. Top Bar: Search and Filters
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cardBackground.withValues(alpha: 0.94)
                          : Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCBD5E1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchFilter = val);
                        // Reset PageController if current page would be out of bounds
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_pageController.hasClients && mounted) {
                            final currentPage = _pageController.page?.round() ?? 0;
                            if (currentPage > 0) {
                              _pageController.jumpToPage(0);
                            }
                          }
                        });
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search stores near you...',
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.textMuted : const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                color: isDark ? AppColors.textMuted : Colors.grey,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchFilter = '');
                                },
                              )
                            : IconButton(
                                icon: const Icon(Icons.list_alt_rounded, size: 20, color: AppColors.primary),
                                tooltip: 'Store list',
                                onPressed: () => _showAllStoresSheet(context, filteredStores),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        GestureDetector(
                          onTap: () => _showAllStoresSheet(context, filteredStores),
                          child: _FilterBadge(
                            icon: Icons.near_me_rounded,
                            label: '${filteredStores.length} stores nearby',
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showAllStoresSheet(context, filteredStores),
                          child: _FilterBadge(
                            icon: Icons.list_rounded,
                            label: 'List View',
                            color: const Color(0xFF38BDF8),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FilterBadge(
                          icon: Icons.storefront_rounded,
                          label: 'Sari-Sari & Retail',
                          color: const Color(0xFF4ADE80),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _FilterBadge(
                          icon: Icons.verified_rounded,
                          label: 'Verified Stora Owners',
                          color: const Color(0xFFFBBF24),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Road Distance & Duration Badge Overlay
          if (activeStore != null && (_roadDistanceKm != null || _isLoadingRoute))
            Positioned(
              left: 16,
              top: 136,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x50000000), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: _isLoadingRoute
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Calculating road route...',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: () {
                          if (activeStore.hasValidLocation) {
                            _fitRouteBounds(
                              LatLng(_userLat, _userLng),
                              LatLng(activeStore.latitude, activeStore.longitude),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_car_rounded, color: Color(0xFF38BDF8), size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '${activeStore.displayName}: $_roadDistanceKm km by road • ~$_roadDurationMinutes min',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

          // 3. Floating Map Controls (Recenter & Zoom)
          Positioned(
            right: 16,
            bottom: filteredStores.isNotEmpty ? 245 : 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh Stores',
                  isDark: isDark,
                  onTap: () {
                    context.read<CatalogProvider>().fetchStores(lat: _userLat, lng: _userLng);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Refreshing nearby stores...'),
                        backgroundColor: AppColors.cardElevated,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My Location',
                  isDark: isDark,
                  onTap: _recenter,
                ),
                const SizedBox(height: 8),
                if (_roadRoutePoints.isNotEmpty) ...[
                  _buildFloatingButton(
                    icon: Icons.alt_route_rounded,
                    tooltip: 'Fit Route',
                    isDark: isDark,
                    onTap: () {
                      if (activeStore != null && activeStore.hasValidLocation) {
                        _fitRouteBounds(
                          LatLng(_userLat, _userLng),
                          LatLng(activeStore.latitude, activeStore.longitude),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                _buildFloatingButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  isDark: isDark,
                  onTap: () => _zoom(1.0),
                ),
                const SizedBox(height: 8),
                _buildFloatingButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  isDark: isDark,
                  onTap: () => _zoom(-1.0),
                ),
              ],
            ),
          ),

          // 4. Empty State
          if (filteredStores.isEmpty)
            Positioned(
              left: 24,
              right: 24,
              top: 160,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.cardBackground.withValues(alpha: 0.96)
                      : Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppColors.cardBorder : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _searchFilter.isNotEmpty ? Icons.search_off_rounded : Icons.explore_off_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchFilter.isNotEmpty
                          ? 'No stores match "$_searchFilter"'
                          : 'No nearby stores found in this area',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchFilter.isNotEmpty
                          ? 'Try searching with another term or clear the filter.'
                          : 'Be the first to introduce local merchants to Stora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_searchFilter.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchFilter = '');
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Clear Search'),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.read<CatalogProvider>().fetchStores(lat: _userLat, lng: _userLng);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                          label: const Text('Refresh Map', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 5. Carousel
          if (filteredStores.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 86,
              child: SizedBox(
                height: 145,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: filteredStores.length,
                  onPageChanged: (index) {
                    final store = filteredStores[index];
                    setState(() {
                      _selectedStore = store;
                    });
                    if (store.hasValidLocation) {
                      _mapController.move(LatLng(store.latitude, store.longitude), _mapController.camera.zoom);
                      _fetchRoadRoute(LatLng(_userLat, _userLng), LatLng(store.latitude, store.longitude));
                    } else {
                      setState(() {
                        _roadRoutePoints = [];
                        _roadDistanceKm = null;
                        _roadDurationMinutes = null;
                      });
                    }
                  },
                  itemBuilder: (ctx, i) {
                    final store = filteredStores[i];
                    final isSelected = activeStore?.id == store.id;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: _StoreCarouselCard(
                        store: store,
                        isSelected: isSelected,
                        isDark: isDark,
                        roadDistanceKm: isSelected ? _roadDistanceKm : null,
                        roadDurationMinutes: isSelected ? _roadDurationMinutes : null,
                        onViewStore: () => widget.onSelectStoreAndShop(store),
                        onGetDirections: () => _openGoogleMapsDirections(store),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStorePin({
    required StoreModel store,
    required bool isSelected,
    required int index,
  }) {
    final distText = store.distanceKm != null
        ? '${store.distanceKm!.toStringAsFixed(1)} km'
        : 'Nearby';

    return GestureDetector(
      onTap: () => _onStoreSelected(store, index),
      child: AnimatedScale(
        scale: isSelected ? 1.18 : 1.0,
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFF1E182A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 120),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      store.isOpen ? store.displayName : '${store.displayName} (Closed)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distText,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : const Color(0xFF38BDF8),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFF56A10)])
                    : AppColors.purpleGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? AppColors.primary : const Color(0xFFC2410C)).withValues(alpha: 0.6),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: store.avatarUrl != null && store.avatarUrl!.isNotEmpty
                    ? Image.network(
                        store.avatarUrl!,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      )
                    : const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
            CustomPaint(
              size: const Size(12, 6),
              painter: _PinTrianglePainter(color: isSelected ? AppColors.primary : const Color(0xFFC2410C)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackground.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.96),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x35000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  final Color color;
  const _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTrianglePainter oldDelegate) => oldDelegate.color != color;
}

class _UserBeacon extends StatelessWidget {
  final AnimationController pulseAnim;

  const _UserBeacon({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        final val = pulseAnim.value;
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28 + (val * 52),
                height: 28 + (val * 52),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: (1.0 - val) * 0.7),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF38BDF8), blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _FilterBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackground.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: const [BoxShadow(color: Color(0x20000000), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCarouselCard extends StatelessWidget {
  final StoreModel store;
  final bool isSelected;
  final bool isDark;
  final double? roadDistanceKm;
  final int? roadDurationMinutes;
  final VoidCallback onViewStore;
  final VoidCallback onGetDirections;

  const _StoreCarouselCard({
    required this.store,
    required this.isSelected,
    required this.isDark,
    this.roadDistanceKm,
    this.roadDurationMinutes,
    required this.onViewStore,
    required this.onGetDirections,
  });

  @override
  Widget build(BuildContext context) {
    final distText = !store.hasValidLocation
        ? 'Location not set'
        : (isSelected && roadDistanceKm != null && roadDurationMinutes != null
            ? '$roadDistanceKm km by road • ~$roadDurationMinutes min'
            : (store.distanceKm != null
                ? '${store.distanceKm!.toStringAsFixed(1)} km away'
                : 'Nearby store'));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.primary : (isDark ? AppColors.cardBorder : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFF56A10)])
                  : AppColors.purpleGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: store.avatarUrl != null && store.avatarUrl!.isNotEmpty
                  ? Image.network(
                      store.avatarUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                    )
                  : const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  store.displayName,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.near_me_rounded, color: AppColors.accentText, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        distText,
                        style: TextStyle(color: AppColors.accentText, fontSize: 11, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      store.isOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        color: store.isOpen ? AppColors.successText : AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (store.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    store.address,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: onViewStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Shop', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
              if (store.hasValidLocation) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: onGetDirections,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car_rounded, size: 13, color: Color(0xFF38BDF8)),
                        SizedBox(width: 4),
                        Text(
                          'Route',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
