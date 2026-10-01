import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _selectedPaymentMethod = 'cash';

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
        duration: Duration(milliseconds: 1500),
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
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to detect location. Please enter your address manually.'),
          backgroundColor: AppColors.danger,
          duration: const Duration(milliseconds: 1500),
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

      final bool canAcceptGcash = store.acceptGcashPayments &&
          (store.paymentPhoneNumber.isNotEmpty || store.paymentQrUrl != null);
      final String paymentMethodToUse = canAcceptGcash ? _selectedPaymentMethod : 'cash';

      final order = await orderProvider.placeOrder(
        ownerId: storeOwnerId,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerAddress: _addressController.text.trim(),
        notes: _notesController.text.trim(),
        paymentMethod: paymentMethodToUse,
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

                // Payment Method Section
                Text(
                  'Payment Method',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Option 1: Cash on Pickup / In-Store
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPaymentMethod = 'cash');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'cash'
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedPaymentMethod == 'cash'
                            ? AppColors.primary
                            : AppColors.cardBorder,
                        width: _selectedPaymentMethod == 'cash' ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF064E3B).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.payments_rounded, color: Color(0xFF34D399), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cash on Pickup / In-Store',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pay with cash upon collecting your order at the store.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _selectedPaymentMethod == 'cash'
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _selectedPaymentMethod == 'cash' ? AppColors.primary : AppColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: GCash / Online Payment
                if (currentStore != null &&
                    currentStore.acceptGcashPayments &&
                    (currentStore.paymentPhoneNumber.isNotEmpty || currentStore.paymentQrUrl != null)) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPaymentMethod = 'gcash');
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _selectedPaymentMethod == 'gcash'
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedPaymentMethod == 'gcash'
                              ? AppColors.primary
                              : AppColors.cardBorder,
                          width: _selectedPaymentMethod == 'gcash' ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF60A5FA), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Online Payment',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Color(0xFF93C5FD),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Scan QR or transfer online after store acceptance.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _selectedPaymentMethod == 'gcash'
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: _selectedPaymentMethod == 'gcash' ? AppColors.primary : AppColors.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // If GCash is selected, show Safe Ordering Notice & Store Details
                  if (_selectedPaymentMethod == 'gcash') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Color(0xFF4ADE80), size: 17),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Safe Ordering: No Advance Payment Needed',
                                  style: const TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'You do NOT need to pay right now! Place your order first. You only transfer payment once the store reviews and confirms your order.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Store Payment Details',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (currentStore.paymentPhoneNumber.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentStore.paymentAccountName.isNotEmpty ? currentStore.paymentAccountName : 'Payment Mobile Number',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                    Text(
                                      currentStore.paymentPhoneNumber,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: currentStore.paymentPhoneNumber));
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                            SizedBox(width: 8),
                                            Text('Payment number copied to clipboard!'),
                                          ],
                                        ),
                                        duration: Duration(milliseconds: 1500),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 14),
                                  label: const Text('Copy'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (currentStore.paymentQrUrl != null) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'Scan to Pay (${currentStore.displayName})',
                                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              const SizedBox(height: 12),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  currentStore.paymentQrUrl!,
                                                  fit: BoxFit.contain,
                                                  width: 280,
                                                  height: 280,
                                                  loadingBuilder: (context, child, progress) {
                                                    if (progress == null) return child;
                                                    return const SizedBox(
                                                      width: 280,
                                                      height: 280,
                                                      child: Center(
                                                        child: CircularProgressIndicator(color: AppColors.primary),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) => Container(
                                                    width: 280,
                                                    height: 280,
                                                    color: Colors.grey[100],
                                                    child: const Center(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                                          SizedBox(height: 8),
                                                          Text('Unable to load QR image', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton.icon(
                                          onPressed: () => Navigator.pop(context),
                                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                                          label: const Text('Close', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.cardElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        currentStore.paymentQrUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return Container(
                                            width: 48,
                                            height: 48,
                                            color: AppColors.cardBorder.withValues(alpha: 0.3),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 48,
                                          height: 48,
                                          color: AppColors.cardBorder.withValues(alpha: 0.3),
                                          child: const Icon(Icons.qr_code_2_rounded, size: 24, color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Payment QR Code Available',
                                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            'Tap to enlarge and scan QR',
                                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.fullscreen_rounded, color: AppColors.primary, size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Online Payment Unavailable',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'This store is currently accepting Cash on Pickup only.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // In-Store Pickup Notice Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF56A10).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF56A10).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF56A10).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFFFB923C), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'In-Store Pickup Only',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'This store does not provide delivery. Your items will be packed for you to pick up directly at the store counter.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Customer & Pickup Info Section
                Text(
                  'Customer & Pickup Information',
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
                  label: 'Customer Address / Landmark',
                  hint: 'House/Unit No., Street, Purok, or nearby landmark',
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
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please provide your address or landmark' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _notesController,
                  label: 'Pickup Notes / Instructions (Optional)',
                  hint: 'e.g. Will pick up around 4 PM, please pack in paper bag',
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
