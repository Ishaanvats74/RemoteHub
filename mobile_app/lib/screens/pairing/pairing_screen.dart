import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../state/devices_state.dart';
import '../../state/websocket_state.dart';
import '../../widgets/common/app_button.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  String? _code;
  bool _isLoading = false;
  String? _error;
  bool _isCopied = false;

  Timer? _countdownTimer;

  int _secondsRemaining =
      ApiConstants.pairingCodeExpireMinutes * 60;

  final int _totalSeconds =
      ApiConstants.pairingCodeExpireMinutes * 60;

  late final ProviderSubscription _pairingSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for the backend notification that a desktop
    // has successfully paired with this account.
    _pairingSubscription = ref.listenManual(
      wsDevicePairedStreamProvider,
      (previous, next) {
        next.whenData((message) {
          if (!mounted) return;

          // Stop the pairing-code countdown.
          _countdownTimer?.cancel();

          // Show success message.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${message.hostname} connected successfully!',
              ),
            ),
          );

          // Give the user a moment to see the message,
          // then return to the previous screen.
          Future.delayed(
            const Duration(milliseconds: 800),
            () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          );
        });
      },
    );

    _fetchPairingCode();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pairingSubscription.close();
    super.dispose();
  }

  Future<void> _fetchPairingCode() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isCopied = false;
    });

    try {
      final code = await ref
          .read(devicesNotifierProvider.notifier)
          .generatePairingCode();

      if (!mounted) return;

      setState(() {
        _code = code;
        _secondsRemaining = _totalSeconds;
        _isLoading = false;
      });

      _startCountdown();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            _secondsRemaining = 0;
          });

          return;
        }

        setState(() {
          _secondsRemaining--;
        });
      },
    );
  }

  Future<void> _copyCode() async {
    if (_code == null) return;

    await Clipboard.setData(
      ClipboardData(text: _code!),
    );

    if (!mounted) return;

    setState(() {
      _isCopied = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pairing code copied'),
      ),
    );

    Future.delayed(
      const Duration(seconds: 2),
      () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      },
    );
  }

  String _formatCountdown() {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  double _progressValue() {
    if (_totalSeconds == 0) return 0;

    return _secondsRemaining / _totalSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair Device'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _error != null
                  ? _buildErrorState()
                  : _buildPairingContent(theme),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Try Again',
            onPressed: _fetchPairingCode,
          ),
        ],
      ),
    );
  }

  Widget _buildPairingContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),

          const Icon(
            Icons.devices,
            size: 72,
          ),

          const SizedBox(height: 24),

          Text(
            'Pair Your Device',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Enter this 6-digit code on the desktop device '
            'you want to pair with your account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 40),

          if (_code != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 28,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.dividerColor,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'PAIRING CODE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SelectableText(
                    _code!,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 44,
                    child: AppButton(
                      text: _isCopied ? 'Copied' : 'Copy Code',
                      onPressed: _copyCode,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          Text(
            'Code expires in',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 8),

          Text(
            _formatCountdown(),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          LinearProgressIndicator(
            value: _progressValue(),
          ),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Open RemoteHub on your desktop and enter '
                    'the code shown above. Once the device pairs, '
                    'this screen will automatically close.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          TextButton(
            onPressed: _fetchPairingCode,
            child: const Text('Generate New Code'),
          ),
        ],
      ),
    );
  }
}