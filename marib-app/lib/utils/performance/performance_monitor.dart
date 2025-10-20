import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:marib/settings.dart';
import 'package:path_provider/path_provider.dart';

import 'frame_stats_accumulator.dart';

class PerformanceMonitor {
  PerformanceMonitor._();

  static final PerformanceMonitor instance = PerformanceMonitor._();

  static const _frameBudget = Duration(microseconds: 16667);
  static const _startupRouteName = '__startup__';
  static const bool _envCollectionEnabled = bool.fromEnvironment(
    'MARIB_ENABLE_PERFORMANCE_MONITOR',
    defaultValue: false,
  );

  bool get isEnvironmentCollectionEnabled => _envCollectionEnabled;

  bool _collectionOverrideEnabled = false;

  bool get isCollectionOverrideEnabled => _collectionOverrideEnabled;

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
  bool _enabled = false;

  Timer? _pendingWrite;

  bool get isEnabled => _enabled;

  bool get shouldCollectMetrics {
    if (_envCollectionEnabled) {
      return true;
    }

    if (_collectionOverrideEnabled) {
      return true;
    }

    if (kReleaseMode) {
      return false;
    }
    if (kDebugMode || kProfileMode) {
      return AppSettings.isPerformanceLoggingEnabled;
    }
    return false;
  }

  bool get _isSchedulingAllowed {
    if (_collectionOverrideEnabled) {
      return true;
    }
    if (_envCollectionEnabled) {
      return true;
    }
    if (!kReleaseMode && AppSettings.isPerformanceLoggingEnabled) {
      return true;
    }
    return false;
  }

  void setManualCollectionEnabled(bool enabled) {
    if (enabled && kReleaseMode && !_envCollectionEnabled) {
      debugPrint(
        'PerformanceMonitor: manual collection cannot be enabled in release builds.',
      );
      return;
    }
    if (_collectionOverrideEnabled == enabled) {
      return;
    }
    _collectionOverrideEnabled = enabled;
    AppSettings.setPerformanceLoggingOverride(enabled);
    if (enabled) {
      initialize();
    } else {
      _updateEnabledState(false);
    }
  }

