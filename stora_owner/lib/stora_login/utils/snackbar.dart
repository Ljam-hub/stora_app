import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

void showStoraSnackBar(
  BuildContext context,
  String message, {
  bool? isError,
  Color? customColor,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  final lower = message.toLowerCase();

  // Verification sent, success, update notifications should NEVER be red
  final isVerificationOrSent = lower.contains('sent') ||
      lower.contains('send') ||
      (lower.contains('verification') &&
          !lower.contains('failed') &&
          !lower.contains('invalid') &&
          !lower.contains('expired')) ||
      lower.contains('code has been') ||
      lower.contains('check your email') ||
      lower.contains('success') ||
      lower.contains('welcome') ||
      lower.contains('verified') ||
      lower.contains('saved') ||
      lower.contains('updated') ||
      lower.contains('copied');

  final isRealError = (isError == true) ||
      (!isVerificationOrSent &&
          (lower.contains('fail') ||
              lower.contains('invalid') ||
              lower.contains('error') ||
              lower.contains('incorrect') ||
              lower.contains('expired') ||
              lower.contains('not found') ||
              lower.contains('please fix') ||
              lower.contains('cannot')));

  final Color bg;
  final IconData icon;

  if (customColor != null) {
    bg = customColor;
    icon = Icons.info_outline_rounded;
  } else if (isRealError) {
    bg = AppColors.error; // Pure red strictly for critical errors
    icon = Icons.error_outline_rounded;
  } else if (isVerificationOrSent) {
    bg = AppColors.secondary; // Vibrant Emerald Green (0xFF10B981)
    icon = lower.contains('verification') || lower.contains('email') || lower.contains('code')
        ? Icons.mark_email_read_rounded
        : Icons.check_circle_outline_rounded;
  } else {
    bg = AppColors.primary;
    icon = Icons.info_outline_rounded;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
