import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/device_model.dart';
import 'common/platform_icon.dart';
import 'common/status_dot.dart';

class DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastSeenText = device.isOnline
        ? 'Active now'
        : 'Seen ${DateFormatter.formatRelativeTime(device.lastSeen)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: device.isOnline
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.surfaceHover,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                PlatformIcon(
                  platform: device.platform,
                  os: device.os,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.hostname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (device.os.isNotEmpty) ...[
                            Text(
                              device.os,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              lastSeenText,
                              style: TextStyle(
                                fontSize: 13,
                                color: device.isOnline
                                    ? AppColors.statusOnline
                                    : AppColors.textMuted,
                                fontWeight: device.isOnline
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusDot(
                  isOnline: device.isOnline,
                  size: 10,
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
