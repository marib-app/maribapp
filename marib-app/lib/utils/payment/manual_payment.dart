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
    required this.paymentGatewayKey,
    this.paymentGatewayLabel,
    this.manualBankName,
    this.manualBank,
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
  final String paymentGatewayKey;
  final String? paymentGatewayLabel;
  final String? manualBankName;
  final Map<String, dynamic>? manualBank;
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
      final converted = value.toString().trim();
      return converted.isEmpty ? null : converted;

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
      final sanitized = str.replaceAll(RegExp(r'[^0-9.-]'), '');
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
    final manualBankData = mapify(json['manual_bank']) ??
        mapify(manualData?['manual_bank']) ??
        mapify(metadata?['manual_bank']);
    final bankMeta = manualBankData ?? mapify(metadata?['bank']);
    final manualMeta = mapify(metadata?['manual']);



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

    final paymentGatewayRaw = toStr(

      json['payment_gateway'] ??
          manualData?['payment_gateway'] ??
          metadata?['payment_gateway'],
    ) ??
        'manual_bank';

    final gatewayKeyCandidate = toStr(
      json['payment_gateway_key'] ??
          json['payment_gateway_canonical'] ??
          json['payment_gateway_normalized'],
    ) ??
        paymentGatewayRaw;
    final canonicalGateway = _canonicalGateway(gatewayKeyCandidate);



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





    String? candidateOrNull(dynamic source) => toStr(source);

    final manualBankName = _firstMeaningfulLabel([
      candidateOrNull(json['manual_bank_name']),
      candidateOrNull(manualData?['manual_bank_name']),
      candidateOrNull(metadata?['manual_bank_name']),
      candidateOrNull(manualData?['bank_name']),
      candidateOrNull(manualData?['bank_account_name']),
      candidateOrNull(manualData?['bankAccountName']),
      candidateOrNull(metadata?['bank_name']),
      candidateOrNull(metadata?['bank.account_name']),
      candidateOrNull(manualBankData?['name']),
      candidateOrNull(manualBankData?['bank_name']),
      candidateOrNull(manualBankData?['beneficiary_name']),
      candidateOrNull(manualBankData?['account_name']),
      candidateOrNull(bankMeta?['name']),
      candidateOrNull(bankMeta?['bank_name']),
      candidateOrNull(bankMeta?['beneficiary_name']),
    ]);



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

    final paymentGatewayLabel = _firstMeaningfulLabel([
      candidateOrNull(json['payment_gateway_label']),
      candidateOrNull(json['payment_gateway_name']),
      candidateOrNull(manualData?['payment_gateway_label']),
      candidateOrNull(manualData?['payment_gateway_name']),
      candidateOrNull(manualData?['gateway_name']),
      candidateOrNull(metadata?['payment_gateway_label']),
      candidateOrNull(metadata?['payment_gateway_name']),
      candidateOrNull(metadata?['gateway_name']),
      candidateOrNull(manualMeta?['payment_gateway_label']),
      candidateOrNull(manualMeta?['payment_gateway_name']),
      candidateOrNull(manualMeta?['gateway_name']),
      candidateOrNull(manualBankData?['display_name']),
      candidateOrNull(bankMeta?['display_name']),
      manualBankName,
    ]) ??
        _defaultGatewayLabel(canonicalGateway, manualBankName, paymentGatewayRaw);


    final manualBank = manualBankData == null
        ? null
        : Map<String, dynamic>.unmodifiable(manualBankData);




    return ManualPayment(
      manualPaymentId: toStr(json['manual_payment_id'] ?? manualData?['id']),
      paymentTransactionId: paymentTransactionId,
      transactionIdentifier: transactionIdentifier,
      transactionReference: transactionReference,
      manualReference: manualReference,
      paymentGateway: paymentGatewayRaw,
      paymentGatewayKey: canonicalGateway,
      paymentGatewayLabel: paymentGatewayLabel,
      manualBankName: manualBankName,
      manualBank: manualBank,

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



  static const Map<String, String> _gatewayAliasMap = <String, String>{
    'manual': 'manual_bank',
    'manual_bank': 'manual_bank',
    'manualbanks': 'manual_bank',
    'manual_banks': 'manual_bank',
    'manualbank': 'manual_bank',
    'manualpayment': 'manual_bank',
    'manual_payment': 'manual_bank',
    'manualtransfer': 'manual_bank',
    'manual_transfer': 'manual_bank',
    'manualgateway': 'manual_bank',
    'manual_gateway': 'manual_bank',
    'manualmethod': 'manual_bank',
    'manual_method': 'manual_bank',
    'bank': 'manual_bank',
    'banks': 'manual_bank',
    'banktransfer': 'manual_bank',
    'bank_transfer': 'manual_bank',
    'bankmanual': 'manual_bank',
    'bank_manual': 'manual_bank',
    'bankmanualtransfer': 'manual_bank',
    'bank_manual_transfer': 'manual_bank',
    'manualpayments': 'manual_bank',
    'manual_payments': 'manual_bank',
    'manualbanking': 'manual_bank',
    'manual_banking': 'manual_bank',
    'offline': 'manual_bank',
    'internal': 'manual_bank',
    'east': 'east_yemen_bank',
    'east_yemen_bank': 'east_yemen_bank',
    'eastyemenbank': 'east_yemen_bank',
    'east_yemen': 'east_yemen_bank',
    'bankalsharq': 'east_yemen_bank',
    'bank_alsharq': 'east_yemen_bank',
    'wallet': 'wallet',
    'walletpayment': 'wallet',
    'wallet_payment': 'wallet',
    'walletgateway': 'wallet',
    'wallet_gateway': 'wallet',
    'walletbalance': 'wallet',
    'wallet_balance': 'wallet',
    'walletpay': 'wallet',
    'wallet_pay': 'wallet',
    'wallettopup': 'wallet',
    'wallet_top_up': 'wallet',
    'walletdeposit': 'wallet',
    'wallet_deposit': 'wallet',
    'cash': 'cash',
    'cod': 'cash',
    'cash_on_delivery': 'cash',
    'cashondelivery': 'cash',
    'cashpayment': 'cash',
    'cash_payment': 'cash',
    'payondelivery': 'cash',
    'pay_on_delivery': 'cash',
  };

  static const Set<String> _manualGatewayLabelAliases = <String>{
    'manual',
    'manual bank',
    'manual banks',
    'manual_bank',
    'manual_banks',
    'manualbank',
    'manualbanks',
    'manual payment',
    'manual payments',
    'manual_payment',
    'manual_payments',
    'manual transfer',
    'manual transfers',
    'manual_transfer',
    'manual_transfers',
    'bank transfer',
    'bank transfers',
    'bank_transfer',
    'bank_transfers',
    'bank manual',
    'bank manuals',
    'bank_manual',
    'bank_manuals',
    'bank manual transfer',
    'bank manual transfers',
    'manual bank transfer',
    'manual bank transfers',
    'manualbanks transfer',
    'manualbanks transfers',
    'manual bank gateway',
    'manual gateway',
    'manual gateways',
    'manual_gateway',
    'manual_gateways',
    'offline',
    'internal',
  };

  static String? _canonicalGatewayOrNull(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lowercase = trimmed.toLowerCase();
    final sanitized = lowercase.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = sanitized.replaceAll('_', '');
    return _gatewayAliasMap[sanitized] ??
        _gatewayAliasMap[lowercase] ??
        _gatewayAliasMap[collapsed];
  }

  static String _canonicalGateway(String? value) {
    return _canonicalGatewayOrNull(value) ?? 'manual_bank';
  }

  static String? _sanitizeGatewayLabel(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lowercase = trimmed.toLowerCase();
    if (_manualGatewayLabelAliases.contains(lowercase)) {
      return null;
    }
    return trimmed;
  }

  static String? _firstMeaningfulLabel(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final sanitized = _sanitizeGatewayLabel(candidate);
      if (sanitized != null) {
        return sanitized;
      }
    }
    return null;
  }

  static String _defaultGatewayLabel(String gatewayKey, String? manualBankName, String? rawGateway) {
    switch (gatewayKey) {
      case 'manual_bank':
        return manualBankName ?? 'التحويل البنكي اليدوي';
      case 'east_yemen_bank':
        return 'بوابة بنك الشرق الإلكترونية';
      case 'wallet':
        return 'المحفظة';
      case 'cash':
        return 'الدفع النقدي';
      default:
        if (manualBankName != null && manualBankName.trim().isNotEmpty) {
          return manualBankName;
        }
        if (rawGateway != null && rawGateway.trim().isNotEmpty) {
          final sanitized = rawGateway.replaceAll(RegExp(r'[_-]+'), ' ').trim();
          return sanitized.isEmpty ? rawGateway.trim() : sanitized;
        }
        return 'التحويل البنكي اليدوي';
    }
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

  String get normalizedGateway => paymentGatewayKey.toLowerCase().trim();

  bool get isEastYemen => normalizedGateway == 'east_yemen_bank';

  bool get isManualBank => normalizedGateway == 'manual_bank';

  String get gatewayLabel {
    final manualLabel = manualBankName?.trim();
    if (isManualBank && manualLabel != null && manualLabel.isNotEmpty) {
      return manualLabel;
    }

    final resolvedLabel = paymentGatewayLabel?.trim();
    if (resolvedLabel != null && resolvedLabel.isNotEmpty) {
      return resolvedLabel;
    }

    if (isEastYemen) {
      return 'بوابة بنك الشرق الإلكترونية';
    }

    switch (normalizedGateway) {
      case 'wallet':
        return 'المحفظة';
      case 'cash':
        return 'الدفع النقدي';
    }

    if (isManualBank) {
      return 'التحويل البنكي اليدوي';
    }

    final raw = paymentGateway.trim();
    if (raw.isNotEmpty) {
      final sanitized = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
      return sanitized.isEmpty ? raw : sanitized;
    }

    return 'التحويل البنكي اليدوي';
  }

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
