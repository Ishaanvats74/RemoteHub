/// Telemetry mapper – single source of truth for field-name mapping.
///
/// If the desktop agent ever changes a key name, update the constants here.
/// The app's UI/state layer reads from this mapper, not from raw JSON.
///
/// Tolerant parsing:
///   - Returns null for missing / null fields (show "N/A" in the UI).
library;

import '../../../models/telemetry_model.dart';

// ────────────────────────────────────────────────────────────
// Key aliases
// Expand these lists if the desktop agent uses different names.
// ────────────────────────────────────────────────────────────

class TelemetryKeys {
  TelemetryKeys._();

  // ── CPU ──
  static const List<String> cpuPercent   = ['cpu_percent', 'cpu_usage', 'cpu'];
  static const List<String> cpuTemp      = ['cpu_temp', 'cpu_temperature'];
  static const List<String> perCoreUsage = ['per_core_usage', 'cpu_per_core', 'core_usage'];

  // ── GPU ──
  static const List<String> gpuPercent   = ['gpu_percent', 'gpu_usage', 'gpu'];
  static const List<String> gpuTemp      = ['gpu_temp', 'gpu_temperature'];
  static const List<String> gpuMemUsed   = ['gpu_mem_used', 'gpu_memory_used', 'gpu_memory_used_mb'];
  static const List<String> gpuMemTotal  = ['gpu_mem_total', 'gpu_memory_total', 'gpu_memory_total_mb'];
  static const List<String> gpuName      = ['gpu_name', 'gpu'];

  // ── RAM ──
  static const List<String> ramPercent   = ['memory_percent', 'ram_percent', 'ram'];
  static const List<String> ramUsedGb    = ['memory_used_gb', 'ram_used_gb'];
  static const List<String> ramTotalGb   = ['memory_total_gb', 'ram_total_gb'];

  // ── Swap ──
  static const List<String> swapPercent  = ['swap_percent', 'swap'];
  static const List<String> swapUsedGb   = ['swap_used_gb'];
  static const List<String> swapTotalGb  = ['swap_total_gb'];

  // ── Disk ──
  static const List<String> diskPercent  = ['disk_percent', 'disk'];
  static const List<String> diskUsedGb   = ['disk_used_gb'];
  static const List<String> diskTotalGb  = ['disk_total_gb'];
  static const List<String> diskReadMbs  = ['disk_read_mbs', 'disk_read', 'disk_read_mb_s'];
  static const List<String> diskWriteMbs = ['disk_write_mbs', 'disk_write', 'disk_write_mb_s'];

  // ── Network ──
  static const List<String> netSentMbs   = ['net_sent_mbs', 'network_sent', 'net_sent_mb_s'];
  static const List<String> netRecvMbs   = ['net_recv_mbs', 'network_recv', 'net_recv_mb_s'];

  // ── Battery ──
  static const List<String> batteryPercent  = ['battery_percent', 'battery'];
  static const List<String> batteryPlugged  = ['battery_plugged', 'plugged_in'];
  static const List<String> batteryStatus   = ['battery_status'];
  static const List<String> batteryTimeLeft = ['battery_time_left', 'battery_time_remaining'];

  // ── Fan ──
  static const List<String> fanSpeed     = ['fan_speed', 'fans', 'fan_rpm'];

  // ── Processes ──
  static const List<String> topProcesses = ['top_processes', 'processes'];

  // ── Uptime ──
  static const List<String> uptime       = ['uptime'];
}

// ────────────────────────────────────────────────────────────
// Parsed structured telemetry
// ────────────────────────────────────────────────────────────

class MappedTelemetry {
  // CPU
  final double? cpuPercent;
  final double? cpuTemp;
  final List<double>? perCoreUsage;

  // GPU
  final double? gpuPercent;
  final double? gpuTemp;
  final double? gpuMemUsedMb;
  final double? gpuMemTotalMb;
  final String? gpuName;

  // RAM
  final double? ramPercent;
  final double? ramUsedGb;
  final double? ramTotalGb;

  // Swap
  final double? swapPercent;
  final double? swapUsedGb;
  final double? swapTotalGb;

  // Disk
  final double? diskPercent;
  final double? diskUsedGb;
  final double? diskTotalGb;
  final double? diskReadMbs;
  final double? diskWriteMbs;

  // Network
  final double? netSentMbs;
  final double? netRecvMbs;

  // Battery
  final double? batteryPercent;
  final bool? batteryPlugged;
  final String? batteryStatus;
  final String? batteryTimeLeft;

  // Fan
  final List<Map<String, dynamic>>? fans;

  // Processes
  final List<Map<String, dynamic>>? topProcesses;

  // Uptime
  final String? uptime;

  // Timestamp
  final DateTime timestamp;

