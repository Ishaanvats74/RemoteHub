import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../models/telemetry_model.dart';
import '../models/ws_message.dart';
import 'devices_state.dart';
import 'websocket_state.dart';

class DeviceDetailState {
  final DeviceModel? device;
  final TelemetryModel? telemetry;
  final bool isLoading;
  final bool isSendingCommand;
  final String? errorMessage;
  final WsCommandResultMessage? lastCommandResult;

  const DeviceDetailState({
    this.device,
    this.telemetry,
    this.isLoading = false,
    this.isSendingCommand = false,
    this.errorMessage,
    this.lastCommandResult,
  });

  DeviceDetailState copyWith({
    DeviceModel? device,
    TelemetryModel? telemetry,
    bool? isLoading,
    bool? isSendingCommand,
    String? errorMessage,
    WsCommandResultMessage? lastCommandResult,
  }) {
    return DeviceDetailState(
      device: device ?? this.device,
      telemetry: telemetry ?? this.telemetry,
      isLoading: isLoading ?? this.isLoading,
      isSendingCommand: isSendingCommand ?? this.isSendingCommand,
      errorMessage: errorMessage,
      lastCommandResult: lastCommandResult ?? this.lastCommandResult,
    );
  }
}

class DeviceDetailNotifier extends StateNotifier<DeviceDetailState> {
  final String deviceId;
  final Ref _ref;
  StreamSubscription? _statusSub;
  StreamSubscription? _telemetrySub;
  StreamSubscription? _commandResultSub;

  DeviceDetailNotifier(this.deviceId, this._ref, DeviceModel? initialDevice)
      : super(DeviceDetailState(device: initialDevice)) {
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
      if (msg.deviceId == deviceId) {
        state = state.copyWith(
          telemetry: msg.telemetry,
          device: state.device?.copyWith(
            status: 'online',
            lastSeen: DateTime.now(),
          ),
        );
      }
    });

    _commandResultSub = wsManager.commandResultStream.listen((msg) {
      if (msg.deviceId == deviceId) {
        state = state.copyWith(
          isSendingCommand: false,
          lastCommandResult: msg,
        );
      }
    });
  }

  Future<void> loadDeviceData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final devicesApi = _ref.read(devicesApiProvider);

      // Load device details & telemetry in parallel
      final results = await Future.wait([
        devicesApi.getDevice(deviceId),
        devicesApi.getDeviceTelemetry(deviceId).catchError((_) => TelemetryModel(rawData: {})),
      ]);

      final device = results[0] as DeviceModel;
      final telemetry = results[1] as TelemetryModel;

      state = state.copyWith(
        device: device,
        telemetry: telemetry.rawData.isNotEmpty ? telemetry : state.telemetry,
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
    state = state.copyWith(isSendingCommand: true, lastCommandResult: null);

    try {
      final wsManager = _ref.read(webSocketManagerProvider);
      await wsManager.sendCommand(deviceId, command);
      // Wait for command_result message via WebSocket listener
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
    state = state.copyWith(lastCommandResult: null);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _telemetrySub?.cancel();
    _commandResultSub?.cancel();
    super.dispose();
  }
}

final deviceDetailProvider = StateNotifierProvider.family<DeviceDetailNotifier,
    DeviceDetailState, DeviceModel>((ref, initialDevice) {
  return DeviceDetailNotifier(initialDevice.id, ref, initialDevice);
});
