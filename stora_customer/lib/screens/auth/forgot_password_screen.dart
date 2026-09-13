import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _codeSent) {
      _checkClipboardForToken();
    }
  }

  String _extractResetToken(String text) {
    final trimmed = text.trim();
    final uuidRegex = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
    final match = uuidRegex.firstMatch(trimmed);
    if (match != null) {
      return match.group(0)!;
    }
    final tokenRegex = RegExp(r'^[0-9a-zA-Z-]{6,36}$');
    if (tokenRegex.hasMatch(trimmed)) {
      return trimmed;
    }
    return '';
  }

  Future<void> _checkClipboardForToken() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      final token = _extractResetToken(text);
      if (token.isNotEmpty && _codeController.text != token) {
        setState(() {
          _codeController.text = token;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reset token auto-pasted from clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      final token = _extractResetToken(text);
      if (token.isNotEmpty) {
        setState(() {
          _codeController.text = token;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reset token pasted from clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (text.isNotEmpty) {
        setState(() {
          _codeController.text = text;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No reset token found in clipboard.')),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await CustomerApiService.instance.forgotPassword(email);
      if (mounted) {
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset code sent! Check your inbox.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleResetPassword() async {
    final code = _codeController.text.trim();
    final newPass = _newPasswordController.text;

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the reset code'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await CustomerApiService.instance.resetPassword(token: code, newPassword: newPass);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully! Please sign in.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _codeSent ? 'Enter Reset Code' : 'Forgot Password?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Enter the reset code sent to your email and choose a new password.'
                    : 'Enter your registered email address and we will send you a reset code.',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),

              if (!_codeSent) ...[
                CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'customer@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Send Reset Code',
                  isLoading: _isLoading,
                  onPressed: _handleSendCode,
                ),
              ] else ...[
                CustomTextField(
                  controller: _codeController,
                  label: 'Reset Code / Token',
                  hint: 'Paste the reset code here',
                  prefixIcon: Icons.vpn_key_outlined,
                  suffix: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36, maxWidth: 36, maxHeight: 36),
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.content_paste_rounded, color: AppColors.primaryLight, size: 20),
                    tooltip: 'Paste from clipboard',
                    onPressed: _pasteFromClipboard,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _newPasswordController,
                  label: 'New Password',
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Save New Password',
                  isLoading: _isLoading,
                  onPressed: _handleResetPassword,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _codeSent = false),
                  child: const Text('Resend code to email', style: TextStyle(color: AppColors.primaryLight)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
