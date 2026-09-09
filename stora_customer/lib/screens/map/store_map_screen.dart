import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  StoreModel? _selectedStore;
  String _searchFilter = '';

  // Pan and Zoom gesture state
  Offset _panOffset = Offset.zero;
  double _zoomLevel = 1.0;
  double _baseZoom = 1.0;

  // Radar beacon pulse animation
  late final AnimationController _pulseAnim;

  // Customer GPS coordinates (Central Manila default)
  final double _userLat = 14.5995;
  final double _userLng = 120.9842;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().fetchStores(lat: _userLat, lng: _userLng);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  void _recenter() {
    setState(() {
      _panOffset = Offset.zero;
      _zoomLevel = 1.0;
    });
  }

  void _zoom(double delta) {
    setState(() {
      _zoomLevel = (_zoomLevel + delta).clamp(0.7, 2.2);
    });
  }

  void _onStoreSelected(StoreModel store, int index, {bool animatePage = true}) {
    setState(() {
      _selectedStore = store;
    });
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

    // Auto-select first store if none selected
    if (_selectedStore == null && filteredStores.isNotEmpty) {
      _selectedStore = filteredStores.first;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0B14) : const Color(0xFFE2E8F0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;

          // Viewport Center: User GPS marker is placed right here
          final center = Offset(screenW / 2 + _panOffset.dx, screenH * 0.42 + _panOffset.dy);

          // Calculate pin positions
          final List<Offset> pinPositions = [];
          for (int i = 0; i < filteredStores.length; i++) {
            final s = filteredStores[i];
            final dLat = s.latitude - _userLat;
            final dLng = s.longitude - _userLng;

            final isCoLocated = (dLat.abs() < 0.0001 && dLng.abs() < 0.0001);

            double ox;
            double oy;

            if (!isCoLocated) {
              final kmX = dLng * 111.0 * math.cos(_userLat * math.pi / 180);
              final kmY = dLat * 111.0;
              ox = center.dx + (kmX * 90.0 * _zoomLevel);
              oy = center.dy - (kmY * 90.0 * _zoomLevel);
            } else {
              // Radial distribution around user location
              final angle = (i * (2 * math.pi / (filteredStores.isEmpty ? 1 : filteredStores.length))) - (math.pi / 2) + 0.3;
              final radius = (120.0 + ((i % 3) * 35.0)) * _zoomLevel;
              ox = center.dx + (math.cos(angle) * radius);
              oy = center.dy + (math.sin(angle) * radius);
            }
            pinPositions.add(Offset(ox, oy));
          }

          return Stack(
            children: [
              // 1. Gesture Detector for Panning and Pinch-to-Zoom
              GestureDetector(
                onScaleStart: (details) {
                  _baseZoom = _zoomLevel;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _zoomLevel = (_baseZoom * details.scale).clamp(0.7, 2.2);
                    _panOffset += details.focalPointDelta;
                  });
                },
                child: SizedBox(
                  width: screenW,
                  height: screenH,
                  child: Stack(
                    children: [
                      // Vector Stylized Map Graphic
                      CustomPaint(
                        size: Size(screenW, screenH),
                        painter: _StylizedCityMapPainter(
                          center: center,
                          zoom: _zoomLevel,
                          pinPositions: pinPositions,
                          isDark: isDark,
                        ),
                      ),

                      // User GPS Beacon in Center
                      Positioned(
                        left: center.dx - 40,
                        top: center.dy - 40,
                        child: _UserBeacon(pulseAnim: _pulseAnim),
                      ),

                      // Interactive Store Pins
                      for (int i = 0; i < filteredStores.length; i++) ...[
                        _buildStorePin(
                          store: filteredStores[i],
                          pos: pinPositions[i],
                          isSelected: _selectedStore?.id == filteredStores[i].id,
                          index: i,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 2. Top Bar: Search and Filters
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search Container
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

                      // Quick Info Chips
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
                      onTap: () => _zoom(0.25),
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom Out',
                      isDark: isDark,
                      onTap: () => _zoom(-0.25),
                    ),
                  ],
                ),
              ),

              // 4. Empty State if no stores found
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

              // 5. Swipable Horizontal Store Cards Carousel at Bottom
              // Positioned at bottom: 86 to comfortably sit above MainShell floating bottom nav bar
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
                        setState(() {
                          _selectedStore = filteredStores[index];
                        });
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
          );
        },
      ),
    );
  }

  Widget _buildStorePin({
    required StoreModel store,
    required Offset pos,
    required bool isSelected,
    required int index,
  }) {
    final distText = store.distanceKm != null
        ? '${store.distanceKm!.toStringAsFixed(1)} km'
        : 'Nearby';

    return Positioned(
      left: pos.dx - 60,
      top: pos.dy - 68,
      child: GestureDetector(
        onTap: () => _onStoreSelected(store, index),
        child: AnimatedScale(
          scale: isSelected ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin Label Pill
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

              // Pin Icon Badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [Color(0xFFFF9E58), Color(0xFFFF6B00)])
                      : AppColors.purpleGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: (isSelected ? AppColors.primary : const Color(0xFF8B5CF6)).withValues(alpha: 0.6),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              // Pin Triangle Pointer
              CustomPaint(
                size: const Size(12, 6),
                painter: _PinTrianglePainter(color: isSelected ? AppColors.primary : const Color(0xFFA04100)),
              ),
            ],
          ),
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
    final path = Path()
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
              // Outer radar pulse
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
              // Glowing translucent aura
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
              // Center Core Dot
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
          // Store Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: [Color(0xFFFF9E58), Color(0xFFFF6B00)])
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
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),

          // Store Info
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

          // Action Button
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

/// Stylized City Map Canvas Painter with high contrast road layout, avenues,
/// parklands, waterways, and dotted GPS guide lines connecting to nearby stores.
class _StylizedCityMapPainter extends CustomPainter {
  final Offset center;
  final double zoom;
  final List<Offset> pinPositions;
  final bool isDark;

  const _StylizedCityMapPainter({
    required this.center,
    required this.zoom,
    required this.pinPositions,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base Land Color
    final landPaint = Paint()
      ..color = isDark ? const Color(0xFF130E20) : const Color(0xFFE8EEF5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // 2. City Blocks / Neighborhood Grids
    final blockPaint = Paint()
      ..color = isDark ? const Color(0xFF1B142D) : Colors.white
      ..style = PaintingStyle.fill;

    final blockBorder = Paint()
      ..color = isDark ? const Color(0xFF281E40) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const blockSize = 90.0;
    final gridOffsetX = center.dx % blockSize;
    final gridOffsetY = center.dy % blockSize;

    for (double x = -blockSize + gridOffsetX; x < size.width + blockSize; x += blockSize) {
      for (double y = -blockSize + gridOffsetY; y < size.height + blockSize; y += blockSize) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 10, y + 10, blockSize - 20, blockSize - 20),
          const Radius.circular(14),
        );
        canvas.drawRRect(rect, blockPaint);
        canvas.drawRRect(rect, blockBorder);
      }
    }

    // 3. Green Park Zones
    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF11301F) : const Color(0xFFDCFCE7)
      ..style = PaintingStyle.fill;

    final parkRect1 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx - 180 * zoom, center.dy - 120 * zoom), width: 180 * zoom, height: 130 * zoom),
      const Radius.circular(24),
    );
    canvas.drawRRect(parkRect1, parkPaint);

    final parkRect2 = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx + 200 * zoom, center.dy + 150 * zoom), width: 220 * zoom, height: 140 * zoom),
      const Radius.circular(28),
    );
    canvas.drawRRect(parkRect2, parkPaint);

    // 4. Meandering River / Canal
    final riverPaint = Paint()
      ..color = isDark ? const Color(0xFF113254) : const Color(0xFFBAE6FD)
      ..strokeWidth = 36.0 * zoom
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final riverPath = Path()
      ..moveTo(-50, center.dy + 220 * zoom)
      ..quadraticBezierTo(
        center.dx - 80 * zoom, center.dy + 160 * zoom,
        center.dx + 80 * zoom, center.dy + 260 * zoom,
      )
      ..quadraticBezierTo(
        center.dx + 240 * zoom, center.dy + 340 * zoom,
        size.width + 50, center.dy + 280 * zoom,
      );
    canvas.drawPath(riverPath, riverPaint);

    // 5. Major Arterial Avenues (Horizontal & Vertical)
    final avenuePaint = Paint()
      ..color = isDark ? const Color(0xFF261D3B) : const Color(0xFFCBD5E1)
      ..strokeWidth = 26.0 * zoom
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(-50, center.dy), Offset(size.width + 50, center.dy), avenuePaint);
    canvas.drawLine(Offset(center.dx, -50), Offset(center.dx, size.height + 50), avenuePaint);

    // Diagonal Express Highway
    final highwayPaint = Paint()
      ..color = isDark ? const Color(0xFF322450) : const Color(0xFF94A3B8)
      ..strokeWidth = 32.0 * zoom
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - 350 * zoom, center.dy - 350 * zoom),
      Offset(center.dx + 350 * zoom, center.dy + 350 * zoom),
      highwayPaint,
    );

    // Highway Center Line (Dashed)
    final dashPaint = Paint()
      ..color = isDark ? const Color(0xFFFBBF24).withValues(alpha: 0.6) : Colors.white
      ..strokeWidth = 2.0 * zoom;

    for (double d = -300; d < 300; d += 24) {
      canvas.drawLine(
        Offset(center.dx + d * zoom, center.dy + d * zoom),
        Offset(center.dx + (d + 12) * zoom, center.dy + (d + 12) * zoom),
        dashPaint,
      );
    }

    // 6. Central Roundabout Plaza
    final plazaPaint = Paint()
      ..color = isDark ? const Color(0xFF322450) : const Color(0xFF94A3B8)
      ..strokeWidth = 22.0 * zoom
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 55 * zoom, plazaPaint);

    final islandPaint = Paint()
      ..color = isDark ? const Color(0xFF1E1730) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 44 * zoom, islandPaint);

    // 7. Route Guides: Dotted glowing navigation lines from user to nearby store pins
    final routePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final pinPos in pinPositions) {
      final double dist = (pinPos - center).distance;
      if (dist > 10) {
        final double step = 12.0;
        final int steps = (dist / step).floor();
        for (int i = 0; i < steps; i += 2) {
          final t1 = i / steps;
          final t2 = (i + 1) / steps;
          final p1 = Offset.lerp(center, pinPos, t1)!;
          final p2 = Offset.lerp(center, pinPos, t2)!;
          canvas.drawLine(p1, p2, routePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StylizedCityMapPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.zoom != zoom ||
        oldDelegate.isDark != isDark ||
        oldDelegate.pinPositions.length != pinPositions.length;
  }
}
