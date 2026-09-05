import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusDot extends StatelessWidget {
  final bool isOnline;
  final double size;
  final bool showLabel;
  final String? customLabel;

  const StatusDot({
    super.key,
    required this.isOnline,
    this.size = 10,
    this.showLabel = false,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.statusOnline : AppColors.statusOffline;
    final labelText = customLabel ?? (isOnline ? 'Online' : 'Offline');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: AppColors.statusOnline.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            labelText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}
