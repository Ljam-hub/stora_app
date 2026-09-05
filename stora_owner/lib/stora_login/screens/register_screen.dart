import 'package:flutter/material.dart';
import 'package:stora/auth/auth_store.dart';
import 'package:stora/data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../utils/validators.dart';
import '../widgets/stora_gradient_button.dart';
import '../widgets/stora_header.dart';
import '../widgets/stora_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateBusinessName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Business name is required';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      showStoraSnackBar(context, 'Please fix the errors above');
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthStore.instance.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        businessName: _businessNameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
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
                      key: const Key('backButton'),
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
                        'Create account',
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
                        'Get Started Free',
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
                        'Set up your store in less than a minute',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.label, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      StoraTextField(
                        fieldKey: const Key('businessNameField'),
                        label: 'Business Name',
                        hint: "Aling Nena's Store",
                        controller: _businessNameController,
                        prefixIcon: const Icon(Icons.storefront_rounded, color: AppColors.label, size: 20),
                        validator: _validateBusinessName,
                      ),
                      const SizedBox(height: 18),
                      StoraTextField(
                        fieldKey: const Key('registerEmailField'),
                        label: 'Email Address',
                        hint: 'nena@storemail.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.label, size: 20),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 18),
                      StoraTextField(
                        fieldKey: const Key('registerPasswordField'),
                        label: 'Password',
                        hint: '••••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.label, size: 20),
                        validator: validatePassword,
                      ),
                      const SizedBox(height: 18),
                      StoraTextField(
                        fieldKey: const Key('confirmPasswordField'),
                        label: 'Confirm Password',
                        hint: '••••••••••',
                        controller: _confirmPasswordController,
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.label, size: 20),
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 26),
                      StoraGradientButton(
                        buttonKey: const Key('registerSubmitButton'),
                        label: 'Create account',
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
