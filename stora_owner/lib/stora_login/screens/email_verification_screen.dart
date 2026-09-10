import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stora/auth/auth_store.dart';
import 'package:stora/data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../widgets/stora_gradient_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  int _resendCooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    _timer?.cancel();
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      showStoraSnackBar(context, 'Please enter the full 6-digit verification code.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AuthStore.instance.verifyEmail(code, targetEmail: widget.email);
      if (!mounted) return;
      showStoraSnackBar(context, 'Email verified successfully! Welcome to STORA.');
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await AuthStore.instance.resendVerification(targetEmail: widget.email);
      if (!mounted) return;
      showStoraSnackBar(context, 'A new verification code has been sent to your email.');
      _startCooldownTimer();
    } on ApiException catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showStoraSnackBar(context, 'Failed to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await AuthStore.instance.logout();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
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
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.primaryLight,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Verify Your Email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We sent a 6-digit verification code to:',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.label, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Code Input Field
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.fieldBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.fieldBorder),
                        ),
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 10,
                          ),
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              color: AppColors.hint,
                              fontSize: 28,
                              letterSpacing: 10,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      StoraGradientButton(
                        label: 'Verify Account',
                        isLoading: _isSubmitting,
                        onPressed: _handleVerify,
                      ),
                      const SizedBox(height: 16),

                      // Resend Code
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Didn't receive code? ",
                            style: TextStyle(color: AppColors.label, fontSize: 13),
                          ),
                          TextButton(
                            onPressed: (_resendCooldown == 0 && !_isResending)
                                ? _handleResend
                                : null,
                            child: _isResending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    _resendCooldown > 0
                                        ? 'Resend (${_resendCooldown}s)'
                                        : 'Resend Code',
                                    style: TextStyle(
                                      color: _resendCooldown > 0
                                          ? AppColors.hint
                                          : AppColors.primaryLight,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF332A40), height: 32),

                      // Back to Login
                      TextButton.icon(
                        onPressed: () async {
                          await AuthStore.instance.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.hint),
                        label: const Text(
                          'Back to Login',
                          style: TextStyle(
                            color: AppColors.hint,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
