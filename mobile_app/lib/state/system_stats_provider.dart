import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import '../models/hardware_specs.dart';
import '../models/live_stats.dart';
import '../services/system_stats_service.dart';

class SystemStatsProvider with ChangeNotifier {
  final SystemStatsService _service;

  HardwareSpecs? _hardwareSpecs;
  LiveStats? _currentStats;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  bool _isLoading = true;

  final List<double> _cpuValues = [];
  final List<double> _ramValues = [];

  List<FlSpot> _cpuHistory = [];
  List<FlSpot> _ramHistory = [];

  StreamSubscription<LiveStats>? _statsSubscription;
  StreamSubscription<ConnectionStatus>? _statusSubscription;

  HardwareSpecs? get hardwareSpecs => _hardwareSpecs;
  LiveStats? get currentStats => _currentStats;
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isLoading => _isLoading;
  List<FlSpot> get cpuHistory => List.unmodifiable(_cpuHistory);
  List<FlSpot> get ramHistory => List.unmodifiable(_ramHistory);

  SystemStatsProvider({SystemStatsService? service})
      : _service = service ?? SystemStatsService();

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // 1. Fetch hardware specs once on startup
    _hardwareSpecs = await _service.fetchHardwareSpecs();

    // 2. Listen to connection status
    _statusSubscription = _service.statusStream.listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });

    // 3. Listen to live stats stream
    _statsSubscription = _service.statsStream.listen((stats) {
      _updateStats(stats);
    });

    // 4. Connect WebSocket
    _service.connectWebSocket();
  }

  void _updateStats(LiveStats stats) {
    _currentStats = stats;
    _isLoading = false;

    // Buffer CPU usage (max 60 points = 60 seconds)
    _cpuValues.add(stats.cpu.usage);
    if (_cpuValues.length > 60) {
      _cpuValues.removeAt(0);
    }
    _cpuHistory = [
      for (int i = 0; i < _cpuValues.length; i++)
        FlSpot(i.toDouble(), _cpuValues[i]),
    ];

    // Buffer RAM usage (max 60 points = 60 seconds)
    _ramValues.add(stats.memory.usage);
    if (_ramValues.length > 60) {
      _ramValues.removeAt(0);
    }
    _ramHistory = [
      for (int i = 0; i < _ramValues.length; i++)
        FlSpot(i.toDouble(), _ramValues[i]),
    ];

    notifyListeners();
  }

  Future<void> refreshHardwareSpecs() async {
    final specs = await _service.fetchHardwareSpecs();
    _hardwareSpecs = specs;
    notifyListeners();
  }

  void reconnect() {
    _service.connectWebSocket();
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _statusSubscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
