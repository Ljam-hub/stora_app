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
// a GCash number, then submit a screenshot + reference number for
// review. Uses the same image_picker dependency add_edit_product_screen
// already relies on for product photos (reads bytes, not a File path,
// for the same cross-platform reason documented there).
// ---------------------------------------------------------------------
class UploadGcashProofScreen extends StatefulWidget {
  final int? amount;
  final String? gcashNumber;
  const UploadGcashProofScreen({super.key, this.amount, this.gcashNumber});

  @override
  State<UploadGcashProofScreen> createState() => _UploadGcashProofScreenState();
}

class _UploadGcashProofScreenState extends State<UploadGcashProofScreen> {
  final _referenceController = TextEditingController();
  Uint8List? _screenshotBytes;
  bool _picking = false;
  bool _submitting = false;

  int get _amount => widget.amount ?? AccountStatusStore.instance.monthlyPrice.toInt();
  String get _gcashNumber => widget.gcashNumber ?? AccountStatusStore.instance.gcashNumber;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
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
      final submittedAt = res['submitted_at'] != null ? DateTime.tryParse(res['submitted_at'] as String) ?? DateTime.now() : DateTime.now();

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
      if (mounted) showStoraSnackBar(context, 'Could not upload payment proof. Please check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Expanded(
                    child: Text('Pay via GCash',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 20),

              RichText(
                text: TextSpan(
                  style: const TextStyle(color: AppColors.label, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Send '),
                    TextSpan(
                      text: '₱$_amount.00',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: HomeColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_gcashNumber,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.label),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _gcashNumber));
                        showStoraSnackBar(context, 'GCash number copied', isError: false);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('UPLOAD SCREENSHOT',
                  style: TextStyle(
                      color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _picking ? null : _pickScreenshot,
                child: Container(
                  width: double.infinity,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.fieldBorder, width: 1.2),
                    image: _screenshotBytes != null
                        ? DecorationImage(image: MemoryImage(_screenshotBytes!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _picking
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.purpleLight, strokeWidth: 2))
                      : _screenshotBytes == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_rounded, color: AppColors.purpleLight, size: 24),
                                SizedBox(height: 6),
                                Text('+ Attach image',
                                    style: TextStyle(
                                        color: AppColors.purpleLight, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            )
                          : Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: GestureDetector(
                                  onTap: () => setState(() => _screenshotBytes = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 18),

              const Text('REFERENCE NUMBER',
                  style: TextStyle(
                      color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _referenceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '0002 104 552 991',
                  hintStyle: const TextStyle(color: AppColors.hint),
                  filled: true,
                  fillColor: AppColors.fieldBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              StoraGradientButton(
                label: _submitting ? 'Submitting...' : 'Submit for review',
                onPressed: _submitting ? () {} : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
