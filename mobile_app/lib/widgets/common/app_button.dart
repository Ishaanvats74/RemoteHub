import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonVariant {
  primary,
  secondary,
  destructive,
  outlined,
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = AppColors.primary;
        fg = const Color(0xFF0B0F19);
        break;
      case AppButtonVariant.secondary:
        bg = AppColors.surfaceHover;
        fg = AppColors.textPrimary;
        border = const BorderSide(color: AppColors.surfaceBorder);
        break;
      case AppButtonVariant.destructive:
        bg = AppColors.actionShutdown;
        fg = Colors.white;
        break;
      case AppButtonVariant.outlined:
        bg = Colors.transparent;
        fg = AppColors.textPrimary;
        border = const BorderSide(color: AppColors.surfaceBorder);
        break;
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: border ?? BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
