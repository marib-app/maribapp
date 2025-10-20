import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:marib/settings.dart';

class PerformanceMonitor {
  PerformanceMonitor._();

  static final PerformanceMonitor instance = PerformanceMonitor._();

  static const _frameBudget = Duration(microseconds: 16667);
  static const _startupRouteName = '__startup__';
  static const bool _envCollectionEnabled = bool.fromEnvironment(
    'MARIB_ENABLE_PERFORMANCE_MONITOR',
    defaultValue: false,
  );

  static const int _maxCompletedSessions = 10;

  final List<_RoutePerformanceSnapshot> _completedSessions =
      <_RoutePerformanceSnapshot>[];
  _RoutePerformanceSession? _currentSession;
  Stopwatch? _monotonicClock;
  int? _engineTimestampOffsetUs;

  int? _appStartUs;
  int? _firstFrameUs;
  int? _firstMeaningfulPaintUs;
  String? _currentRouteName;
  bool _initialized = false;

  Timer? _pendingWrite;

  bool get shouldCollectMetrics {
    if (_envCollectionEnabled) {
      return true;
    }
    if (kReleaseMode) {
      return false;
    }
    if (kDebugMode || kProfileMode) {
      return AppSettings.enablePerfLogging;
    }
    return false;
  }

  void initialize() {
    if (!shouldCollectMetrics) {
      return;
    }
    if (_initialized) {
      return;
    }
    _initialized = true;
    _monotonicClock ??= Stopwatch()..start();
    final int now = _elapsedUs();

    _appStartUs = now;
    _currentSession = _RoutePerformanceSession(
      routeName: _startupRouteName,
      startedAtUs: now,
      wallClockStartedAt: DateTime.now(),
    );
  }

  void handleFrameTimings(List<FrameTiming> timings) {
    if (!shouldCollectMetrics) {
      return;
    }
    if (!_initialized) {
      initialize();
    }
    if (_currentSession == null) {
      _currentSession = _RoutePerformanceSession(
        routeName: _currentRouteName ?? _startupRouteName,
        startedAtUs: _elapsedUs(),
        wallClockStartedAt: DateTime.now(),
      );
    }

    for (final FrameTiming timing in timings) {
      final int buildStartEngineUs =
          timing.timestampInMicroseconds(FramePhase.buildStart);
      final int rasterFinishEngineUs =
          timing.timestampInMicroseconds(FramePhase.rasterFinish);

      final int buildStartUs = _convertEngineTimestamp(buildStartEngineUs);
      final int rasterFinishUs = _convertEngineTimestamp(rasterFinishEngineUs);

      _firstFrameUs ??= buildStartUs;
      _firstMeaningfulPaintUs ??= rasterFinishUs;

      _currentSession!.recordFrame(
        timing: timing,
        buildStartUs: buildStartUs,
        rasterFinishUs: rasterFinishUs,
      );
    }

    _scheduleReportWrite();
  }

