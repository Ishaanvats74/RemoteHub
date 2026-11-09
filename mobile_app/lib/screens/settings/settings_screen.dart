import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/background/background_service.dart';
import '../../features/notifications/notification_settings_service.dart';
import '../../state/auth_state.dart';
import '../../state/server_settings_state.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _bgServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _checkBgService();
  }

  Future<void> _checkBgService() async {
    final running = await BackgroundServiceHelper.isRunning();
    if (mounted) setState(() => _bgServiceRunning = running);
  }

  Future<void> _toggleBgService(bool val) async {
    if (val) {
      await BackgroundServiceHelper.start();
    } else {
      await BackgroundServiceHelper.stop();
    }
    await _checkBgService();
  }

  void _showUrlDialog() {
    final current = ref.read(serverSettingsProvider);
    final ctrl = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://10.0.2.2:8000',
            prefixIcon: Icon(Icons.dns_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) ref.read(serverSettingsProvider.notifier).setBaseUrl(url);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('You will be signed out from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.actionShutdown),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await BackgroundServiceHelper.stop();
    await ref.read(authNotifierProvider.notifier).logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState   = ref.watch(authNotifierProvider);
    final notifState  = ref.watch(notifSettingsProvider);
    final notifNotifier = ref.read(notifSettingsProvider.notifier);
    final serverUrl   = ref.watch(serverSettingsProvider);
    final user        = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ── Profile card ─────────────────────────────────────────────────
          if (user != null)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${user.username}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(user.email,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          _sectionHeader('Notifications'),

          _card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Enable Alerts',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Temperature & usage threshold alerts',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  value: notifState.enabled,
                  onChanged: (v) => notifNotifier.setEnabled(v),
                  activeTrackColor: AppColors.primary,
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                _sliderTile(
                  label: 'CPU temp threshold',
                  value: notifState.cpuTempThreshold,
                  min: 50,
                  max: 100,
                  unit: '°C',
                  onChanged: notifNotifier.setCpuTempThreshold,
                  enabled: notifState.enabled,
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                _sliderTile(
                  label: 'GPU temp threshold',
                  value: notifState.gpuTempThreshold,
                  min: 50,
                  max: 100,
                  unit: '°C',
                  onChanged: notifNotifier.setGpuTempThreshold,
                  enabled: notifState.enabled,
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                _sliderTile(
                  label: 'CPU usage alert (0 = off)',
                  value: notifState.cpuUsageThreshold,
                  min: 0,
                  max: 100,
                  unit: '%',
                  onChanged: notifNotifier.setCpuUsageThreshold,
                  enabled: notifState.enabled,
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                _sliderTile(
                  label: 'RAM usage alert (0 = off)',
                  value: notifState.ramUsageThreshold,
                  min: 0,
                  max: 100,
                  unit: '%',
                  onChanged: notifNotifier.setRamUsageThreshold,
                  enabled: notifState.enabled,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Background Monitoring'),

          _card(
            child: SwitchListTile.adaptive(
              title: const Text('Keep monitoring in background',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text(
                BackgroundServiceHelper.isSupported
                    ? 'Runs a foreground service. Requires battery optimisation exemption for '
                        'reliable alerts when the screen is off.'
                    : 'Background keep-alive service is only supported on Android and iOS devices.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: BackgroundServiceHelper.isSupported && _bgServiceRunning,
              onChanged: BackgroundServiceHelper.isSupported ? _toggleBgService : null,
              activeTrackColor: AppColors.primary,
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Server'),

          _card(
            child: ListTile(
              leading: const Icon(Icons.dns_rounded, color: AppColors.primary),
              title: const Text('Backend URL',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text(serverUrl,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 18),
              onTap: _showUrlDialog,
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Account'),

          _card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.actionShutdown),
              title: const Text('Log Out',
                  style: TextStyle(color: AppColors.actionShutdown, fontWeight: FontWeight.w600)),
              onTap: _logout,
            ),
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'RemoteHub v1.0.0',
              style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: child,
      );

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required void Function(double) onChanged,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              Text('${value.toStringAsFixed(0)} $unit',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            activeColor: enabled ? AppColors.primary : AppColors.textMuted,
            inactiveColor: AppColors.surfaceBorder,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
