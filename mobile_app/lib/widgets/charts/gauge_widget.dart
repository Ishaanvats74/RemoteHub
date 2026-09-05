import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GaugeWidget extends StatelessWidget {
  final double value; // 0 to 100
  final double max;
  final Color primaryColor;
  final Color? backgroundColor;
  final String? centerText;
  final String? label;
  final double size;
  final double strokeWidth;

  const GaugeWidget({
    super.key,
    required this.value,
    this.max = 100.0,
    required this.primaryColor,
    this.backgroundColor,
    this.centerText,
    this.label,
    this.size = 120.0,
    this.strokeWidth = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, max);
    final remaining = (max - clampedValue).clamp(0.0, max);
    final bg = backgroundColor ?? Colors.white.withValues(alpha: 0.08);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: 270,
              sectionsSpace: 0,
              centerSpaceRadius: (size / 2) - strokeWidth,
              sections: [
                PieChartSectionData(
                  color: primaryColor,
                  value: clampedValue > 0 ? clampedValue : 0.001,
                  showTitle: false,
                  radius: strokeWidth,
                ),
                PieChartSectionData(
                  color: bg,
                  value: remaining > 0 ? remaining : 0.001,
                  showTitle: false,
                  radius: strokeWidth,
                ),
              ],
            ),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerText ?? '${clampedValue.toInt()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: size * 0.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
