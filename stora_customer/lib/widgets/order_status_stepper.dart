import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../theme/app_theme.dart';

class OrderStatusStepper extends StatelessWidget {
  final CustomerOrder order;

  const OrderStatusStepper({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order.status.toLowerCase();
    final isDeclined = status == 'declined' || status == 'auto_declined';
    final isCounter = status == 'counter_offer';
    final isAccepted = status == 'accepted';

    // Step calculation:
    // Step 0: Placed
    // Step 1: Confirmed / Accepted / Counter / Declined
    // Step 2: Preparing / Ready
    // Step 3: Completed
    int currentStep = 0;
    if (isCounter) {
      currentStep = 1;
    } else if (isAccepted) {
      currentStep = 2;
    } else if (isDeclined) {
      currentStep = 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Order Status',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (order.expiresAt != null && status == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.timer_outlined, size: 12, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text('Awaiting Store Response', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Stepper Horizontal Line & Nodes
          Row(
            children: [
              _StepNode(
                icon: Icons.check_circle_rounded,
                title: 'Placed',
                isActive: true,
                isCompleted: currentStep > 0 || !isDeclined,
                color: AppColors.success,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: currentStep >= 1 ? (isDeclined ? AppColors.danger : AppColors.success) : AppColors.cardBorder,
                ),
              ),
              _StepNode(
                icon: isDeclined
                    ? Icons.cancel_rounded
                    : (isCounter ? Icons.swap_horiz_rounded : Icons.storefront_rounded),
                title: isDeclined
                    ? 'Declined'
                    : (isCounter ? 'Counter' : 'Accepted'),
                isActive: currentStep >= 1,
                isCompleted: currentStep >= 2,
                color: isDeclined ? AppColors.danger : (isCounter ? AppColors.primary : AppColors.success),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: currentStep >= 2 ? AppColors.success : AppColors.cardBorder,
                ),
              ),
              _StepNode(
                icon: Icons.shopping_bag_rounded,
                title: 'Preparing',
                isActive: currentStep >= 2,
                isCompleted: currentStep >= 3,
                color: AppColors.primary,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: currentStep >= 3 ? AppColors.success : AppColors.cardBorder,
                ),
              ),
              _StepNode(
                icon: Icons.done_all_rounded,
                title: 'Ready',
                isActive: currentStep >= 3,
                isCompleted: currentStep >= 3,
                color: AppColors.success,
              ),
            ],
          ),

          // Contextual Message Box for Counter or Decline
          if (isDeclined) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.declineReason != null && order.declineReason!.isNotEmpty
                          ? 'Reason: ${order.declineReason}'
                          : 'Store was unable to fulfill this order.',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isCounter) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.primaryLight, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Store Counter-Offer',
                        style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Spacer(),
                      if (order.counterPrice != null)
                        Text(
                          'New: ₱${order.counterPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                    ],
                  ),
                  if (order.counterNotes != null && order.counterNotes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Note: ${order.counterNotes}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final bool isCompleted;
  final Color color;

  const _StepNode({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.isCompleted,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.2) : AppColors.cardBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? color : AppColors.cardBorder,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? color : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textMuted,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
