import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import '../theme/theme_mode_controller.dart';

// ---------------------------------------------------------------------
// Profile — store header (name, owner, plan pill) plus a settings
// menu. Reached from the Dashboard's avatar icon in its header row
// (see dashboard_screen.dart).
// ---------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final hasAvatar = AuthStore.instance.avatarUrl != null && AuthStore.instance.avatarUrl!.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: const Text('Take a photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasAvatar) ...[
              const Divider(color: HomeColors.cardBorder, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Remove profile photo', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'remove') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: HomeColors.cardBorder),
          ),
          title: const Text('Remove Profile Photo', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          content: const Text(
            'Are you sure you want to remove your profile photo and restore the default avatar?',
            style: TextStyle(color: AppColors.label, fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.label, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isUploadingAvatar = true);
      try {
        await AuthStore.instance.removeAvatar();
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
          showStoraSnackBar(context, 'Profile photo removed. Classic design restored.', isError: false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
          showStoraSnackBar(context, 'Failed to remove photo: $e');
        }
      }
      return;
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      await AuthStore.instance.uploadAvatar(bytes, picked.name);
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        showStoraSnackBar(context, 'Store profile photo updated successfully!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        showStoraSnackBar(context, 'Failed to upload photo: $e');
      }
    }
  }

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
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

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
                  obscureText: obscureOld,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: const TextStyle(color: AppColors.label),
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: oldPasswordController,
                      builder: (context, value, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (value.text.isNotEmpty)
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.close_rounded, color: AppColors.label, size: 18),
                                tooltip: 'Clear password',
                                onPressed: () => oldPasswordController.clear(),
                              ),
                            IconButton(
                              padding: const EdgeInsets.only(right: 8),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: Icon(
                                obscureOld ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: AppColors.label,
                                size: 20,
                              ),
                              tooltip: obscureOld ? 'Show password' : 'Hide password',
                              onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: const TextStyle(color: AppColors.label),
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: newPasswordController,
                      builder: (context, value, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (value.text.isNotEmpty)
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.close_rounded, color: AppColors.label, size: 18),
                                tooltip: 'Clear password',
                                onPressed: () => newPasswordController.clear(),
                              ),
                            IconButton(
                              padding: const EdgeInsets.only(right: 8),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: Icon(
                                obscureNew ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: AppColors.label,
                                size: 20,
                              ),
                              tooltip: obscureNew ? 'Show password' : 'Hide password',
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: const TextStyle(color: AppColors.label),
                    filled: true,
                    fillColor: AppColors.fieldBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: confirmPasswordController,
                      builder: (context, value, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (value.text.isNotEmpty)
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.close_rounded, color: AppColors.label, size: 18),
                                tooltip: 'Clear password',
                                onPressed: () => confirmPasswordController.clear(),
                              ),
                            IconButton(
                              padding: const EdgeInsets.only(right: 8),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: Icon(
                                obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: AppColors.label,
                                size: 20,
                              ),
                              tooltip: obscureConfirm ? 'Show password' : 'Hide password',
                              onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                            ),
                          ],
                        );
                      },
                    ),
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
                      if (newPass.length < 8) {
                        showStoraSnackBar(context, 'New password must be at least 8 characters');
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
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: HomeColors.purpleGradient,
                                ),
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundColor: HomeColors.cardElevated,
                                  backgroundImage: (auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty)
                                      ? NetworkImage(auth.avatarUrl!)
                                      : null,
                                  child: (auth.avatarUrl == null || auth.avatarUrl!.isEmpty)
                                      ? const Icon(Icons.storefront_rounded, color: AppColors.purpleLight, size: 38)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: HomeColors.cardBackground, width: 2),
                                    ),
                                    child: _isUploadingAvatar
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(storeName,
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(ownerEmail, style: const TextStyle(color: AppColors.label, fontSize: 13)),
                          const SizedBox(height: 8),
                          if (AuthStore.instance.isEmailVerified)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.verified_rounded, color: AppColors.secondaryLight, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Email Verified',
                                  style: TextStyle(
                                    color: AppColors.secondaryLight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EmailVerificationScreen(email: ownerEmail),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warningAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verify Email',
                                      style: TextStyle(
                                        color: AppColors.warningAmber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                  AnimatedBuilder(
                    animation: ThemeModeController.instance,
                    builder: (context, _) {
                      final themeCtrl = ThemeModeController.instance;
                      final isDark = themeCtrl.isDarkMode;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  size: 18,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDark ? 'Dark Mode' : 'Light Mode',
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      isDark ? 'Comfortable dark theme' : 'Crisp light retail theme',
                                      style: const TextStyle(color: AppColors.label, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isDark,
                                activeTrackColor: AppColors.primary,
                                activeThumbColor: Colors.white,
                                onChanged: (val) {
                                  themeCtrl.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    destructive: false,
                    onTap: () => _confirmLogout(context),
                  ),
                  _MenuTile(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete Account',
                    destructive: true,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HomeColors.cardBorder),
        ),
        title: const Text('Log Out', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.label, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.of(ctx).pop();
              await AuthStore.instance.logout();
              InventoryStore.instance.reset();
              CategoryStore.instance.reset();
              SalesStore.instance.reset();
              CartStore.instance.clear();
              AccountStatusStore.instance.reset();
              nav.pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: HomeColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: HomeColors.cardBorder),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text('Delete Account', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete your account? This action is permanent and cannot be undone. All your orders, messages, and profile data will be permanently deleted.',
            style: TextStyle(color: AppColors.label, fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.label, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      final nav = Navigator.of(context);
                      try {
                        await AuthStore.instance.deleteAccount();
                        InventoryStore.instance.reset();
                        CategoryStore.instance.reset();
                        SalesStore.instance.reset();
                        CartStore.instance.clear();
                        AccountStatusStore.instance.reset();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          showStoraSnackBar(context, 'Your store account has been deleted.', isError: false);
                        }
                        nav.pushNamedAndRemoveUntil('/login', (route) => false);
                      } catch (e) {
                        setDialogState(() => isDeleting = false);
                        if (context.mounted) {
                          showStoraSnackBar(context, 'Failed to delete account: $e');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
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
