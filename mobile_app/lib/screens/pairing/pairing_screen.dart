import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/devices_state.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _cancel = CancelToken();

  bool _submitting = false;
  String? _hostname;
  String? _error;
  bool _approved = false;

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    final api = ref.read(devicesApiProvider);
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final request = await api.requestPairing(_code.text, _cancel);
      if (!mounted) return;
      final id = request['session_id'] as String;
      final expiresAt = DateTime.parse(request['expires_at'] as String);
      setState(() => _hostname = request['hostname'] as String);

      while (mounted) {
        if (DateTime.now().isAfter(expiresAt)) {
          throw const PairingFailure(
            'This code expired. Get a new one from your laptop.',
          );
        }
        try {
          final status = await api.getPairingStatus(id, _cancel);
          if (!mounted) return;
          switch (status['status']) {
            case 'denied':
              throw const PairingFailure(
                'The request was declined. Get a new code from your laptop.',
              );
            case 'approved':
              if (status['online'] == true) {
                _finish();
                return;
              }
              if (!_approved) setState(() => _approved = true);
          }
        } on DioException catch (error) {
          if (!mounted || CancelToken.isCancel(error)) return;
          final code = error.response?.statusCode;
          if (code != null && code < 500 && code != 429) rethrow;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } on PairingFailure catch (error) {
      _showError(error.message);
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) {
        _showError(api.apiClient.formatDioError(error));
      }
    } on FormatException {
      _showError('The server returned an invalid pairing response.');
    } on TypeError {
      _showError('The server returned an invalid pairing response.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    if (_approved) {
      _finish();
      return;
    }
    setState(() {
      _submitting = false;
      _hostname = null;
      _error = message;
    });
  }

  void _finish() => Navigator.of(context).pop(true);

  @override
  void dispose() {
    _cancel.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hostname = _hostname;

    return Scaffold(
      appBar: AppBar(title: const Text('Pair a laptop')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: hostname == null
                        ? Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Icon(
                                  Icons.laptop_mac_outlined,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Enter the laptop code',
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Open RemoteHub on your laptop and enter the six digits it displays.',
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _code,
                                  enabled: !_submitting,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  maxLength: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Pairing code',
                                    hintText: '000000',
                                    border: OutlineInputBorder(),
                                    counterText: '',
                                  ),
                                  validator: (value) =>
                                      (value?.length ?? 0) == 6
                                      ? null
                                      : 'Enter all six digits.',
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _submitting ? null : _submit,
                                  child: Text(
                                    _submitting
                                        ? 'Sending request…'
                                        : 'Request connection',
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: CircularProgressIndicator()),
                              const SizedBox(height: 24),
                              Text(
                                _approved
                                    ? 'Connecting to your laptop'
                                    : 'Waiting for approval',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _approved
                                    ? '$hostname approved your request. It will appear online when it connects.'
                                    : 'Select Approve in RemoteHub on $hostname.',
                              ),
                              if (_approved) ...[
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _finish,
                                  child: const Text('Go to devices'),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PairingFailure implements Exception {
  const PairingFailure(this.message);

  final String message;
}
