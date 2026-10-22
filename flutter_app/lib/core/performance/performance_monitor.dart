import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'frame_metrics.dart';

/// Explicit opt-in for physical-device profile runs. No user/network data.
class PerformanceMonitor with WidgetsBindingObserver {
  PerformanceMonitor._();
  static final _instance = PerformanceMonitor._();
  final _frames = FrameMetrics();
  final _interval = Stopwatch();
  bool _installed = false;
  bool _active = true;

  static void installIfEnabled() {
    if (!kProfileMode || !const bool.fromEnvironment('PERF_METRICS')) return;
    final monitor = _instance;
    if (monitor._installed) return;
    monitor._installed = true;
    monitor._interval.start();
    WidgetsBinding.instance.addObserver(monitor);
    SchedulerBinding.instance.addTimingsCallback(monitor._record);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _frames.clear();
    _interval.reset();
  }

  void _record(List<FrameTiming> timings) {
    if (!_active) return;
    for (final timing in timings) {
      _frames.add(
        buildMicros: timing.buildDuration.inMicroseconds,
        rasterMicros: timing.rasterDuration.inMicroseconds,
      );
    }
    if (_interval.elapsed < const Duration(seconds: 10)) return;
    final rate =
        PlatformDispatcher.instance.implicitView?.display.refreshRate ?? 60;
    debugPrint('NUTRIMIND_PERF ${jsonEncode(_frames.report(rate))}');
    _frames.clear();
    _interval.reset();
  }
}
