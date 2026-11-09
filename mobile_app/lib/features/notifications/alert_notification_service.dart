import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/telemetry/telemetry_mapper.dart';
import 'notification_settings_service.dart';

/// Notification channel IDs & names (Android).
const String _kTempChannelId   = 'remotehub_temp_alerts';
const String _kTempChannelName = 'Temperature Alerts';
const String _kBgChannelId     = 'remotehub_bg_service';
const String _kBgChannelName   = 'Background Service';

/// Unique notification IDs.
const int _kCpuTempNotifId = 1001;
const int _kGpuTempNotifId = 1002;
const int _kBgServiceNotifId = 2000;

/// Re-arm hysteresis: temperature must drop this many degrees below
/// threshold before the alert fires again.
const double _kHysteresis = 5.0;

/// Service that manages flutter_local_notifications and evaluates
/// temperature thresholds for every incoming telemetry payload.
class AlertNotificationService {
  AlertNotificationService._();
  static final AlertNotificationService instance = AlertNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // ── Per-device, per-metric cooldown tracker ──────────────────────────────
  // Key: "$deviceId:$metric"
  final Map<String, DateTime> _lastFiredAt = {};
  final Map<String, bool> _armed = {};   // true = can fire, false = waiting for hysteresis

  // ── Current temperatures for in-app banner tracking ──────────────────────
  // Key: "$deviceId:cpu" / "$deviceId:gpu"  → temp value
  final Map<String, double> _lastTemps = {};

  // ── Stream for in-app banner updates ─────────────────────────────────────
  final StreamController<AlertBannerEvent> _bannerController =
      StreamController<AlertBannerEvent>.broadcast();

  Stream<AlertBannerEvent> get bannerStream => _bannerController.stream;

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialise() async {
    if (_initialised) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channels.
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kTempChannelId,
        _kTempChannelName,
        description: 'Fires when CPU/GPU temperature exceeds your threshold.',
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kBgChannelId,
        _kBgChannelName,
        description: 'Persistent notification while RemoteHub monitors in background.',
        importance: Importance.low,
        playSound: false,
        showBadge: false,
      ),
    );

    _initialised = true;
  }

  /// Request POST_NOTIFICATIONS permission on Android 13+.
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Temperature alert evaluation
  // ─────────────────────────────────────────────────────────────────────────

  /// Called for every incoming telemetry message.
  Future<void> evaluateTelemetry({
    required String deviceId,
    required String hostname,
    required MappedTelemetry telemetry,
    required NotificationSettingsService settings,
  }) async {
    if (!_initialised) return;
    if (!settings.enabled) return;

    await _checkTemp(
      deviceId: deviceId,
      hostname: hostname,
      metric: 'cpu',
      value: telemetry.cpuPercent,      // ← using cpuTemp if present
      temp: telemetry.cpuTemp,
      threshold: settings.cpuTempThreshold,
      notifId: _kCpuTempNotifId,
      label: 'CPU',
    );

    await _checkTemp(
      deviceId: deviceId,
      hostname: hostname,
      metric: 'gpu',
      value: telemetry.gpuPercent,
      temp: telemetry.gpuTemp,
      threshold: settings.gpuTempThreshold,
      notifId: _kGpuTempNotifId,
      label: 'GPU',
    );
  }

  Future<void> _checkTemp({
    required String deviceId,
    required String hostname,
    required String metric,
    required double? value,
    required double? temp,
    required double threshold,
    required int notifId,
    required String label,
  }) async {
    if (temp == null) return;

    final key = '$deviceId:$metric';
    _lastTemps[key] = temp;

    // Broadcast for in-app banner.
    _bannerController.add(AlertBannerEvent(
      deviceId: deviceId,
      metric: metric,
      temperature: temp,
      threshold: threshold,
    ));

    final bool isHot = temp >= threshold;
    final bool wasArmed = _armed[key] ?? true;

    if (!isHot) {
      // Cool-down path: re-arm when temp drops below (threshold - hysteresis).
      if (!wasArmed && temp <= threshold - _kHysteresis) {
        _armed[key] = true;
      }
      return;
    }

    if (!wasArmed) return; // Waiting for hysteresis.

    // Check cooldown.
    final cooldownDuration = Duration(minutes: NotificationSettingsService.cooldownMinutes);
    final lastFired = _lastFiredAt[key];
    if (lastFired != null && DateTime.now().difference(lastFired) < cooldownDuration) {
      return;
    }

    // Fire!
    _armed[key] = false;
    _lastFiredAt[key] = DateTime.now();

    await _showTempNotification(
      notifId: notifId,
      title: 'High $label temperature on $hostname',
      body: '$label temp: ${temp.toStringAsFixed(0)} °C  (threshold: ${threshold.toStringAsFixed(0)} °C)',
      deviceId: deviceId,
    );
  }

  Future<void> _showTempNotification({
    required int notifId,
    required String title,
    required String body,
    required String deviceId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _kTempChannelId,
      _kTempChannelName,
      channelDescription: 'Temperature threshold exceeded.',
      importance: Importance.high,
      priority: Priority.high,
      ticker: title,
    );

    await _plugin.show(
      notifId,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: deviceId,
    );
  }

  // ── Background service persistent notification ────────────────────────────

  Future<void> showBackgroundNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _kBgChannelId,
      _kBgChannelName,
      channelDescription: 'RemoteHub is monitoring your devices.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      _kBgServiceNotifId,
      'RemoteHub',
      'Monitoring your devices',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelBackgroundNotification() async {
    await _plugin.cancel(_kBgServiceNotifId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  void _onNotificationTap(NotificationResponse response) {
    // The payload is the deviceId.  The app can listen to this and
    // navigate to the device detail screen.  Deep-linking via go_router
    // is handled in main.dart via a GlobalKey<NavigatorState>.
    if (kDebugMode) {
      debugPrint('[Notifications] Tapped. Payload: ${response.payload}');
    }
  }

  void dispose() {
    _bannerController.close();
  }
}

/// Emitted on the bannerStream whenever a temperature is evaluated.
class AlertBannerEvent {
  final String deviceId;
  final String metric; // 'cpu' | 'gpu'
  final double temperature;
  final double threshold;

  AlertBannerEvent({
    required this.deviceId,
    required this.metric,
    required this.temperature,
    required this.threshold,
  });

  bool get isAlert => temperature >= threshold;
}
