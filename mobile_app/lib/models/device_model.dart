class DeviceModel {
  final String id;
  final String userId;
  final String hostname;
  final String os;
  final String platform;
  final String status; // 'online', 'offline'
  final DateTime? lastSeen;
  final DateTime? createdAt;

  const DeviceModel({
    required this.id,
    required this.userId,
    required this.hostname,
    required this.os,
    required this.platform,
    required this.status,
    this.lastSeen,
    this.createdAt,
  });

  bool get isOnline => status.toLowerCase() == 'online';

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      hostname: json['hostname'] as String? ?? 'Unknown Host',
      os: json['os'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())?.toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'hostname': hostname,
      'os': os,
      'platform': platform,
      'status': status,
      if (lastSeen != null) 'last_seen': lastSeen!.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  DeviceModel copyWith({
    String? id,
    String? userId,
    String? hostname,
    String? os,
    String? platform,
    String? status,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hostname: hostname ?? this.hostname,
      os: os ?? this.os,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
