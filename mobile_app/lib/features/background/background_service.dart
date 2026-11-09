import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/token_storage.dart';
import '../../core/config.dart';
import '../../features/notifications/alert_notification_service.dart';
import '../../features/notifications/notification_settings_service.dart';
import '../../features/telemetry/telemetry_mapper.dart';
import '../../models/telemetry_model.dart';

/// ══════════════════════════════════════════════════════════════════════════
/// Background Service
///
/// Uses flutter_background_service to run a foreground service on Android
/// that keeps the WebSocket alive and evaluates temperature alerts even
/// when the app is in the background / device screen is off.
///
/// ⚠️  Without FCM, alerts only fire while this service is running.
///     Users should exempt the app from battery optimisation for reliable
///     background alerting (see README for instructions).
/// ══════════════════════════════════════════════════════════════════════════

Future<void> initBackgroundService() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  try {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'remotehub_bg_service',
        initialNotificationTitle: 'RemoteHub',
        initialNotificationContent: 'Monitoring your devices',
        foregroundServiceNotificationId: 2000,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onBackgroundServiceStart,
        onBackground: _iosBackground,
      ),
    );
  } catch (e) {
    debugPrint('Background service init warning: $e');
  }
}

@pragma('vm:entry-point')
Future<bool> _iosBackground(ServiceInstance service) async {
  // iOS background fetch handler – minimal work only.
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialise notification service in the background isolate.
  await AlertNotificationService.instance.initialise();
  await NotificationSettingsService.instance.init();

  // Read stored tokens.
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final tokenStorage = TokenStorage(storage: storage);

  // Read saved server URL.
  final savedUrl = await tokenStorage.getBaseUrl() ?? AppConfig.defaultBaseUrl;
  final wsUrl = '${AppConfig.wsBaseUrl(savedUrl)}/ws/mobile';

  WebSocketChannel? channel;
  StreamSubscription? sub;
  Timer? reconnectTimer;
  int reconnectAttempts = 0;

  late final Future<void> Function() connect;

  void scheduleReconnect() {
    sub?.cancel();
    channel = null;
    reconnectAttempts++;
    final delay = Duration(
      seconds: [1, 2, 4, 8, 16, 30][reconnectAttempts.clamp(0, 5)],
    );
    reconnectTimer?.cancel();
    reconnectTimer = Timer(delay, () => connect());
  }

  connect = () async {
    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await channel!.ready;
      channel!.sink.add(jsonEncode({'token': token}));

      reconnectAttempts = 0;

      sub = channel!.stream.listen(
        (data) async {
          try {
            final decoded = jsonDecode(data.toString()) as Map<String, dynamic>?;
            if (decoded == null) return;

            if (decoded['type'] == 'telemetry') {
              final rawData = decoded['data'] as Map<String, dynamic>? ?? {};
              final deviceId = decoded['device_id']?.toString() ?? '';
              final telemetry = TelemetryModel.fromJson(rawData);
              final mapped = TelemetryMapper.map(telemetry);

              // Evaluate alerts (hostname not available in bg; use device ID).
              await AlertNotificationService.instance.evaluateTelemetry(
                deviceId: deviceId,
                hostname: deviceId,
                telemetry: mapped,
                settings: NotificationSettingsService.instance,
              );
            }
          } catch (_) {}
        },
        onDone: scheduleReconnect,
        onError: (_) => scheduleReconnect(),
      );
    } catch (_) {
      scheduleReconnect();
    }
  };

  await connect();

  service.on('stop').listen((_) {
    reconnectTimer?.cancel();
    sub?.cancel();
    channel?.sink.close();
    service.stopSelf();
  });
}

class BackgroundServiceHelper {
  BackgroundServiceHelper._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> start() async {
    if (!isSupported) return;
    try {
      final service = FlutterBackgroundService();
      final running = await service.isRunning();
      if (!running) {
        await service.startService();
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      final service = FlutterBackgroundService();
      final running = await service.isRunning();
      if (running) {
        service.invoke('stop');
      }
    } catch (_) {}
  }

  static Future<bool> isRunning() async {
    if (!isSupported) return false;
    try {
      return await FlutterBackgroundService().isRunning();
    } catch (_) {
      return false;
    }
  }
}
