import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../state/devices_state.dart';
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
  int _secondsRemaining = ApiConstants.pairingCodeExpireMinutes * 60;
  final int _totalSeconds = ApiConstants.pairingCodeExpireMinutes * 60;

  @override
  void initState() {
    super.initState();
    _fetchPairingCode();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPairingCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isCopied = false;
    });

    try {
      final code = await ref.read(devicesNotifierProvider.notifier).generatePairingCode();
      if (mounted) {
        setState(() {
          _code = code;
          _isLoading = false;
          _secondsRemaining = _totalSeconds;
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _copyToClipboard() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    setState(() {
      _isCopied = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppColors.statusOnline, size: 18),
            SizedBox(width: 8),
            Text('Pairing code copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _secondsRemaining <= 0;
    final progress = _secondsRemaining / _totalSeconds;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pair Laptop / Desktop'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Instructions Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.laptop_chromebook_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Desktop Setup Instructions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildInstructionStep(
                      step: '1',
                      text: 'Launch the RemoteCtrl companion app on your laptop or PC.',
                    ),
                    const SizedBox(height: 10),
                    _buildInstructionStep(
                      step: '2',
                      text: 'Select "Pair with Account" and enter the 6-digit code below.',
                    ),
                    const SizedBox(height: 10),
                    _buildInstructionStep(
                      step: '3',
                      text: 'Once connected, your laptop will appear on your device dashboard.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Code Display Card
              if (_isLoading) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: const [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Generating secure pairing code...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.actionShutdownBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.actionShutdown.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.actionShutdown,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Retry Generation',
                        variant: AppButtonVariant.primary,
                        height: 44,
                        width: 180,
                        onPressed: _fetchPairingCode,
                      ),
                    ],
                  ),
                ),
              ] else if (_code != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExpired
                          ? AppColors.actionShutdown.withValues(alpha: 0.5)
                          : AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isExpired ? AppColors.actionShutdown : AppColors.primary)
                            .withValues(alpha: 0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isExpired ? 'PAIRING CODE EXPIRED' : 'YOUR 6-DIGIT PAIRING CODE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: isExpired
                              ? AppColors.actionShutdown
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // 6-digit display
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _buildDigitBoxes(_code!, isExpired),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Countdown timer bar
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isExpired ? 'Expired' : 'Expires in',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                DateFormatter.formatCountdown(_secondsRemaining),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isExpired
                                      ? AppColors.actionShutdown
                                      : _secondsRemaining < 60
                                          ? AppColors.statusConnecting
                                          : AppColors.textPrimary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isExpired
                                    ? AppColors.actionShutdown
                                    : _secondsRemaining < 60
                                        ? AppColors.statusConnecting
                                        : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons (Copy / Refresh)
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: _isCopied ? 'Copied' : 'Copy Code',
                              icon: _isCopied
                                  ? Icons.check_circle_rounded
                                  : Icons.copy_rounded,
                              variant: isExpired
                                  ? AppButtonVariant.outlined
                                  : AppButtonVariant.secondary,
                              onPressed: isExpired ? null : _copyToClipboard,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              text: 'New Code',
                              icon: Icons.refresh_rounded,
                              variant: isExpired
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.outlined,
                              onPressed: _fetchPairingCode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDigitBoxes(String code, bool isExpired) {
    final digits = code.replaceAll(' ', '').split('');
    final widgets = <Widget>[];

    for (int i = 0; i < digits.length; i++) {
      widgets.add(
        Container(
          width: 44,
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpired
                  ? AppColors.actionShutdown.withValues(alpha: 0.4)
                  : AppColors.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              digits[i],
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isExpired ? AppColors.textMuted : AppColors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildInstructionStep({required String step, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
