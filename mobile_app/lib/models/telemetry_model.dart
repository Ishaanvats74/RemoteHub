class TelemetryModel {
  final double? cpuPercent;
  final double? memoryPercent;
  final double? diskPercent;
  final double? batteryPercent;
  final String? uptime;
  final Map<String, dynamic> rawData;
  final DateTime timestamp;

  TelemetryModel({
    this.cpuPercent,
    this.memoryPercent,
    this.diskPercent,
    this.batteryPercent,
    this.uptime,
    required this.rawData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return TelemetryModel(
      cpuPercent: parseDouble(json['cpu_percent'] ?? json['cpu'] ?? json['cpu_usage']),
      memoryPercent: parseDouble(json['memory_percent'] ?? json['ram_percent'] ?? json['ram'] ?? json['memory']),
      diskPercent: parseDouble(json['disk_percent'] ?? json['disk'] ?? json['disk_usage']),
      batteryPercent: parseDouble(json['battery_percent'] ?? json['battery']),
      uptime: json['uptime']?.toString(),
      rawData: Map<String, dynamic>.from(json),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => rawData;
}
