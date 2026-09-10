import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/order_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'cart/cart_screen.dart';
import 'map/store_map_screen.dart';
import 'orders/orders_screen.dart';
import 'profile/profile_screen.dart';
import 'shop/shop_screen.dart';



class MainShell extends StatefulWidget {
  final int initialTab;

  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    NotificationService.instance.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orderProvider = context.read<OrderProvider>();
      orderProvider.startPolling();
      orderProvider.onOrderStatusChanged = (order, newStatus) {
        if (!mounted) return;
        final isReady = newStatus == 'ready';
        final isAccepted = newStatus == 'accepted';
        final isDeclined = newStatus == 'declined' || newStatus == 'auto_declined';

        _showInAppCustomerPopup(
          title: isReady
              ? '🎉 Order #${order.id} Ready for Pickup!'
              : (isAccepted
                  ? '👨‍🍳 Order #${order.id} Accepted!'
                  : (isDeclined ? 'Order #${order.id} Declined' : 'Order #${order.id} Update')),
          message: isReady
              ? 'Your items are packed and ready for pickup at the store!'
              : (isAccepted
                  ? 'The store accepted your order and is now preparing it.'
                  : (isDeclined ? 'The store was unable to fulfill your order.' : 'The store updated your order.')),
          icon: isReady
              ? Icons.storefront_rounded
              : (isAccepted ? Icons.check_circle_rounded : (isDeclined ? Icons.cancel_outlined : Icons.info_outline_rounded)),
          accentColor: isReady
              ? const Color(0xFF00E676)
              : (isAccepted ? const Color(0xFFFF6B00) : (isDeclined ? const Color(0xFFEF4444) : const Color(0xFFFFA726))),
        );
      };
    });

    NotificationService.instance.onForegroundMessageReceived = (message) {
      if (!mounted) return;

      // Auto refresh customer orders when an update is pushed
      context.read<OrderProvider>().refresh();

      final title = message.notification?.title ?? message.data['title'] ?? 'Order Update';
      final body = message.notification?.body ?? message.data['body'] ?? 'Your order status has changed.';

      _showInAppCustomerPopup(
        title: title,
        message: body,
        icon: Icons.notifications_active_rounded,
        accentColor: const Color(0xFFFF6B00),
      );
    };
  }

  void _showInAppCustomerPopup({
    required String title,
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: const Color(0xFF1B1428),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor, width: 1.5),
        ),
        duration: const Duration(seconds: 8),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                setState(() => _currentIndex = 3);
              },
              style: TextButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'View',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      final orderProvider = context.read<OrderProvider>();
      orderProvider.stopPolling();
      orderProvider.onOrderStatusChanged = null;
    } catch (_) {}
    NotificationService.instance.onForegroundMessageReceived = null;
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    final screens = [
      ShopScreen(
        onGoToCart: () => setState(() => _currentIndex = 2),
      ),
      StoreMapScreen(
        onSelectStoreAndShop: (store) {
          context.read<CatalogProvider>().selectStore(store);
          setState(() => _currentIndex = 0); // Switch to Shop tab
        },
      ),
      CartScreen(
        onStartShopping: () => setState(() => _currentIndex = 0),
        onOrderPlaced: () => setState(() => _currentIndex = 3),
      ),
      OrdersScreen(
        onStartShopping: () => setState(() => _currentIndex = 0),
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.navBackground.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x60000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront_rounded,
                label: 'Shop',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map',
              ),
              _buildCartNavItem(cart: cart, index: 2),
              _buildNavItem(
                index: 3,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Orders',
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );

  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCartNavItem({required CartProvider cart, int index = 2}) {
    final isSelected = _currentIndex == index;
    final count = cart.totalItemCount;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined,
                  size: 22,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Text(
                'Cart',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
