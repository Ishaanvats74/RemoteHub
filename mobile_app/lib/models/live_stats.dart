class LiveStats {
  final CpuLiveStats cpu;
  final MemoryLiveStats memory;
  final DiskLiveStats disk;
  final GpuLiveStats? gpu;
  final BatteryLiveStats? battery;
  final Map<String, List<SensorTemp>> temperatures;
  final Map<String, List<FanSpeed>> fans;

  const LiveStats({
    required this.cpu,
    required this.memory,
    required this.disk,
    this.gpu,
    this.battery,
    this.temperatures = const {},
    this.fans = const {},
  });

  factory LiveStats.fromJson(Map<String, dynamic> json) {
    // Temperatures map
    final Map<String, List<SensorTemp>> tempsMap = {};
    if (json['temperatures'] is Map<String, dynamic>) {
      final rawTemps = json['temperatures'] as Map<String, dynamic>;
      rawTemps.forEach((key, val) {
        if (val is List) {
          tempsMap[key] = val
              .whereType<Map<String, dynamic>>()
              .map((e) => SensorTemp.fromJson(e))
              .toList();
        }
      });
    }

    // Fans map
    final Map<String, List<FanSpeed>> fansMap = {};
    if (json['fans'] is Map<String, dynamic>) {
      final rawFans = json['fans'] as Map<String, dynamic>;
      rawFans.forEach((key, val) {
        if (val is List) {
          fansMap[key] = val
              .whereType<Map<String, dynamic>>()
              .map((e) => FanSpeed.fromJson(e))
              .toList();
        }
      });
    }

    return LiveStats(
      cpu: json['cpu'] is Map<String, dynamic>
          ? CpuLiveStats.fromJson(json['cpu'] as Map<String, dynamic>)
          : CpuLiveStats.empty(),
      memory: json['memory'] is Map<String, dynamic>
          ? MemoryLiveStats.fromJson(json['memory'] as Map<String, dynamic>)
          : MemoryLiveStats.empty(),
      disk: json['disk'] is Map<String, dynamic>
          ? DiskLiveStats.fromJson(json['disk'] as Map<String, dynamic>)
          : DiskLiveStats.empty(),
      gpu: json['gpu'] is Map<String, dynamic>
          ? GpuLiveStats.fromJson(json['gpu'] as Map<String, dynamic>)
          : null,
      battery: json['battery'] is Map<String, dynamic>
          ? BatteryLiveStats.fromJson(json['battery'] as Map<String, dynamic>)
          : null,
      temperatures: tempsMap,
      fans: fansMap,
    );
  }

  factory LiveStats.empty() {
    return LiveStats(
      cpu: CpuLiveStats.empty(),
      memory: MemoryLiveStats.empty(),
      disk: DiskLiveStats.empty(),
    );
  }
}

class CpuLiveStats {
  final double usage;
  final double? temperature;

  const CpuLiveStats({
    required this.usage,
    this.temperature,
  });

  factory CpuLiveStats.fromJson(Map<String, dynamic> json) {
    double usageVal = 0.0;
    if (json['usage'] is num) {
      usageVal = (json['usage'] as num).toDouble();
    } else if (json['usage'] != null) {
      usageVal = double.tryParse(json['usage'].toString()) ?? 0.0;
    }

    double? tempVal;
    if (json['temperature'] is num) {
      tempVal = (json['temperature'] as num).toDouble();
    } else if (json['temperature'] != null) {
      tempVal = double.tryParse(json['temperature'].toString());
    }

    return CpuLiveStats(
      usage: usageVal.clamp(0.0, 100.0),
      temperature: tempVal,
    );
  }

  factory CpuLiveStats.empty() => const CpuLiveStats(usage: 0.0);
}

class MemoryLiveStats {
  final double usage;
  final double usedGb;
  final double totalGb;

  const MemoryLiveStats({
    required this.usage,
    required this.usedGb,
    required this.totalGb,
  });

  factory MemoryLiveStats.fromJson(Map<String, dynamic> json) {
    double usageVal = _parseDouble(json['usage']);
    double used = _parseDouble(json['used_gb']);
    double total = _parseDouble(json['total_gb']);

    return MemoryLiveStats(
      usage: usageVal.clamp(0.0, 100.0),
      usedGb: used,
      totalGb: total,
    );
  }

