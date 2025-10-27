import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';

class ManualPaymentsController extends ChangeNotifier {
  ManualPaymentsController({ManualPaymentService? service})
      : _service = service ?? ManualPaymentService();

  static const Duration pollInterval = Duration(seconds: 20);

  final ManualPaymentService _service;
  final List<ManualPayment> _transactions = <ManualPayment>[];

  bool _loading = false;
  bool _fetching = false;
  Object? _error;
  Timer? _pollTimer;
  bool _disposed = false;

  List<ManualPayment> get transactions => UnmodifiableListView(_transactions);
  bool get loading => _loading;
  bool get fetching => _fetching;
  Object? get error => _error;

  Future<void> loadManualPayments({bool showLoader = true}) async {
    if (_fetching || _disposed) return;

    _fetching = true;

    if (showLoader) {
      _loading = true;
      _error = null;
      _notifyListeners();
    }

    DateTime _toDt(dynamic value) {
      if (value is DateTime) return value;
      final String stringValue = (value ?? '').toString().trim();
      if (stringValue.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      final num? parsedNumber = num.tryParse(stringValue);
      if (parsedNumber != null) {
        if (stringValue.length >= 13) {
          return DateTime.fromMillisecondsSinceEpoch(parsedNumber.toInt(), isUtc: true)
              .toLocal();
        }
        if (stringValue.length >= 10) {
          return DateTime.fromMillisecondsSinceEpoch(parsedNumber.toInt() * 1000, isUtc: true)
              .toLocal();
        }
      }

      final DateTime? iso = DateTime.tryParse(stringValue.replaceFirst(' ', 'T'));
      if (iso != null) return iso;

      final Match? manualMatch = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$',
      ).firstMatch(stringValue);

      if (manualMatch != null) {
        final int year = int.parse(manualMatch.group(1)!);
        final int month = int.parse(manualMatch.group(2)!);
        final int day = int.parse(manualMatch.group(3)!);
        final int hour = int.parse(manualMatch.group(4)!);
        final int minute = int.parse(manualMatch.group(5)!);
        final int second = int.parse(manualMatch.group(6) ?? '0');
        return DateTime(year, month, day, hour, minute, second);
      }

      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    try {
      final Iterable<ManualPayment> list = await _service.fetchMyManualPayments();
      final List<ManualPayment> sorted = List<ManualPayment>.from(list)
        ..sort((ManualPayment a, ManualPayment b) {
          return _toDt(b.createdAt).compareTo(_toDt(a.createdAt));
        });

      _transactions
        ..clear()
        ..addAll(sorted);
      _error = null;
    } catch (error) {
      final String message = error.toString();
      final String normalizedMessage = message.toLowerCase();
      final bool indicatesNoData = message.contains('لم يتم العثور') ||
          normalizedMessage.contains('no manual payments found');

      if (indicatesNoData) {
        _transactions.clear();
        _error = null;
      } else {
        _error = error;
      }
    } finally {
      _fetching = false;
      if (showLoader) {
        _loading = false;
      }
      _notifyListeners();
      _updatePolling();
    }
  }

  void _updatePolling() {
    if (_disposed) return;

    final bool shouldPoll = _transactions.any((ManualPayment mp) => mp.shouldAutoRefresh);
    if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }

    if (_pollTimer != null) return;

    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_disposed) return;
      loadManualPayments(showLoader: false);
    });
  }

  void _notifyListeners() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}