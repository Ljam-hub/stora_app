import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_config.dart';
import '../../stora_login/theme/app_colors.dart';
import '../../stora_login/utils/snackbar.dart';
import '../stores/store_status_store.dart';
import '../theme/home_colors.dart';

class StorePaymentScreen extends StatefulWidget {
  const StorePaymentScreen({super.key});

  @override
  State<StorePaymentScreen> createState() => _StorePaymentScreenState();
}

class _StorePaymentScreenState extends State<StorePaymentScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _pickedQrBytes;
  String? _pickedQrFilename;
  String? _existingQrUrl;
  bool _acceptGcash = true;
  bool _qrCleared = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPaymentDetails();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPaymentDetails() async {
    final status = StoreStatusStore.instance;
    _phoneController.text = status.paymentPhoneNumber;
    _nameController.text = status.paymentAccountName;
    _existingQrUrl = status.paymentQrUrl;
    _acceptGcash = status.acceptGcashPayments;

    try {
      final data = await ApiClient.instance.getStoreLocation();
      if (mounted) {
        final phone = data['payment_phone_number']?.toString() ?? '';
        final name = data['payment_account_name']?.toString() ?? '';
        final rawQr = (data['payment_qr_url'] ?? data['payment_qr_code'])?.toString();
        final qrUrl = (rawQr != null && rawQr.isNotEmpty) ? ApiConfig.resolveMediaUrl(rawQr) : null;
        final acceptGcash = (data['accept_gcash_payments'] is bool)
            ? (data['accept_gcash_payments'] as bool)
            : (data['accept_gcash_payments']?.toString().toLowerCase() == 'true' || data['accept_gcash_payments'] == null);

        setState(() {
          _phoneController.text = phone;
          _nameController.text = name;
          _existingQrUrl = qrUrl;
          _acceptGcash = acceptGcash;
          _isLoading = false;
        });

        status.updatePaymentDetails(
          paymentPhoneNumber: phone,
          paymentAccountName: name,
          paymentQrUrl: qrUrl,
          clearQrCode: qrUrl == null,
          acceptGcashPayments: acceptGcash,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickQrCode(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() {
          _pickedQrBytes = bytes;
          _pickedQrFilename = picked.name;
          _qrCleared = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showStoraSnackBar(context, 'Failed to pick image: $e', isError: true);
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: Text('Take a photo', style: TextStyle(color: HomeColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickQrCode(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text('Choose from gallery', style: TextStyle(color: HomeColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickQrCode(ImageSource.gallery);
              },
            ),
            if ((_pickedQrBytes != null || (_existingQrUrl != null && _existingQrUrl!.isNotEmpty)) && !_qrCleared) ...[
              Divider(color: HomeColors.cardBorder, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Remove QR Code', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _pickedQrBytes = null;
                    _pickedQrFilename = null;
                    _qrCleared = true;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    setState(() => _isSaving = true);
    try {
      final res = await ApiClient.instance.updateStorePaymentInfo(
        paymentPhoneNumber: phone,
        paymentAccountName: name,
        paymentQrBytes: _pickedQrBytes,
        paymentQrFilename: _pickedQrFilename,
        clearQrCode: _qrCleared,
        acceptGcashPayments: _acceptGcash,
      );

      final rawQr = (res['payment_qr_url'] ?? res['payment_qr_code'])?.toString();
      final updatedQrUrl = _qrCleared
          ? null
          : ((rawQr != null && rawQr.isNotEmpty)
              ? ApiConfig.resolveMediaUrl(rawQr)
              : _existingQrUrl);

      StoreStatusStore.instance.updatePaymentDetails(
        paymentPhoneNumber: phone,
        paymentAccountName: name,
        paymentQrUrl: updatedQrUrl,
        clearQrCode: _qrCleared,
        acceptGcashPayments: _acceptGcash,
      );

      if (mounted) {
        setState(() {
          _pickedQrBytes = null;
          _pickedQrFilename = null;
          _existingQrUrl = updatedQrUrl;
          _qrCleared = false;
        });
        showStoraSnackBar(context, 'Payment details saved successfully!', isError: false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showStoraSnackBar(context, 'Failed to save: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool get _hasUnsavedChanges {
    final status = StoreStatusStore.instance;
    return _pickedQrBytes != null ||
        _qrCleared ||
        _phoneController.text.trim() != status.paymentPhoneNumber ||
        _nameController.text.trim() != status.paymentAccountName;
  }

  Future<bool> _handleBackPress() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Unsaved Changes', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'You have unsaved changes to your payment information or QR code. Do you want to discard them?',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep Editing', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.dangerText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final hasQr = !_qrCleared && (_pickedQrBytes != null || (_existingQrUrl != null && _existingQrUrl!.isNotEmpty));

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: HomeColors.background,
        appBar: AppBar(
          backgroundColor: HomeColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: HomeColors.textPrimary),
            onPressed: () async {
              final shouldPop = await _handleBackPress();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Store Payment & QR',
            style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accept GCash at Checkout Toggle Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: HomeColors.cardBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _acceptGcash
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : HomeColors.cardBorder,
                          width: _acceptGcash ? 1.5 : 1.0,
                        ),
                        boxShadow: HomeColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _acceptGcash
                                            ? AppColors.primary.withValues(alpha: 0.15)
                                            : HomeColors.textSecondary.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _acceptGcash ? Icons.payments_rounded : Icons.money_off_rounded,
                                        color: _acceptGcash ? AppColors.primary : HomeColors.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Accept GCash at Checkout',
                                            style: TextStyle(
                                              color: HomeColors.textPrimary,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _acceptGcash
                                                ? 'Active • Displayed to customers'
                                                : 'Paused • Cash on Pickup only',
                                            style: TextStyle(
                                              color: _acceptGcash ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _acceptGcash,
                                activeThumbColor: AppColors.primary,
                                activeTrackColor: AppColors.primary.withValues(alpha: 0.38),
                                onChanged: (val) async {
                                  HapticFeedback.selectionClick();
                                  setState(() => _acceptGcash = val);
                                  try {
                                    await ApiClient.instance.updateStorePaymentInfo(
                                      paymentPhoneNumber: _phoneController.text.trim(),
                                      paymentAccountName: _nameController.text.trim(),
                                      acceptGcashPayments: val,
                                    );
                                    StoreStatusStore.instance.updatePaymentDetails(
                                      paymentPhoneNumber: _phoneController.text.trim(),
                                      paymentAccountName: _nameController.text.trim(),
                                      acceptGcashPayments: val,
                                    );
                                    if (context.mounted) {
                                      showStoraSnackBar(
                                        context,
                                        val
                                            ? 'Online payments active at checkout.'
                                            : 'Online payments paused. Checkout set to Cash on Pickup.',
                                        isError: false,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => _acceptGcash = !val);
                                    }
                                    if (context.mounted) {
                                      showStoraSnackBar(context, 'Failed to update setting: $e', isError: true);
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          if (!_acceptGcash) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFFFBBF24), size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your QR code and number remain saved, but are hidden from customers at checkout.',
                                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11.5, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Guide banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Payment Details',
                                  style: TextStyle(
                                    color: HomeColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Customers can view and 1-tap copy your payment phone number and scan your QR code at checkout.',
                                  style: TextStyle(
                                    color: HomeColors.textSecondary,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Phone Number Input
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HomeColors.cardBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: HomeColors.cardBorder),
                        boxShadow: HomeColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Payment Mobile Number (GCash / Maya)',
                                style: TextStyle(
                                  color: HomeColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. 0917 123 4567',
                              hintStyle: TextStyle(color: HomeColors.textSecondary.withValues(alpha: 0.6)),
                              filled: true,
                              fillColor: HomeColors.cardElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: HomeColors.cardBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: HomeColors.cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.content_paste_rounded, size: 18),
                                tooltip: 'Paste from clipboard',
                                onPressed: () async {
                                  final data = await Clipboard.getData('text/plain');
                                  if (data?.text != null && mounted) {
                                    setState(() {
                                      _phoneController.text = data!.text!.trim();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              const Icon(Icons.account_box_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Account Holder Name',
                                style: TextStyle(
                                  color: HomeColors.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(color: HomeColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Juan Dela Cruz',
                              hintStyle: TextStyle(color: HomeColors.textSecondary.withValues(alpha: 0.6)),
                              filled: true,
                              fillColor: HomeColors.cardElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: HomeColors.cardBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: HomeColors.cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // QR Code Upload Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HomeColors.cardBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: HomeColors.cardBorder),
                        boxShadow: HomeColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Payment QR Code',
                                style: TextStyle(
                                  color: HomeColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Upload a screenshot of your store\'s GCash, Maya, or bank QR code.',
                            style: TextStyle(color: HomeColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 16),

                          if (hasQr) ...[
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: HomeColors.cardBorder, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _pickedQrBytes != null
                                        ? Image.memory(
                                            _pickedQrBytes!,
                                            fit: BoxFit.contain,
                                          )
                                        : Image.network(
                                            ApiConfig.resolveMediaUrl(_existingQrUrl) ?? _existingQrUrl!,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(
                                                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) => const Center(
                                              child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _pickedQrBytes = null;
                                          _pickedQrFilename = null;
                                          _qrCleared = true;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: TextButton.icon(
                                onPressed: _showImageSourceSheet,
                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                label: const Text('Change QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ] else ...[
                            GestureDetector(
                              onTap: _showImageSourceSheet,
                              child: Container(
                                width: double.infinity,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: HomeColors.cardElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    style: BorderStyle.solid,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 28),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Upload QR Code Image',
                                      style: TextStyle(
                                        color: HomeColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Supports JPG, PNG from camera or gallery',
                                      style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Save Payment Details',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
