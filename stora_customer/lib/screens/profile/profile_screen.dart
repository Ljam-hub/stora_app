import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _openEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final nameController = TextEditingController(text: auth.currentUser?.name ?? '');
    final emailController = TextEditingController(text: auth.currentUser?.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: nameController,
              label: 'Full Name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: emailController,
              label: 'Email Address',
              prefixIcon: Icons.email_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              final ok = await auth.updateProfile(
                name: nameController.text,
                email: emailController.text,
              );
              if (mounted) {
                nav.pop();
                if (ok) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      backgroundColor: AppColors.successBg,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _openEditDeliveryDialog() {
    final auth = context.read<AuthProvider>();
    final phoneController = TextEditingController(text: auth.savedPhone ?? '');
    final addressController = TextEditingController(text: auth.savedAddress ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text('Default Delivery Info', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: phoneController,
              label: 'Phone Number',
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: addressController,
              label: 'Delivery Address',
              prefixIcon: Icons.location_on_outlined,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              await auth.saveDeliveryDetails(
                phone: phoneController.text,
                address: addressController.text,
              );
              if (mounted) {
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Delivery information saved!'),
                    backgroundColor: AppColors.successBg,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out from Stora Customer?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & Name Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.glowShadow(AppColors.primary, opacity: 0.3),
                    ),
                    child: Center(
                      child: Text(
                        (user?.displayName.isNotEmpty == true ? user!.displayName[0] : 'C').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Customer',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Customer Account',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primaryLight),
                    onPressed: _openEditProfileDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Saved Delivery Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: AppColors.primaryLight, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Default Delivery Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _openEditDeliveryDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.cardBorder, height: 16),
                  Row(
                    children: [
                      const Text('Phone: ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      Text(
                        auth.savedPhone?.isNotEmpty == true ? auth.savedPhone! : 'Not set',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Address: ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      Expanded(
                        child: Text(
                          auth.savedAddress?.isNotEmpty == true ? auth.savedAddress! : 'Not set',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // System / Server Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dns_outlined, color: AppColors.textMuted, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Backend Connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.cardBorder, height: 16),
                  Row(
                    children: [
                      const Text('Server URL: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Expanded(
                        child: Text(
                          ApiConfig.baseUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.circle, color: AppColors.success, size: 8),
                      SizedBox(width: 6),
                      Text('Connected & Active', style: TextStyle(color: AppColors.success, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logout Button
            GradientButton(
              text: 'Sign Out',
              icon: Icons.logout_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
              ),
              onPressed: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }
}
