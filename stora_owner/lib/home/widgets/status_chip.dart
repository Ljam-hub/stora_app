import 'package:flutter/material.dart';

/// Small rounded status/plan badge — mirrors the badge treatment
/// dashboard_screen.dart already uses on its stat cards ("Healthy",
/// "Action"), reused here for FREE/PREMIUM tags, review-status tags,
/// and the plan pill on Profile.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
