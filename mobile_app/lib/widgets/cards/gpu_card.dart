import 'package:flutter/material.dart';
import '../../models/hardware_specs.dart';
import '../../models/live_stats.dart';
import '../charts/gauge_widget.dart';

class GpuCard extends StatelessWidget {
  final GpuLiveStats? stats;
  final List<GpuSpecs> gpus;

  static const Color accentColor = Color(0xFF7E22CE); // Purple
  static const Color accentLight = Color(0xFFA855F7);
  static const Color accentNeon = Color(0xFFC084FC);

  const GpuCard({
    super.key,
    this.stats,
    required this.gpus,
  });

  @override
  Widget build(BuildContext context) {
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
            // Header: Title and Icon
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
                        Icons.videogame_asset_rounded,
                        color: accentNeon,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'GPU',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (gpus.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentNeon.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      gpus.first.type,
                      style: const TextStyle(
                        color: accentNeon,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Body: GPU available or Fallback
            Expanded(
              child: gpus.isEmpty
                  ? _buildUnavailableFallback(
                      title: 'GPU monitoring unavailable',
                      subtitle: 'No compatible graphics hardware was detected.',
                    )
                  : _buildGpuContent(gpus.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpuContent(GpuSpecs gpu) {
    final gpuName = stats?.name ?? gpu.name;
    final hasUsage = stats?.usage != null;
    final hasTemp = stats?.temperature != null && stats!.temperature! > 0;
    final usageVal = stats?.usage ?? 0.0;
    final vramGb = gpu.memoryGb != null ? '${gpu.memoryGb!.toStringAsFixed(1)} GB' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GPU Name & VRAM Subtitle
        Text(
          gpuName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          vramGb != null ? 'Dedicated Video Memory: $vramGb' : 'Dedicated Graphics Adapter',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),

        // Stats Display or Idle State
        if (hasUsage || hasTemp)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasUsage)
                GaugeWidget(
                  value: usageVal,
                  primaryColor: accentNeon,
                  centerText: '${usageVal.toInt()}%',
                  label: 'LOAD',
                  size: 115,
                  strokeWidth: 14,
                ),
              if (hasUsage && hasTemp) const SizedBox(width: 28),
              if (hasTemp)
                GaugeWidget(
                  value: stats!.temperature!,
                  max: 100,
                  primaryColor: stats!.temperature! > 80
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFF59E0B),
                  centerText: '${stats!.temperature!.toInt()}°C',
                  label: 'TEMP',
                  size: 115,
                  strokeWidth: 14,
                ),
            ],
          )
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  size: 36,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 10),
                Text(
                  'Active Hardware Accelerated',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live sensor telemetry idle or running via driver',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
      ],
    );
  }

  Widget _buildUnavailableFallback({
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videogame_asset_off_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
