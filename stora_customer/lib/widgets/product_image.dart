import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared widget for displaying product images from base64, URL, or a
/// category-adaptive fallback icon. Replaces duplicated image-decoding
/// logic formerly in ProductCard, CartItemTile, and ProductDetailSheet.
class ProductImage extends StatelessWidget {
  final String? imageData;
  final String categoryName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key,
    required this.imageData,
    this.categoryName = '',
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = _buildImage();
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildImage() {
    if (imageData != null && imageData!.isNotEmpty) {
      try {
        if (imageData!.startsWith('data:image') || imageData!.length > 100) {
          final clean = imageData!.contains(',')
              ? imageData!.split(',').last
              : imageData!;
          final bytes = base64Decode(clean);
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        } else if (imageData!.startsWith('http')) {
          return Image.network(
            imageData!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        }
      } catch (_) {}
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    final cat = categoryName.toLowerCase();
    final IconData iconData;
    final List<Color> gradientColors;

    if (cat.contains('drink') || cat.contains('beverage')) {
      iconData = Icons.local_drink_rounded;
      gradientColors = const [Color(0xFF1E293B), Color(0xFF0F172A)];
    } else if (cat.contains('snack') || cat.contains('food')) {
      iconData = Icons.fastfood_rounded;
      gradientColors = const [Color(0xFF2E1065), Color(0xFF1E1B4B)];
    } else if (cat.contains('house') || cat.contains('clean')) {
      iconData = Icons.cleaning_services_rounded;
      gradientColors = const [Color(0xFF064E3B), Color(0xFF022C22)];
    } else if (cat.contains('care') || cat.contains('person')) {
      iconData = Icons.sanitizer_rounded;
      gradientColors = const [Color(0xFF4C1D95), Color(0xFF2E1065)];
    } else {
      iconData = Icons.inventory_2_rounded;
      gradientColors = const [Color(0xFF1F1A28), Color(0xFF141018)];
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: iconSize * 2.25,
            height: iconSize * 2.25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          Container(
            padding: EdgeInsets.all(iconSize * 0.44),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: AppColors.glowShadow(AppColors.primary, opacity: 0.2),
            ),
            child: Icon(iconData, size: iconSize, color: AppColors.primaryLight),
          ),
        ],
      ),
    );
  }
}
