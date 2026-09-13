import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api/api_client.dart';
import '../data/models/account_status.dart';
import '../data/stores/account_status_store.dart';
import '../stora_login/stora_login.dart';
import 'past_receipts_sheet.dart';
import 'subscription_receipt_modal.dart';
import 'subscription_screen.dart';
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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    AccountStatusStore.instance.addListener(_onAccountStatusChanged);
    _refreshStatus();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    AccountStatusStore.instance.removeListener(_onAccountStatusChanged);
    super.dispose();
  }

  void _onAccountStatusChanged() {
    if (!mounted) return;
    final accountStatus = AccountStatusStore.instance.status;
    final proof = accountStatus.latestPaymentProof;
    final rawAmount = proof?.amount;
    final proofAmount = (rawAmount != null && rawAmount.isNotEmpty)
        ? double.tryParse(rawAmount)
        : null;
    final actualAmount = proofAmount ?? accountStatus.monthlyPrice;

    setState(() {
      if (proof != null && (proof.isPending || proof.isRejected)) {
        _status = SubscriptionStatus.fromBackend(
          proof.status,
          proof.submittedAt,
          referenceNumber: proof.referenceNumber,
          amount: actualAmount,
        );
        if (_status!.isApproved || _status!.isRejected) {
          _pollTimer?.cancel();
        }
      } else if (accountStatus.isPremium) {
        _status = SubscriptionStatus(
          currentStep: SubscriptionStep.approved,
          submittedAt: proof?.submittedAt ?? accountStatus.trialStartedAt ?? DateTime.now(),
          referenceNumber: proof?.referenceNumber,
          amount: actualAmount,
        );
        _pollTimer?.cancel();
      } else if (proof != null) {
        _status = SubscriptionStatus.fromBackend(
          proof.status,
          proof.submittedAt,
          referenceNumber: proof.referenceNumber,
          amount: actualAmount,
        );
        if (_status!.isApproved || _status!.isRejected) {
          _pollTimer?.cancel();
        }
      } else {
        _status = widget.status;
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final isDone = _status != null && (_status!.isApproved || _status!.isRejected);
    if (!isDone) {
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        if (_status != null && (_status!.isApproved || _status!.isRejected)) {
          _pollTimer?.cancel();
          return;
        }
        _refreshStatus(background: true);
      });
    }
  }

  Future<void> _refreshStatus({bool background = false}) async {
    if (!background) setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.getSubscriptionStatus();
      final accountStatus = AccountStatus.fromJson(res);
      final proof = accountStatus.latestPaymentProof;

      // Keep the global store updated as well
      AccountStatusStore.instance.fetchStatus();

      if (mounted) {
        final rawAmount = proof?.amount;
        final proofAmount = (rawAmount != null && rawAmount.isNotEmpty)
            ? double.tryParse(rawAmount)
            : null;
        final actualAmount = proofAmount ?? accountStatus.monthlyPrice;

        setState(() {
          if (proof != null && (proof.isPending || proof.isRejected)) {
            _status = SubscriptionStatus.fromBackend(
              proof.status,
              proof.submittedAt,
              referenceNumber: proof.referenceNumber,
              amount: actualAmount,
            );
            if (_status!.isApproved || _status!.isRejected) {
              _pollTimer?.cancel();
            }
          } else if (accountStatus.isPremium) {
            _status = SubscriptionStatus(
              currentStep: SubscriptionStep.approved,
              submittedAt: proof?.submittedAt ?? accountStatus.trialStartedAt ?? DateTime.now(),
              referenceNumber: proof?.referenceNumber,
              amount: actualAmount,
            );
            _pollTimer?.cancel();
          } else if (proof != null) {
            _status = SubscriptionStatus.fromBackend(
              proof.status,
              proof.submittedAt,
              referenceNumber: proof.referenceNumber,
              amount: actualAmount,
            );
            if (_status!.isApproved || _status!.isRejected) {
              _pollTimer?.cancel();
            }
          } else {
            _status = widget.status;
          }
        });
      }
    } catch (_) {
      // Keep displaying existing or fallback status on network error
    } finally {
      if (mounted && !background) setState(() => _loading = false);
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
      backgroundColor: HomeColors.scaffoldBackground,
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
                    icon: Icon(Icons.chevron_left, color: HomeColors.textPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Subscription',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HomeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Past Receipts',
                    onPressed: () => PastReceiptsSheet.show(context),
                    icon: Icon(Icons.receipt_long_rounded, color: HomeColors.textPrimary, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loading ? null : _refreshStatus,
                    icon: _loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: HomeColors.textPrimary),
                          )
                        : Icon(Icons.refresh_rounded, color: HomeColors.textPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.cardBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'STATUS',
                style: TextStyle(
                  color: HomeColors.textSecondary,
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
                  border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.35), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          status.headline,
                          style: TextStyle(color: HomeColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        StatusChip(label: status.headline, color: chipColor, background: chipBg),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted ${_formatSubmitted(status.submittedAt)}',
                      style: TextStyle(color: HomeColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (status.referenceNumber != null && status.referenceNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${status.referenceNumber}',
                        style: TextStyle(color: HomeColors.textMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 22),

                    if (status.isRejected) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF87171), width: 1.2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AccountStatusStore.instance.isPremium
                                        ? 'Renewal Payment Proof Rejected'
                                        : 'Payment Proof Rejected',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AccountStatusStore.instance.isPremium
                                        ? 'Your extension proof could not be verified. Note: Your current Premium subscription is still active (${AccountStatusStore.instance.daysLeft} days left). You can resubmit or dismiss this warning.'
                                        : 'Your GCash payment proof was reviewed and could not be verified by the admin. Please verify your reference number, ensure the payment was sent to the correct GCash account, and submit a clear screenshot.',
                                    style: const TextStyle(color: Color(0xFFFEE2E2), fontSize: 12.5, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      _StepTracker(currentStep: status.currentStep),
                      if (!status.isApproved) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5), width: 1.2),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Color(0xFFFBBF24), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Awaiting admin verification. Once approved, your receipt and premium features will be unlocked.',
                                  style: TextStyle(color: Color(0xFFD97706), fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (status.isRejected) ...[
                StoraGradientButton(
                  label: AccountStatusStore.instance.isPremium
                      ? 'Resubmit renewal proof'
                      : 'Resubmit payment proof',
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const UploadGcashProofScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                if (AccountStatusStore.instance.isPremium) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomeColors.textPrimary,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: BorderSide(color: HomeColors.cardBorder, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final proof = AccountStatusStore.instance.status.latestPaymentProof;
                      AccountStatusStore.instance.dismissRejectedProof(proof?.id);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4ADE80), size: 18),
                    label: Text('Dismiss & Keep Current Plan', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeColors.textPrimary,
                    backgroundColor: const Color(0xFF9333EA).withValues(alpha: 0.12),
                    side: const BorderSide(color: Color(0xFFA855F7), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => PastReceiptsSheet.show(context),
                  icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFFC084FC), size: 18),
                  label: Text('Past Subscription Receipts', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
              ] else if (status.isApproved) ...[
                StoraGradientButton(
                  label: 'Extend / Renew Subscription',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SubscriptionScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeColors.textPrimary,
                    backgroundColor: const Color(0xFF9333EA).withValues(alpha: 0.12),
                    side: const BorderSide(color: Color(0xFFA855F7), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _showSubscriptionReceipt(context, status),
                  icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFFC084FC), size: 18),
                  label: Text('Subscription Receipts', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
              ] else ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeColors.textPrimary,
                    backgroundColor: const Color(0xFF9333EA).withValues(alpha: 0.12),
                    side: const BorderSide(color: Color(0xFFA855F7), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => PastReceiptsSheet.show(context),
                  icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFFC084FC), size: 18),
                  label: Text('Past Subscription Receipts', style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSubscriptionReceipt(BuildContext context, SubscriptionStatus status) {
    SubscriptionReceiptModal.show(
      context,
      amount: status.amount ?? 100.0,
      referenceNumber: status.referenceNumber ?? '',
      date: status.submittedAt,
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
    final color = isDone ? HomeColors.successText : HomeColors.textSecondary;
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
                color: isDone ? HomeColors.textPrimary : HomeColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

