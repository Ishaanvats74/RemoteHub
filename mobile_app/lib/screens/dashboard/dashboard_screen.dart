import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/websocket_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../models/device_model.dart';
import '../../state/auth_state.dart';
import '../../state/devices_state.dart';
import '../../state/websocket_state.dart';
import '../../widgets/common/empty_state_view.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/status_dot.dart';
import '../../widgets/device_card.dart';
import '../auth/login_screen.dart';
import '../device_detail/device_detail_screen.dart';
import '../pairing/pairing_screen.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(devicesNotifierProvider.notifier).loadDevices();
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of RemoteCtrl? All active WebSocket links will be closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionShutdown,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final rootNavigator = Navigator.of(this.context);
              Navigator.of(context).pop();
              await ref.read(authNotifierProvider.notifier).logout();
              if (mounted) {
                rootNavigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _openDeviceDetail(DeviceModel device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(device: device),
      ),
    );
  }

  void _openPairingScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PairingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final devicesState = ref.watch(devicesNotifierProvider);
    final wsStatusAsync = ref.watch(wsStatusStreamProvider);
    final wsStatus = wsStatusAsync.value ?? ref.watch(webSocketManagerProvider).status;

    // Listen for session expiry to route to login
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated && next.isSessionExpired) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
            backgroundColor: AppColors.actionShutdown,
          ),
        );
      }
    });

    final isWsConnected = wsStatus == WsConnectionStatus.connected;
    final isWsReconnecting = wsStatus == WsConnectionStatus.reconnecting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.power_settings_new_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'RemoteCtrl',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // WebSocket live link status badge
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isWsConnected
                      ? AppColors.statusOnline.withValues(alpha: 0.3)
                      : isWsReconnecting
                          ? AppColors.statusConnecting.withValues(alpha: 0.3)
                          : AppColors.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusDot(
                    isOnline: isWsConnected,
                    customLabel: isWsConnected
                        ? 'Live'
                        : isWsReconnecting
                            ? 'Syncing'
                            : 'Offline',
                    showLabel: true,
                    size: 8,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pair New Device',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            onPressed: _openPairingScreen,
          ),
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(devicesNotifierProvider.notifier).loadDevices();
        },
        child: devicesState.isLoading && devicesState.devices.isEmpty
            ? const LoadingSkeletonList(count: 5)
            : devicesState.errorMessage != null && devicesState.devices.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: AppColors.actionShutdown,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            devicesState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(devicesNotifierProvider.notifier).loadDevices();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : devicesState.devices.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: EmptyStateView(
                              onButtonPressed: _openPairingScreen,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: devicesState.devices.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Paired Computers (${devicesState.devices.length})',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (authState.user != null)
                                        Text(
                                          'Logged in as @${authState.user!.username}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _openPairingScreen,
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Pair Device'),
                                  ),
                                ],
                              ),
                            );
                          }

                          final device = devicesState.devices[index - 1];
                          return DeviceCard(
                            device: device,
                            onTap: () => _openDeviceDetail(device),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF0B0F19),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Pair Device',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: _openPairingScreen,
      ),
    );
  }
}
