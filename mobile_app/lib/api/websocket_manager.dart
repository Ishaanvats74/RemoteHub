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

  WsConnectionStatus get status => _status;
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;
  Stream<WsIncomingMessage> get messageStream => _messageController.stream;

  Stream<WsCommandResultMessage> get commandResultStream => _messageController.stream
      .where((msg) => msg is WsCommandResultMessage)
      .cast<WsCommandResultMessage>();

  Stream<WsTelemetryMessage> get telemetryStream => _messageController.stream
      .where((msg) => msg is WsTelemetryMessage)
      .cast<WsTelemetryMessage>();

  Stream<WsDeviceStatusMessage> get deviceStatusStream => _messageController.stream
      .where((msg) => msg is WsDeviceStatusMessage)
      .cast<WsDeviceStatusMessage>();

  void _updateStatus(WsConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
      debugPrint('[WebSocket] Status changed to: $newStatus');
    }
  }

  Uri _buildWsUri() {
    final httpBase = getBaseUrl();
    final uri = Uri.parse(httpBase);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(
      scheme: wsScheme,
      path: '/ws/mobile',
    );
  }

  Future<void> connect() async {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();

    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[WebSocket] Cannot connect: no access token available');
      _updateStatus(WsConnectionStatus.disconnected);
      return;
    }

    if (_status == WsConnectionStatus.connected || _status == WsConnectionStatus.connecting) {
      return;
    }

    _updateStatus(_reconnectAttempts > 0
        ? WsConnectionStatus.reconnecting
        : WsConnectionStatus.connecting);

    final wsUri = _buildWsUri();
    debugPrint('[WebSocket] Connecting to $wsUri...');

    try {
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      // Authenticate as first message
      final authPayload = jsonEncode({'token': token});
      _channel!.sink.add(authPayload);
      debugPrint('[WebSocket] Auth token handshake sent');

      _reconnectAttempts = 0;
      _updateStatus(WsConnectionStatus.connected);

      _subscription = _channel!.stream.listen(
        _handleIncomingData,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      // Flush queued commands
      _flushPendingCommands();
    } catch (e) {
      debugPrint('[WebSocket] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleIncomingData(dynamic rawData) {
    try {
      final String stringData = rawData.toString();
      debugPrint('[WebSocket] Received: $stringData');

      final decoded = jsonDecode(stringData);
      if (decoded is Map<String, dynamic>) {
        final message = WsIncomingMessage.fromJson(decoded);
        _messageController.add(message);
      }
    } catch (e) {
      debugPrint('[WebSocket] Error parsing message: $e (Raw: $rawData)');
      // Guarded JSON parsing ensures app will never crash
    }
  }

  void _handleError(dynamic error) {
    debugPrint('[WebSocket] Stream error: $error');
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleDone() {
    debugPrint('[WebSocket] Connection closed (Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason})');
    final code = _channel?.closeCode;
    _subscription?.cancel();
    _channel = null;

    if (code == 1008) {
      // 1008 = Policy Violation / Bad or missing token
      debugPrint('[WebSocket] Closed with 1008 (Unauthorized token)');
      _updateStatus(WsConnectionStatus.disconnected);
      return;
    }

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    } else {
      _updateStatus(WsConnectionStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _channel = null;

    if (_intentionalDisconnect) {
      _updateStatus(WsConnectionStatus.disconnected);
      return;
    }

    _updateStatus(WsConnectionStatus.reconnecting);
    _reconnectAttempts++;

    // Exponential backoff: min 1s, max 30s + small jitter
    final backoffSeconds = min(30, pow(2, min(_reconnectAttempts - 1, 5)).toInt());
    final jitterMs = Random().nextInt(500);
    final delay = Duration(seconds: backoffSeconds, milliseconds: jitterMs);

    debugPrint('[WebSocket] Reconnecting in ${delay.inSeconds}s (Attempt $_reconnectAttempts)...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  /// Sends a remote control command to the target device.
  /// If disconnected, queues the command to send immediately upon reconnect.
  Future<void> sendCommand(String deviceId, WsCommandType command) async {
    final payload = {
      'type': 'command',
      'device_id': deviceId,
      'command': command.value,
    };

    if (_status == WsConnectionStatus.connected && _channel != null) {
      final jsonString = jsonEncode(payload);
      _channel!.sink.add(jsonString);
      debugPrint('[WebSocket] Sent command: $jsonString');
      return;
    }

    // Queue command for delivery when reconnected
    debugPrint('[WebSocket] Disconnected. Queuing command: ${command.value} for device: $deviceId');
    final completer = Completer<void>();
    _pendingCommands.add(QueuedCommand(
      deviceId: deviceId,
      command: command,
      completer: completer,
    ));

    // If currently disconnected or idle, trigger connection
    if (_status == WsConnectionStatus.disconnected) {
      connect();
    }

    return completer.future;
  }

  void _flushPendingCommands() {
    if (_pendingCommands.isEmpty) return;

    debugPrint('[WebSocket] Flushing ${_pendingCommands.length} queued command(s)...');
    final toSend = List<QueuedCommand>.from(_pendingCommands);
    _pendingCommands.clear();

    for (final item in toSend) {
      try {
        final payload = jsonEncode({
          'type': 'command',
          'device_id': item.deviceId,
          'command': item.command.value,
        });
        _channel?.sink.add(payload);
        item.completer.complete();
        debugPrint('[WebSocket] Delivered queued command: ${item.command.value}');
      } catch (e) {
        item.completer.completeError(e);
      }
    }
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _pendingCommands.clear();
    _reconnectAttempts = 0;
    _updateStatus(WsConnectionStatus.disconnected);
    debugPrint('[WebSocket] Disconnected intentionally');
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
  }
}
