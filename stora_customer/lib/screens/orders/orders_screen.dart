import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/notification_badge.dart';
import '../../widgets/order_card.dart';
import '../../widgets/shimmer_order_card.dart';
import '../../widgets/fade_slide_in.dart';

class OrdersScreen extends StatefulWidget {
  final VoidCallback? onStartShopping;

  const OrdersScreen({super.key, this.onStartShopping});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<OrderProvider>();
      provider.fetchOrders();
      provider.markOrdersTabSeen();
      if (provider.selectedStatusFilter != 'all') {
        provider.markFilterSeen(provider.selectedStatusFilter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    final filters = [
      {'id': 'all', 'label': 'All Orders'},
      {'id': 'pending', 'label': 'Pending'},
      {'id': 'counter_offer', 'label': 'Counter-Offers'},
      {'id': 'accepted', 'label': 'Accepted'},
      {'id': 'declined', 'label': 'Declined'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final f = filters[index];
                final isSelected = orderProvider.selectedStatusFilter == f['id'];
                int badgeCount = 0;
                if (f['id'] == 'pending') badgeCount = orderProvider.unreadPendingCount;
                if (f['id'] == 'counter_offer') badgeCount = orderProvider.unreadCounterOfferCount;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(f['label']!),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 6),
                          AppNotificationBadge(
                            count: badgeCount,
                            minSize: 16,
                            borderColor: isSelected ? AppColors.primary : AppColors.cardBackground,
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      orderProvider.setFilter(f['id']!);
                    },
                    selectedColor: AppColors.cardElevated,
                    checkmarkColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.cardBackground,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Orders list / Empty state with swipe-to-refresh
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.cardElevated,
              onRefresh: () => orderProvider.refresh(),
              child: orderProvider.isLoading && orderProvider.rawOrders.isEmpty
                  ? ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: 4,
                      itemBuilder: (_, index) => const ShimmerOrderCard(),
                    )
                  : orderProvider.orders.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No Orders Found',
                                message: orderProvider.selectedStatusFilter != 'all'
                                    ? 'You have no orders in the "${orderProvider.selectedStatusFilter}" status.'
                                    : 'You haven\'t placed any orders yet. Start exploring products to make your first purchase!',
                                buttonText: 'Start Shopping',
                                onButtonPressed: widget.onStartShopping,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: orderProvider.orders.length,
                          itemBuilder: (context, index) {
                            final order = orderProvider.orders[index];
                            return FadeSlideIn(
                              delay: Duration(milliseconds: 60 * (index % 8)),
                              child: OrderCard(order: order),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
