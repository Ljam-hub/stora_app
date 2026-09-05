import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:stora/auth/auth_store.dart';
import 'package:stora/data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../utils/validators.dart';
import '../widgets/stora_gradient_button.dart';
import '../widgets/stora_header.dart';
import '../widgets/stora_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      showStoraSnackBar(context, 'Please fix the errors above');
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthStore.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StoraHeader(),
                  const SizedBox(height: 32),
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
                          'Welcome back',
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
                          'Sign in to manage your store inventory',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.label, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        StoraTextField(
                          fieldKey: const Key('loginEmailField'),
                          label: 'Email Address',
                          hint: 'nena@storemail.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.label, size: 20),
                          validator: validateEmail,
                        ),
                        const SizedBox(height: 18),
                        StoraTextField(
                          fieldKey: const Key('loginPasswordField'),
                          label: 'Password',
                          hint: '••••••••••',
                          controller: _passwordController,
                          obscureText: true,
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.label, size: 20),
                          validator: validatePassword,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/forgot-password');
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(color: AppColors.purpleLight, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        StoraGradientButton(
                          buttonKey: const Key('loginSubmitButton'),
                          label: 'Log in',
                          isLoading: _busy,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: AppColors.label, fontSize: 14),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Create account',
                            style: const TextStyle(
                              color: AppColors.purpleLight,
                              fontWeight: FontWeight.w800,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context).pushNamed('/register');
                              },
                          ),
                        ],
                      ),
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
