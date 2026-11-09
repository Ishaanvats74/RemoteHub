import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../features/notifications/alert_notification_service.dart';
import '../features/notifications/notification_settings_service.dart';
import '../features/telemetry/rolling_buffer.dart';
import '../models/device_model.dart';
import '../models/telemetry_model.dart';
import '../models/ws_message.dart';
import 'devices_state.dart';
import 'websocket_state.dart';

// ── Per-device rolling buffer registry ──────────────────────────────────────
// Kept in a plain Map so all devices share one registry (Riverpod family
// would create a new buffer for every distinct DeviceModel instance).
final _buffers = <String, RollingTelemetryBuffer>{};

RollingTelemetryBuffer bufferForDevice(String deviceId) {
  return _buffers.putIfAbsent(
    deviceId,
    () => RollingTelemetryBuffer(maxSize: AppConfig.telemetryBufferSize),
  );
}

// ── Provider ─────────────────────────────────────────────────────────────────
final deviceDetailProvider = StateNotifierProvider.family<DeviceDetailNotifier,
    DeviceDetailState, DeviceModel>((ref, initialDevice) {
  return DeviceDetailNotifier(initialDevice.id, ref, initialDevice);
});

// ── State ─────────────────────────────────────────────────────────────────────
class DeviceDetailState {
  final DeviceModel? device;
  final TelemetryModel? telemetry;
  final RollingTelemetryBuffer? buffer;
  final bool isLoading;
  final bool isSendingCommand;
  final String? errorMessage;
  final WsCommandResultMessage? lastCommandResult;
  final bool commandTimedOut;

  const DeviceDetailState({
    this.device,
    this.telemetry,
    this.buffer,
    this.isLoading = false,
    this.isSendingCommand = false,
    this.errorMessage,
    this.lastCommandResult,
    this.commandTimedOut = false,
  });

  DeviceDetailState copyWith({
    DeviceModel? device,
    TelemetryModel? telemetry,
    RollingTelemetryBuffer? buffer,
    bool? isLoading,
    bool? isSendingCommand,
    String? errorMessage,
    WsCommandResultMessage? lastCommandResult,
    bool? commandTimedOut,
  }) {
    return DeviceDetailState(
      device: device ?? this.device,
      telemetry: telemetry ?? this.telemetry,
      buffer: buffer ?? this.buffer,
      isLoading: isLoading ?? this.isLoading,
      isSendingCommand: isSendingCommand ?? this.isSendingCommand,
      errorMessage: errorMessage,
      lastCommandResult: lastCommandResult ?? this.lastCommandResult,
      commandTimedOut: commandTimedOut ?? this.commandTimedOut,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class DeviceDetailNotifier extends StateNotifier<DeviceDetailState> {
  final String deviceId;
  final Ref _ref;
  StreamSubscription? _statusSub;
  StreamSubscription? _telemetrySub;
  StreamSubscription? _commandResultSub;
  Timer? _commandTimeoutTimer;

  DeviceDetailNotifier(this.deviceId, this._ref, DeviceModel? initialDevice)
      : super(DeviceDetailState(
          device: initialDevice,
          buffer: bufferForDevice(initialDevice?.id ?? ''),
        )) {
    _listenToWsEvents();
    loadDeviceData();
  }

  void _listenToWsEvents() {
    final wsManager = _ref.read(webSocketManagerProvider);

    _statusSub = wsManager.deviceStatusStream.listen((msg) {
      if (msg.deviceId == deviceId && state.device != null) {
        state = state.copyWith(
          device: state.device!.copyWith(
            status: msg.status,
            lastSeen: DateTime.now(),
          ),
        );
      }
    });

    _telemetrySub = wsManager.telemetryStream.listen((msg) {
      // Accept telemetry if deviceId matches or if message omits deviceId (single desktop stream)
      if (msg.deviceId.isNotEmpty && msg.deviceId != deviceId) return;

      final buf = bufferForDevice(deviceId);
      buf.add(msg.telemetry);

      // Evaluate temperature alerts.
      final notifSettings = NotificationSettingsService.instance;
      AlertNotificationService.instance.evaluateTelemetry(
        deviceId: deviceId,
        hostname: state.device?.hostname ?? deviceId,
        telemetry: buf.latest!,
        settings: notifSettings,
      );

      state = state.copyWith(
        telemetry: msg.telemetry,
        buffer: buf,
        device: state.device?.copyWith(
          status: 'online',
          lastSeen: DateTime.now(),
        ),
      );
    });

    _commandResultSub = wsManager.commandResultStream.listen((msg) {
      if (msg.deviceId.isNotEmpty && msg.deviceId != deviceId) return;
      _commandTimeoutTimer?.cancel();
      state = state.copyWith(
        isSendingCommand: false,
        lastCommandResult: msg,
        commandTimedOut: false,
      );
    });
  }

  Future<void> loadDeviceData() async {
    // Cache-first: only show full-screen loader if we have no prior device data
    if (state.device == null) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final devicesApi = _ref.read(devicesApiProvider);

      final results = await Future.wait<dynamic>([
        devicesApi.getDevice(deviceId),
        devicesApi.getDeviceTelemetry(deviceId).catchError((_) => TelemetryModel(rawData: {})),
      ]);

      final device = results[0] as DeviceModel;
      final telemetry = results[1] as TelemetryModel;

      final buf = bufferForDevice(deviceId);
      if (telemetry.rawData.isNotEmpty) {
        buf.add(telemetry);
      }

      state = state.copyWith(
        device: device,
        telemetry: telemetry.rawData.isNotEmpty ? telemetry : state.telemetry,
        buffer: buf,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> sendCommand(WsCommandType command) async {
    state = state.copyWith(
        isSendingCommand: true, lastCommandResult: null, commandTimedOut: false);

    try {
      final wsManager = _ref.read(webSocketManagerProvider);
      await wsManager.sendCommand(deviceId, command);

      // Start 10-second timeout.
      _commandTimeoutTimer?.cancel();
      _commandTimeoutTimer = Timer(
        Duration(seconds: AppConfig.commandResultTimeoutSeconds),
        () {
          if (state.isSendingCommand) {
            state = state.copyWith(
              isSendingCommand: false,
              commandTimedOut: true,
            );
          }
        },
      );
    } catch (e) {
      state = state.copyWith(
        isSendingCommand: false,
        lastCommandResult: WsCommandResultMessage(
          deviceId: deviceId,
          command: command.value,
          success: false,
          message: e.toString(),
        ),
      );
    }
  }

  void clearLastCommandResult() {
    state = state.copyWith(
        lastCommandResult: null, commandTimedOut: false);
  }

  @override
  void dispose() {
    _commandTimeoutTimer?.cancel();
    _statusSub?.cancel();
    _telemetrySub?.cancel();
    _commandResultSub?.cancel();
    super.dispose();
  }
}
