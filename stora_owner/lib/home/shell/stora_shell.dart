import 'package:flutter/material.dart';
import '../../data/stores/account_status_store.dart';
import '../../stora_login/stora_login.dart';
import '../screens/alerts_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/inventory_list_screen.dart';
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
  }

  @override
  void dispose() {
    AccountStatusStore.instance.removeListener(_checkPriceChange);
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
      decoration: const BoxDecoration(
        color: HomeColors.navBackground,
        border: Border(top: BorderSide(color: HomeColors.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            final item = _items[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.purple.withValues(alpha: 0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: selected ? AppColors.purpleLight : AppColors.label,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? AppColors.purpleLight : AppColors.label,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
