import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/websocket_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/device_model.dart';
import '../../models/ws_message.dart';
import '../../state/device_detail_state.dart';
import '../../state/websocket_state.dart';
import '../../widgets/common/platform_icon.dart';
import '../../widgets/common/status_dot.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/telemetry_grid.dart';

class DeviceDetailScreen extends ConsumerWidget {
  final DeviceModel device;

  const DeviceDetailScreen({
    super.key,
    required this.device,
  });

  Future<void> _handleCommand(
    BuildContext context,
    WidgetRef ref,
    DeviceModel currentDevice,
    WsCommandType command,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      hostname: currentDevice.hostname,
      command: command,
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Text('Sending ${command.displayName} signal to ${currentDevice.hostname}...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      await ref.read(deviceDetailProvider(device).notifier).sendCommand(command);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(deviceDetailProvider(device));
    final currentDevice = detailState.device ?? device;

    // Listen for WebSocket command results and display snackbar toast
    ref.listen<DeviceDetailState>(deviceDetailProvider(device), (previous, next) {
      if (next.lastCommandResult != null &&
          next.lastCommandResult != previous?.lastCommandResult) {
        final result = next.lastCommandResult!;
        final isSuccess = result.success;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isSuccess ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSuccess ? AppColors.statusOnline : AppColors.actionShutdown,
                width: 1,
              ),
            ),
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: isSuccess ? AppColors.statusOnline : AppColors.actionShutdown,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSuccess
                            ? '${result.command.toUpperCase()} Executed'
                            : '${result.command.toUpperCase()} Failed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (result.message != null && result.message!.isNotEmpty)
                        Text(
                          result.message!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        ref.read(deviceDetailProvider(device).notifier).clearLastCommandResult();
      }
    });

    final wsStatusAsync = ref.watch(wsStatusStreamProvider);
    final wsStatus = wsStatusAsync.value ?? ref.watch(webSocketManagerProvider).status;
    final isWsConnected = wsStatus == WsConnectionStatus.connected;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          currentDevice.hostname,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StatusDot(
                isOnline: currentDevice.isOnline,
                showLabel: true,
                size: 9,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await ref.read(deviceDetailProvider(device).notifier).loadDeviceData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device Summary Card
                _buildDeviceSummaryCard(currentDevice),
                const SizedBox(height: 24),

                // Live status connection bar
                if (!isWsConnected) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.actionRestartBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.statusConnecting.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.wifi_off_rounded, color: AppColors.statusConnecting, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Realtime WebSocket is reconnecting. Commands will be queued.',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Remote Power Controls Section
                const Text(
                  'Power Controls',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap an action to send real-time control signals to this machine.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Power Actions Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.25,
                  children: [
                    _buildPowerActionCard(
                      title: 'Shutdown',
                      subtitle: 'Power off machine',
                      icon: Icons.power_settings_new_rounded,
                      color: AppColors.actionShutdown,
                      bgColor: AppColors.actionShutdownBg,
                      isLoading: detailState.isSendingCommand,
                      onTap: () => _handleCommand(
                        context,
                        ref,
                        currentDevice,
                        WsCommandType.shutdown,
                      ),
                    ),
                    _buildPowerActionCard(
                      title: 'Restart',
                      subtitle: 'Reboot system',
                      icon: Icons.restart_alt_rounded,
                      color: AppColors.actionRestart,
                      bgColor: AppColors.actionRestartBg,
                      isLoading: detailState.isSendingCommand,
                      onTap: () => _handleCommand(
                        context,
                        ref,
                        currentDevice,
                        WsCommandType.restart,
                      ),
                    ),
                    _buildPowerActionCard(
                      title: 'Sleep',
                      subtitle: 'Low-power state',
                      icon: Icons.bedtime_outlined,
                      color: AppColors.actionSleep,
                      bgColor: AppColors.actionSleepBg,
                      isLoading: detailState.isSendingCommand,
                      onTap: () => _handleCommand(
                        context,
                        ref,
                        currentDevice,
                        WsCommandType.sleep,
                      ),
                    ),
                    _buildPowerActionCard(
                      title: 'Lock',
                      subtitle: 'Lock user session',
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.actionLock,
                      bgColor: AppColors.actionLockBg,
                      isLoading: detailState.isSendingCommand,
                      onTap: () => _handleCommand(
                        context,
                        ref,
                        currentDevice,
                        WsCommandType.lock,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Live Telemetry Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Telemetry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (detailState.telemetry != null)
                      Text(
                        'Updated ${DateFormatter.formatRelativeTime(detailState.telemetry!.timestamp)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (detailState.telemetry != null)
                  TelemetryGrid(telemetry: detailState.telemetry!)
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.query_stats_rounded,
                          size: 36,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Waiting for live telemetry stream...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSummaryCard(DeviceModel currentDevice) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: currentDevice.isOnline
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.surfaceBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          PlatformIcon(
            platform: currentDevice.platform,
            os: currentDevice.os,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentDevice.hostname,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentDevice.os.isNotEmpty
                      ? currentDevice.os
                      : 'Platform: ${currentDevice.platform}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentDevice.isOnline
                      ? 'Live WebSocket Connection Active'
                      : 'Last seen ${DateFormatter.formatRelativeTime(currentDevice.lastSeen)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: currentDevice.isOnline
                        ? AppColors.statusOnline
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Icon(icon, color: color, size: 22),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
