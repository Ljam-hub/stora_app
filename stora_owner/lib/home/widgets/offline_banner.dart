import 'package:flutter/material.dart';
import '../../data/services/connectivity_service.dart';
import '../theme/home_colors.dart';

class OfflineBannerWrapper extends StatelessWidget {
  final Widget child;

  const OfflineBannerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.isOnline,
      builder: (context, isOnline, _) {
        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: isOnline ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: HomeColors.warningBg,
              border: Border(
                bottom: BorderSide(color: HomeColors.warningText.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 16, color: HomeColors.warningText),
                const SizedBox(width: 8),
                Text(
                  'No internet connection • Local offline mode active',
                  style: TextStyle(
                    color: HomeColors.warningText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
