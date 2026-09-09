import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../stora_login/theme/app_colors.dart';
import '../theme/home_colors.dart';

/// Renders a product image from [imageBytes] if available,
/// or a category-adaptive glowing retail placeholder badge if no image exists.
class ProductImageWidget extends StatelessWidget {
  final Uint8List? imageBytes;
  final String productName;
  final String category;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final double iconSize;

  const ProductImageWidget({
    super.key,
    required this.imageBytes,
    required this.productName,
    required this.category,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          imageBytes!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(radius),
        ),
      );
    }

    return _buildPlaceholder(radius);
  }

  Widget _buildPlaceholder(BorderRadius radius) {
    final cat = category.toLowerCase();
    final name = productName.toLowerCase();

    final IconData iconData;
    final List<Color> gradientColors;
    final Color glowColor;

    if (cat.contains('drink') || cat.contains('beverage') || name.contains('coke') || name.contains('water') || name.contains('coffee') || name.contains('juice') || name.contains('tea')) {
      iconData = Icons.local_drink_rounded;
      gradientColors = const [Color(0xFF1E293B), Color(0xFF0F172A)];
      glowColor = const Color(0xFF38BDF8);
    } else if (cat.contains('snack') || cat.contains('food') || name.contains('chip') || name.contains('biscuit') || name.contains('bread') || name.contains('noodle') || name.contains('candy')) {
      iconData = Icons.fastfood_rounded;
      gradientColors = const [Color(0xFF2E1065), Color(0xFF1E1B4B)];
      glowColor = AppColors.primaryLight;
    } else if (cat.contains('house') || cat.contains('clean') || name.contains('detergent') || name.contains('soap') || name.contains('bleach')) {
      iconData = Icons.cleaning_services_rounded;
      gradientColors = const [Color(0xFF064E3B), Color(0xFF022C22)];
      glowColor = const Color(0xFF4ADE80);
    } else if (cat.contains('care') || cat.contains('person') || name.contains('shampoo') || name.contains('toothpaste') || name.contains('lotion')) {
      iconData = Icons.sanitizer_rounded;
      gradientColors = const [Color(0xFF4C1D95), Color(0xFF2E1065)];
      glowColor = const Color(0xFFA78BFA);
    } else {
      iconData = Icons.inventory_2_rounded;
      gradientColors = const [Color(0xFF261D33), Color(0xFF171222)];
      glowColor = AppColors.primaryLight;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient circular ring
          Container(
            width: iconSize * 2.2,
            height: iconSize * 2.2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor.withValues(alpha: 0.08),
            ),
          ),
          // Elevated circular emblem badge
          Container(
            padding: EdgeInsets.all(iconSize * 0.35),
            decoration: BoxDecoration(
              color: HomeColors.cardElevated,
              shape: BoxShape.circle,
              border: Border.all(color: glowColor.withValues(alpha: 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              iconData,
              size: iconSize,
              color: glowColor,
            ),
          ),
        ],
      ),
    );
  }
}
