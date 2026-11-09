import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/websocket_state.dart';

/// A hidden debug screen accessible from Settings (long-press on version).
/// Shows the last raw JSON received for each WebSocket message type.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsManager = ref.watch(webSocketManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Debug – Raw WebSocket Messages'),
        backgroundColor: AppColors.background,
      ),
      body: StreamBuilder(
        stream: wsManager.messageStream,
        builder: (context, snapshot) {
          final msg = snapshot.data;
          if (msg == null) {
            return const Center(
              child: Text('Waiting for WebSocket messages...',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return _DebugMessageView(message: msg);
        },
      ),
    );
  }
}

class _DebugMessageView extends StatefulWidget {
  final dynamic message;
  const _DebugMessageView({required this.message});

  @override
  State<_DebugMessageView> createState() => _DebugMessageViewState();
}

class _DebugMessageViewState extends State<_DebugMessageView> {
  // Keep a rolling log of the last 20 raw messages.
  final List<String> _log = [];

  @override
  void didUpdateWidget(_DebugMessageView old) {
    super.didUpdateWidget(old);
    if (widget.message != old.message) {
      final raw = _toJsonString(widget.message);
      if (raw != null) {
        setState(() {
          _log.insert(0, raw);
          if (_log.length > 20) _log.removeLast();
        });
      }
    }
  }

  String? _toJsonString(dynamic msg) {
    try {
      if (msg == null) return null;
      // Use toString / reflection-safe approach.
      final map = <String, dynamic>{
        'type': msg.runtimeType.toString(),
        'payload': msg.toString(),
      };
      return const JsonEncoder.withIndent('  ').convert(map);
    } catch (_) {
      return msg.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_log.isEmpty) {
      return const Center(
        child: Text('No messages yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _log.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.surfaceBorder),
      itemBuilder: (_, i) {
        final entry = _log[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Message #${_log.length - i}',
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: AppColors.textMuted),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: SelectableText(
                entry,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
