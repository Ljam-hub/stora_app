import 'package:flutter/material.dart';
import '../../stora_login/theme/app_colors.dart';
import '../stores/orders_store.dart';
import '../theme/home_colors.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  String _filter = 'pending'; // 'pending', 'all'

  @override
  void initState() {
    super.initState();
    OrdersStore.instance.fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Customer Orders',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.purpleLight),
            onPressed: () => OrdersStore.instance.fetchOrders(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: OrdersStore.instance,
        builder: (context, _) {
          final store = OrdersStore.instance;

          if (store.isLoading && store.orders.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.purpleLight),
            );
          }

          if (store.error != null && store.orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: HomeColors.dangerText, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      store.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.label, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purpleLight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => store.fetchOrders(),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allOrders = store.orders;
          final displayedOrders = _filter == 'pending'
              ? allOrders.where((o) => o['status'] == 'pending' || o['status'] == 'counter_offer').toList()
              : allOrders;

          return RefreshIndicator(
            color: AppColors.purpleLight,
            backgroundColor: HomeColors.cardBackground,
            onRefresh: () => store.fetchOrders(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Filter chips
                Row(
                  children: [
                    _FilterChip(
                      label: 'Active / Pending (${store.pendingCount})',
                      isSelected: _filter == 'pending',
                      onTap: () => setState(() => _filter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'All Orders (${allOrders.length})',
                      isSelected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (displayedOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: HomeColors.cardElevated,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.label,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'pending' ? 'No pending orders' : 'No orders found',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Incoming customer carts will appear here.',
                            style: TextStyle(color: AppColors.label, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...displayedOrders.map((order) => _OrderCard(order: order)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purpleLight : HomeColors.cardElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.purpleLight : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.label,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isExpanded = true;
  bool _isProcessing = false;

  int get orderId => widget.order['id'] as int;
  String get status => (widget.order['status'] as String?) ?? 'pending';
  String get customerName => (widget.order['customer_name'] as String?) ?? 'Customer';
  String get customerPhone => (widget.order['customer_phone'] as String?) ?? '';
  String get customerAddress => (widget.order['customer_address'] as String?) ?? '';
  String get notes => (widget.order['notes'] as String?) ?? '';
  String get totalAmount => widget.order['total_amount']?.toString() ?? '0.00';
  List get items => (widget.order['items'] as List?) ?? [];

  Color get _statusColor {
    switch (status) {
      case 'accepted':
        return HomeColors.successText;
      case 'declined':
      case 'auto_declined':
        return HomeColors.dangerText;
      case 'counter_offer':
        return const Color(0xFFFFA726);
      default:
        return AppColors.purpleLight;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'accepted':
        return 'ACCEPTED';
      case 'declined':
        return 'DECLINED';
      case 'auto_declined':
        return 'EXPIRED';
      case 'counter_offer':
        return 'COUNTERED';
      default:
        return 'PENDING REVIEW';
    }
  }

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      await OrdersStore.instance.acceptOrder(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HomeColors.successBg,
            content: Text('Order #$orderId accepted! Stock deducted and recorded in sales.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HomeColors.dangerBg,
            content: Text('Failed to accept order: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDeclineDialog() {
    final controller = TextEditingController();
    String selectedReason = 'Out of stock';
    final standardReasons = ['Out of stock', 'Store closed', 'Outside delivery area', 'Custom reason'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Decline Order', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Select reason for customer:', style: TextStyle(color: AppColors.label, fontSize: 13)),
              const SizedBox(height: 10),
              ...standardReasons.map((r) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.purpleLight,
                    title: Text(r, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (val) => setDialogState(() => selectedReason = val!),
                  )),
              if (selectedReason == 'Custom reason') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter reason...',
                    hintStyle: const TextStyle(color: AppColors.label),
                    filled: true,
                    fillColor: HomeColors.cardElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeColors.dangerText,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final reason = selectedReason == 'Custom reason' ? controller.text.trim() : selectedReason;
                Navigator.of(ctx).pop();
                setState(() => _isProcessing = true);
                try {
                  await OrdersStore.instance.declineOrder(orderId, reason: reason);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: HomeColors.cardElevated,
                        content: Text('Order #$orderId declined.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: const Text('Decline Order'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCounterDialog() {
    final notesController = TextEditingController();
    final priceController = TextEditingController(text: totalAmount);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Propose Counter-Offer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Suggest modifications or adjusted pricing to the customer:',
              style: TextStyle(color: AppColors.label, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Notes for Customer *',
                labelStyle: const TextStyle(color: AppColors.label),
                hintText: 'e.g. Medium size substituted, ₱20 discount',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: HomeColors.cardElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Adjusted Total (₱)',
                labelStyle: const TextStyle(color: AppColors.label),
                filled: true,
                fillColor: HomeColors.cardElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA726),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) return;
              final price = double.tryParse(priceController.text.trim());
              Navigator.of(ctx).pop();
              setState(() => _isProcessing = true);
              try {
                await OrdersStore.instance.counterOrder(
                  orderId,
                  notes: notes,
                  counterPrice: price,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: HomeColors.cardElevated,
                      content: Text('Counter-offer sent for Order #$orderId.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text('Send Counter', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending' || status == 'counter_offer';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? AppColors.purpleLight.withValues(alpha: 0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #$orderId',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customerName,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱$totalAmount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Contact Details
          if (customerPhone.isNotEmpty || customerAddress.isNotEmpty || notes.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HomeColors.cardElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerPhone.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, color: AppColors.label, size: 14),
                        const SizedBox(width: 6),
                        Text(customerPhone, style: const TextStyle(color: AppColors.label, fontSize: 12)),
                      ],
                    ),
                  if (customerAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.label, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(customerAddress, style: const TextStyle(color: AppColors.label, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded, color: AppColors.label, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Note: "$notes"', style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Items Divider & Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.label,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Items List
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: items.map<Widget>((item) {
                  final name = item['product_name'] ?? 'Item';
                  final qty = item['quantity'] ?? 1;
                  final price = item['unit_price'] ?? '0.00';
                  final subtotal = item['subtotal'] ?? '0.00';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${qty}x',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              Text(
                                '₱$price each',
                                style: const TextStyle(color: AppColors.label, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱$subtotal',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // Action Buttons for Pending Orders
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _isProcessing
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(color: AppColors.purpleLight),
                      ),
                    )
                  : Row(
                      children: [
                        // Decline
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HomeColors.dangerText,
                              side: const BorderSide(color: HomeColors.dangerText),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _showDeclineDialog,
                            child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Counter
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFA726),
                              side: const BorderSide(color: Color(0xFFFFA726)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _showCounterDialog,
                            child: const Text('Counter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Accept
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HomeColors.successText,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _handleAccept,
                            child: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
