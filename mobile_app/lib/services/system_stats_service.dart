import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/hardware_specs.dart';
import '../models/live_stats.dart';

enum ConnectionStatus {
  connecting,
  connected,
  disconnected,
}

class SystemStatsService {
  final String httpBaseUrl;
  final String wsUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  final _statsController = StreamController<LiveStats>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  Stream<LiveStats> get statsStream => _statsController.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  SystemStatsService({
    this.httpBaseUrl = 'http://127.0.0.1:8000',
    this.wsUrl = 'ws://127.0.0.1:8000/ws/stats',
  });

  void _setStatus(ConnectionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    }
  }

  /// Fetch static hardware specifications once
  Future<HardwareSpecs> fetchHardwareSpecs() async {
    final uri = Uri.parse('$httpBaseUrl/stats/hardware');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return HardwareSpecs.fromJson(decoded);
        }
      }
      debugPrint('Hardware specs returned ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching hardware specs: $e');
    }
    return HardwareSpecs.empty();
  }

  /// Connect to the live telemetry WebSocket stream with auto-reconnect
  void connectWebSocket() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    _setStatus(ConnectionStatus.connecting);
    debugPrint('Connecting to WebSocket: $wsUrl');

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (message) {
          _setStatus(ConnectionStatus.connected);
          try {
            final decoded = json.decode(message.toString());
            if (decoded is Map<String, dynamic>) {
              final stats = LiveStats.fromJson(decoded);
              if (!_statsController.isClosed) {
                _statsController.add(stats);
              }
            }
          } catch (e) {
            debugPrint('Error parsing incoming stats JSON: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Error creating WebSocket channel: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _setStatus(ConnectionStatus.disconnected);
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDisposed && _currentStatus != ConnectionStatus.connected) {
        debugPrint('Attempting WebSocket reconnect...');
        connectWebSocket();
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _statsController.close();
    _statusController.close();
  }
}
