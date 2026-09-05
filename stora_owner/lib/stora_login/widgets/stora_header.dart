import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared logo + title block used on login & auth screens.
class StoraHeader extends StatelessWidget {
  final String tagline;
  const StoraHeader({super.key, this.tagline = 'Inventory made simple'});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.purpleLight, AppColors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1F1A28),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppColors.purpleLight,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'STORA.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tagline,
          style: const TextStyle(
            color: AppColors.purpleLight,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
