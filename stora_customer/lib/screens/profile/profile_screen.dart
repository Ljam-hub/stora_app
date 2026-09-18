import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../storage/hidden_products_store.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/email_verification_screen.dart';
import '../chat/customer_chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;
  bool _isOpeningSupport = false;

  Future<void> _pickAndUploadAvatar() async {
    final auth = context.read<AuthProvider>();
    final hasAvatar = auth.currentUser?.avatarUrl != null && auth.currentUser!.avatarUrl!.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: Text('Take a photo', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text('Choose from gallery', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasAvatar) ...[
              Divider(color: AppColors.cardBorder, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Remove profile photo', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (action == 'remove') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          title: Text('Remove Profile Photo', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to remove your profile photo and restore the default avatar?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      setState(() => _uploadingAvatar = true);
      try {
        final ok = await auth.removeAvatar();
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        if (ok) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Profile photo removed. Classic avatar restored.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Color(0xFF059669),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to remove profile photo.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null || !mounted) return;

      setState(() => _uploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final ok = await auth.uploadAvatar(bytes, picked.name);
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      if (ok) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to upload profile photo.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _openEditProfileDialog() async {
    final auth = context.read<AuthProvider>();
    final nameController = TextEditingController(text: auth.currentUser?.name ?? '');
    final emailController = TextEditingController(text: auth.currentUser?.email ?? '');

    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          title: Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary)),
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
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await auth.updateProfile(
                  name: nameController.text,
                  email: emailController.text,
                );
                if (ok) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Color(0xFF059669),
                      ),
                    );
                  }
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update profile. Please try again.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
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
    } finally {
      nameController.dispose();
      emailController.dispose();
    }
  }

  void _openEditDeliveryDialog() async {
    final auth = context.read<AuthProvider>();
    final phoneController = TextEditingController(text: auth.savedPhone ?? '');
    final addressController = TextEditingController(text: auth.savedAddress ?? '');
    bool isLocating = false;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> autoLocate() async {
              if (isLocating) return;
              setDialogState(() => isLocating = true);
              final messenger = ScaffoldMessenger.of(context);
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Detecting current GPS location...'),
                  duration: Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final res = await LocationService.instance.detectCurrentAddress();
              if (dialogCtx.mounted) {
                setDialogState(() => isLocating = false);
              }
              messenger.hideCurrentSnackBar();
              if (res.success && res.address != null) {
                addressController.text = res.address!;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Location found: ${res.address!}'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(res.errorMessage ?? 'Could not detect location.'),
                    backgroundColor: AppColors.danger,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.cardBorder),
              ),
              title: Text('Default Delivery Info', style: TextStyle(color: AppColors.textPrimary)),
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
                    prefixIconTooltip: 'Locate current address',
                    onPrefixIconPressed: autoLocate,
                    suffix: isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                            tooltip: 'Detect current location',
                            onPressed: autoLocate,
                          ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await auth.saveDeliveryDetails(
                      phone: phoneController.text,
                      address: addressController.text,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Delivery information saved!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Details'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      phoneController.dispose();
      addressController.dispose();
    }
  }

  void _openChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.cardBorder),
            ),
            title: Text('Change Password', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: oldPasswordController,
                    label: 'Current Password',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: newPasswordController,
                    label: 'New Password',
                    hint: 'At least 8 characters',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: confirmPasswordController,
                    label: 'Confirm New Password',
                    hint: 'Repeat new password',
                    prefixIcon: Icons.lock_reset_outlined,
                    isPassword: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final oldPass = oldPasswordController.text;
                        final newPass = newPasswordController.text;
                        final confirmPass = confirmPasswordController.text;

                        if (oldPass.isEmpty || newPass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all password fields.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        if (newPass.length < 8) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('New password must be at least 8 characters.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        if (newPass != confirmPass) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('New passwords do not match.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);

                        try {
                          await CustomerApiService.instance.changePassword(
                            oldPassword: oldPass,
                            newPassword: newPass,
                          );
                          if (ctx.mounted) nav.pop();
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) setDialogState(() => isSaving = false);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Update Password'),
              ),
            ],
          ),
        ),
      );
    } finally {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: Text('Log Out', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              context.read<OrderProvider>().reset();
              context.read<ChatProvider>().reset();
              context.read<CartProvider>().clear();
              HiddenProductsStore.instance.clear();
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('Log Out', style: TextStyle(color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount() {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
              const SizedBox(width: 8),
              Text('Delete Account', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete your account? This action is permanent and cannot be undone. All your orders, messages, and profile data will be permanently deleted.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(context);
                      try {
                        context.read<OrderProvider>().reset();
                        context.read<ChatProvider>().reset();
                        context.read<CartProvider>().clear();
                        HiddenProductsStore.instance.clear();
                        await context.read<AuthProvider>().deleteAccount();
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Your account has been deleted.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                        nav.pushNamedAndRemoveUntil('/login', (route) => false);
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isDeleting = false);
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
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

  Future<void> _openSupportChat() async {
    if (_isOpeningSupport) return;
    _isOpeningSupport = true;
    try {
      final contact = await CustomerApiService.instance.getSupportContact();
      if (!mounted) return;
      final supportId = (contact?['id'] as num?)?.toInt() ?? 1;
      final supportName = (contact?['name'] as String?) ?? 'STORA Support';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerChatScreen(
            storeOwnerId: supportId,
            storeName: supportName,
            isSupport: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to connect to STORA Support: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningSupport = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CustomerThemeController>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                  Stack(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                          boxShadow: AppColors.glowShadow(AppColors.primary, opacity: 0.3),
                        ),
                        child: ClipOval(
                          child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  user.avatarUrl!,
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      (user.displayName.isNotEmpty ? user.displayName[0] : 'C').toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
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
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cardBackground, width: 2),
                            ),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Customer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Customer Account',
                                style: TextStyle(
                                  color: AppColors.accentText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (user?.isEmailVerified == true)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, color: AppColors.successText, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      color: AppColors.successText,
                                      fontSize: 11,
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
                                      builder: (_) => EmailVerificationScreen(email: user?.email ?? ''),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 12),
                                      SizedBox(width: 2),
                                      Text(
                                        'Verify',
                                        style: TextStyle(
                                          color: AppColors.warning,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: AppColors.accentText),
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
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: AppColors.accentText, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Default Delivery Info',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _openEditDeliveryDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentText,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  Divider(color: AppColors.cardBorder, height: 16),
                  Row(
                    children: [
                      Text('Phone: ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      Text(
                        auth.savedPhone?.isNotEmpty == true ? auth.savedPhone! : 'Not set',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Address: ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      Expanded(
                        child: Text(
                          auth.savedAddress?.isNotEmpty == true ? auth.savedAddress! : 'Not set',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App Appearance / Theme Mode Tile
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Consumer<CustomerThemeController>(
                builder: (context, themeCtrl, _) {
                  final currentMode = themeCtrl.themeMode;

                  IconData icon;
                  String title;
                  String subtitle;
                  if (currentMode == ThemeMode.system) {
                    icon = Icons.brightness_auto_rounded;
                    title = 'System Theme';
                    subtitle = 'Follows your device dark / light mode';
                  } else if (currentMode == ThemeMode.dark) {
                    icon = Icons.dark_mode_rounded;
                    title = 'Dark Mode';
                    subtitle = 'Comfortable for low-light browsing';
                  } else {
                    icon = Icons.light_mode_rounded;
                    title = 'Light Mode';
                    subtitle = 'Crisp high-contrast retail mode';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: Container(
                              key: ValueKey(icon),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                icon,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorderLight),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _buildThemeSegment(
                              label: 'Light',
                              icon: Icons.light_mode_rounded,
                              isSelected: currentMode == ThemeMode.light,
                              onTap: () => themeCtrl.setThemeMode(ThemeMode.light),
                            ),
                            _buildThemeSegment(
                              label: 'Dark',
                              icon: Icons.dark_mode_rounded,
                              isSelected: currentMode == ThemeMode.dark,
                              onTap: () => themeCtrl.setThemeMode(ThemeMode.dark),
                            ),
                            _buildThemeSegment(
                              label: 'System',
                              icon: Icons.brightness_auto_rounded,
                              isSelected: currentMode == ThemeMode.system,
                              onTap: () => themeCtrl.setThemeMode(ThemeMode.system),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Change Password Tile
            InkWell(
              onTap: _openChangePasswordDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Security',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Change your account password',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Help & Customer Support Tile
            InkWell(
              onTap: _openSupportChat,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Help & Customer Support',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chat directly with STORA Support team',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Logout Button
            GradientButton(
              text: 'Log Out',
              icon: Icons.logout_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFC62828)],
              ),
              onPressed: _handleLogout,
            ),
            const SizedBox(height: 14),

            // Delete Account Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleDeleteAccount,
                icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.danger),
                label: const Text('Delete Account', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSegment({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
