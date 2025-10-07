import 'dart:convert';
import 'package:flutter/material.dart';



class ManualPayment {
  ManualPayment({

    this.manualPaymentId,
    this.paymentTransactionId,
    this.transactionIdentifier,
    this.transactionReference,
    this.manualReference,
    required this.paymentGateway,
    required this.paymentStatus,
    this.status,
    this.transactionStatus,



    required this.amount,
    required this.currency,
    required this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.expiresAt,
    this.expiresIn,
    this.notes,
    this.statusMessage,
    this.receiptUrl,
    this.payableType,
    this.payableId,
    this.payable,
    this.context,
    this.metadata,
    this.manualPaymentData,
  });

  final String? manualPaymentId;
  final String? paymentTransactionId;
  final String? transactionIdentifier;
  final String? transactionReference;
  final String? manualReference;
  final String paymentGateway;
  final String paymentStatus;
  final String? status;
  final String? transactionStatus;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final DateTime? expiresAt;
  final int? expiresIn;
  final String? notes;
  final String? statusMessage;
  final String? receiptUrl;
  final String? payableType;
  final int? payableId;
  final Map<String, dynamic>? payable;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? manualPaymentData;

  factory ManualPayment.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? mapify(dynamic value) {
      if (value == null) return null;
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry('$key', value));
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              return decoded.map((key, value) => MapEntry('$key', value));
            }
          } catch (_) {}
        }
      }
      if (value is List) {
        final map = <String, dynamic>{};
        for (final entry in value) {
          if (entry is Map) {
            for (final element in entry.entries) {
              map['${element.key}'] = element.value;
            }
          }
        }
        return map.isEmpty ? null : map;
      }
      return null;
    }

    String? toStr(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return '$value'.trim().isEmpty ? null : '$value'.trim();
    }

    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(toStr(value) ?? '');
    }

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      final str = toStr(value);
      if (str == null) return 0.0;
      final sanitized = str.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      return double.tryParse(sanitized) ?? 0.0;
    }

    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return DateTime.tryParse(trimmed);
      }
      if (value is num) {
        // Heuristic: values larger than 1e12 are milliseconds, otherwise seconds.
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value.toInt());
        }
        return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
      }
      return null;
    }

    final manualData = mapify(json['manual_payment']);
    final metadata = mapify(json['metadata']) ?? mapify(json['meta']);
    final context = mapify(json['context']) ?? mapify(metadata?['context']);
    final payable = mapify(json['payable']) ?? mapify(metadata?['payable']);

    final paymentTransactionId =
    toStr(json['payment_transaction_id'] ?? json['transaction_id'] ?? json['id']);
    final transactionIdentifier = toStr(
      json['transaction_identifier'] ??
          json['transaction_code'] ??
          json['transaction_number'] ??
          json['identifier'],
    ) ??
        paymentTransactionId;
    final transactionReference = toStr(
      json['transaction_reference'] ??
          json['payment_reference'] ??
          metadata?['transaction_reference'],
    ) ??
        toStr(json['reference']);
    final manualReference = toStr(
      manualData?['reference'] ??
          json['manual_reference'] ??
          metadata?['manual_reference'],
    );

    final paymentGateway = toStr(
      json['payment_gateway'] ??
          manualData?['payment_gateway'] ??
          metadata?['payment_gateway'],
    ) ??
        'manual_bank';

    final paymentStatus = toStr(
      json['payment_status'] ??
          manualData?['payment_status'] ??
          metadata?['payment_status'],
    ) ??
        'pending';


    final status = toStr(
      json['status'] ??
          manualData?['status'] ??
          metadata?['status'],
    );

    final transactionStatus = toStr(
      json['transaction_status'] ??
          manualData?['transaction_status'] ??
          metadata?['transaction_status'],
    );


    DateTime? resolveTimestamp(Iterable<dynamic> candidates) {
      for (final candidate in candidates) {
        final parsed = toDate(candidate);
        if (parsed != null) return parsed;
      }
      return null;
    }

    final createdAt = resolveTimestamp([
      json['created_at'],
      manualData?['created_at'],
      metadata?['created_at'],
      json['createdAt'],
      manualData?['createdAt'],
      metadata?['createdAt'],
      json['updated_at'],
      manualData?['updated_at'],
      metadata?['updated_at'],
      json['updatedAt'],
      manualData?['updatedAt'],
      metadata?['updatedAt'],
    ]) ??


          DateTime.now();




    return ManualPayment(
      manualPaymentId: toStr(json['manual_payment_id'] ?? manualData?['id']),
      paymentTransactionId: paymentTransactionId,
      transactionIdentifier: transactionIdentifier,
      transactionReference: transactionReference,
      manualReference: manualReference,
      paymentGateway: paymentGateway,
      paymentStatus: paymentStatus,

      status: status,
      transactionStatus: transactionStatus,

      amount: toDouble(json['amount'] ?? manualData?['amount']),
      currency: toStr(json['currency'] ?? manualData?['currency']) ?? 'YER',
      createdAt: createdAt,
      updatedAt: toDate(json['updated_at'] ?? manualData?['updated_at']),
      approvedAt: toDate(json['approved_at'] ?? manualData?['approved_at']),
      expiresAt: toDate(json['expires_at']),
      expiresIn: toInt(json['expires_in']),
      notes: toStr(json['notes'] ?? manualData?['notes']),
      statusMessage: toStr(
        json['status_message'] ??
            json['failure_reason'] ??
            manualData?['status_message'] ??
            metadata?['status_message'] ??
            metadata?['message'],
      ),
      receiptUrl: toStr(json['receipt_url'] ?? manualData?['receipt_url']),
      payableType: toStr(json['payable_type'] ?? manualData?['payable_type']),
      payableId: toInt(json['payable_id'] ?? manualData?['payable_id']),
      payable: payable,
      context: context,
      metadata: metadata,
      manualPaymentData: manualData,
    );
  }

  String get normalizedStatus {
    final raw = resolvedStatus;
    return raw?.toLowerCase().trim() ?? '';
  }


  String get normalizedTransactionStatus =>
      transactionStatus?.toLowerCase().trim() ?? '';

  String get normalizedPaymentStatus => paymentStatus.toLowerCase().trim();


  String? get resolvedStatus {
    for (final candidate in [status, transactionStatus, paymentStatus]) {
      if (candidate == null) continue;
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  Set<String> get _normalizedStatuses {
    final statuses = <String>{};
    void addCandidate(String? value) {
      if (value == null) return;
      final normalized = value.toLowerCase().trim();
      if (normalized.isNotEmpty) {
        statuses.add(normalized);
      }
    }

    addCandidate(status);
    addCandidate(transactionStatus);
    addCandidate(paymentStatus);
    return statuses;
  }

  static const Set<String> _pendingStatuses = {
    'pending',
    'processing',
    'submitted',
    'awaiting_approval',
    'in_progress',
    'in_review',
    'initiated',
    'created',
    'queued',
    'on_hold',
  };

  static const Set<String> _actionRequiredStatuses = {
    'requires_action',
    'action_required',

    'requires_payment_method',
  };

  static const Set<String> _successStatuses = {



    'approved',
    'success',
    'succeed',
    'succeeded',
    'completed',
    'paid',
    'settled',
  };



  static const Set<String> _failureStatuses = {
    'failed',
    'declined',
    'rejected',
    'cancelled',
    'canceled',
    'voided',
    'error',
  };

  bool _matchesStatus(Set<String> candidates) {
    for (final value in _normalizedStatuses) {
      if (candidates.contains(value)) {
        return true;
      }
    }
    return false;
  }

  String get normalizedGateway => paymentGateway.toLowerCase().trim();

  bool get isEastYemen => normalizedGateway == 'east_yemen_bank';

  bool get isManualBank => normalizedGateway == 'manual_bank';

  String get gatewayLabel => isEastYemen
      ? 'بوابة بنك الشرق الإلكترونية'
      : 'التحويل البنكي اليدوي';

  bool get isApproved => _matchesStatus(_successStatuses);

  bool get isFailure => _matchesStatus(_failureStatuses);

  bool get isPending => !isFinal && _matchesStatus(_pendingStatuses);

  bool get isActionRequired =>
      !isFinal && _matchesStatus(_actionRequiredStatuses);

  bool get isSucceeded => _matchesStatus(_successStatuses);

  bool get isRejected => _matchesStatus(_failureStatuses);




  bool get isExpired => normalizedStatus == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  bool get isRefunded => const {'refunded', 'reversed'}.contains(normalizedStatus);

  bool get isFinal => isExpired || isRefunded || isSucceeded || isRejected;

  bool get isTerminal => isFinal;


  bool get shouldAutoRefresh => !isTerminal;

  String get statusLabelAr {
    if (isExpired) return 'منتهي الصلاحية';
    if (isRefunded) return 'مسترد';

    if (isSucceeded) {
      if (normalizedStatus == 'approved' &&
          normalizedTransactionStatus == 'succeed') {
        return 'مكتمل';
      }
      if (normalizedStatus == 'approved') {
        return 'مقبول';
      }
      return 'مكتمل';
    }

    if (isRejected) {
      if (_matchesStatus(const {'rejected', 'declined'})) {
        return 'مرفوض';
      }
      if (_matchesStatus(const {'cancelled', 'canceled', 'voided'})) {
        return 'ملغي';
      }
      return 'فشلت';
    }

    if (isActionRequired) {
      return 'بانتظار الإجراء';
    }

    if (isPending) {
      return 'قيد المراجعة';
    }

    final raw = resolvedStatus;
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return 'غير معروف';
  }

  Color get statusColor {
    if (isExpired) return Colors.grey;
    if (isRefunded) return Colors.blueGrey.shade600;
    if (isSucceeded) return Colors.green.shade600;
    if (isRejected) return Colors.red.shade600;
    if (isActionRequired) return Colors.deepOrange.shade400;
    if (isPending) return Colors.orange.shade700;
    return Colors.blueGrey.shade700;
  }

  String get amountValueLabel {


    final isWhole = amount == amount.roundToDouble();
    return isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  }

  String? get currencyLabel {


    final trimmedCurrency = currency.trim();
    return trimmedCurrency.isEmpty ? null : trimmedCurrency;
  }

  String get amountLabel {
    final amountStr = amountValueLabel;
    final currencyStr = currencyLabel;
    return currencyStr == null ? amountStr : '$amountStr $currencyStr';

  }

  String get displayTransactionIdentifier {
    final candidates = <String?>[
      transactionIdentifier,
      paymentTransactionId,
      transactionReference,
      manualReference,
      manualPaymentIdentifierLabel,
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '—';
  }

  String? get payableSummary {
    final label = _humanizePayableType(payableType);
    final combined = _combinedDetails;
    final name = _firstNonEmpty(
      combined,
      [
        'title',
        'name',
        'package_name',
        'package_title',
        'order_title',
        'subscription_name',
        'plan_name',
      ],
    );

    final code = _firstNonEmpty(
      combined,
      [
        'code',
        'order_code',
        'order_number',
        'package_code',
        'reference',
        'invoice_number',
        'subscription_code',
      ],
    );

    final idPart = code ??
        (payableId != null ? '#$payableId' : null);

    final pieces = <String>[];
    if (label != null && label.isNotEmpty) pieces.add(label);
    if (name != null && name.isNotEmpty) pieces.add(name);
    if (idPart != null && idPart.isNotEmpty) pieces.add(idPart);

    if (pieces.isEmpty) return null;
    return pieces.join(' • ');
  }



  String? get _normalizedManualPaymentId {
    final raw = manualPaymentId;
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  String? get manualPaymentIdentifierLabel {
    final normalized = _normalizedManualPaymentId;
    if (normalized == null) return null;
    final numeric = int.tryParse(normalized);
    if (numeric != null) {
      return 'MP-$numeric';
    }
    return normalized;
  }

  String? get manualPaymentDisplayId {
    final normalized = _normalizedManualPaymentId;
    if (normalized == null) return null;
    final numeric = int.tryParse(normalized);
    if (numeric != null) {
      return '#$numeric';
    }
    return normalized;
  }


  List<String> get additionalHighlights {
    final combined = _combinedDetails;
    final seen = <String>{};
    final result = <String>[];

    void addHighlight(List<String> keys, String label) {
      final value = _firstNonEmpty(combined, keys);
      if (value == null || value.isEmpty) return;
      final entryKey = '$label:$value';
      if (seen.contains(entryKey)) return;
      seen.add(entryKey);
      result.add('$label: $value');
    }

    addHighlight(['package_name', 'package_title'], 'الباقة');
    addHighlight(['package_code'], 'رمز الباقة');
    addHighlight(['order_code', 'order_number'], 'رقم الطلب');
    addHighlight(['item_name', 'item_title'], 'العنصر');
    addHighlight(['sender_name', 'sender'], 'اسم المرسل');
    addHighlight(['bank_name'], 'البنك');

    if (notes != null && notes!.isNotEmpty) {
      final key = 'notes:${notes!}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add('ملاحظات: ${notes!}');
      }
    }

    final eastStatus = _firstNonEmpty(
      combined,
      const ['east_yemen_bank_status', 'eastYemenBankStatus'],
    );
    if (eastStatus != null && eastStatus.isNotEmpty) {
      final key = 'east_status:$eastStatus';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add('حالة بنك الشرق: $eastStatus');
      }
    }


    return result;
  }

  Map<String, dynamic> get _combinedDetails {
    final combined = <String, dynamic>{};
    void merge(Map<String, dynamic>? source) {
      if (source == null) return;
      for (final entry in source.entries) {
        final key = entry.key.toString();
        combined.putIfAbsent(key, () => entry.value);
      }
    }

    merge(payable);
    merge(context);
    merge(metadata);
    merge(manualPaymentData);
    return combined;
  }

  String? _firstNonEmpty(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return null;
  }

  String? _humanizePayableType(String? type) {
    if (type == null || type.isEmpty) return null;
    final normalized = type.toLowerCase();
    if (normalized.contains('package')) return 'الباقة';
    if (normalized.contains('order')) return 'الطلب';
    if (normalized.contains('subscription')) return 'الاشتراك';
    if (normalized.contains('plan')) return 'الخطة';
    if (normalized.contains('wallet')) return 'المحفظة';
    return type.split(RegExp(r'[\\.]')).last;
  }
}
