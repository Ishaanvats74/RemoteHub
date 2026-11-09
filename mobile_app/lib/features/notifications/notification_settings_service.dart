import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists notification settings in SharedPreferences.
class NotificationSettingsService {
  NotificationSettingsService._();
  static final NotificationSettingsService instance = NotificationSettingsService._();

  // Shared preference keys
  static const String _keyEnabled          = 'notif_enabled';
  static const String _keyCpuThreshold     = 'notif_cpu_threshold';
  static const String _keyGpuThreshold     = 'notif_gpu_threshold';
  static const String _keyCpuUsageThreshold = 'notif_cpu_usage_threshold';
  static const String _keyRamUsageThreshold = 'notif_ram_usage_threshold';

  // Defaults
  static const double defaultCpuTempThreshold = 85;
  static const double defaultGpuTempThreshold = 80;
  static const double defaultCpuUsageThreshold = 95; // 0 = disabled
  static const double defaultRamUsageThreshold = 90; // 0 = disabled
  static const int cooldownMinutes = 5;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  bool get enabled => _prefs?.getBool(_keyEnabled) ?? true;
  double get cpuTempThreshold =>
      _prefs?.getDouble(_keyCpuThreshold) ?? defaultCpuTempThreshold;
  double get gpuTempThreshold =>
      _prefs?.getDouble(_keyGpuThreshold) ?? defaultGpuTempThreshold;
  double get cpuUsageThreshold =>
      _prefs?.getDouble(_keyCpuUsageThreshold) ?? defaultCpuUsageThreshold;
  double get ramUsageThreshold =>
      _prefs?.getDouble(_keyRamUsageThreshold) ?? defaultRamUsageThreshold;

  Future<void> setEnabled(bool v) async {
    await init();
    await _prefs!.setBool(_keyEnabled, v);
  }

  Future<void> setCpuTempThreshold(double v) async {
    await init();
    await _prefs!.setDouble(_keyCpuThreshold, v);
  }

  Future<void> setGpuTempThreshold(double v) async {
    await init();
    await _prefs!.setDouble(_keyGpuThreshold, v);
  }

  Future<void> setCpuUsageThreshold(double v) async {
    await init();
    await _prefs!.setDouble(_keyCpuUsageThreshold, v);
  }

  Future<void> setRamUsageThreshold(double v) async {
    await init();
    await _prefs!.setDouble(_keyRamUsageThreshold, v);
  }
}

// ── Riverpod providers ───────────────────────────────────────────────────────

class NotifSettingsNotifier extends StateNotifier<NotificationSettingsState> {
  final NotificationSettingsService _service;

  NotifSettingsNotifier(this._service)
      : super(NotificationSettingsState(
          enabled: _service.enabled,
          cpuTempThreshold: _service.cpuTempThreshold,
          gpuTempThreshold: _service.gpuTempThreshold,
          cpuUsageThreshold: _service.cpuUsageThreshold,
          ramUsageThreshold: _service.ramUsageThreshold,
        ));

  Future<void> setEnabled(bool v) async {
    await _service.setEnabled(v);
    state = state.copyWith(enabled: v);
  }

  Future<void> setCpuTempThreshold(double v) async {
    await _service.setCpuTempThreshold(v);
    state = state.copyWith(cpuTempThreshold: v);
  }

  Future<void> setGpuTempThreshold(double v) async {
    await _service.setGpuTempThreshold(v);
    state = state.copyWith(gpuTempThreshold: v);
  }

  Future<void> setCpuUsageThreshold(double v) async {
    await _service.setCpuUsageThreshold(v);
    state = state.copyWith(cpuUsageThreshold: v);
  }

  Future<void> setRamUsageThreshold(double v) async {
    await _service.setRamUsageThreshold(v);
    state = state.copyWith(ramUsageThreshold: v);
  }
}

class NotificationSettingsState {
  final bool enabled;
  final double cpuTempThreshold;
  final double gpuTempThreshold;
  final double cpuUsageThreshold;
  final double ramUsageThreshold;

  const NotificationSettingsState({
    required this.enabled,
    required this.cpuTempThreshold,
    required this.gpuTempThreshold,
    required this.cpuUsageThreshold,
    required this.ramUsageThreshold,
  });

  NotificationSettingsState copyWith({
    bool? enabled,
    double? cpuTempThreshold,
    double? gpuTempThreshold,
    double? cpuUsageThreshold,
    double? ramUsageThreshold,
  }) => NotificationSettingsState(
        enabled: enabled ?? this.enabled,
        cpuTempThreshold: cpuTempThreshold ?? this.cpuTempThreshold,
        gpuTempThreshold: gpuTempThreshold ?? this.gpuTempThreshold,
        cpuUsageThreshold: cpuUsageThreshold ?? this.cpuUsageThreshold,
        ramUsageThreshold: ramUsageThreshold ?? this.ramUsageThreshold,
      );
}

final notifSettingsProvider =
    StateNotifierProvider<NotifSettingsNotifier, NotificationSettingsState>((ref) {
  return NotifSettingsNotifier(NotificationSettingsService.instance);
});
