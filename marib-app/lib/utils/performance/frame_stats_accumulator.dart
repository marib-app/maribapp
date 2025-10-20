import 'package:flutter/foundation.dart';

class FrameStatsAccumulator {
  FrameStatsAccumulator()
      : _p50Estimator = _P2QuantileEstimator(0.50),
        _p95Estimator = _P2QuantileEstimator(0.95);

  final _P2QuantileEstimator _p50Estimator;
  final _P2QuantileEstimator _p95Estimator;

  double _sum = 0;
  int _count = 0;

  void addSample(double value) {
    _sum += value;
    _count += 1;
    _p50Estimator.add(value);
    _p95Estimator.add(value);
  }

  double get sum => _sum;

  int get count => _count;

  double? get mean => _count == 0 ? null : _sum / _count;

  double? get p50 => _p50Estimator.estimate;

  double? get p95 => _p95Estimator.estimate;

  void reset() {
    _sum = 0;
    _count = 0;
    _p50Estimator.reset();
    _p95Estimator.reset();
  }

  @visibleForTesting
  int get debugSampleBufferLength => _p50Estimator.debugSampleBufferLength;
}

class _P2QuantileEstimator {
  _P2QuantileEstimator(this.percentile);

  final double percentile;

  final List<double> _initialSamples = <double>[];
  List<double>? _markerHeights;
  List<int>? _markerPositions;
  List<double>? _desiredMarkerPositions;
  List<double>? _desiredMarkerIncrements;

  bool get _isInitialized => _markerHeights != null;

  void add(double value) {
    if (!_isInitialized) {
      _initialSamples.add(value);
      if (_initialSamples.length == 5) {
        _initializeMarkers();
      }
      return;
    }

    final List<double> markerHeights = _markerHeights!;
    final List<int> markerPositions = _markerPositions!;
    final List<double> desiredPositions = _desiredMarkerPositions!;
    final List<double> desiredIncrements = _desiredMarkerIncrements!;

    int k;
    if (value < markerHeights[0]) {
      markerHeights[0] = value;
      k = 0;
    } else if (value >= markerHeights[4]) {
      markerHeights[4] = value;
      k = 3;
    } else {
      k = 0;
      for (int i = 0; i < 4; i++) {
        if (value < markerHeights[i + 1]) {
          k = i;
          break;
        }
      }
    }

    for (int i = k + 1; i < 5; i++) {
      markerPositions[i] += 1;
    }

    for (int i = 0; i < 5; i++) {
      desiredPositions[i] += desiredIncrements[i];
    }

    for (int i = 1; i <= 3; i++) {
      final double d = desiredPositions[i] - markerPositions[i];
      if ((d >= 1 && markerPositions[i + 1] - markerPositions[i] > 1) ||
          (d <= -1 && markerPositions[i - 1] - markerPositions[i] < -1)) {
        final int direction = d >= 0 ? 1 : -1;
        final double candidate =
        _parabolicPrediction(i, direction, markerHeights, markerPositions);
        if (candidate > markerHeights[i - 1] &&
            candidate < markerHeights[i + 1]) {
          markerHeights[i] = candidate;
        } else {
          markerHeights[i] =
              _linearPrediction(i, direction, markerHeights, markerPositions);
        }
        markerPositions[i] += direction;
      }
    }
  }

  double? get estimate {
    if (_isInitialized) {
      return _markerHeights![2];
    }
    if (_initialSamples.isEmpty) {
      return null;
    }
    final List<double> sorted = List<double>.from(_initialSamples)..sort();
    final double index = percentile * (sorted.length - 1);
    final int lowerIndex = index.floor();
    final int upperIndex = index.ceil();
    if (lowerIndex == upperIndex) {
      return sorted[lowerIndex];
    }
    final double weight = index - lowerIndex;
    return sorted[lowerIndex] * (1 - weight) + sorted[upperIndex] * weight;
  }

  void reset() {
    _initialSamples.clear();
    _markerHeights = null;
    _markerPositions = null;
    _desiredMarkerPositions = null;
    _desiredMarkerIncrements = null;
  }

  void _initializeMarkers() {
    _initialSamples.sort();
    _markerHeights = List<double>.from(_initialSamples);
    _markerPositions = <int>[1, 2, 3, 4, 5];
    _desiredMarkerPositions = <double>[
      1,
      1 + 2 * percentile,
      1 + 4 * percentile,
      3 + 2 * percentile,
      5,
    ];
    _desiredMarkerIncrements = <double>[
      0,
      percentile / 2,
      percentile,
      (1 + percentile) / 2,
      1,
    ];
  }

  double _parabolicPrediction(
      int index,
      int direction,
      List<double> heights,
      List<int> positions,
      ) {
    final int lowerIndex = index - 1;
    final int upperIndex = index + 1;
    final double height = heights[index];
    final double lowerHeight = heights[lowerIndex];
    final double upperHeight = heights[upperIndex];
    final int position = positions[index];
    final int lowerPosition = positions[lowerIndex];
    final int upperPosition = positions[upperIndex];

    final double numerator = (direction * (position - lowerPosition + direction) /
        (upperPosition - lowerPosition)) * (upperHeight - height) /
        (upperPosition - position) +
        (direction * (upperPosition - position - direction) /
            (upperPosition - lowerPosition)) *
            (height - lowerHeight) /
            (position - lowerPosition);

    return height + numerator;
  }

  double _linearPrediction(
      int index,
      int direction,
      List<double> heights,
      List<int> positions,
      ) {
    final double height = heights[index];
    final double adjacentHeight = heights[index + direction];
    final int position = positions[index];
    final int adjacentPosition = positions[index + direction];
    return height +
        direction * (adjacentHeight - height) / (adjacentPosition - position);
  }

  @visibleForTesting
  int get debugSampleBufferLength =>
      _isInitialized ? 5 : _initialSamples.length;
}