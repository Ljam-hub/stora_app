import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/order_card.dart';

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
      context.read<OrderProvider>().fetchOrders();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => orderProvider.fetchOrders(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => orderProvider.refresh(),
        child: Column(
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

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f['label']!),
                      selected: isSelected,
                      onSelected: (_) => orderProvider.setFilter(f['id']!),
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

            // Orders list / Empty state
            Expanded(
              child: orderProvider.isLoading && orderProvider.rawOrders.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : orderProvider.orders.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No Orders Found',
                          message: orderProvider.selectedStatusFilter != 'all'
                              ? 'You have no orders in the "${orderProvider.selectedStatusFilter}" status.'
                              : 'You haven\'t placed any orders yet. Start exploring products to make your first purchase!',
                          buttonText: 'Start Shopping',
                          onButtonPressed: widget.onStartShopping,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orderProvider.orders.length,
                          itemBuilder: (context, index) {
                            final order = orderProvider.orders[index];
                            return OrderCard(order: order);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
