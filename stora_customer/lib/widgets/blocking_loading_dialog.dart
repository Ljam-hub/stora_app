import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a logout-style modal dialog that blocks all user interaction completely
/// (barrierDismissible: false, PopScope canPop: false) while an asynchronous task executes.
Future<T> showCustomerBlockingLoadingDialog<T>({
  required BuildContext context,
  required String message,
  required Future<T> Function() task,
}) async {
  final dialogContextCompleter = Completer<BuildContext>();

  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogCtx) {
      if (!dialogContextCompleter.isCompleted) {
        dialogContextCompleter.complete(dialogCtx);
      }
      return PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  final dialogCtx = await dialogContextCompleter.future;
  try {
    return await task();
  } finally {
    if (dialogCtx.mounted) {
      Navigator.of(dialogCtx, rootNavigator: true).pop();
    }
  }
}
