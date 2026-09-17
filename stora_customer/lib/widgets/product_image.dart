import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../config/api_config.dart';

/// Shared widget for displaying product images from base64, URL, or a
/// category-adaptive fallback icon. Replaces duplicated image-decoding
/// logic formerly in ProductCard, CartItemTile, and ProductDetailSheet.
class ProductImage extends StatelessWidget {
  static final Map<String, Uint8List> _base64Cache = {};
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
    final raw = imageData?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        if (raw.startsWith('http://') ||
            raw.startsWith('https://') ||
            raw.startsWith('//') ||
            raw.startsWith('/media/') ||
            raw.startsWith('media/') ||
            raw.startsWith('/static/') ||
            raw.startsWith('static/')) {
          final resolved = ApiConfig.resolveMediaUrl(raw);
          if (resolved != null) {
            final targetCacheWidth = width != null ? (width! * 2.5).toInt() : 360;
            return Image.network(
              resolved,
              width: width,
              height: height,
              fit: fit,
              cacheWidth: targetCacheWidth,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            );
          }
        } else {
          // Fast lookup in in-memory base64 cache
          Uint8List? bytes = _base64Cache[raw];
          if (bytes == null) {
            // Decode base64 image (handles raw base64, data URIs, JPEG headers with /9j/, etc.)
            var clean = raw.contains(',') ? raw.split(',').last.trim() : raw;
            clean = clean.replaceAll(RegExp(r'\s+'), '');
            if (clean.isNotEmpty) {
              while (clean.length % 4 != 0) {
                clean += '=';
              }
              bytes = base64Decode(clean);
              if (_base64Cache.length > 200) {
                _base64Cache.clear();
              }
              _base64Cache[raw] = bytes;
            }
          }
          if (bytes != null && bytes.isNotEmpty) {
            final targetCacheWidth = width != null ? (width! * 2.5).toInt() : 360;
            return Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              cacheWidth: targetCacheWidth,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            );
          }
        }
      } catch (e) {
        debugPrint('ProductImage decode error: $e');
      }
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
            child: Icon(iconData, size: iconSize, color: AppColors.accentText),
          ),
        ],
      ),
    );
  }
}
