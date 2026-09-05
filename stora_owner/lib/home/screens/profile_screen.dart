import 'package:flutter/material.dart';
import '../../data/api/api_client.dart';
import '../../data/stores/account_status_store.dart';
import '../../auth/auth_store.dart';
import '../../stora_login/stora_login.dart';
import '../stores/cart_store.dart';
import '../stores/category_store.dart';
import '../stores/inventory_store.dart';
import '../stores/sales_store.dart';
import '../theme/home_colors.dart';
import '../widgets/status_chip.dart';
import '../../subscription/subscription_screen.dart';
import '../../subscription/subscription_status_screen.dart';
import '../../subscription/subscription_status.dart';

// ---------------------------------------------------------------------
// Profile — store header (name, owner, plan pill) plus a settings
// menu. Reached from the Dashboard's avatar icon in its header row
// (see dashboard_screen.dart).
// ---------------------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context) {
    final businessController = TextEditingController(text: AuthStore.instance.businessName ?? '');
    final emailController = TextEditingController(text: AuthStore.instance.email ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: businessController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Store / Business Name',
                  labelStyle: const TextStyle(color: AppColors.label),
                  filled: true,
                  fillColor: AppColors.fieldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: AppColors.label),
                  filled: true,
                  fillColor: AppColors.fieldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final bName = businessController.text.trim();
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        showStoraSnackBar(context, 'Email cannot be empty');
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await AuthStore.instance.updateProfile(
                          newBusinessName: bName,
                          newEmail: email,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          showStoraSnackBar(context, 'Profile updated successfully', isError: false);
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) showStoraSnackBar(context, e.message);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) showStoraSnackBar(context, 'Could not update profile');
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: const TextStyle(color: AppColors.label),
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: const TextStyle(color: AppColors.label),
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: const TextStyle(color: AppColors.label),
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final oldPass = oldPasswordController.text;
                      final newPass = newPasswordController.text;
                      final confirmPass = confirmPasswordController.text;

                      if (oldPass.isEmpty || newPass.isEmpty) {
                        showStoraSnackBar(context, 'Please fill in all password fields');
                        return;
                      }
                      if (newPass.length < 6) {
                        showStoraSnackBar(context, 'New password must be at least 6 characters');
                        return;
                      }
                      if (newPass != confirmPass) {
                        showStoraSnackBar(context, 'New passwords do not match');
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final msg = await AuthStore.instance.changePassword(
                          oldPassword: oldPass,
                          newPassword: newPass,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          showStoraSnackBar(context, msg, isError: false);
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) showStoraSnackBar(context, e.message);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) showStoraSnackBar(context, 'Could not change password');
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Change', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AuthStore.instance, AccountStatusStore.instance]),
      builder: (context, _) {
        final auth = AuthStore.instance;
        final account = AccountStatusStore.instance.status;
        final storeName = auth.businessName?.isNotEmpty == true ? auth.businessName! : 'Your Store';
        final ownerEmail = auth.email ?? '';

        final isPremium = account.isPremium;
        final isPending = account.latestPaymentProof?.isPending == true;
        final planLabel = isPremium
            ? 'Premium'
            : isPending
                ? 'Pending · Premium'
                : 'Free plan';
        final planColor = isPremium ? HomeColors.successText : AppColors.purpleLight;
        final planBg = isPremium ? HomeColors.successBg : AppColors.fieldBackground;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: HomeColors.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const Expanded(
                        child: Text('Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: HomeColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HomeColors.cardBorder),
                      boxShadow: HomeColors.cardShadow,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: HomeColors.purpleGradient,
                            ),
                            child: const CircleAvatar(
                              radius: 34,
                              backgroundColor: HomeColors.cardElevated,
                              child: Icon(Icons.storefront_rounded, color: AppColors.purpleLight, size: 36),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(storeName,
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(ownerEmail, style: const TextStyle(color: AppColors.label, fontSize: 13)),
                          const SizedBox(height: 12),
                          StatusChip(label: planLabel, color: planColor, background: planBg),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _MenuTile(
                    icon: Icons.edit_note_rounded,
                    label: 'Edit profile',
                    onTap: () => _showEditProfileDialog(context),
                  ),
                  _MenuTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change password',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  _MenuTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Subscription Plan',
                    onTap: () {
                      if (account.latestPaymentProof != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubscriptionStatusScreen(
                              status: SubscriptionStatus.fromBackend(
                                account.latestPaymentProof!.status,
                                account.latestPaymentProof!.submittedAt,
                                referenceNumber: account.latestPaymentProof!.referenceNumber,
                              ),
                            ),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubscriptionScreen(
                              productsUsed: account.productCount,
                              productsLimit: account.productLimit,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    destructive: true,
                    onTap: () async {
                      await AuthStore.instance.logout();
                      InventoryStore.instance.reset();
                      CategoryStore.instance.reset();
                      SalesStore.instance.reset();
                      CartStore.instance.clear();
                      AccountStatusStore.instance.reset();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : Colors.white;
    final iconBg = destructive ? HomeColors.dangerBg : AppColors.purple.withValues(alpha: 0.12);
    final iconColor = destructive ? AppColors.error : AppColors.purpleLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: HomeColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.cardBorder),
            boxShadow: HomeColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              if (!destructive) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.label),
            ],
          ),
        ),
      ),
    );
  }
}
