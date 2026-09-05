import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/telemetry_model.dart';

class TelemetryGrid extends StatelessWidget {
  final TelemetryModel telemetry;

  const TelemetryGrid({
    super.key,
    required this.telemetry,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    if (telemetry.cpuPercent != null) {
      tiles.add(_buildMetricTile(
        title: 'CPU Usage',
        value: '${telemetry.cpuPercent!.toStringAsFixed(1)}%',
        percentage: telemetry.cpuPercent! / 100.0,
        icon: Icons.memory_rounded,
        color: _getUsageColor(telemetry.cpuPercent!),
      ));
    }

    if (telemetry.memoryPercent != null) {
      tiles.add(_buildMetricTile(
        title: 'RAM Usage',
        value: '${telemetry.memoryPercent!.toStringAsFixed(1)}%',
        percentage: telemetry.memoryPercent! / 100.0,
        icon: Icons.developer_board_rounded,
        color: _getUsageColor(telemetry.memoryPercent!),
      ));
    }

    if (telemetry.diskPercent != null) {
      tiles.add(_buildMetricTile(
        title: 'Disk Storage',
        value: '${telemetry.diskPercent!.toStringAsFixed(1)}%',
        percentage: telemetry.diskPercent! / 100.0,
        icon: Icons.storage_rounded,
        color: _getUsageColor(telemetry.diskPercent!),
      ));
    }

    if (telemetry.batteryPercent != null) {
      tiles.add(_buildMetricTile(
        title: 'Battery Level',
        value: '${telemetry.batteryPercent!.toStringAsFixed(0)}%',
        percentage: telemetry.batteryPercent! / 100.0,
        icon: Icons.battery_charging_full_rounded,
        color: telemetry.batteryPercent! < 20
            ? AppColors.actionShutdown
            : AppColors.statusOnline,
      ));
    }

    if (telemetry.uptime != null && telemetry.uptime!.isNotEmpty) {
      tiles.add(_buildGenericTile(
        title: 'System Uptime',
        value: telemetry.uptime!,
        icon: Icons.timer_outlined,
      ));
    }

    // Generic key-value pairs for other properties in rawData
    telemetry.rawData.forEach((key, val) {
      final lowerKey = key.toLowerCase();
      if (lowerKey != 'cpu_percent' &&
          lowerKey != 'cpu' &&
          lowerKey != 'cpu_usage' &&
          lowerKey != 'memory_percent' &&
          lowerKey != 'ram_percent' &&
          lowerKey != 'ram' &&
          lowerKey != 'memory' &&
          lowerKey != 'disk_percent' &&
          lowerKey != 'disk' &&
          lowerKey != 'battery_percent' &&
          lowerKey != 'battery' &&
          lowerKey != 'uptime' &&
          lowerKey != 'timestamp' &&
          lowerKey != 'type' &&
          lowerKey != 'device_id') {
        tiles.add(_buildGenericTile(
          title: _formatKey(key),
          value: val.toString(),
          icon: Icons.insights_rounded,
        ));
      }
    });

    if (tiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: const Center(
          child: Text(
            'No live telemetry reported yet by this device.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: tiles,
    );
  }

  Color _getUsageColor(double percent) {
    if (percent >= 90) return AppColors.actionShutdown;
    if (percent >= 75) return AppColors.actionRestart;
    return AppColors.primary;
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str.isNotEmpty
            ? '${str[0].toUpperCase()}${str.substring(1)}'
            : '')
        .join(' ');
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required double percentage,
    required IconData icon,
    required Color color,
  }) {
    final clampedProgress = percentage.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              fontFamily: 'monospace',
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: AppColors.primary),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}
