import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/hardware_specs.dart';
import '../../models/live_stats.dart';
import '../charts/line_chart_widget.dart';

class RamCard extends StatelessWidget {
  final MemoryLiveStats stats;
  final RamSpecs specs;
  final List<FlSpot> history;

  static const Color accentColor = Color(0xFF059669); // Green
  static const Color accentLight = Color(0xFF34D399);

  const RamCard({
    super.key,
    required this.stats,
    required this.specs,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final usedGbStr = stats.usedGb.toStringAsFixed(1);
    final totalGbStr = (stats.totalGb > 0 ? stats.totalGb : specs.totalGb).toStringAsFixed(1);
    final availableGbStr = (stats.totalGb - stats.usedGb).clamp(0.0, stats.totalGb).toStringAsFixed(1);

    final List<String> specTags = [];
    if (specs.type.isNotEmpty && specs.type.toLowerCase() != 'unknown') {
      specTags.add(specs.type);
    }
    if (specs.speed.isNotEmpty && specs.speed.toLowerCase() != 'unknown') {
      specTags.add(specs.speed);
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
            // Header: Title, Icon, and Type/Speed tags
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
                        Icons.storage_rounded,
                        color: accentLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Memory',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (specTags.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentLight.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      specTags.join(' • '),
                      style: const TextStyle(
                        color: accentLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Metrics row: Large % number + Available GB tag
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$availableGbStr GB',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Subtitle: "X GB / Y GB used"
            Text(
              '$usedGbStr GB / $totalGbStr GB used',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w500,
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