  void initialize() {
    final bool enable = shouldCollectMetrics;
    _updateEnabledState(enable);
    if (!enable) {
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
      _updateEnabledState(false);
      return;
    }
    _updateEnabledState(true);
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
      _updateEnabledState(false);
      return;
    }
    _updateEnabledState(true);
    _switchRoute(route.settings.name ?? route.runtimeType.toString());
  }

  void onRouteReplaced(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    if (!shouldCollectMetrics) {
      _updateEnabledState(false);
      return;
    }
    _updateEnabledState(true);
    if (newRoute != null) {
      _switchRoute(newRoute.settings.name ?? newRoute.runtimeType.toString());
    }
  }

  void onRoutePopped(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!shouldCollectMetrics) {
      _updateEnabledState(false);
      return;
    }
    _updateEnabledState(true);
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
      _updateEnabledState(false);
      return;
    }
    _updateEnabledState(true);
    final file = await _resolveLogFile();
    final List<_RoutePerformanceSnapshot> sessions = _buildSessionsForReport();

    final Map<String, dynamic> payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'ttffMs': _computeDurationMs(_appStartUs, _firstFrameUs),
      'fmpMs': _computeDurationMs(_appStartUs, _firstMeaningfulPaintUs),
      'routes': _groupSessionsByRoute(sessions),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload));
    debugPrint('Performance metrics written to: ${file.path}');
    _completedSessions.clear();
  }

  List<_RoutePerformanceSnapshot> _buildSessionsForReport() {
    final List<_RoutePerformanceSnapshot> sessions =
        List<_RoutePerformanceSnapshot>.from(_completedSessions);
    if (_currentSession != null) {
      sessions.add(_currentSession!.snapshot());
    }
    if (sessions.length > _maxCompletedSessions) {
      sessions.removeRange(0, sessions.length - _maxCompletedSessions);
    }
    return sessions;
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
    final FrameStatsSummary aggregated = FrameStatsSummary.aggregate(
        sessions.map((session) => session.frameMetrics));

    return <String, dynamic>{
      'totalFrames': aggregated.frameCount,
      'droppedFrames': aggregated.droppedFrames,
      'averageFps': aggregated.averageFps,
      'meanFrameMs': aggregated.meanFrameMs,
      'p50FrameMs': aggregated.p50FrameMs,
      'p95FrameMs': aggregated.p95FrameMs,
      'frameMetrics': aggregated.toJson(),
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
      _enforceCompletedSessionLimit();

      _currentSession = null;
      _scheduleReportWrite();
    }
  }

  void _enforceCompletedSessionLimit() {
    if (_completedSessions.length <= _maxCompletedSessions) {
      return;
    }
    _completedSessions.removeRange(
        0, _completedSessions.length - _maxCompletedSessions);
  }

  Duration get _reportWriteInterval {
    if (_envCollectionEnabled && kReleaseMode) {
      return const Duration(seconds: 10);
    }
    if (!kReleaseMode && AppSettings.isPerformanceLoggingEnabled) {
      return const Duration(seconds: 5);
    }
    return const Duration(seconds: 1);
  }

  void _updateEnabledState(bool enabled) {
    if (_enabled == enabled) {
      if (!enabled) {
        _pendingWrite?.cancel();
        _pendingWrite = null;
      }
      return;
    }
    _enabled = enabled;
    if (!enabled) {
      _pendingWrite?.cancel();
      _pendingWrite = null;
    }
  }

  void _scheduleReportWrite() {
    if (!_enabled || !shouldCollectMetrics || !_isSchedulingAllowed) {
      _pendingWrite?.cancel();
      _pendingWrite = null;
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
  final FrameStatsAccumulator _frameStats = FrameStatsAccumulator();

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
    _frameStats.addSample(frameDurationMs);

    droppedFrames += PerformanceMonitor.countDroppedFrames(timing.totalSpan);
    _firstFrameUs ??= buildStartUs;
    _firstMeaningfulFrameUs ??= rasterFinishUs;
  }

  _RoutePerformanceSnapshot snapshot({bool finalize = false}) {
    final int droppedFrameCount = droppedFrames;
    final FrameStatsSummary frameMetrics = _frameStats.summarize(
      droppedFrames: droppedFrameCount,
      reset: finalize,
    );

    final _RoutePerformanceSnapshot snapshot = _RoutePerformanceSnapshot(
      routeName: routeName,
      startedAtUs: startedAtUs,
      wallClockStartedAt: wallClockStartedAt,
      frameMetrics: frameMetrics,
      firstFrameUs: _firstFrameUs,
      firstMeaningfulFrameUs: _firstMeaningfulFrameUs,
    );
    if (finalize) {
      totalFrames = 0;
      droppedFrames = 0;
    }

    return snapshot;
  }
}

class _RoutePerformanceSnapshot {
  const _RoutePerformanceSnapshot({
    required this.routeName,
    required this.startedAtUs,
    required this.wallClockStartedAt,
    required this.frameMetrics,
    required this.firstFrameUs,
    required this.firstMeaningfulFrameUs,
  });

  final String routeName;
  final int startedAtUs;
  final DateTime wallClockStartedAt;
  final FrameStatsSummary frameMetrics;

  final int? firstFrameUs;
  final int? firstMeaningfulFrameUs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'routeName': routeName,
      'startedAt': wallClockStartedAt.toIso8601String(),
      'frameMetrics': frameMetrics.toJson(),
      'ttffMs': PerformanceMonitor.instance
          ._computeDurationMs(startedAtUs, firstFrameUs),
      'fmpMs': PerformanceMonitor.instance
          ._computeDurationMs(startedAtUs, firstMeaningfulFrameUs),
    };
  }
}
