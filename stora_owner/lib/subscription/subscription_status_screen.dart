import 'package:flutter/material.dart';
import '../data/api/api_client.dart';
import '../data/models/account_status.dart';
import '../stora_login/stora_login.dart';
import 'subscription_status.dart';
import 'upload_gcash_proof_screen.dart';
import '../home/theme/home_colors.dart';
import '../home/utils/date_utils.dart';
import '../home/widgets/status_chip.dart';

// ---------------------------------------------------------------------
// Subscription Status — shown after a GCash proof has been submitted
// (from UploadGcashProofScreen) or reopened from the Profile menu,
// tracking review progress: Submitted -> Under review -> Approved / Rejected.
// ---------------------------------------------------------------------
class SubscriptionStatusScreen extends StatefulWidget {
  final SubscriptionStatus? status;
  const SubscriptionStatusScreen({super.key, this.status});

  @override
  State<SubscriptionStatusScreen> createState() => _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  SubscriptionStatus? _status;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.getSubscriptionStatus();
      final accountStatus = AccountStatus.fromJson(res);
      final proof = accountStatus.latestPaymentProof;

      if (mounted) {
        setState(() {
          if (accountStatus.isPremium) {
            _status = SubscriptionStatus(
              currentStep: SubscriptionStep.approved,
              submittedAt: proof?.submittedAt ?? accountStatus.trialStartedAt ?? DateTime.now(),
              referenceNumber: proof?.referenceNumber,
            );
          } else if (proof != null) {
            _status = SubscriptionStatus.fromBackend(
              proof.status,
              proof.submittedAt,
              referenceNumber: proof.referenceNumber,
            );
          } else {
            _status = widget.status;
          }
        });
      }
    } catch (_) {
      // Keep displaying existing or fallback status on network error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _formatSubmitted(DateTime dt) => formatManilaShortDateTime(dt);

  @override
  Widget build(BuildContext context) {
    final status = _status ??
        widget.status ??
        SubscriptionStatus(
          currentStep: SubscriptionStep.submitted,
          submittedAt: DateTime.now(),
        );

    final (chipColor, chipBg) = switch (status.currentStep) {
      SubscriptionStep.approved => (HomeColors.successText, HomeColors.successBg),
      SubscriptionStep.rejected => (AppColors.error, HomeColors.dangerBg),
      _ => (AppColors.purpleLight, AppColors.fieldBackground),
    };

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
                    child: Text(
                      'Subscription',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _refreshStatus,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.label),
                          )
                        : const Icon(Icons.refresh_rounded, color: AppColors.label),
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'STATUS',
                style: TextStyle(
                  color: AppColors.label,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: HomeColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          status.headline,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        StatusChip(label: status.headline, color: chipColor, background: chipBg),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted ${_formatSubmitted(status.submittedAt)}',
                      style: const TextStyle(color: AppColors.label, fontSize: 12),
                    ),
                    if (status.referenceNumber != null && status.referenceNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${status.referenceNumber}',
                        style: const TextStyle(color: AppColors.label, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 22),

                    if (status.isRejected) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: HomeColors.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your submitted GCash proof could not be verified. Please check the reference number and screenshot, and submit again.',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      _StepTracker(currentStep: status.currentStep),
                      if (!status.isApproved) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Usually completed within 24 hours.',
                          style: TextStyle(color: AppColors.label, fontSize: 12),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (status.isRejected) ...[
                StoraGradientButton(
                  label: 'Resubmit payment proof',
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const UploadGcashProofScreen()),
                  ),
                ),
              ] else ...[
                Opacity(
                  opacity: status.isApproved ? 1 : 0.5,
                  child: IgnorePointer(
                    ignoring: !status.isApproved,
                    child: StoraGradientButton(
                      label: 'View receipt',
                      onPressed: () {
                        showStoraSnackBar(context, 'Subscription is active.', isError: false);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTracker extends StatelessWidget {
  final SubscriptionStep currentStep;
  const _StepTracker({required this.currentStep});

  static const _steps = [
    ('Submitted', SubscriptionStep.submitted),
    ('Under review', SubscriptionStep.underReview),
    ('Approved & active', SubscriptionStep.approved),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          _StepRow(
            label: _steps[i].$1,
            isDone: _steps[i].$2.index <= currentStep.index,
            isLast: i == _steps.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isLast;
  const _StepRow({required this.label, required this.isDone, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = isDone ? HomeColors.successText : AppColors.label;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? HomeColors.successBg : Colors.transparent,
                  border: Border.all(color: color, width: 1.6),
                ),
                child: isDone ? Icon(Icons.check, size: 12, color: color) : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.4,
                    color: isDone ? HomeColors.successText.withValues(alpha: 0.4) : AppColors.fieldBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
                color: isDone ? Colors.white : AppColors.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

