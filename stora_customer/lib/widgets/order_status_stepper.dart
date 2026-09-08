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
    final isReady = status == 'ready';

    // Step calculation:
    // Step 0: Placed
    // Step 1: Confirmed / Accepted / Counter / Declined
    // Step 2: Preparing
    // Step 3: Ready for Pickup
    int currentStep = 0;
    if (isCounter) {
      currentStep = 1;
    } else if (isAccepted) {
      currentStep = 2;
    } else if (isReady) {
      currentStep = 3;
    } else if (isDeclined) {
      currentStep = 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Order Status',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.2),
              ),
              if (order.expiresAt != null && status == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(height: 18),

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
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: currentStep >= 1 ? (isDeclined ? AppColors.danger : AppColors.success) : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: currentStep >= 2 ? AppColors.success : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
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
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: currentStep >= 3 ? AppColors.success : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _StepNode(
                icon: Icons.done_all_rounded,
                title: 'Ready',
                isActive: currentStep >= 3,
                isCompleted: currentStep >= 3,
                color: const Color(0xFF00E676),
              ),
            ],
          ),

          // Contextual Message Box for Ready, Preparing, Counter or Decline
          if (isReady) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your order is prepared and ready for pickup at the store! 🎉',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isAccepted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.shopping_bag_outlined, color: AppColors.primaryLight, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Order accepted! The store is currently preparing and packing your items.',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isDeclined) ...[
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.18) : AppColors.cardBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? color : AppColors.cardBorder,
              width: isActive ? 2 : 1.2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? color : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textMuted,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
