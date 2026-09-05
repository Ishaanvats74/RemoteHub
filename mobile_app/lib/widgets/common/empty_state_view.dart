import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'app_button.dart';

class EmptyStateView extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final IconData icon;

  const EmptyStateView({
    super.key,
    this.title = 'No Devices Connected',
    this.message = 'Pair your laptop or desktop to start sending remote power commands.',
    this.buttonText = 'Pair New Device',
    this.onButtonPressed,
    this.icon = Icons.devices_other_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
              ),
              child: Icon(
                icon,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 28),
              AppButton(
                text: buttonText!,
                icon: Icons.add_rounded,
                width: 200,
                onPressed: onButtonPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
