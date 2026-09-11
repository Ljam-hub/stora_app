import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/store_model.dart';
import '../../providers/catalog_provider.dart';
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

    _acquireLocation();
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

      if (position != null && mounted) {
        setState(() {
          _userLat = position!.latitude;
          _userLng = position.longitude;
        });
        _mapController.move(LatLng(_userLat, _userLng), 15.0);
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        content: Text('Locating your GPS position...'),
      ),
    );
    await _acquireLocation();
    _mapController.move(LatLng(_userLat, _userLng), 15.0);
  }

  void _zoom(double delta) {
    final newZoom = (_mapController.camera.zoom + delta).clamp(1.0, 20.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  void _onStoreSelected(StoreModel store, int index, {bool animatePage = true}) {
    setState(() {
      _selectedStore = store;
    });
    _mapController.move(LatLng(store.latitude, store.longitude), _mapController.camera.zoom);
    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showAllStoresSheet(BuildContext context, List<StoreModel> stores) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
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
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
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
                          final dist = s.distanceKm != null
                              ? '${s.distanceKm!.toStringAsFixed(1)} km away'
                              : 'Nearby';
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
                            title: Text(
                              s.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              s.address.isNotEmpty ? s.address : dist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final allStores = catalog.stores;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredStores = allStores.where((s) {
      if (_searchFilter.trim().isEmpty) return true;
      final q = _searchFilter.trim().toLowerCase();
      return s.displayName.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q);
    }).toList();

    if (_selectedStore == null && filteredStores.isNotEmpty) {
      _selectedStore = filteredStores.first;
    }

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
              MarkerLayer(
                markers: [
                  for (int i = 0; i < filteredStores.length; i++)
                    Marker(
                      point: LatLng(filteredStores[i].latitude, filteredStores[i].longitude),
                      width: 140,
                      height: 100,
                      alignment: Alignment.topCenter,
                      child: _buildStorePin(
                        store: filteredStores[i],
                        isSelected: _selectedStore?.id == filteredStores[i].id,
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
                      onChanged: (val) => setState(() => _searchFilter = val),
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

          // 3. Floating Map Controls (Recenter & Zoom)
          Positioned(
            right: 16,
            bottom: filteredStores.isNotEmpty ? 245 : 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My Location',
                  isDark: isDark,
                  onTap: _recenter,
                ),
                const SizedBox(height: 8),
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
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                    _mapController.move(LatLng(store.latitude, store.longitude), _mapController.camera.zoom);
                  },
                  itemBuilder: (ctx, i) {
                    final store = filteredStores[i];
                    final isSelected = _selectedStore?.id == store.id;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: _StoreCarouselCard(
                        store: store,
                        isSelected: isSelected,
                        isDark: isDark,
                        onViewStore: () => widget.onSelectStoreAndShop(store),
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
                      store.displayName,
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
  final VoidCallback onViewStore;

  const _StoreCarouselCard({
    required this.store,
    required this.isSelected,
    required this.isDark,
    required this.onViewStore,
  });

  @override
  Widget build(BuildContext context) {
    final distText = store.distanceKm != null
        ? '${store.distanceKm!.toStringAsFixed(1)} km away'
        : 'Nearby store';

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
                    const Icon(Icons.near_me_rounded, color: AppColors.primaryLight, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      distText,
                      style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Open', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
                if (store.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    store.address,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onViewStore,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        ],
      ),
    );
  }
}
