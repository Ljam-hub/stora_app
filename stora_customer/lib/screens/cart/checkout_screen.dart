import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/location_service.dart';
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
  bool _isLocating = false;

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

  Future<void> _handleAutoLocate() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Locating your current address...'),
          ],
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await LocationService.instance.detectCurrentAddress();

    if (!mounted) return;
    setState(() => _isLocating = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.success && result.address != null && result.address!.isNotEmpty) {
      _addressController.text = result.address!;
      context.read<AuthProvider>().saveDeliveryDetails(
        address: result.address!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location detected: ${result.address!}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to detect location. Please enter your address manually.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handlePlaceOrder() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    if (_formKey.currentState?.validate() != true) {
      setState(() => _isSubmitting = false);
      return;
    }
    FocusScope.of(context).unfocus();
    final orderProvider = context.read<OrderProvider>();
    final auth = context.read<AuthProvider>();

    final storeOwnerId = cart.storeId;
    if (storeOwnerId == null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot place order: Store information missing.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final catalog = context.read<CatalogProvider>();
    var store = catalog.stores.where((s) => s.id == storeOwnerId).firstOrNull ??
        (catalog.selectedStore?.id == storeOwnerId ? catalog.selectedStore : null);
    if (store == null) {
      try {
        await catalog.fetchStores();
        store = catalog.stores.where((s) => s.id == storeOwnerId).firstOrNull ??
            (catalog.selectedStore?.id == storeOwnerId ? catalog.selectedStore : null);
      } catch (_) {}
    }
    if (store == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot place order: Store information could not be retrieved.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (!store.isOpen) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot place order: This store is currently closed.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

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
    bool dismissed = false;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return PopScope(
          canPop: false,
          child: Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Order Placed!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order #$orderId has been submitted to the store. You will receive real-time updates as the owner accepts or prepares your order.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      key: const Key('checkout_track_order_button'),
                      text: 'Track Order',
                      onPressed: () {
                        if (dismissed) return;
                        dismissed = true;
                        Navigator.pop(ctx);
                        if (mounted) {
                          Navigator.pop(context);
                        }
                        widget.onOrderPlaced?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CustomerThemeController>();
    final cart = context.watch<CartProvider>();
    final catalog = context.watch<CatalogProvider>();
    final storeOwnerId = cart.storeId;
    final currentStore = storeOwnerId != null
        ? (catalog.stores.where((s) => s.id == storeOwnerId).firstOrNull ??
            (catalog.selectedStore?.id == storeOwnerId ? catalog.selectedStore : null))
        : null;
    final isStoreClosed = currentStore != null && !currentStore.isOpen;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Checkout Order',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
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
                              Text(
                                'Ordering from',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                              Text(
                                cart.storeName!,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
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
                Text(
                  'Delivery Information',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  key: const Key('checkout_name_field'),
                  fieldKey: const Key('checkout_name_input'),
                  controller: _nameController,
                  label: 'Customer Full Name',
                  hint: 'Juan Dela Cruz',
                  prefixIcon: Icons.person_outline,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  key: const Key('checkout_phone_field'),
                  fieldKey: const Key('checkout_phone_input'),
                  controller: _phoneController,
                  label: 'Contact Phone Number',
                  hint: '0912 345 6789',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your contact phone' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  key: const Key('checkout_address_field'),
                  fieldKey: const Key('checkout_address_input'),
                  controller: _addressController,
                  label: 'Delivery / Pickup Address',
                  hint: 'House/Unit No., Street, Barangay, City',
                  prefixIcon: Icons.location_on_outlined,
                  prefixIconTooltip: 'Auto-detect current location',
                  onPrefixIconPressed: _handleAutoLocate,
                  suffix: _isLocating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                          tooltip: 'Use current GPS location',
                          onPressed: _handleAutoLocate,
                        ),
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
                      Text(
                        'Order Summary',
                        style: TextStyle(
                          color: AppColors.textPrimary,
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
                              Expanded(
                                child: Text(
                                  '${i.quantity}x ${i.product.name}',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                i.formattedSubtotal,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 20, color: AppColors.cardBorder),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              color: AppColors.textPrimary,
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

                if (isStoreClosed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store_mall_directory_outlined, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This store is currently closed. Orders cannot be placed at this time.',
                            style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Place Order Button
                GradientButton(
                  key: const Key('checkout_place_order_button'),
                  text: isStoreClosed
                      ? 'Store is Currently Closed'
                      : 'Place Order (${cart.formattedTotal})',
                  icon: isStoreClosed ? Icons.lock_outline : Icons.send_rounded,
                  isLoading: _isSubmitting,
                  onPressed: (_isSubmitting || isStoreClosed || cart.isEmpty) ? null : _handlePlaceOrder,
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
