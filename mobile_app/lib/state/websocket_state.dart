import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/websocket_manager.dart';
import '../models/ws_message.dart';
import 'server_settings_state.dart';

final webSocketManagerProvider = Provider<WebSocketManager>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final baseUrl = ref.watch(serverSettingsProvider);

  final manager = WebSocketManager(
    tokenStorage: storage,
    getBaseUrl: () => baseUrl,
  );

  ref.onDispose(() {
    manager.dispose();
  });

  return manager;
});

final wsStatusStreamProvider = StreamProvider<WsConnectionStatus>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.statusStream;
});

final wsCommandResultStreamProvider =
    StreamProvider<WsCommandResultMessage>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.commandResultStream;
});

final wsTelemetryStreamProvider =
    StreamProvider<WsTelemetryMessage>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.telemetryStream;
});

final wsDeviceStatusStreamProvider =
    StreamProvider<WsDeviceStatusMessage>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.deviceStatusStream;
});

// -------------------------------------------------
// Device Paired
// -------------------------------------------------

final wsDevicePairedStreamProvider =
    StreamProvider<WsDevicePairedMessage>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.devicePairedStream;
});