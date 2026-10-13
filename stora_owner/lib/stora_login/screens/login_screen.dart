import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stora/auth/auth_store.dart';
import 'package:stora/data/api/api_client.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar.dart';
import '../utils/validators.dart';
import '../widgets/stora_gradient_button.dart';
import '../widgets/stora_header.dart';
import '../widgets/stora_text_field.dart';
import 'email_verification_screen.dart';

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
    if (_busy) return;
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
      TextInput.finishAutofillContext(shouldSave: true);
      FocusScope.of(context).unfocus();
      // Yield so Android's AutofillManager can capture fields and present the "Save password to Google" dialog
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      if (!AuthStore.instance.isEmailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: _emailController.text.trim(),
              autoSendOnEntry: false,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
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
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.commit,
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
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
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
                            autofillHints: const [AutofillHints.password],
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
                            onPressed: _busy ? null : _submit,
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
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () => _showCyberSecurityNotice(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: AppColors.purpleLight.withValues(alpha: 0.85)),
                            const SizedBox(width: 6),
                            const Text(
                              'Data Privacy & Cyber Security Compliant',
                              style: TextStyle(
                                color: AppColors.label,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(RA 10173 · RA 10175)',
                              style: TextStyle(
                                color: AppColors.purpleLight.withValues(alpha: 0.85),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
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
      ),
    );
  }

  void _showCyberSecurityNotice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.fieldBorder)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.label.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cyber Security & Data Privacy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Philippine Legal Framework & Protections',
                                style: TextStyle(
                                  color: AppColors.label,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildLegalCard(
                      icon: Icons.shield_outlined,
                      title: 'Republic Act No. 10175',
                      subtitle: 'Cybercrime Prevention Act of 2012',
                      description:
                          'STORA strictly safeguards store owners and customers against unauthorized access, computer data tampering, digital identity theft, and fraudulent transactions. All platform communication is secured with TLS encryption, and security infractions are prosecuted under Philippine cyber law.',
                    ),
                    const SizedBox(height: 12),
                    _buildLegalCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Republic Act No. 10173',
                      subtitle: 'Data Privacy Act of 2012 (DPA)',
                      description:
                          'Your retail transaction records, utang ledgers, contact numbers, and payment details are strictly confidential. Stora enforces end-to-end data isolation: administrative panels automatically mask personal identifiable information (PII), customer chats and verification codes are completely shielded, and payment QR codes remain tamper-proof.',
                    ),
                    const SizedBox(height: 12),
                    _buildLegalCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'Zero Exploitation Guarantee',
                      subtitle: 'Privacy & Security By Design',
                      description:
                          '• Customer peer chats are strictly private and shielded from platform oversight.\n'
                          '• Email verification codes bypass public view to eliminate intercept attacks.\n'
                          '• Store locations and customer phones are encrypted with authenticated AES.\n'
                          '• Store owners retain full ownership to export or delete their data anytime.',
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Understood & Acknowledged', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.label,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
