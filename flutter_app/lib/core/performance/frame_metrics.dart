import 'dart:collection';
import 'dart:math' as math;

/// Bounded window of frame phase timings, not an estimate of displayed FPS.
class FrameMetrics {
  FrameMetrics({this.capacity = 600}) : assert(capacity > 0);
  final int capacity;
  final _samples = ListQueue<(int, int)>();

  void add({required int buildMicros, required int rasterMicros}) {
    if (_samples.length == capacity) _samples.removeFirst();
    _samples.add((buildMicros, rasterMicros));
  }

  void clear() => _samples.clear();
  int get length => _samples.length;

  Map<String, Object> report(double refreshRate) {
    final hz = refreshRate.isFinite && refreshRate > 0 ? refreshRate : 60.0;
    final budget = 1000000 / hz;
    final builds = _samples.map((s) => s.$1).toList()..sort();
    final rasters = _samples.map((s) => s.$2).toList()..sort();
    double percentile(List<int> values, double q) => values.isEmpty
        ? 0
        : values[math.max(0, (values.length * q).ceil() - 1)] / 1000;
    return {
      'sampled_frames': length,
      'display_hz': hz,
      'frame_budget_ms': budget / 1000,
      'build_p50_ms': percentile(builds, .50),
      'build_p95_ms': percentile(builds, .95),
      'raster_p50_ms': percentile(rasters, .50),
      'raster_p95_ms': percentile(rasters, .95),
      'build_max_ms': percentile(builds, 1),
      'raster_max_ms': percentile(rasters, 1),
      // UI/raster stages are pipelined: do not sum their durations.
      'over_budget_frames': _samples
          .where((s) => s.$1 > budget || s.$2 > budget)
          .length,
    };
  }
}
