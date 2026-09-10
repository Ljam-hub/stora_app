import 'package:flutter/material.dart';
import '../../data/services/notification_service.dart';
import '../../data/stores/account_status_store.dart';
import '../../stora_login/stora_login.dart';
import '../screens/alerts_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/inventory_list_screen.dart';
import '../screens/pending_orders_screen.dart';
import '../screens/pos_screen.dart';
import '../stores/category_store.dart';
import '../stores/inventory_store.dart';
import '../stores/orders_store.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';

/// App shell — bottom nav with 4 tabs. "Add / Edit product" and "Sales
/// history" are pushed on top rather than being tabs, since they're
/// flows, not destinations.
class StoraShell extends StatefulWidget {
  const StoraShell({super.key});

  @override
  State<StoraShell> createState() => _StoraShellState();
}

class _StoraShellState extends State<StoraShell> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    InventoryListScreen(),
    PosScreen(),
    AlertsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AccountStatusStore.instance.addListener(_checkPriceChange);
    AccountStatusStore.instance.fetchStatus();
    InventoryStore.instance.loadProducts();
    CategoryStore.instance.loadCategories();
    SalesStore.instance.loadSales();
    OrdersStore.instance.fetchOrders();
    OrdersStore.instance.startPolling();
    OwnerNotificationService.instance.init();

    OrdersStore.instance.onNewOrderReceived = (order) {
      if (!mounted) return;
      final id = order['id'];
      final cust = (order['customer_name'] as String?)?.trim();
      final name = (cust != null && cust.isNotEmpty) ? cust : 'A customer';
      final total = order['total_amount']?.toString() ?? '0.00';
      _showInAppOrderPopup(
        title: '🔔 New Order #$id Received!',
        message: '$name placed an order for ₱$total.',
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
          );
        },
      );
    };

    OwnerNotificationService.instance.onForegroundMessageReceived = (message) {
      if (!mounted) return;
      final title = message.notification?.title ?? message.data['title'] ?? 'New Customer Order';
      final body = message.notification?.body ?? message.data['body'] ?? 'A customer just placed an order!';
      _showInAppOrderPopup(
        title: title,
        message: body,
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
          );
        },
      );
    };
  }

  void _showInAppOrderPopup({
    required String title,
    required String message,
    required VoidCallback onAction,
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
          side: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
        ),
        duration: const Duration(seconds: 8),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                color: Color(0xFFFF6B00),
                size: 22,
              ),
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
                onAction();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Review',
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
    OrdersStore.instance.stopPolling();
    OrdersStore.instance.onNewOrderReceived = null;
    AccountStatusStore.instance.removeListener(_checkPriceChange);
    OwnerNotificationService.instance.onForegroundMessageReceived = null;
    super.dispose();
  }

  void _checkPriceChange() {
    final prompt = AccountStatusStore.instance.priceChangePrompt;
    if (prompt != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AccountStatusStore.instance.clearPriceChangePrompt();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: HomeColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.campaign_rounded, color: AppColors.purpleLight),
                SizedBox(width: 10),
                Text('Price Update', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              prompt,
              style: const TextStyle(color: AppColors.label, fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got it', style: TextStyle(color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _StoraNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _StoraNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _StoraNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(Icons.space_dashboard_rounded, 'Home'),
    _NavItem(Icons.inventory_2_rounded, 'Inventory'),
    _NavItem(Icons.point_of_sale_rounded, 'Sales'),
    _NavItem(Icons.notifications_rounded, 'Alerts'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          decoration: BoxDecoration(
            color: HomeColors.navBackground.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HomeColors.cardBorderLight.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final item = _items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.purple.withValues(alpha: 0.16) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? AppColors.purple.withValues(alpha: 0.3) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: selected ? AppColors.purpleLight : AppColors.label,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? AppColors.purpleLight : AppColors.label,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                            letterSpacing: selected ? 0.2 : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
