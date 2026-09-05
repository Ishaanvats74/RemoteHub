import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/hardware_specs.dart';
import '../../models/live_stats.dart';
import '../charts/line_chart_widget.dart';
import '../charts/gauge_widget.dart';

class CpuCard extends StatelessWidget {
  final CpuLiveStats stats;
  final CpuSpecs specs;
  final List<FlSpot> history;

  static const Color accentColor = Color(0xFF2563EB); // Vibrant Blue
  static const Color accentLight = Color(0xFF60A5FA);

  const CpuCard({
    super.key,
    required this.stats,
    required this.specs,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final hasTemp = stats.temperature != null && stats.temperature! > 0;

    String subtitle = specs.brand;
    final List<String> details = [];
    if (specs.cores != null && specs.threads != null) {
      details.add('${specs.cores} Cores / ${specs.threads} Threads');
    } else if (specs.cores != null) {
      details.add('${specs.cores} Cores');
    }
    if (specs.frequencyGhz != null && specs.frequencyGhz! > 0) {
      details.add('${specs.frequencyGhz!.toStringAsFixed(1)} GHz');
    }
    if (details.isNotEmpty) {
      subtitle += '  •  ${details.join('  •  ')}';
    }

    return Card(
      elevation: 0,
      color: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title, Icon, and Accent Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.memory_rounded,
                        color: accentLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CPU',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentLight.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Utilization',
                    style: TextStyle(
                      color: accentLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics row: Large % number + optional Temperature gauge
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${stats.usage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const Spacer(),
                // Temperature Gauge (Cleanly hidden if null)
                if (hasTemp) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GaugeWidget(
                        value: stats.temperature!,
                        max: 105,
                        primaryColor: stats.temperature! > 80
                            ? const Color(0xFFEF4444)
                            : (stats.temperature! > 65
                                ? const Color(0xFFF59E0B)
                                : accentLight),
                        centerText: '${stats.temperature!.toInt()}°',
                        label: 'TEMP',
                        size: 52,
                        strokeWidth: 6,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Package Temp',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${stats.temperature!.toStringAsFixed(1)} °C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Subtitle: Brand, Cores, Threads
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 18),

            // 60-second Scrolling Line Chart
            Expanded(
              child: LineChartWidget(
                spots: history,
                lineColor: accentLight,
                maxY: 100,
                unit: '%',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
