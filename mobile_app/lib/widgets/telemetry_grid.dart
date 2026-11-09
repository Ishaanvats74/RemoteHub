import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/telemetry/rolling_buffer.dart';
import '../../models/telemetry_model.dart';
import 'charts/line_chart_widget.dart';

class TelemetryGrid extends StatefulWidget {
  final TelemetryModel telemetry;
  final RollingTelemetryBuffer? buffer;

  const TelemetryGrid({
    super.key,
    required this.telemetry,
    this.buffer,
  });

  @override
  State<TelemetryGrid> createState() => _TelemetryGridState();
}

class _TelemetryGridState extends State<TelemetryGrid> {
  String _selectedMetric = 'cpu'; // 'cpu' | 'ram' | 'gpu' | 'disk'

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Real-Time Performance Chart ──────────────────────────
        _buildLiveChartCard(t),

        const SizedBox(height: 20),

        // ── Detailed Metric Cards ────────────────────────────────
        _buildHardwareCards(t),

        // ── Battery Card (if present) ────────────────────────────
        if (t.batteryPercent != null) ...[
          const SizedBox(height: 12),
          _buildBatteryCard(t),
        ],

        // ── Thermal Sensors / Fans (if present) ──────────────────
        if ((t.temperatures != null && t.temperatures!.isNotEmpty) ||
            (t.fans != null && t.fans!.isNotEmpty)) ...[
          const SizedBox(height: 12),
          _buildSensorsCard(t),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Real-Time Chart Card
  // ══════════════════════════════════════════════════════════════

  Widget _buildLiveChartCard(TelemetryModel t) {
    final accentColor = _getMetricColor(_selectedMetric);
    final metricName = _getMetricLabel(_selectedMetric);
    final spots = _getSpotsForMetric(_selectedMetric);

    // Compute min, max, avg
    double currentVal = _getCurrentMetricValue(_selectedMetric);
    double minVal = currentVal;
    double maxVal = currentVal;
    double sumVal = 0.0;

    if (spots.isNotEmpty) {
      minVal = spots.map((s) => s.y).reduce(math.min);
      maxVal = spots.map((s) => s.y).reduce(math.max);
      sumVal = spots.map((s) => s.y).reduce((a, b) => a + b);
    }
    final avgVal = spots.isNotEmpty ? sumVal / spots.length : currentVal;
    final maxX = math.max(10.0, (spots.length - 1).toDouble());

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector Tabs (CPU, RAM, GPU, Disk)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSelectorTab('cpu', 'CPU', Icons.memory_rounded, t.cpuPercent),
                const SizedBox(width: 8),
                _buildSelectorTab('ram', 'RAM', Icons.developer_board_rounded, t.memoryPercent),
                const SizedBox(width: 8),
                _buildSelectorTab('gpu', 'GPU', Icons.videogame_asset_rounded, t.gpuPercent),
                const SizedBox(width: 8),
                _buildSelectorTab('disk', 'Disk', Icons.storage_rounded, t.diskPercent),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Header with Current Value and Live Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.statusOnline,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusOnline.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$metricName Performance',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${currentVal.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Quick Summary Pills (AVG, MIN, MAX)
          Row(
            children: [
              _buildStatPill('AVG', '${avgVal.toStringAsFixed(1)}%', AppColors.textSecondary),
              const SizedBox(width: 6),
              _buildStatPill('MIN', '${minVal.toStringAsFixed(1)}%', AppColors.statusOnline),
              const SizedBox(width: 6),
              _buildStatPill(
                'MAX',
                '${maxVal.toStringAsFixed(1)}%',
                maxVal >= 85 ? AppColors.actionShutdown : AppColors.primary,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Chart Display
          SizedBox(
            height: 160,
            child: LineChartWidget(
              spots: spots,
              lineColor: accentColor,
              minY: 0.0,
              maxY: 100.0,
              maxX: maxX,
              unit: '%',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTab(String key, String label, IconData icon, double? currentPercent) {
    final isSelected = _selectedMetric == key;
    final color = _getMetricColor(key);

    return InkWell(
      onTap: () => setState(() => _selectedMetric = key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppColors.surfaceHover.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.6) : AppColors.surfaceBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (currentPercent != null) ...[
              const SizedBox(width: 6),
              Text(
                '${currentPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Detailed Hardware Cards Grid
  // ══════════════════════════════════════════════════════════════

  Widget _buildHardwareCards(TelemetryModel t) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: [
        // CPU Card
        _buildMetricDetailCard(
          keyName: 'cpu',
          title: 'CPU',
          icon: Icons.memory_rounded,
          percent: t.cpuPercent ?? 0.0,
          color: const Color(0xFF38BDF8), // Cyan
          subtitle: t.cpuTemp != null ? '${t.cpuTemp!.toStringAsFixed(1)}°C' : 'Load',
          badgeText: t.cpuTemp != null ? '${t.cpuTemp!.toStringAsFixed(0)}°C' : null,
          badgeColor: _getTempColor(t.cpuTemp),
        ),

        // RAM Card
        _buildMetricDetailCard(
          keyName: 'ram',
          title: 'Memory (RAM)',
          icon: Icons.developer_board_rounded,
          percent: t.memoryPercent ?? 0.0,
          color: const Color(0xFFA855F7), // Purple
          subtitle: (t.memoryUsedGb != null && t.memoryTotalGb != null)
              ? '${t.memoryUsedGb!.toStringAsFixed(1)} / ${t.memoryTotalGb!.toStringAsFixed(1)} GB'
              : 'RAM Load',
          extraInfo: (t.memoryTotalGb != null && t.memoryUsedGb != null)
              ? '${(t.memoryTotalGb! - t.memoryUsedGb!).toStringAsFixed(1)} GB free'
              : null,
        ),

        // GPU Card
        _buildMetricDetailCard(
          keyName: 'gpu',
          title: 'GPU',
          icon: Icons.videogame_asset_rounded,
          percent: t.gpuPercent ?? 0.0,
          color: const Color(0xFF10B981), // Emerald
          subtitle: t.gpuName != null
              ? (t.gpuName!.length > 18 ? '${t.gpuName!.substring(0, 18)}...' : t.gpuName!)
              : 'Graphics Card',
          badgeText: t.gpuTemp != null ? '${t.gpuTemp!.toStringAsFixed(0)}°C' : null,
          badgeColor: _getTempColor(t.gpuTemp),
          extraInfo: (t.gpuMemoryTotalMb != null && t.gpuMemoryTotalMb! > 0)
              ? '${t.gpuMemoryUsedMb?.toStringAsFixed(0) ?? '0'} / ${t.gpuMemoryTotalMb!.toStringAsFixed(0)} MB VRAM'
              : null,
        ),

        // Disk Storage Card
        _buildMetricDetailCard(
          keyName: 'disk',
          title: 'Storage',
          icon: Icons.storage_rounded,
          percent: t.diskPercent ?? 0.0,
          color: const Color(0xFFF59E0B), // Amber
          subtitle: (t.diskUsedGb != null && t.diskTotalGb != null)
              ? '${t.diskUsedGb!.toStringAsFixed(1)} / ${t.diskTotalGb!.toStringAsFixed(1)} GB'
              : 'Disk Usage',
          badgeText: (t.diskPercent != null && t.diskPercent! >= 85) ? 'High' : null,
          badgeColor: AppColors.actionShutdown,
          extraInfo: (t.diskTotalGb != null && t.diskUsedGb != null)
              ? '${(t.diskTotalGb! - t.diskUsedGb!).toStringAsFixed(1)} GB free'
              : null,
        ),
      ],
    );
  }

  Widget _buildMetricDetailCard({
    required String keyName,
    required String title,
    required IconData icon,
    required double percent,
    required Color color,
    required String subtitle,
    String? badgeText,
    Color? badgeColor,
    String? extraInfo,
  }) {
    final isSelected = _selectedMetric == keyName;
    final clampedPercent = percent.clamp(0.0, 100.0);

    return InkWell(
      onTap: () => setState(() => _selectedMetric = keyName),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.surfaceBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Title, Badge, Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? color).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: (badgeColor ?? color).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor ?? color,
                      ),
                    ),
                  ),
              ],
            ),

            // Big Numeric Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  percent.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),

            // Subtitle & Extra info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (extraInfo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    extraInfo,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clampedPercent / 100.0,
                minHeight: 5,
                backgroundColor: AppColors.surfaceHover,
                valueColor: AlwaysStoppedAnimation<Color>(
                  clampedPercent >= 85 ? AppColors.actionShutdown : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Battery & Power Card
  // ══════════════════════════════════════════════════════════════

  Widget _buildBatteryCard(TelemetryModel t) {
    final isPlugged = t.batteryPluggedIn ?? false;
    final percent = t.batteryPercent ?? 0.0;
    final status = t.batteryStatus ?? (isPlugged ? 'Charging' : 'On Battery');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.statusOnline.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPlugged ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
              color: percent < 20 ? AppColors.actionShutdown : AppColors.statusOnline,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Battery & Power',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPlugged
                            ? AppColors.statusOnline.withValues(alpha: 0.15)
                            : AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPlugged ? AppColors.statusOnline : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPlugged
                      ? 'Connected to AC power'
                      : (t.batteryTimeRemaining != null
                          ? '${t.batteryTimeRemaining} remaining'
                          : 'Operating on battery power'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Sensors & Fan Readouts
  // ══════════════════════════════════════════════════════════════

  Widget _buildSensorsCard(TelemetryModel t) {
    final tempEntries = <Widget>[];

    if (t.temperatures != null) {
      t.temperatures!.forEach((sensor, list) {
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              final label = item['label']?.toString() ?? sensor;
              final temp = item['temperature'];
              if (temp != null) {
                tempEntries.add(
                  _buildSensorPill(label, '$temp°C', Icons.thermostat_rounded, AppColors.statusOnline),
                );
              }
            }
          }
        }
      });
    }

    if (t.fans != null) {
      t.fans!.forEach((fan, list) {
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              final label = item['label']?.toString() ?? fan;
              final rpm = item['rpm'];
              if (rpm != null) {
                tempEntries.add(
                  _buildSensorPill(label, '$rpm RPM', Icons.mode_fan_off_rounded, AppColors.primary),
                );
              }
            }
          }
        }
      });
    }

    if (tempEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.device_thermostat_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Hardware Sensors & Cooling',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tempEntries,
          ),
        ],
      ),
    );
  }

  Widget _buildSensorPill(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════════

  List<FlSpot> _getSpotsForMetric(String metric) {
    final samples = widget.buffer?.samples ?? [];
    if (samples.isEmpty) {
      final cur = _getCurrentMetricValue(metric);
      return [FlSpot(0, cur), FlSpot(1, cur)];
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      double val = 0.0;
      switch (metric) {
        case 'cpu':
          val = s.cpuPercent ?? 0.0;
          break;
        case 'ram':
          val = s.ramPercent ?? 0.0;
          break;
        case 'gpu':
          val = s.gpuPercent ?? 0.0;
          break;
        case 'disk':
          val = s.diskPercent ?? 0.0;
          break;
      }
      spots.add(FlSpot(i.toDouble(), val.clamp(0.0, 100.0)));
    }

    if (spots.length == 1) {
      spots.insert(0, FlSpot(0, spots[0].y));
    }
    return spots;
  }

  double _getCurrentMetricValue(String metric) {
    final t = widget.telemetry;
    switch (metric) {
      case 'cpu':
        return t.cpuPercent ?? 0.0;
      case 'ram':
        return t.memoryPercent ?? 0.0;
      case 'gpu':
        return t.gpuPercent ?? 0.0;
      case 'disk':
        return t.diskPercent ?? 0.0;
      default:
        return 0.0;
    }
  }

  Color _getMetricColor(String metric) {
    switch (metric) {
      case 'cpu':
        return const Color(0xFF38BDF8); // Cyan
      case 'ram':
        return const Color(0xFFA855F7); // Purple
      case 'gpu':
        return const Color(0xFF10B981); // Emerald
      case 'disk':
        return const Color(0xFFF59E0B); // Amber
      default:
        return AppColors.primary;
    }
  }

  String _getMetricLabel(String metric) {
    switch (metric) {
      case 'cpu':
        return 'CPU';
      case 'ram':
        return 'Memory (RAM)';
      case 'gpu':
        return 'GPU';
      case 'disk':
        return 'Disk Storage';
      default:
        return metric.toUpperCase();
    }
  }

  Color _getTempColor(double? temp) {
    if (temp == null) return AppColors.statusOnline;
    if (temp >= 80) return AppColors.actionShutdown;
    if (temp >= 65) return AppColors.actionRestart;
    return AppColors.statusOnline;
  }
}
