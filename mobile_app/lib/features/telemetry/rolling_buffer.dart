import 'dart:collection';

import '../../models/telemetry_model.dart';
import '../telemetry/telemetry_mapper.dart';

/// Per-device rolling telemetry buffer.
///
/// Holds the last [maxSize] samples in insertion order.
/// Thread-safe for single-isolate use (Flutter main isolate).
class RollingTelemetryBuffer {
  final int maxSize;
  final Queue<MappedTelemetry> _buffer;

  RollingTelemetryBuffer({this.maxSize = 120}) : _buffer = Queue<MappedTelemetry>();

  void add(TelemetryModel raw) {
    final mapped = TelemetryMapper.map(raw);
    _buffer.addLast(mapped);
    while (_buffer.length > maxSize) {
      _buffer.removeFirst();
    }
  }

  List<MappedTelemetry> get samples => List.unmodifiable(_buffer);

  MappedTelemetry? get latest => _buffer.isEmpty ? null : _buffer.last;

  int get length => _buffer.length;

  bool get isEmpty => _buffer.isEmpty;

  void clear() => _buffer.clear();

  /// Extract a time-series for a single metric.
  List<double?> getTimeSeries(double? Function(MappedTelemetry) selector) {
    return _buffer.map(selector).toList();
  }
}
