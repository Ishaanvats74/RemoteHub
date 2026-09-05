import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PlatformIcon extends StatelessWidget {
  final String platform;
  final String os;
  final double size;
  final Color? color;

  const PlatformIcon({
    super.key,
    required this.platform,
    required this.os,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final lowerPlatform = platform.toLowerCase();
    final lowerOs = os.toLowerCase();

    IconData iconData;
    Color defaultColor;

    if (lowerPlatform.contains('win') || lowerOs.contains('win')) {
      iconData = Icons.window;
      defaultColor = const Color(0xFF00A4EF);
    } else if (lowerPlatform.contains('darwin') ||
        lowerPlatform.contains('mac') ||
        lowerOs.contains('mac') ||
        lowerOs.contains('apple')) {
      iconData = Icons.apple;
      defaultColor = const Color(0xFFA2AAAD);
    } else if (lowerPlatform.contains('linux') || lowerOs.contains('linux') || lowerOs.contains('ubuntu')) {
      iconData = Icons.terminal_rounded;
      defaultColor = const Color(0xFFFCC624);
    } else {
      iconData = Icons.laptop_chromebook_rounded;
      defaultColor = AppColors.primary;
    }

    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        color: (color ?? defaultColor).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? defaultColor).withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: size,
          color: color ?? defaultColor,
        ),
      ),
    );
  }
}
