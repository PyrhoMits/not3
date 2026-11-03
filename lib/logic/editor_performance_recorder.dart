// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in frame recorder for repeatable editor profiling.
///
/// Enable it with `--dart-define=NOT3_EDITOR_PERF=true` and provide the
/// device refresh rate with `--dart-define=NOT3_REFRESH_HZ=120` when needed.
/// It is disabled by default and never runs in release builds.
class EditorPerformanceRecorder {
  EditorPerformanceRecorder._();

  static final EditorPerformanceRecorder instance =
      EditorPerformanceRecorder._();

  static const bool enabled = bool.fromEnvironment(
    'NOT3_EDITOR_PERF',
    defaultValue: false,
  );
  static const String _refreshHzValue = String.fromEnvironment(
    'NOT3_REFRESH_HZ',
    defaultValue: '60',
  );
  static final double refreshHz = double.tryParse(_refreshHzValue) ?? 60;

  final List<FrameTiming> _frames = [];
  final List<Map<String, Object?>> _markers = [];
  Timer? _reportTimer;
  bool _running = false;

  void start() {
    if (!enabled || kReleaseMode || _running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _reportTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => report('rolling'),
    );
    mark('recorder_start', data: {'refreshHz': refreshHz});
  }

  void stop() {
    if (!_running) return;
    report('editor_close');
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _reportTimer?.cancel();
    _reportTimer = null;
    _running = false;
  }

  void mark(String name, {Map<String, Object?> data = const {}}) {
    if (!enabled || kReleaseMode || !_running) return;
    _markers.add({
      'name': name,
      'atMs': DateTime.now().millisecondsSinceEpoch,
      ...data,
    });
    if (_markers.length > 64) _markers.removeAt(0);
  }

  void _onTimings(List<FrameTiming> timings) {
    _frames.addAll(timings);
    if (_frames.length > 3600) {
      _frames.removeRange(0, _frames.length - 3600);
    }
  }

  void report(String scenario) {
    if (!enabled || kReleaseMode || !_running || _frames.isEmpty) return;
    final builds = [
      for (final frame in _frames) frame.buildDuration.inMicroseconds / 1000,
    ]..sort();
    final rasters = [
      for (final frame in _frames) frame.rasterDuration.inMicroseconds / 1000,
    ]..sort();
    final totals = [
      for (final frame in _frames) frame.totalSpan.inMicroseconds / 1000,
    ];
    final budgetMs = 1000 / refreshHz;
    final missed = totals.where((duration) => duration > budgetMs).length;
    debugPrint(
      'NOT3_EDITOR_PERF ${jsonEncode({'scenario': scenario, 'frames': _frames.length, 'missedFrames': missed, 'frameBudgetMs': budgetMs, 'buildMs': _summary(builds), 'rasterMs': _summary(rasters), 'markers': List<Map<String, Object?>>.from(_markers)})}',
    );
    _frames.clear();
    _markers.clear();
  }

  static Map<String, double> _summary(List<double> sorted) => {
    'p50': _percentile(sorted, 0.50),
    'p95': _percentile(sorted, 0.95),
    'worst': sorted.last,
  };

  static double _percentile(List<double> sorted, double percentile) {
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }
}
