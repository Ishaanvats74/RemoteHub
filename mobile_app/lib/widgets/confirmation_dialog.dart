import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ws_message.dart';
import 'common/app_button.dart';

class ConfirmationDialog extends StatelessWidget {
  final String hostname;
  final WsCommandType command;
  final VoidCallback onConfirm;

  const ConfirmationDialog({
    super.key,
    required this.hostname,
    required this.command,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String hostname,
    required WsCommandType command,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConfirmationDialog(
        hostname: hostname,
        command: command,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color actionColor;
    IconData actionIcon;
    String warningMessage;
    bool isDestructive = false;

    switch (command) {
      case WsCommandType.shutdown:
        actionColor = AppColors.actionShutdown;
        actionIcon = Icons.power_settings_new_rounded;
        warningMessage =
            'Shutting down will terminate all running applications on "$hostname". Any unsaved work will be lost immediately.';
        isDestructive = true;
        break;
      case WsCommandType.restart:
        actionColor = AppColors.actionRestart;
        actionIcon = Icons.restart_alt_rounded;
        warningMessage =
            'Restarting will reboot "$hostname" immediately. Ensure no critical background transfers or unsaved files are open.';
        isDestructive = true;
        break;
      case WsCommandType.sleep:
        actionColor = AppColors.actionSleep;
        actionIcon = Icons.bedtime_outlined;
        warningMessage =
            'Put "$hostname" into low-power sleep mode. You can wake it using physical interaction or wake-on-LAN.';
        break;
      case WsCommandType.lock:
        actionColor = AppColors.actionLock;
        actionIcon = Icons.lock_outline_rounded;
        warningMessage =
            'Lock the current user session on "$hostname". The user must enter their password to regain access.';
        break;
    }

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: actionColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(actionIcon, color: actionColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${command.displayName} Machine',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hostname,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.actionShutdownBg
                    : AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDestructive
                      ? AppColors.actionShutdown.withValues(alpha: 0.3)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isDestructive
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded,
                    color: isDestructive
                        ? AppColors.actionShutdown
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      warningMessage,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDestructive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Cancel',
                    variant: AppButtonVariant.outlined,
                    height: 46,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: 'Confirm ${command.displayName}',
                    variant: isDestructive
                        ? AppButtonVariant.destructive
                        : AppButtonVariant.primary,
                    height: 46,
                    onPressed: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
