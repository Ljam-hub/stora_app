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

class _StoreMapScreenState extends State<StoreMapScreen> {
  final _searchController = TextEditingController();
  StoreModel? _selectedStore;
  String _searchFilter = '';

  // Simulated customer GPS location (e.g. Central Manila)
  final double _userLat = 14.5995;
  final double _userLng = 120.9842;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogProvider>().fetchStores(lat: _userLat, lng: _userLng);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final allStores = catalog.stores;

    final filteredStores = allStores.where((s) {
      if (_searchFilter.trim().isEmpty) return true;
      final q = _searchFilter.trim().toLowerCase();
      return s.displayName.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Interactive Stylized Map View
          Positioned.fill(
            child: _InteractiveMapCanvas(
              stores: filteredStores,
              selectedStore: _selectedStore,
              onPinTapped: (store) {
                setState(() => _selectedStore = store);
              },
            ),
          ),

          // 2. Search Bar at Top (matching Stitch Store Map Discovery Screen)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x70000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchFilter = val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search stores near you...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchFilter = '');
                            },
                          )
                        : const Icon(Icons.tune_rounded, color: AppColors.textMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Quick Info Chips
          Positioned(
            top: 120,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterBadge(
                    icon: Icons.near_me_rounded,
                    label: '${filteredStores.length} stores nearby',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const _FilterBadge(
                    icon: Icons.storefront_rounded,
                    label: 'Sari-Sari & Retail',
                    color: Color(0xFF4ADE80),
                  ),
                  const SizedBox(width: 8),
                  const _FilterBadge(
                    icon: Icons.verified_rounded,
                    label: 'Verified Stora Owners',
                    color: Color(0xFF38BDF8),
                  ),
                ],
              ),
            ),
          ),

          // 4. Selected Store Bottom Drawer Card matching Stitch design
          if (_selectedStore != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _StoreDetailCard(
                store: _selectedStore!,
                onClose: () => setState(() => _selectedStore = null),
                onViewStore: () {
                  widget.onSelectStoreAndShop(_selectedStore!);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FilterBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StoreDetailCard extends StatelessWidget {
  final StoreModel store;
  final VoidCallback onClose;
  final VoidCallback onViewStore;

  const _StoreDetailCard({
    required this.store,
    required this.onClose,
    required this.onViewStore,
  });

  @override
  Widget build(BuildContext context) {
    final distanceText = store.distanceKm != null
        ? '${store.distanceKm!.toStringAsFixed(1)} km away'
        : 'Nearby store';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x90000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.glowShadow(AppColors.primary, opacity: 0.35),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
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
                          distanceText,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Open for pickup',
                          style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          if (store.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      store.address,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onViewStore,
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 18),
              label: const Text(
                'View Store Catalog',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveMapCanvas extends StatelessWidget {
  final List<StoreModel> stores;
  final StoreModel? selectedStore;
  final Function(StoreModel store) onPinTapped;

  const _InteractiveMapCanvas({
    required this.stores,
    required this.selectedStore,
    required this.onPinTapped,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // Dark map texture
            CustomPaint(
              size: Size(w, h),
              painter: _CustomerMapPainter(),
            ),

            // Store markers placed dynamically on canvas
            for (int i = 0; i < stores.length; i++) ...[
              _buildPin(stores[i], i, stores.length, w, h),
            ],

            // User location indicator (center)
            Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF38BDF8), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPin(StoreModel store, int index, int total, double w, double h) {
    final angle = (index * (2 * math.pi / (total == 0 ? 1 : total))) + 0.3;
    final radius = 90.0 + ((index % 3) * 45.0);

    final cx = (w / 2) + (math.cos(angle) * radius);
    final cy = (h / 2) + (math.sin(angle) * radius);

    final isSelected = selectedStore?.id == store.id;

    return Positioned(
      left: cx - 28,
      top: cy - 36,
      child: GestureDetector(
        onTap: () => onPinTapped(store),
        child: AnimatedScale(
          scale: isSelected ? 1.25 : 1.0,
          duration: const Duration(milliseconds: 250),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.white : AppColors.cardBorder,
                    width: 1,
                  ),
                  boxShadow: const [BoxShadow(color: Color(0x50000000), blurRadius: 8)],
                ),
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  store.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)])
                      : AppColors.purpleGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isSelected ? const Color(0xFFFBBF24) : AppColors.primary).withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: Colors.black,
                  size: isSelected ? 18 : 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Map base background
    final bg = Paint()..color = const Color(0xFF0F0B18);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // City grid lines
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Stylized avenues & highways
    final highway = Paint()
      ..color = const Color(0xFF231B36)
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round;

    final avenue = Paint()
      ..color = const Color(0xFF1B142A)
      ..strokeWidth = 8.0;

    // Diagonal arterial roads
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.75), highway);
    canvas.drawLine(Offset(size.width * 0.1, 0), Offset(size.width * 0.85, size.height), highway);
    canvas.drawLine(Offset(0, size.height * 0.6), Offset(size.width, size.height * 0.3), avenue);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.2, size.height), avenue);

    // River / waterway feature
    final river = Paint()
      ..color = const Color(0xFF10263E).withValues(alpha: 0.7)
      ..strokeWidth = 24.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.85);
    path.quadraticBezierTo(size.width * 0.45, size.height * 0.75, size.width, size.height * 0.95);
    canvas.drawPath(path, river);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
