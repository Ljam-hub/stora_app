import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class CheckoutScreen extends StatefulWidget {
  final VoidCallback? onOrderPlaced;

  const CheckoutScreen({super.key, this.onOrderPlaced});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  final _notesController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.currentUser?.name ?? '');
    _phoneController = TextEditingController(text: auth.savedPhone ?? '');
    _addressController = TextEditingController(text: auth.savedAddress ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handlePlaceOrder() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final cart = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();
    final auth = context.read<AuthProvider>();

    final storeOwnerId = cart.storeId;
    if (storeOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot place order: Store information missing.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Save delivery details for future convenience
      await auth.saveDeliveryDetails(
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );

      final order = await orderProvider.placeOrder(
        ownerId: storeOwnerId,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerAddress: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        items: cart.toOrderItems(),
      );

      cart.clear();

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showOrderSuccessDialog(order.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showOrderSuccessDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success),
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.success, size: 40),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Order Placed Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #$orderId has been submitted to the store. You will receive real-time updates as the owner accepts or prepares your order.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          GradientButton(
            text: 'Track Order',
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close checkout screen
              if (widget.onOrderPlaced != null) {
                widget.onOrderPlaced!();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Order'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Store Header Card
                if (cart.storeName != null && cart.storeName!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ordering from',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                              Text(
                                cart.storeName!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Delivery Info Section
                const Text(
                  'Delivery Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _nameController,
                  label: 'Customer Full Name',
                  hint: 'Juan Dela Cruz',
                  prefixIcon: Icons.person_outline,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _phoneController,
                  label: 'Contact Phone Number',
                  hint: '0912 345 6789',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your contact phone' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _addressController,
                  label: 'Delivery / Pickup Address',
                  hint: 'House/Unit No., Street, Barangay, City',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please provide your address' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _notesController,
                  label: 'Order Notes / Instructions (Optional)',
                  hint: 'e.g. Please deliver before 5 PM, ring the bell',
                  prefixIcon: Icons.note_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Order Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...cart.items.map(
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${i.quantity}x ${i.product.name}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              Text(
                                i.formattedSubtotal,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20, color: AppColors.cardBorder),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            cart.formattedTotal,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Place Order Button
                GradientButton(
                  text: 'Place Order (${cart.formattedTotal})',
                  icon: Icons.send_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _handlePlaceOrder,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