  void onRoutePushed(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!shouldCollectMetrics) {
      return;
    }
    _switchRoute(route.settings.name ?? route.runtimeType.toString());
  }

  void onRouteReplaced(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    if (!shouldCollectMetrics) {
      return;
    }
    if (newRoute != null) {
      _switchRoute(newRoute.settings.name ?? newRoute.runtimeType.toString());
    }
  }

  void onRoutePopped(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!shouldCollectMetrics) {
      return;
    }
    if (previousRoute != null) {
      _switchRoute(
          previousRoute.settings.name ?? previousRoute.runtimeType.toString());
    } else {
      _endCurrentSession();
      _currentRouteName = null;
    }
  }

  Future<void> saveReport() async {
    if (!shouldCollectMetrics) {
      return;
    }
    final file = await _resolveLogFile();
    final List<_RoutePerformanceSnapshot> sessions =
        <_RoutePerformanceSnapshot>[
      ..._completedSessions,
      if (_currentSession != null) _currentSession!.snapshot(),
    ];

    final Map<String, dynamic> payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'ttffMs': _computeDurationMs(_appStartUs, _firstFrameUs),
      'fmpMs': _computeDurationMs(_appStartUs, _firstMeaningfulPaintUs),
      'routes': _groupSessionsByRoute(sessions),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
    debugPrint('Performance metrics written to: ${file.path}');
  }

  Map<String, dynamic> _groupSessionsByRoute(
    List<_RoutePerformanceSnapshot> sessions,
  ) {
    final Map<String, List<_RoutePerformanceSnapshot>> grouped =
        <String, List<_RoutePerformanceSnapshot>>{};
    for (final _RoutePerformanceSnapshot session in sessions) {
      grouped.putIfAbsent(
          session.routeName, () => <_RoutePerformanceSnapshot>[]);
      grouped[session.routeName]!.add(session);
    }

    final Map<String, dynamic> summary = <String, dynamic>{};
    grouped
        .forEach((String routeName, List<_RoutePerformanceSnapshot> records) {
      summary[routeName] = <String, dynamic>{
        'sessions': records.map((e) => e.toJson()).toList(),
        'aggregated': _aggregateSessions(records),
      };
    });
    return summary;
  }

  Map<String, dynamic> _aggregateSessions(
      List<_RoutePerformanceSnapshot> sessions) {
    int totalFrames = 0;
    int droppedFrames = 0;
    double totalFrameTimeMs = 0;

    double weightedP50 = 0;
    double weightedP95 = 0;
    double p50Weight = 0;
    double p95Weight = 0;

    for (final _RoutePerformanceSnapshot session in sessions) {
      totalFrames += session.totalFrames;
      droppedFrames += session.droppedFrames;
      totalFrameTimeMs += session.totalFrameTimeMs;

      if (session.p50FrameMs != null && session.totalFrames > 0) {
        weightedP50 += session.p50FrameMs! * session.totalFrames;
        p50Weight += session.totalFrames;
      }
      if (session.p95FrameMs != null && session.totalFrames > 0) {
        weightedP95 += session.p95FrameMs! * session.totalFrames;
        p95Weight += session.totalFrames;
      }
    }

    final double? p50 = p50Weight == 0 ? null : weightedP50 / p50Weight;
    final double? p95 = p95Weight == 0 ? null : weightedP95 / p95Weight;
    final double averageFps =
        totalFrameTimeMs == 0 ? 0 : (totalFrames * 1000) / totalFrameTimeMs;

    return <String, dynamic>{
      'totalFrames': totalFrames,
      'droppedFrames': droppedFrames,
      'averageFps': averageFps,
      'p50FrameMs': p50,
      'p95FrameMs': p95,
    };
  }

  void _switchRoute(String routeName) {
    if (_currentRouteName == routeName) {
      return;
    }
    _endCurrentSession();
    _currentRouteName = routeName;
    _currentSession = _RoutePerformanceSession(
      routeName: routeName,
      startedAtUs: _elapsedUs(),
      wallClockStartedAt: DateTime.now(),
    );
  }

  void _endCurrentSession() {
    if (_currentSession != null) {
      final _RoutePerformanceSnapshot snapshot =
          _currentSession!.snapshot(finalize: true);
      _completedSessions.add(snapshot);
      if (_completedSessions.length > _maxCompletedSessions) {
        _completedSessions.removeRange(
            0, _completedSessions.length - _maxCompletedSessions);
      }
      _currentSession = null;
      _scheduleReportWrite();
    }
  }

  Duration get _reportWriteInterval {
    if (_envCollectionEnabled && kReleaseMode) {
      return const Duration(seconds: 10);
    }
    if (!kReleaseMode && AppSettings.enablePerfLogging) {
      return const Duration(seconds: 5);
    }
    return const Duration(seconds: 1);
  }

  void _scheduleReportWrite() {
    if (!shouldCollectMetrics) {
      return;
    }
    _pendingWrite ??= Timer(_reportWriteInterval, () {
      _pendingWrite = null;
      unawaited(saveReport());
    });
  }

  int _elapsedUs() {
    _monotonicClock ??= Stopwatch()..start();
    return _monotonicClock!.elapsedMicroseconds;
  }

  int _convertEngineTimestamp(int engineTimestampUs) {
    _engineTimestampOffsetUs ??= _elapsedUs() - engineTimestampUs;
    return engineTimestampUs + _engineTimestampOffsetUs!;
  }

  Future<File> _resolveLogFile() async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory logDir = Directory('${dir.path}/performance');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final File file = File('${logDir.path}/metrics.json');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  double? _computeDurationMs(int? startUs, int? endUs) {
    if (startUs == null || endUs == null || endUs < startUs) {
      return null;
    }
    return (endUs - startUs) / 1000.0;
  }

  static double? _percentile(List<double> values, double percentile,
      {bool valuesAreSorted = false}) {
    if (values.isEmpty) {
      return null;
    }
    final List<double> sorted;
    if (valuesAreSorted) {
      sorted = values;
    } else {
      sorted = List<double>.from(values)..sort();
    }

    final double index = percentile * (sorted.length - 1);
    final int lowerIndex = index.floor();
    final int upperIndex = index.ceil();
    if (lowerIndex == upperIndex) {
      return sorted[lowerIndex];
    }
    final double weight = index - lowerIndex;
    return sorted[lowerIndex] * (1 - weight) + sorted[upperIndex] * weight;
  }

  static int countDroppedFrames(Duration frameDuration) {
    if (frameDuration <= _frameBudget) {
      return 0;
    }
    return (frameDuration.inMicroseconds / _frameBudget.inMicroseconds).ceil() -
        1;
  }
}

