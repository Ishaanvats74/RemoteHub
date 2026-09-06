import 'telemetry_model.dart';

enum WsCommandType {
  shutdown,
  restart,
  sleep,
  lock,
}

extension WsCommandTypeExtension on WsCommandType {
  String get value {
    switch (this) {
      case WsCommandType.shutdown:
        return 'shutdown';
      case WsCommandType.restart:
        return 'restart';
      case WsCommandType.sleep:
        return 'sleep';
      case WsCommandType.lock:
        return 'lock';
    }
  }

  String get displayName {
    switch (this) {
      case WsCommandType.shutdown:
        return 'Shutdown';
      case WsCommandType.restart:
        return 'Restart';
      case WsCommandType.sleep:
        return 'Sleep';
      case WsCommandType.lock:
        return 'Lock';
    }
  }
}

sealed class WsIncomingMessage {
  const WsIncomingMessage();

  factory WsIncomingMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';

    switch (type) {
      case 'command_result':
        return WsCommandResultMessage.fromJson(json);

      case 'telemetry':
        return WsTelemetryMessage.fromJson(json);

      case 'device_status':
      case 'status':
        return WsDeviceStatusMessage.fromJson(json);

      case 'device_paired':
        return WsDevicePairedMessage.fromJson(json);

      default:
        return WsGenericMessage(
          type: type,
          payload: json,
        );
    }
  }
}

class WsCommandResultMessage extends WsIncomingMessage {
  final String deviceId;
  final String command;
  final bool success;
  final String? message;
  final DateTime timestamp;

  WsCommandResultMessage({
    required this.deviceId,
    required this.command,
    required this.success,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WsCommandResultMessage.fromJson(Map<String, dynamic> json) {
    return WsCommandResultMessage(
      deviceId: (json['device_id'] ?? '').toString(),
      command: json['command'] as String? ?? '',
      success: json['success'] == true ||
          json['status'] == 'ok' ||
          json['status'] == 'success',
      message: json['message'] as String? ??
          json['error'] as String?,
      timestamp: DateTime.now(),
    );
  }
}

class WsTelemetryMessage extends WsIncomingMessage {
  final String deviceId;
  final TelemetryModel telemetry;

  WsTelemetryMessage({
    required this.deviceId,
    required this.telemetry,
  });

  factory WsTelemetryMessage.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json['telemetry'] is Map<String, dynamic>
            ? json['telemetry'] as Map<String, dynamic>
            : json;

    return WsTelemetryMessage(
      deviceId: (json['device_id'] ?? '').toString(),
      telemetry: TelemetryModel.fromJson(rawData),
    );
  }
}

class WsDeviceStatusMessage extends WsIncomingMessage {
  final String deviceId;
  final String status;

  WsDeviceStatusMessage({
    required this.deviceId,
    required this.status,
  });

  bool get isOnline => status.toLowerCase() == 'online';

  factory WsDeviceStatusMessage.fromJson(Map<String, dynamic> json) {
    return WsDeviceStatusMessage(
      deviceId: (json['device_id'] ?? '').toString(),
      status: json['status'] as String? ?? 'offline',
    );
  }
}

// -------------------------------------------------
// Device Paired
// -------------------------------------------------

class WsDevicePairedMessage extends WsIncomingMessage {
  final String deviceId;
  final String hostname;
  final String? os;
  final String? platform;

  WsDevicePairedMessage({
    required this.deviceId,
    required this.hostname,
    this.os,
    this.platform,
  });

  factory WsDevicePairedMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    return WsDevicePairedMessage(
      deviceId: (json['device_id'] ?? '').toString(),
      hostname: (json['hostname'] ?? 'Unknown Device').toString(),
      os: json['os']?.toString(),
      platform: json['platform']?.toString(),
    );
  }
}

class WsGenericMessage extends WsIncomingMessage {
  final String type;
  final Map<String, dynamic> payload;

  const WsGenericMessage({
    required this.type,
    required this.payload,
  });
}

