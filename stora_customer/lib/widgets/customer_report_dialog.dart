import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

Future<void> showCustomerReportDialog({
  required BuildContext context,
  required int reportedUserId,
  required String targetName,
  int? orderId,
  VoidCallback? onReportSubmitted,
}) async {
  String selectedReason = 'fraud';
  final descriptionController = TextEditingController();
  bool isSubmitting = false;
  Uint8List? evidenceBytes;
  String? evidenceFilename;

  final reasons = [
    {'value': 'fraud', 'label': 'Fraud, Scam, or Undelivered Items'},
    {'value': 'harassment', 'label': 'Harassment / Abusive Behavior'},
    {'value': 'inappropriate_content', 'label': 'Inappropriate Photos or Content'},
    {'value': 'fake_order', 'label': 'Misleading Pricing or Order Issues'},
    {'value': 'spam', 'label': 'Spam / Unsolicited Ads'},
    {'value': 'other', 'label': 'Other Violation'},
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
        evidenceFilename = file.name.isNotEmpty ? file.name : 'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flag_rounded, color: Colors.amber, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report ${targetName.trim().isNotEmpty ? targetName.trim() : 'Store'}',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reports are sent to platform administrators for investigation.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Violation Reason',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          dropdownColor: AppColors.cardElevated,
                          isExpanded: true,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                          items: reasons.map((r) {
                            return DropdownMenuItem<String>(
                              value: r['value'],
                              child: Text(r['label']!),
                            );
                          }).toList(),
                          onChanged: isSubmitting
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setSheetState(() => selectedReason = val);
                                  }
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Explanation / Details (Optional)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Describe what happened in detail for the platform admin...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.cardElevated,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Attach Evidence (Optional)',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (evidenceBytes != null)
                          Text(
                            '1 photo attached',
                            style: TextStyle(color: AppColors.successText, fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (evidenceBytes == null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSubmitting ? null : () => pickEvidence(ImageSource.gallery, setSheetState),
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide(color: AppColors.cardBorder),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSubmitting ? null : () => pickEvidence(ImageSource.camera, setSheetState),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Camera'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide(color: AppColors.cardBorder),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                evidenceBytes!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    evidenceFilename ?? 'evidence.jpg',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Attached',
                                          style: TextStyle(
                                            color: AppColors.successText,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(evidenceBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove Image',
                              icon: const Icon(Icons.close_rounded, color: AppColors.danger, size: 20),
                              onPressed: isSubmitting
                                  ? null
                                  : () => setSheetState(() {
                                        evidenceBytes = null;
                                        evidenceFilename = null;
                                      }),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.cardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    setSheetState(() => isSubmitting = true);
                                    try {
                                      await CustomerApiService.instance.submitReport(
                                        reportedUserId: reportedUserId,
                                        reason: selectedReason,
                                        description: descriptionController.text.trim(),
                                        orderId: orderId,
                                        attachmentBytes: evidenceBytes,
                                        filename: evidenceFilename ?? 'report_evidence.jpg',
                                      );

                                      if (ctx.mounted) Navigator.of(ctx).pop();

                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Report submitted. Our administrators will review this store.'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                      onReportSubmitted?.call();
                                    } catch (e) {
                                      if (ctx.mounted) setSheetState(() => isSubmitting = false);
                                      final eStr = e.toString().toLowerCase();
                                      final msg = eStr.contains('pending report') || eStr.contains('already have')
                                          ? 'You already have an active pending report for this store.'
                                          : 'Failed to submit report: $e';
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(msg),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[700],
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Submit Report',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
