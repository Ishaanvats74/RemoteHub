import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hardware_specs.dart';
import '../models/live_stats.dart';
import '../services/system_stats_service.dart';
import '../state/system_stats_provider.dart';
import '../widgets/cards/cpu_card.dart';
import '../widgets/cards/gpu_card.dart';
import '../widgets/cards/ram_card.dart';
import '../widgets/cards/storage_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D111A), // Deep Windows Dark Slate
      body: Consumer<SystemStatsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentStats == null) {
            return _buildLoadingState(context, provider);
          }

          final stats = provider.currentStats;
          final specs = provider.hardwareSpecs;

          return SafeArea(
            child: Column(
              children: [
                // Top Application Header
                _buildHeader(context, provider),

                // Main 4-Card Responsive Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 960;
                        final isMedium = constraints.maxWidth >= 600;

                        if (isWide) {
                          // Desktop 2x2 Grid with balanced aspect ratio
                          final cardWidth = (constraints.maxWidth - 16) / 2;
                          final cardHeight = (constraints.maxHeight - 16) / 2;
                          final aspectRatio = (cardWidth / cardHeight).clamp(1.1, 1.8);

                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: aspectRatio,
                            physics: const BouncingScrollPhysics(),
                            children: _buildCards(provider, stats, specs),
                          );
                        } else if (isMedium) {
                          // Medium Tablet / Half-Screen 2-column scrollable
                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.15,
                            children: _buildCards(provider, stats, specs),
                          );
                        } else {
                          // Narrow window 1-column scrollable
                          return ListView(
                            children: _buildCards(provider, stats, specs)
                                .map((card) => SizedBox(height: 340, child: Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: card,
                                    )))
                                .toList(),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCards(
    SystemStatsProvider provider,
    dynamic stats,
    dynamic specs,
  ) {
    final liveStats = stats as LiveStats? ?? LiveStats.empty();
    final hwSpecs = specs as HardwareSpecs? ?? HardwareSpecs.empty();

    return [
      CpuCard(
        stats: liveStats.cpu,
        specs: hwSpecs.cpu,
        history: provider.cpuHistory,
      ),
      RamCard(
        stats: liveStats.memory,
        specs: hwSpecs.ram,
        history: provider.ramHistory,
      ),
      StorageCard(
        stats: liveStats.disk,
      ),
      GpuCard(
        stats: liveStats.gpu,
        gpus: hwSpecs.gpus,
      ),
    ];
  }

  Widget _buildHeader(BuildContext context, SystemStatsProvider provider) {
    final specs = provider.hardwareSpecs;
    final status = provider.connectionStatus;
    final battery = provider.currentStats?.battery;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                specs != null && specs.os.isNotEmpty
                    ? '${specs.os} ${specs.osVersion}  •  Task Manager Telemetry'
                    : 'System Resource Monitor',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Battery Status (if available on laptop)
          if (battery != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    battery.pluggedIn
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_std_rounded,
                    color: battery.percent > 20 ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${battery.percent.toInt()}% ${battery.status}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Connection status pill
          _buildConnectionBadge(status, provider),
          const SizedBox(width: 10),

          // Reconnect / Refresh button
          IconButton(
            tooltip: 'Reconnect / Refresh Specs',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF161B26),
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            onPressed: () {
              provider.refreshHardwareSpecs();
              provider.reconnect();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(
    ConnectionStatus status,
    SystemStatsProvider provider,
  ) {
    Color dotColor;
    String label;
    Color bg;

    switch (status) {
      case ConnectionStatus.connected:
        dotColor = const Color(0xFF10B981);
        label = 'Connected';
        bg = const Color(0xFF064E3B).withValues(alpha: 0.4);
        break;
      case ConnectionStatus.connecting:
        dotColor = const Color(0xFFF59E0B);
        label = 'Connecting...';
        bg = const Color(0xFF78350F).withValues(alpha: 0.4);
        break;
      case ConnectionStatus.disconnected:
        dotColor = const Color(0xFFEF4444);
        label = 'Reconnecting';
        bg = const Color(0xFF7F1D1D).withValues(alpha: 0.4);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: dotColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, SystemStatsProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Initializing System Telemetry...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching hardware specs and connecting to ws://127.0.0.1:8000/ws/stats',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Force Retry'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF60A5FA),
            ),
            onPressed: () {
              provider.refreshHardwareSpecs();
              provider.reconnect();
            },
          ),
        ],
      ),
    );
  }
}