  const MappedTelemetry({
    this.cpuPercent,
    this.cpuTemp,
    this.perCoreUsage,
    this.gpuPercent,
    this.gpuTemp,
    this.gpuMemUsedMb,
    this.gpuMemTotalMb,
    this.gpuName,
    this.ramPercent,
    this.ramUsedGb,
    this.ramTotalGb,
    this.swapPercent,
    this.swapUsedGb,
    this.swapTotalGb,
    this.diskPercent,
    this.diskUsedGb,
    this.diskTotalGb,
    this.diskReadMbs,
    this.diskWriteMbs,
    this.netSentMbs,
    this.netRecvMbs,
    this.batteryPercent,
    this.batteryPlugged,
    this.batteryStatus,
    this.batteryTimeLeft,
    this.fans,
    this.topProcesses,
    this.uptime,
    required this.timestamp,
  });
}

// ────────────────────────────────────────────────────────────
// Mapper
// ────────────────────────────────────────────────────────────

class TelemetryMapper {
  TelemetryMapper._();

  /// Convert a raw [TelemetryModel] (which carries raw JSON) into
  /// a fully-typed [MappedTelemetry].  Never throws.
  static MappedTelemetry map(TelemetryModel raw) {
    var d = raw.rawData;
    if (d.containsKey('data') && d['data'] is Map) {
      d = Map<String, dynamic>.from(d['data'] as Map);
    } else if (d.containsKey('telemetry') && d['telemetry'] is Map) {
      d = Map<String, dynamic>.from(d['telemetry'] as Map);
    }

    return MappedTelemetry(
      cpuPercent:    raw.cpuPercent ?? _d(d, TelemetryKeys.cpuPercent),
      cpuTemp:       raw.cpuTemp ?? _d(d, TelemetryKeys.cpuTemp),
      perCoreUsage:  _dList(d, TelemetryKeys.perCoreUsage),
      gpuPercent:    raw.gpuPercent ?? _d(d, TelemetryKeys.gpuPercent),
      gpuTemp:       raw.gpuTemp ?? _d(d, TelemetryKeys.gpuTemp),
      gpuMemUsedMb:  raw.gpuMemoryUsedMb ?? _d(d, TelemetryKeys.gpuMemUsed),
      gpuMemTotalMb: raw.gpuMemoryTotalMb ?? _d(d, TelemetryKeys.gpuMemTotal),
      gpuName:       raw.gpuName ?? _s(d, TelemetryKeys.gpuName),
      ramPercent:    raw.memoryPercent ?? _d(d, TelemetryKeys.ramPercent),
      ramUsedGb:     raw.memoryUsedGb ?? _d(d, TelemetryKeys.ramUsedGb),
      ramTotalGb:    raw.memoryTotalGb ?? _d(d, TelemetryKeys.ramTotalGb),
      swapPercent:   _d(d, TelemetryKeys.swapPercent),
      swapUsedGb:    _d(d, TelemetryKeys.swapUsedGb),
      swapTotalGb:   _d(d, TelemetryKeys.swapTotalGb),
      diskPercent:   raw.diskPercent ?? _d(d, TelemetryKeys.diskPercent),
      diskUsedGb:    raw.diskUsedGb ?? _d(d, TelemetryKeys.diskUsedGb),
      diskTotalGb:   raw.diskTotalGb ?? _d(d, TelemetryKeys.diskTotalGb),
      diskReadMbs:   _d(d, TelemetryKeys.diskReadMbs),
      diskWriteMbs:  _d(d, TelemetryKeys.diskWriteMbs),
      netSentMbs:    _d(d, TelemetryKeys.netSentMbs),
      netRecvMbs:    _d(d, TelemetryKeys.netRecvMbs),
      batteryPercent: raw.batteryPercent ?? _d(d, TelemetryKeys.batteryPercent),
      batteryPlugged: raw.batteryPluggedIn ?? _b(d, TelemetryKeys.batteryPlugged),
      batteryStatus:  raw.batteryStatus ?? _s(d, TelemetryKeys.batteryStatus),
      batteryTimeLeft: raw.batteryTimeRemaining ?? _s(d, TelemetryKeys.batteryTimeLeft),
      fans:           _mapList(d, TelemetryKeys.fanSpeed),
      topProcesses:   _mapList(d, TelemetryKeys.topProcesses),
      uptime:         raw.uptime ?? _s(d, TelemetryKeys.uptime),
      timestamp:      raw.timestamp,
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  static double? _d(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final parsed = double.tryParse(v.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _s(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  static bool? _b(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v == null) continue;
      if (v is bool) return v;
      final s = v.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return null;
  }

  static List<double>? _dList(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is List && v.isNotEmpty) {
        try {
          return v.map<double>((e) {
            if (e is num) return e.toDouble();
            return double.tryParse(e.toString()) ?? 0.0;
          }).toList();
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  static List<Map<String, dynamic>>? _mapList(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is List && v.isNotEmpty) {
        try {
          return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }
}
