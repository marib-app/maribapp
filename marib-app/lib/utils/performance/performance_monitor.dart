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

  final List<_RoutePerformanceSession> _completedSessions =
      <_RoutePerformanceSession>[];
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
    final List<_RoutePerformanceSession> sessions = <_RoutePerformanceSession>[
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
    List<_RoutePerformanceSession> sessions,
  ) {
    final Map<String, List<_RoutePerformanceSession>> grouped =
        <String, List<_RoutePerformanceSession>>{};
    for (final _RoutePerformanceSession session in sessions) {
      grouped.putIfAbsent(
          session.routeName, () => <_RoutePerformanceSession>[]);
      grouped[session.routeName]!.add(session);
    }

    final Map<String, dynamic> summary = <String, dynamic>{};
    grouped.forEach((String routeName, List<_RoutePerformanceSession> records) {
      summary[routeName] = <String, dynamic>{
        'sessions': records.map((e) => e.toJson()).toList(),
        'aggregated': _aggregateSessions(records),
      };
    });
    return summary;
  }

  Map<String, dynamic> _aggregateSessions(
      List<_RoutePerformanceSession> sessions) {
    final List<double> frameTimes = <double>[];
    int totalFrames = 0;
    int droppedFrames = 0;
    double totalFrameTimeMs = 0;

    for (final _RoutePerformanceSession session in sessions) {
      frameTimes.addAll(session.frameDurationsMs);
      totalFrames += session.totalFrames;
      droppedFrames += session.droppedFrames;
      totalFrameTimeMs += session.frameDurationsMs.fold<double>(
        0,
        (double a, double b) => a + b,
      );
    }

    final double? p50 = _percentile(frameTimes, 0.50);
    final double? p95 = _percentile(frameTimes, 0.95);
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
      _completedSessions.add(_currentSession!.snapshot());
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

  static double? _percentile(List<double> values, double percentile) {
    if (values.isEmpty) {
      return null;
    }
    final List<double> sorted = List<double>.from(values)..sort();
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
  final List<double> frameDurationsMs = <double>[];
  final DateTime wallClockStartedAt;

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
    frameDurationsMs.add(timing.totalSpan.inMicroseconds / 1000.0);
    droppedFrames += PerformanceMonitor.countDroppedFrames(timing.totalSpan);
    _firstFrameUs ??= buildStartUs;
    _firstMeaningfulFrameUs ??= rasterFinishUs;
  }

  _RoutePerformanceSession snapshot() {
    final _RoutePerformanceSession copy = _RoutePerformanceSession(
      routeName: routeName,
      startedAtUs: startedAtUs,
      wallClockStartedAt: wallClockStartedAt,
    );
    copy.frameDurationsMs.addAll(frameDurationsMs);
    copy.totalFrames = totalFrames;
    copy.droppedFrames = droppedFrames;
    copy._firstFrameUs = _firstFrameUs;
    copy._firstMeaningfulFrameUs = _firstMeaningfulFrameUs;
    return copy;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'routeName': routeName,
      'startedAt': wallClockStartedAt.toIso8601String(),
      'frames': totalFrames,
      'droppedFrames': droppedFrames,
      'averageFps': frameDurationsMs.isEmpty
          ? 0
          : (totalFrames * 1000) /
              frameDurationsMs.fold<double>(0, (double a, double b) => a + b),
      'p50FrameMs': PerformanceMonitor._percentile(frameDurationsMs, 0.50),
      'p95FrameMs': PerformanceMonitor._percentile(frameDurationsMs, 0.95),
      'ttffMs': PerformanceMonitor.instance
          ._computeDurationMs(startedAtUs, _firstFrameUs),
      'fmpMs': PerformanceMonitor.instance
          ._computeDurationMs(startedAtUs, _firstMeaningfulFrameUs),
    };
  }
}
