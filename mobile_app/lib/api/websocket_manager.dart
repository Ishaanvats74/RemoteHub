import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/ws_message.dart';
import 'token_storage.dart';

enum WsConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class QueuedCommand {
  final String deviceId;
  final WsCommandType command;
  final Completer<void> completer;

  QueuedCommand({
    required this.deviceId,
    required this.command,
    required this.completer,
  });
}

class WebSocketManager {
  final TokenStorage tokenStorage;
  final String Function() getBaseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  WsConnectionStatus _status = WsConnectionStatus.disconnected;
  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;

  final StreamController<WsConnectionStatus> _statusController =
      StreamController<WsConnectionStatus>.broadcast();

  final StreamController<WsIncomingMessage> _messageController =
      StreamController<WsIncomingMessage>.broadcast();

  final List<QueuedCommand> _pendingCommands = [];

  WebSocketManager({
    required this.tokenStorage,
    required this.getBaseUrl,
  });

  // -------------------------------------------------
  // Status / Streams
  // -------------------------------------------------

  WsConnectionStatus get status => _status;

  Stream<WsConnectionStatus> get statusStream =>
      _statusController.stream;

  Stream<WsIncomingMessage> get messageStream =>
      _messageController.stream;

  Stream<WsCommandResultMessage> get commandResultStream =>
      _messageController.stream
          .where((msg) => msg is WsCommandResultMessage)
          .cast<WsCommandResultMessage>();

  Stream<WsTelemetryMessage> get telemetryStream =>
      _messageController.stream
          .where((msg) => msg is WsTelemetryMessage)
          .cast<WsTelemetryMessage>();

  Stream<WsDeviceStatusMessage> get deviceStatusStream =>
      _messageController.stream
          .where((msg) => msg is WsDeviceStatusMessage)
          .cast<WsDeviceStatusMessage>();

  // NEW: pairing-success messages
  Stream<WsDevicePairedMessage> get devicePairedStream =>
      _messageController.stream
          .where((msg) => msg is WsDevicePairedMessage)
          .cast<WsDevicePairedMessage>();

  // -------------------------------------------------
  // Connection Status
  // -------------------------------------------------

  void _updateStatus(WsConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);

