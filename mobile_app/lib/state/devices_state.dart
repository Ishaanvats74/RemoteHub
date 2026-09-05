import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/devices_api.dart';
import '../models/device_model.dart';
import 'auth_state.dart';
import 'websocket_state.dart';

final devicesApiProvider = Provider<DevicesApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return DevicesApi(apiClient: client);
});

class DevicesState {
  final List<DeviceModel> devices;
  final bool isLoading;
  final String? errorMessage;

  const DevicesState({
    this.devices = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DevicesState copyWith({
    List<DeviceModel>? devices,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DevicesState(
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DevicesNotifier extends StateNotifier<DevicesState> {
  final DevicesApi _devicesApi;
  final Ref _ref;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _telemetrySubscription;

  DevicesNotifier(this._ref, this._devicesApi) : super(const DevicesState()) {
    _listenToWebSocketUpdates();
  }

  void _listenToWebSocketUpdates() {
    final wsManager = _ref.read(webSocketManagerProvider);

    _statusSubscription = wsManager.deviceStatusStream.listen((msg) {
      _updateDeviceStatus(msg.deviceId, msg.status);
    });

    _telemetrySubscription = wsManager.telemetryStream.listen((msg) {
      _updateDeviceStatus(msg.deviceId, 'online');
    });
  }

  void _updateDeviceStatus(String deviceId, String status) {
    if (state.devices.isEmpty) return;

    final updated = state.devices.map((device) {
      if (device.id == deviceId) {
        return device.copyWith(
          status: status,
          lastSeen: DateTime.now(),
        );
      }
      return device;
    }).toList();

    state = state.copyWith(devices: updated);
  }

  Future<void> loadDevices() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final devices = await _devicesApi.getDevices();
      state = state.copyWith(
        devices: devices,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<String> generatePairingCode() async {
    return await _devicesApi.getPairingCode();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }
}

final devicesNotifierProvider =
    StateNotifierProvider<DevicesNotifier, DevicesState>((ref) {
  final api = ref.watch(devicesApiProvider);
  return DevicesNotifier(ref, api);
});
