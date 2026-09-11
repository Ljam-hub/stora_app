import 'package:flutter/material.dart';

/// Red notification badge styled like modern messenger notification badges.
/// Displays a vibrant red circle/pill with crisp bold white number and border.
class AppNotificationBadge extends StatelessWidget {
  final int count;
  final Widget? child;
  final double top;
  final double right;
  final double minSize;
  final Color badgeColor;
  final Color textColor;
  final Color? borderColor;
  final double borderWidth;
  final int maxCount;
  final bool showIfZero;

  const AppNotificationBadge({
    super.key,
    required this.count,
    this.child,
    this.top = -4,
    this.right = -7,
    this.minSize = 18,
    this.badgeColor = const Color(0xFFEF4444),
    this.textColor = Colors.white,
    this.borderColor,
    this.borderWidth = 1.5,
    this.maxCount = 99,
    this.showIfZero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (child == null) {
      return _buildBadge(context);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        if (count > 0 || showIfZero)
          Positioned(
            top: top,
            right: right,
            child: _buildBadge(context),
          ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context) {
    if (count <= 0 && !showIfZero) {
      return const SizedBox.shrink();
    }

    final displayText = count > maxCount ? '$maxCount+' : '$count';

    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 1.3, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, scale, badgeWidget) {
        return Transform.scale(
          scale: scale,
          child: badgeWidget,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(minSize),
          border: Border.all(
            color: borderColor ?? const Color(0xFF161122),
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withValues(alpha: 0.5),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            displayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: minSize >= 18 ? 10 : 9,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
