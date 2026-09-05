import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_state.dart';
import '../../state/server_settings_state.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../dashboard/dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authNotifierProvider.notifier).login(email, password);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  void _showServerSettingsDialog() {
    final currentUrl = ref.read(serverSettingsProvider);
    final urlController = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend Server URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the FastAPI server host and port. Use 10.0.2.2 for Android emulator, or your local machine LAN IP.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: urlController,
              hint: 'http://10.0.2.2:8000',
              prefixIcon: const Icon(Icons.dns_rounded, size: 20, color: AppColors.primary),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                ref.read(serverSettingsProvider.notifier).setBaseUrl(newUrl);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Server Settings',
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: _showServerSettingsDialog,
          ),
        ],
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
                    // Brand header
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          size: 30,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome to RemoteCtrl',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to manage and remotely control your paired computers.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Inline Error Message Banner
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

                    // Input fields
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
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: '••••••••',
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      validator: (val) =>
                          (val == null || val.isEmpty) ? 'Password is required' : null,
                    ),
                    const SizedBox(height: 28),

                    // Sign In Button
                    AppButton(
                      text: 'Sign In',
                      isLoading: isLoading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 24),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            ref.read(authNotifierProvider.notifier).clearError();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignupScreen()),
                            );
                          },
                          child: const Text(
                            'Sign Up',
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
