import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../utils/validators.dart';
import '../widgets/stora_gradient_button.dart';
import '../widgets/stora_header.dart';
import '../widgets/stora_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForToken();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
      if (!mounted) return;
      final text = data?.text?.trim() ?? '';
      final token = _extractResetToken(text);
      if (token.isNotEmpty && _tokenController.text != token) {
        setState(() {
          _tokenController.text = token;
        });
        if (mounted) {
          showStoraSnackBar(context, 'Reset token auto-pasted from clipboard', isError: false);
        }
      }
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      if (!mounted) return;
      final text = data?.text?.trim() ?? '';
      final token = _extractResetToken(text);
      if (token.isNotEmpty) {
        setState(() {
          _tokenController.text = token;
        });
        if (mounted) {
          showStoraSnackBar(context, 'Reset token pasted from clipboard', isError: false);
        }
      } else if (text.isNotEmpty) {
        setState(() {
          _tokenController.text = text;
        });
      } else {
        if (mounted) {
          showStoraSnackBar(context, 'Clipboard is empty');
        }
      }
    } catch (_) {}
  }

  String? _validateToken(String? v) {
    if (v == null || v.trim().isEmpty) return 'Reset code is required';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final message = await ApiClient.instance.confirmPasswordReset(
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      showStoraSnackBar(context, message, isError: false);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1827),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF332A40)),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'New password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 20),
                const StoraHeader(),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1827),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF332A40)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Set New Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter the reset code sent to your email and your new password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.label, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      StoraTextField(
                        label: 'Reset Code',
                        hint: 'Paste the code from your email',
                        controller: _tokenController,
                        prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.label, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste_rounded, color: AppColors.primaryLight, size: 20),
                          tooltip: 'Paste from clipboard',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36, maxWidth: 36, maxHeight: 36),
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _pasteFromClipboard,
                        ),
                        validator: _validateToken,
                      ),
                      const SizedBox(height: 18),
                      StoraTextField(
                        label: 'New Password',
                        hint: '••••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.label, size: 20),
                        validator: validatePassword,
                      ),
                      const SizedBox(height: 18),
                      StoraTextField(
                        label: 'Confirm New Password',
                        hint: '••••••••••',
                        controller: _confirmController,
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.label, size: 20),
                        validator: _validateConfirm,
                      ),
                      const SizedBox(height: 26),
                      StoraGradientButton(
                        label: 'Reset password',
                        isLoading: _busy,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}