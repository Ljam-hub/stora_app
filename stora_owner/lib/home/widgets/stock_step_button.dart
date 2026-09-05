import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';

class StockStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;
  const StockStepButton({super.key, required this.icon, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.fieldBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Icon(icon, size: 12, color: disabled ? AppColors.label : AppColors.purpleLight),
      ),
    );
  }
}