  factory MemoryLiveStats.empty() => const MemoryLiveStats(usage: 0.0, usedGb: 0.0, totalGb: 0.0);
}

class DiskLiveStats {
  final double usage;
  final double usedGb;
  final double totalGb;

  const DiskLiveStats({
    required this.usage,
    required this.usedGb,
    required this.totalGb,
  });

  double get freeGb => (totalGb - usedGb).clamp(0.0, totalGb);

  factory DiskLiveStats.fromJson(Map<String, dynamic> json) {
    double usageVal = _parseDouble(json['usage']);
    double used = _parseDouble(json['used_gb']);
    double total = _parseDouble(json['total_gb']);

    return DiskLiveStats(
      usage: usageVal.clamp(0.0, 100.0),
      usedGb: used,
      totalGb: total,
    );
  }

  factory DiskLiveStats.empty() => const DiskLiveStats(usage: 0.0, usedGb: 0.0, totalGb: 0.0);
}

class GpuLiveStats {
  final String? name;
  final double? usage;
  final double? temperature;
  final double? memoryUsedMb;
  final double? memoryTotalMb;

  const GpuLiveStats({
    this.name,
    this.usage,
    this.temperature,
    this.memoryUsedMb,
    this.memoryTotalMb,
  });

  factory GpuLiveStats.fromJson(Map<String, dynamic> json) {
    double? usageVal;
    if (json['usage'] is num) {
      usageVal = (json['usage'] as num).toDouble();
    } else if (json['usage'] != null) {
      usageVal = double.tryParse(json['usage'].toString());
    }

    double? tempVal;
    if (json['temperature'] is num) {
      tempVal = (json['temperature'] as num).toDouble();
    } else if (json['temperature'] != null) {
      tempVal = double.tryParse(json['temperature'].toString());
    }

    double? memUsed;
    if (json['memory_used_mb'] is num) {
      memUsed = (json['memory_used_mb'] as num).toDouble();
    } else if (json['memory_used_mb'] != null) {
      memUsed = double.tryParse(json['memory_used_mb'].toString());
    }

    double? memTotal;
    if (json['memory_total_mb'] is num) {
      memTotal = (json['memory_total_mb'] as num).toDouble();
    } else if (json['memory_total_mb'] != null) {
      memTotal = double.tryParse(json['memory_total_mb'].toString());
    }

    return GpuLiveStats(
      name: json['name']?.toString(),
      usage: usageVal?.clamp(0.0, 100.0),
      temperature: tempVal,
      memoryUsedMb: memUsed,
      memoryTotalMb: memTotal,
    );
  }
}

class BatteryLiveStats {
  final double percent;
  final bool pluggedIn;
  final String status;
  final String timeRemaining;

  const BatteryLiveStats({
    required this.percent,
    required this.pluggedIn,
    required this.status,
    required this.timeRemaining,
  });

  factory BatteryLiveStats.fromJson(Map<String, dynamic> json) {
    return BatteryLiveStats(
      percent: _parseDouble(json['percent']).clamp(0.0, 100.0),
      pluggedIn: json['plugged_in'] == true,
      status: json['status']?.toString() ?? '',
      timeRemaining: json['time_remaining']?.toString() ?? '',
    );
  }
}

class SensorTemp {
  final String label;
  final double temperature;

  const SensorTemp({required this.label, required this.temperature});

  factory SensorTemp.fromJson(Map<String, dynamic> json) {
    return SensorTemp(
      label: json['label']?.toString() ?? 'Sensor',
      temperature: _parseDouble(json['temperature']),
    );
  }
}

class FanSpeed {
  final String label;
  final int rpm;

  const FanSpeed({required this.label, required this.rpm});

  factory FanSpeed.fromJson(Map<String, dynamic> json) {
    int rpmVal = 0;
    if (json['rpm'] is num) {
      rpmVal = (json['rpm'] as num).toInt();
    } else if (json['rpm'] != null) {
      rpmVal = int.tryParse(json['rpm'].toString()) ?? 0;
    }
    return FanSpeed(
      label: json['label']?.toString() ?? 'Fan',
      rpm: rpmVal,
    );
  }
}

double _parseDouble(dynamic val) {
  if (val is num) return val.toDouble();
  if (val != null) return double.tryParse(val.toString()) ?? 0.0;
  return 0.0;
}