class _RoutePerformanceSession {
  _RoutePerformanceSession({
    required this.routeName,
    required this.startedAtUs,
    required this.wallClockStartedAt,
  });

  final String routeName;
  final int startedAtUs;
  final DateTime wallClockStartedAt;
  final List<double> _frameDurationsMs = <double>[];

  double _totalFrameTimeMs = 0;
  bool _durationsSorted = false;

  int totalFrames = 0;
  int droppedFrames = 0;
  int? _firstFrameUs;
  int? _firstMeaningfulFrameUs;

  void recordFrame({
    required FrameTiming timing,
    required int buildStartUs,
    required int rasterFinishUs,
  }) {
    totalFrames += 1;
    final double frameDurationMs = timing.totalSpan.inMicroseconds / 1000.0;
    _frameDurationsMs.add(frameDurationMs);
    _totalFrameTimeMs += frameDurationMs;
    _durationsSorted = false;
    droppedFrames += PerformanceMonitor.countDroppedFrames(timing.totalSpan);
    _firstFrameUs ??= buildStartUs;
    _firstMeaningfulFrameUs ??= rasterFinishUs;
  }

  _RoutePerformanceSnapshot snapshot({bool finalize = false}) {
    if (_frameDurationsMs.isNotEmpty && !_durationsSorted) {
      _frameDurationsMs.sort();
      _durationsSorted = true;
    }

    final double? p50 = PerformanceMonitor._percentile(
      _frameDurationsMs,
      0.50,
      valuesAreSorted: true,
    );
    final double? p95 = PerformanceMonitor._percentile(
      _frameDurationsMs,
      0.95,
      valuesAreSorted: true,
    );

    final _RoutePerformanceSnapshot snapshot = _RoutePerformanceSnapshot(
      routeName: routeName,
      startedAtUs: startedAtUs,
      wallClockStartedAt: wallClockStartedAt,
      totalFrames: totalFrames,
      droppedFrames: droppedFrames,
      totalFrameTimeMs: _totalFrameTimeMs,
      p50FrameMs: p50,
      p95FrameMs: p95,
      firstFrameUs: _firstFrameUs,
      firstMeaningfulFrameUs: _firstMeaningfulFrameUs,
    );
    if (finalize) {
      _frameDurationsMs.clear();
      _durationsSorted = false;
      _totalFrameTimeMs = 0;
    }

    return snapshot;
  }
}

class _RoutePerformanceSnapshot {
  const _RoutePerformanceSnapshot({
    required this.routeName,
    required this.startedAtUs,
    required this.wallClockStartedAt,
    required this.totalFrames,
    required this.droppedFrames,
    required this.totalFrameTimeMs,
    required this.p50FrameMs,
    required this.p95FrameMs,
    required this.firstFrameUs,
    required this.firstMeaningfulFrameUs,
  });

  final String routeName;
  final int startedAtUs;
  final DateTime wallClockStartedAt;
  final int totalFrames;
  final int droppedFrames;
  final double totalFrameTimeMs;
  final double? p50FrameMs;
  final double? p95FrameMs;
  final int? firstFrameUs;
  final int? firstMeaningfulFrameUs;

  Map<String, dynamic> toJson() {
    final double averageFps =
        totalFrameTimeMs == 0 ? 0 : (totalFrames * 1000) / totalFrameTimeMs;

    return <String, dynamic>{
      'routeName': routeName,
      'startedAt': wallClockStartedAt.toIso8601String(),
      'frames': totalFrames,
      'droppedFrames': droppedFrames,
      'averageFps': averageFps,
      'p50FrameMs': p50FrameMs,
      'p95FrameMs': p95FrameMs,
      'ttffMs': PerformanceMonitor.instance
          ._computeDurationMs(startedAtUs, firstFrameUs),
      'fmpMs': PerformanceMonitor.instance
          ._computeDurationMs(startedAtUs, firstMeaningfulFrameUs),
    };
  }
}
