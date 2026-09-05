import 'package:flutter/material.dart';
import '../../data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../utils/validators.dart';
import '../widgets/stora_gradient_button.dart';
import '../widgets/stora_header.dart';
import '../widgets/stora_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final message = await ApiClient.instance
          .requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      showStoraSnackBar(context, message, isError: false);
      Navigator.of(context).pushReplacementNamed(
        '/reset-password',
        arguments: _emailController.text.trim(),
      );
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
                        'Reset password',
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
                        'Forgot Password',
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
                        'Enter your registered email and we\'ll send a 6-digit reset code.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.label, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      StoraTextField(
                        label: 'Email Address',
                        hint: 'nena@storemail.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.label, size: 20),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 26),
                      StoraGradientButton(
                        label: 'Send reset code',
                        isLoading: _busy,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}