      debugPrint(
        '[WebSocket] Status changed to: $newStatus',
      );
    }
  }

  // -------------------------------------------------
  // Build WebSocket URL
  // -------------------------------------------------

  Uri _buildWsUri() {
    final httpBase = getBaseUrl();
    final uri = Uri.parse(httpBase);

    final wsScheme =
        uri.scheme == 'https' ? 'wss' : 'ws';

    return uri.replace(
      scheme: wsScheme,
      path: '/ws/mobile',
    );
  }

  // -------------------------------------------------
  // Connect
  // -------------------------------------------------

  Future<void> connect() async {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();

    final token = await tokenStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      debugPrint(
        '[WebSocket] Cannot connect: no access token available',
      );

      _updateStatus(
        WsConnectionStatus.disconnected,
      );

      return;
    }

    if (_status == WsConnectionStatus.connected ||
        _status == WsConnectionStatus.connecting) {
      return;
    }

    _updateStatus(
      _reconnectAttempts > 0
          ? WsConnectionStatus.reconnecting
          : WsConnectionStatus.connecting,
    );

    final wsUri = _buildWsUri();

    debugPrint(
      '[WebSocket] Connecting to $wsUri...',
    );

    try {
      _channel = WebSocketChannel.connect(wsUri);

      await _channel!.ready;

      // -------------------------------------------------
      // Authenticate as first WebSocket message
      // -------------------------------------------------

      final authPayload = jsonEncode({
        'token': token,
      });

      _channel!.sink.add(authPayload);

      debugPrint(
        '[WebSocket] Auth token handshake sent',
      );

      _reconnectAttempts = 0;

      _updateStatus(
        WsConnectionStatus.connected,
      );

      // -------------------------------------------------
      // Listen for incoming messages
      // -------------------------------------------------

      _subscription = _channel!.stream.listen(
        _handleIncomingData,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      // Send commands that were queued while disconnected.
      _flushPendingCommands();
    } catch (e) {
      debugPrint(
        '[WebSocket] Connection failed: $e',
      );

      _scheduleReconnect();
    }
  }

  // -------------------------------------------------
  // Incoming WebSocket Messages
  // -------------------------------------------------

  void _handleIncomingData(dynamic rawData) {
    try {
      final String stringData =
          rawData.toString();

      debugPrint(
        '[WebSocket] Received: $stringData',
      );

      final decoded =
          jsonDecode(stringData);

      if (decoded is Map<String, dynamic>) {
        final message =
            WsIncomingMessage.fromJson(decoded);

        // Everything goes through the central
        // broadcast stream.
        _messageController.add(message);

        // Optional debug logging for pairing.
        if (message is WsDevicePairedMessage) {
          debugPrint(
            '[WebSocket] Device paired: '
            '${message.hostname} '
            '(${message.deviceId})',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[WebSocket] Error parsing message: '
        '$e (Raw: $rawData)',
      );
    }
  }

  // -------------------------------------------------
  // WebSocket Error
  // -------------------------------------------------

  void _handleError(dynamic error) {
    debugPrint(
      '[WebSocket] Stream error: $error',
    );

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  // -------------------------------------------------
  // WebSocket Closed
  // -------------------------------------------------

  void _handleDone() {
    debugPrint(
      '[WebSocket] Connection closed '
      '(Code: ${_channel?.closeCode}, '
      'Reason: ${_channel?.closeReason})',
    );

    final code =
        _channel?.closeCode;

    _subscription?.cancel();
    _channel = null;

    if (code == 1008) {
      // 1008 = Policy Violation.
      // Your backend uses this when the
      // authentication token is invalid.

      debugPrint(
        '[WebSocket] Closed with 1008 '
        '(Unauthorized token)',
      );

      _updateStatus(
        WsConnectionStatus.disconnected,
      );

      return;
    }

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    } else {
      _updateStatus(
        WsConnectionStatus.disconnected,
      );
    }
  }

  // -------------------------------------------------
  // Reconnect
  // -------------------------------------------------

  void _scheduleReconnect() {
    _subscription?.cancel();
    _channel = null;

    if (_intentionalDisconnect) {
      _updateStatus(
        WsConnectionStatus.disconnected,
      );

      return;
    }

    _updateStatus(
      WsConnectionStatus.reconnecting,
    );

    _reconnectAttempts++;

    // Exponential backoff:
    // 1s → 2s → 4s → 8s → 16s → 30s
    // plus a small random jitter.

    final backoffSeconds = min(
      30,
      pow(
        2,
        min(
          _reconnectAttempts - 1,
          5,
        ),
      ).toInt(),
    );

    final jitterMs =
        Random().nextInt(500);

    final delay = Duration(
      seconds: backoffSeconds,
      milliseconds: jitterMs,
    );

    debugPrint(
      '[WebSocket] Reconnecting in '
      '${delay.inSeconds}s '
      '(Attempt $_reconnectAttempts)...',
    );

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(
      delay,
      () {
        connect();
      },
    );
  }

  // -------------------------------------------------
  // Send Command
  // -------------------------------------------------

  /// Sends a remote-control command to the target
  /// desktop device.
  ///
  /// If the WebSocket is disconnected, the command
  /// is queued and sent after reconnection.
  Future<void> sendCommand(
    String deviceId,
    WsCommandType command,
  ) async {
    final payload = {
      'type': 'command',
      'device_id': deviceId,
      'command': command.value,
    };

    if (_status ==
            WsConnectionStatus.connected &&
        _channel != null) {
      final jsonString =
          jsonEncode(payload);

      _channel!.sink.add(
        jsonString,
      );

      debugPrint(
        '[WebSocket] Sent command: '
        '$jsonString',
      );

      return;
    }

    // -------------------------------------------------
    // Queue while disconnected
    // -------------------------------------------------

    debugPrint(
      '[WebSocket] Disconnected. '
      'Queuing command: ${command.value} '
      'for device: $deviceId',
    );

    final completer =
        Completer<void>();

    _pendingCommands.add(
      QueuedCommand(
        deviceId: deviceId,
        command: command,
        completer: completer,
      ),
    );

    // Trigger a connection if currently idle.
    if (_status ==
        WsConnectionStatus.disconnected) {
      connect();
    }

    return completer.future;
  }

  // -------------------------------------------------
  // Flush Pending Commands
  // -------------------------------------------------

  void _flushPendingCommands() {
    if (_pendingCommands.isEmpty) {
      return;
    }

    debugPrint(
      '[WebSocket] Flushing '
      '${_pendingCommands.length} '
      'queued command(s)...',
    );

    final toSend =
        List<QueuedCommand>.from(
      _pendingCommands,
    );

    _pendingCommands.clear();

    for (final item in toSend) {
      try {
        final payload = jsonEncode({
          'type': 'command',
          'device_id': item.deviceId,
          'command': item.command.value,
        });

        _channel?.sink.add(
          payload,
        );

        item.completer.complete();

        debugPrint(
          '[WebSocket] Delivered queued command: '
          '${item.command.value}',
        );
      } catch (e) {
        item.completer.completeError(e);
      }
    }
  }

  // -------------------------------------------------
  // Disconnect
  // -------------------------------------------------

  void disconnect() {
    _intentionalDisconnect = true;

    _reconnectTimer?.cancel();
    _subscription?.cancel();

    _channel?.sink.close();
    _channel = null;

    _pendingCommands.clear();
    _reconnectAttempts = 0;

    _updateStatus(
      WsConnectionStatus.disconnected,
    );

    debugPrint(
      '[WebSocket] Disconnected intentionally',
    );
  }

  // -------------------------------------------------
  // Dispose
  // -------------------------------------------------

  void dispose() {
    disconnect();

    _statusController.close();
    _messageController.close();
  }
}