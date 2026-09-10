import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import '../data/api/api_client.dart';
import '../data/stores/account_status_store.dart';
import '../stora_login/stora_login.dart';
import '../home/theme/home_colors.dart';
import 'subscription_status_screen.dart';
import 'subscription_status.dart';

// ---------------------------------------------------------------------
// Upload GCash Proof — instructs the owner to send the plan price to
// a GCash number or scan the QR code (synced from backend or bundled),
// then submit a screenshot + reference number for review.
// ---------------------------------------------------------------------
class UploadGcashProofScreen extends StatefulWidget {
  final int? amount;
  final String? gcashNumber;
  final String? gcashName;
  final String? qrCodeUrl;

  const UploadGcashProofScreen({
    super.key,
    this.amount,
    this.gcashNumber,
    this.gcashName,
    this.qrCodeUrl,
  });

  @override
  State<UploadGcashProofScreen> createState() => _UploadGcashProofScreenState();
}

class _UploadGcashProofScreenState extends State<UploadGcashProofScreen> {
  final _referenceController = TextEditingController();
  Uint8List? _screenshotBytes;
  bool _picking = false;
  bool _submitting = false;

  int get _amount =>
      widget.amount ?? AccountStatusStore.instance.monthlyPrice.toInt();
  String get _gcashNumber =>
      widget.gcashNumber ?? AccountStatusStore.instance.gcashNumber;
  String get _gcashName =>
      widget.gcashName ?? AccountStatusStore.instance.gcashName;
  String? get _qrCodeUrl =>
      widget.qrCodeUrl ?? AccountStatusStore.instance.qrCodeUrl;

  @override
  void initState() {
    super.initState();
    // Refresh latest payment and QR configuration from backend
    AccountStatusStore.instance.fetchStatus().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _screenshotBytes = bytes);
      }
    } catch (_) {
      if (mounted) showStoraSnackBar(context, 'Could not open the image picker');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_screenshotBytes == null) {
      showStoraSnackBar(context, 'Please attach your GCash screenshot');
      return;
    }
    final ref = _referenceController.text.trim();
    if (ref.isEmpty) {
      showStoraSnackBar(context, 'Please enter the reference number');
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiClient.instance.uploadPaymentProof(
        referenceNumber: ref,
        amount: _amount.toDouble(),
        screenshotBytes: _screenshotBytes!,
      );

      if (!mounted) return;
      showStoraSnackBar(context, 'Submitted for review', isError: false);
      AccountStatusStore.instance.fetchStatus();

      final statusStr = (res['status'] as String?) ?? 'pending';
      final submittedAt = res['submitted_at'] != null
          ? DateTime.tryParse(res['submitted_at'] as String) ?? DateTime.now()
          : DateTime.now();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubscriptionStatusScreen(
            status: SubscriptionStatus.fromBackend(
              statusStr,
              submittedAt,
              referenceNumber: ref,
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showStoraSnackBar(context, e.message);
    } catch (e) {
      if (mounted) {
        showStoraSnackBar(
          context,
          'Could not upload payment proof. Please check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildQrWidget({required double size}) {
    if (_qrCodeUrl != null && _qrCodeUrl!.isNotEmpty) {
      return Image.network(
        _qrCodeUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF005CEE),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/gcash_qr.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }

    return Image.asset(
      'assets/images/gcash_qr.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  void _showEnlargedQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded,
                          color: Color(0xFF005CEE), size: 26),
                      SizedBox(width: 8),
                      Text(
                        'GCash QR Code',
                        style: TextStyle(
                          color: Color(0xFF1E1E2D),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildQrWidget(size: 250),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _gcashName.isNotEmpty ? _gcashName : 'STORA Admin',
                style: const TextStyle(
                  color: Color(0xFF1E1E2D),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _gcashNumber,
                style: const TextStyle(
                  color: Color(0xFF4A5568),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF005CEE).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Color(0xFF005CEE)),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Scan to pay via GCash, Maya, or any InstaPay app',
                        style: TextStyle(
                          color: Color(0xFF005CEE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _gcashName.isNotEmpty ? _gcashName : 'STORA Admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Pay via GCash',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 18),

              // Amount Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C1B4D), Color(0xFF1B1428)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.purpleLight.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AMOUNT TO SEND',
                          style: TextStyle(
                            color: AppColors.label,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱.00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        '1 Mo. Premium',
                        style: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // GCash Account Details Card (Name + Number)
              Container(
                decoration: BoxDecoration(
                  color: HomeColors.cardBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  children: [
                    // Card Title Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF005CEE).withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(17),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF005CEE),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              'G',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'GCash Account Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Account Name Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ACCOUNT NAME',
                                  style: TextStyle(
                                    color: AppColors.label,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_user_rounded,
                                      size: 16,
                                      color: Color(0xFF00B0FF),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: AppColors.label,
                            ),
                            tooltip: 'Copy Name',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: displayName));
                              showStoraSnackBar(
                                context,
                                'Account name copied',
                                isError: false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: AppColors.fieldBorder, height: 1),

                    // GCash Number Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GCASH NUMBER',
                                  style: TextStyle(
                                    color: AppColors.label,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _gcashNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _gcashNumber),
                              );
                              showStoraSnackBar(
                                context,
                                'GCash number copied',
                                isError: false,
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF005CEE).withValues(alpha: 0.25),
                              foregroundColor: const Color(0xFF00B0FF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Color(0xFF005CEE),
                                  width: 1,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 15),
                            label: const Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // QR Code Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: HomeColors.cardBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              color: Color(0xFF00B0FF),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'OR SCAN QR CODE',
                              style: TextStyle(
                                color: AppColors.label,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => _showEnlargedQr(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            size: 16,
                            color: Color(0xFF00B0FF),
                          ),
                          label: const Text(
                            'Enlarge',
                            style: TextStyle(
                              color: Color(0xFF00B0FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // QR Image container
                    GestureDetector(
                      onTap: () => _showEnlargedQr(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildQrWidget(size: 170),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap QR to enlarge • Accepts GCash, Maya & InstaPay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.hint,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Step 2: Upload Screenshot
              const Text(
                'UPLOAD SCREENSHOT',
                style: TextStyle(
                  color: AppColors.label,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _picking ? null : _pickScreenshot,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _screenshotBytes != null
                          ? const Color(0xFF00E676)
                          : AppColors.fieldBorder,
                      width: 1.3,
                    ),
                    image: _screenshotBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_screenshotBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _picking
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.purpleLight,
                            strokeWidth: 2,
                          ),
                        )
                      : _screenshotBytes == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Color(0xFFFF6B00),
                                  size: 28,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '+ Attach GCash Receipt',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Screenshot of completed transfer',
                                  style: TextStyle(
                                    color: AppColors.hint,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            )
                          : Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _screenshotBytes = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 20),

              // Step 3: Reference Number
              const Text(
                'REFERENCE NUMBER',
                style: TextStyle(
                  color: AppColors.label,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referenceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 0002 104 552 991',
                  hintStyle: const TextStyle(color: AppColors.hint),
                  prefixIcon: const Icon(
                    Icons.tag_rounded,
                    color: AppColors.label,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: AppColors.fieldBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.purple,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              StoraGradientButton(
                label: _submitting ? 'Submitting Proof...' : 'Submit for review',
                onPressed: _submitting ? () {} : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
