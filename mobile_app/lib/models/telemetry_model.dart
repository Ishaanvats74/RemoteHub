class TelemetryModel {
  // CPU
  final double? cpuPercent;
  final double? cpuTemp;

  // Memory
  final double? memoryPercent;
  final double? memoryUsedGb;
  final double? memoryTotalGb;

  // Disk
  final double? diskPercent;
  final double? diskUsedGb;
  final double? diskTotalGb;

  // GPU
  final String? gpuName;
  final double? gpuPercent;
  final double? gpuTemp;
  final double? gpuMemoryUsedMb;
  final double? gpuMemoryTotalMb;

  // Battery
  final double? batteryPercent;
  final bool? batteryPluggedIn;
  final String? batteryStatus;
  final String? batteryTimeRemaining;

  // Sensor maps
  final Map<String, dynamic>? temperatures;
  final Map<String, dynamic>? fans;

  final String? uptime;
  final Map<String, dynamic> rawData;
  final DateTime timestamp;

  TelemetryModel({
    this.cpuPercent,
    this.cpuTemp,
    this.memoryPercent,
    this.memoryUsedGb,
    this.memoryTotalGb,
    this.diskPercent,
    this.diskUsedGb,
    this.diskTotalGb,
    this.gpuName,
    this.gpuPercent,
    this.gpuTemp,
    this.gpuMemoryUsedMb,
    this.gpuMemoryTotalMb,
    this.batteryPercent,
    this.batteryPluggedIn,
    this.batteryStatus,
    this.batteryTimeRemaining,
    this.temperatures,
    this.fans,
    this.uptime,
    required this.rawData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TelemetryModel.fromJson(Map<String, dynamic> rawInput) {
    var json = rawInput;
    if (json.containsKey('data') && json['data'] is Map) {
      json = Map<String, dynamic>.from(json['data'] as Map);
    } else if (json.containsKey('telemetry') && json['telemetry'] is Map) {
      json = Map<String, dynamic>.from(json['telemetry'] as Map);
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      final str = value.toString().toLowerCase();
      if (str == 'true' || str == '1') return true;
      if (str == 'false' || str == '0') return false;
      return null;
    }

    // CPU parsing
    double? cpuP;
    double? cpuT;
    final cpuRaw = json['cpu'];
    if (cpuRaw is Map) {
      cpuP = parseDouble(cpuRaw['usage'] ?? cpuRaw['percent'] ?? cpuRaw['load']);
      cpuT = parseDouble(cpuRaw['temperature'] ?? cpuRaw['temp']);
    } else {
      cpuP = parseDouble(json['cpu_percent'] ?? json['cpu'] ?? json['cpu_usage']);
      cpuT = parseDouble(json['cpu_temp'] ?? json['cpu_temperature']);
    }

    // Memory parsing
    double? memP;
    double? memUsed;
    double? memTotal;
    final memRaw = json['memory'] ?? json['ram'];
    if (memRaw is Map) {
      memP = parseDouble(memRaw['usage'] ?? memRaw['percent']);
      memUsed = parseDouble(memRaw['used_gb']);
      memTotal = parseDouble(memRaw['total_gb']);
    } else {
      memP = parseDouble(json['memory_percent'] ?? json['ram_percent'] ?? json['ram'] ?? json['memory']);
      memUsed = parseDouble(json['memory_used_gb'] ?? json['ram_used_gb']);
      memTotal = parseDouble(json['memory_total_gb'] ?? json['ram_total_gb']);
    }

    // Disk parsing
    double? diskP;
    double? diskUsed;
    double? diskTotal;
    final diskRaw = json['disk'] ?? json['storage'];
    if (diskRaw is Map) {
      diskP = parseDouble(diskRaw['usage'] ?? diskRaw['percent']);
      diskUsed = parseDouble(diskRaw['used_gb']);
      diskTotal = parseDouble(diskRaw['total_gb']);
    } else {
      diskP = parseDouble(json['disk_percent'] ?? json['disk'] ?? json['disk_usage']);
      diskUsed = parseDouble(json['disk_used_gb']);
      diskTotal = parseDouble(json['disk_total_gb']);
    }

    // GPU parsing
    String? gpuN;
    double? gpuP;
    double? gpuT;
    double? gpuMemUsed;
    double? gpuMemTotal;
    dynamic gpuRaw = json['gpu'];
    if (gpuRaw is List && gpuRaw.isNotEmpty) {
      gpuRaw = gpuRaw.first;
    }
    if (gpuRaw is Map) {
      gpuN = gpuRaw['name']?.toString();
      gpuP = parseDouble(gpuRaw['usage'] ?? gpuRaw['percent'] ?? gpuRaw['load']);
      gpuT = parseDouble(gpuRaw['temperature'] ?? gpuRaw['temp']);
      gpuMemUsed = parseDouble(gpuRaw['memory_used_mb'] ?? gpuRaw['mem_used_mb']);
      gpuMemTotal = parseDouble(gpuRaw['memory_total_mb'] ?? gpuRaw['mem_total_mb']);
    } else {
      gpuP = parseDouble(json['gpu_percent'] ?? json['gpu_usage']);
      gpuT = parseDouble(json['gpu_temp'] ?? json['gpu_temperature']);
      gpuN = json['gpu_name']?.toString();
    }

    // Battery parsing
    double? battP;
    bool? battPlugged;
    String? battStatus;
    String? battTime;
    final battRaw = json['battery'];
    if (battRaw is Map) {
      battP = parseDouble(battRaw['percent'] ?? battRaw['usage']);
      battPlugged = parseBool(battRaw['plugged_in'] ?? battRaw['plugged']);
      battStatus = battRaw['status']?.toString();
      battTime = battRaw['time_remaining']?.toString();
    } else {
      battP = parseDouble(json['battery_percent'] ?? json['battery']);
      battPlugged = parseBool(json['plugged_in'] ?? json['battery_plugged']);
      battStatus = json['battery_status']?.toString();
      battTime = json['battery_time_remaining']?.toString();
    }

    // Sensor maps
    Map<String, dynamic>? temps;
    if (json['temperatures'] is Map) {
      temps = Map<String, dynamic>.from(json['temperatures'] as Map);
    }
    Map<String, dynamic>? fans;
    if (json['fans'] is Map) {
      fans = Map<String, dynamic>.from(json['fans'] as Map);
    }

    return TelemetryModel(
      cpuPercent: cpuP,
      cpuTemp: cpuT,
      memoryPercent: memP,
      memoryUsedGb: memUsed,
      memoryTotalGb: memTotal,
      diskPercent: diskP,
      diskUsedGb: diskUsed,
      diskTotalGb: diskTotal,
      gpuName: gpuN,
      gpuPercent: gpuP,
      gpuTemp: gpuT,
      gpuMemoryUsedMb: gpuMemUsed,
      gpuMemoryTotalMb: gpuMemTotal,
      batteryPercent: battP,
      batteryPluggedIn: battPlugged,
      batteryStatus: battStatus,
      batteryTimeRemaining: battTime,
      temperatures: temps,
      fans: fans,
      uptime: json['uptime']?.toString(),
      rawData: Map<String, dynamic>.from(rawInput),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => rawData;
}
