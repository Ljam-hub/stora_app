import 'package:flutter/material.dart';
import '../../stora_login/stora_login.dart';
import '../theme/home_colors.dart';

/// Settings-style row tile — icon, label, chevron — used on Profile
/// for menu entries like "Edit profile", "Subscription", "Log out".
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: HomeColors.cardBackground, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (!destructive) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.label),
            ],
          ),
        ),
      ),
    );
  }
}
