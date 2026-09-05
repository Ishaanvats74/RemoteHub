import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../dashboard/dashboard_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authNotifierProvider.notifier).register(
          username: username,
          email: email,
          password: password,
        );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(authNotifierProvider.notifier).clearError();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create an Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set up your administrator credentials to pair desktop clients.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Inline Error Banner
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.actionShutdownBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.actionShutdown.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.actionShutdown,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Username field
                    AppTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'admin_sys',
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      validator: Validators.validateUsername,
                    ),
                    const SizedBox(height: 18),

                    // Email field
                    AppTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'admin@company.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 18),

                    // Password field
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password (min 6 chars)',
                      hint: '••••••••',
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSignup(),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 28),

                    // Create Account Button
                    AppButton(
                      text: 'Create Account',
                      isLoading: isLoading,
                      onPressed: _handleSignup,
                    ),
                    const SizedBox(height: 24),

                    // Back to Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            ref.read(authNotifierProvider.notifier).clearError();
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
}
