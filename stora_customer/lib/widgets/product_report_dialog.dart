import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../storage/hidden_products_store.dart';
import '../theme/app_theme.dart';

Future<void> showProductReportDialog({
  required BuildContext context,
  required ProductModel product,
  VoidCallback? onReportSubmitted,
}) async {
  if (product.ownerId == null || product.ownerId! <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot report product: Store owner information missing.'),
        backgroundColor: AppColors.danger,
      ),
    );
    return;
  }

  // Check cooldown
  if (HiddenProductsStore.instance.isReported(product.id)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have already reported this product recently. Our moderation team is reviewing it.'),
        backgroundColor: AppColors.warning,
      ),
    );
    return;
  }

  String selectedReason = 'counterfeit';
  final descriptionController = TextEditingController();
  bool isSubmitting = false;
  bool hideProductAfterReport = true;
  Uint8List? evidenceBytes;
  String? evidenceFilename;

  final reasons = [
    {
      'value': 'counterfeit',
      'backendReason': 'fraud',
      'label': 'Counterfeit / Fake Item',
      'icon': Icons.gpp_bad_outlined,
    },
    {
      'value': 'misleading',
      'backendReason': 'fake_order',
      'label': 'Misleading Price or Description',
      'icon': Icons.price_change_outlined,
    },
    {
      'value': 'expired',
      'backendReason': 'other',
      'label': 'Expired, Spoiled, or Unsafe',
      'icon': Icons.event_busy_outlined,
    },
    {
      'value': 'prohibited',
      'backendReason': 'inappropriate_content',
      'label': 'Prohibited or Illegal Item',
      'icon': Icons.gavel_outlined,
    },
    {
      'value': 'damaged',
      'backendReason': 'other',
      'label': 'Defective or Damaged Product',
      'icon': Icons.broken_image_outlined,
    },
    {
      'value': 'inappropriate',
      'backendReason': 'inappropriate_content',
      'label': 'Inappropriate or Offensive Content',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'value': 'other',
      'backendReason': 'other',
      'label': 'Other Concern',
      'icon': Icons.help_outline_rounded,
    },
  ];

  final picker = ImagePicker();

  Future<void> pickEvidence(ImageSource source, StateSetter setSheetState) async {
    try {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image must be smaller than 10MB.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      setSheetState(() {
        evidenceBytes = bytes;
        evidenceFilename = file.name.isNotEmpty ? file.name : 'evidence_.jpg';
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load image: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  try {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      isDismissible: !isSubmitting,
      enableDrag: !isSubmitting,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            final isDark = Theme.of(modalContext).brightness == Brightness.dark;
            final keyboardPadding = MediaQuery.of(modalContext).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardPadding),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flag_rounded, color: AppColors.danger, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Product',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: AppColors.textMuted,
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Divider(color: AppColors.cardBorder.withValues(alpha: 0.6), height: 1),
                    const SizedBox(height: 14),

                    Text(
                      'Reason for report',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Column(
                      children: reasons.map((r) {
                        final isSelected = selectedReason == r['value'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.danger.withValues(alpha: 0.08)
                                : (isDark ? AppColors.cardElevated : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.danger.withValues(alpha: 0.5)
                                  : AppColors.cardBorder.withValues(alpha: 0.6),
                              width: isSelected ? 1.2 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isSubmitting
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() => selectedReason = r['value'] as String);
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      r['icon'] as IconData,
                                      size: 18,
                                      color: isSelected ? AppColors.danger : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        r['label'] as String,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: isSelected ? AppColors.danger : AppColors.textMuted.withValues(alpha: 0.6),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Details / Description (Optional)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: descriptionController,
                      enabled: !isSubmitting,
                      maxLines: 3,
                      maxLength: 500,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Please describe the issue with this product in detail...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                        filled: true,
                        fillColor: isDark ? AppColors.cardElevated : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Evidence Attachment
                    Row(
                      children: [
                        Text(
                          'Photo Evidence (Optional)',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (evidenceBytes != null)
                          TextButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setSheetState(() {
                                      evidenceBytes = null;
                                      evidenceFilename = null;
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                            label: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                          )
                        else
                          TextButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () => pickEvidence(ImageSource.gallery, setSheetState),
                            icon: const Icon(Icons.add_photo_alternate_rounded, size: 16, color: AppColors.primary),
                            label: const Text('Add Photo', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          ),
                      ],
                    ),

                    if (evidenceBytes != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                          image: DecorationImage(
                            image: MemoryImage(evidenceBytes!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Hide product checkbox
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardElevated : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined, size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: isSubmitting
                                  ? null
                                  : () => setSheetState(() => hideProductAfterReport = !hideProductAfterReport),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hide this product from my feed',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'You will no longer see this product while browsing',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Checkbox(
                            value: hideProductAfterReport,
                            activeColor: AppColors.danger,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: isSubmitting
                                ? null
                                : (val) => setSheetState(() => hideProductAfterReport = val ?? true),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: AppColors.cardBorder),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setSheetState(() => isSubmitting = true);
                                    try {
                                      final reasonMeta = reasons.firstWhere(
                                        (r) => r['value'] == selectedReason,
                                        orElse: () => reasons.last,
                                      );
                                      final backendReason = reasonMeta['backendReason'] as String? ?? 'other';
                                      final userText = descriptionController.text.trim();
                                      final enrichedDescription =
                                          '[REPORTED PRODUCT #${product.id} - ${product.name} | Price: ${product.formattedPrice} | Store: ${product.storeName ?? "Store #${product.ownerId}"}] '
                                          'Reason: ${reasonMeta['label']}${userText.isNotEmpty ? ' - $userText' : ''}';

                                      await CustomerApiService.instance.submitReport(
                                        reportedUserId: product.ownerId!,
                                        reason: backendReason,
                                        description: enrichedDescription,
                                        attachmentBytes: evidenceBytes,
                                        filename: evidenceFilename ?? 'evidence.jpg',
                                      );

                                      // Mark product as reported (cooldown)
                                      await HiddenProductsStore.instance.markReported(product.id);

                                      // Hide product if requested
                                      if (hideProductAfterReport) {
                                        await HiddenProductsStore.instance.hideProduct(
                                          product.id,
                                          name: product.name,
                                          price: product.price,
                                          imageUrl: product.imageUrl,
                                          storeName: product.storeName,
                                          categoryName: product.categoryName,
                                        );
                                      }

                                      if (modalContext.mounted) {
                                        Navigator.pop(ctx);
                                      }

                                      if (context.mounted) {
                                        final messenger = ScaffoldMessenger.of(context);
                                        messenger.hideCurrentSnackBar();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            duration: const Duration(seconds: 5),
                                            behavior: SnackBarBehavior.floating,
                                            content: Row(
                                              children: [
                                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    hideProductAfterReport
                                                        ? 'Report submitted and product hidden.'
                                                        : 'Product report submitted. Admin will review.',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            action: hideProductAfterReport
                                                ? SnackBarAction(
                                                    label: 'UNDO',
                                                    textColor: Colors.amberAccent,
                                                    onPressed: () async {
                                                      await HiddenProductsStore.instance.unhideProduct(product.id);
                                                      onReportSubmitted?.call();
                                                    },
                                                  )
                                                : null,
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                      onReportSubmitted?.call();
                                    } catch (e) {
                                      if (modalContext.mounted) {
                                        setSheetState(() => isSubmitting = false);
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to submit report: $e'),
                                            backgroundColor: AppColors.danger,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.flag_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Submit Report',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    descriptionController.dispose();
  }
}
