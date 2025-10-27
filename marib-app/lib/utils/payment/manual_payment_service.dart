// lib/new_code/utils/manual_payment_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:marib/settings.dart';
import 'package:marib/utils/payment/bank_account.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/api.dart';
import 'package:meta/meta.dart';
import 'package:marib/utils/payment/east_yemen_bank_config.dart';

const String manualPaymentWalletTopUpPurpose = 'wallet_top_up';

const Set<String> _zeroDecimalCurrencies = {
  'BIF',
  'CLP',
  'DJF',
  'GNF',
  'ISK',
  'JPY',
  'KMF',
  'KRW',
  'PYG',
  'RWF',
  'UGX',
  'UYI',
  'VND',
  'VUV',
  'XAF',
  'XOF',
  'XPF',
  'YER',
};

const Map<String, int> _currencyPrecisionOverrides = {
  'BHD': 3,
  'IQD': 3,
  'JOD': 3,
  'KWD': 3,
  'LYD': 3,
  'OMR': 3,
  'TND': 3,
  'CLF': 4,
};

String _normalizeCurrencyCode(String currency) => currency.trim().toUpperCase();

String? _canonicalPaymentMethodOrNull(String? value) {
  if (value == null) {
    return null;
  }

  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  if (trimmed.toLowerCase() == 'null') {
    return null;
  }

  final String lowercase = trimmed.toLowerCase();
  final String sanitized = lowercase.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final String collapsed = sanitized.replaceAll('_', '');

  const Map<String, String> aliases = <String, String>{
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
    'bankpayment': 'manual_bank',
    'bank_payment': 'manual_bank',
    'manualpayments': 'manual_bank',
    'manual_payments': 'manual_bank',
    'manualbanking': 'manual_bank',
    'manual_banking': 'manual_bank',
    'bankmanual': 'manual_bank',
    'bank_manual': 'manual_bank',
    'bankmanualtransfer': 'manual_bank',
    'bank_manual_transfer': 'manual_bank',
    'east': 'east_yemen_bank',
    'east_yemen_bank': 'east_yemen_bank',
    'eastyemenbank': 'east_yemen_bank',
    'east_yemen': 'east_yemen_bank',
    'bankalsharq': 'east_yemen_bank',
    'bank_alsharq': 'east_yemen_bank',
    'bankalsharqbank': 'east_yemen_bank',
    'bank_alsharq_bank': 'east_yemen_bank',
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
    'cashondelivery': 'cash',
    'cash_on_delivery': 'cash',
    'cashdelivery': 'cash',
    'cash_delivery': 'cash',
    'cashpayment': 'cash',
    'cash_payment': 'cash',
    'cashondeliveryfee': 'cash',
    'cash_on_delivery_fee': 'cash',
    'cod': 'cash',
    'payondelivery': 'cash',
    'pay_on_delivery': 'cash',
    'deliverycash': 'cash',
    'delivery_cash': 'cash',
  };

  return aliases[sanitized] ?? aliases[lowercase] ?? aliases[collapsed];
}

String _canonicalPaymentMethod(String value) {
  final String? canonical = _canonicalPaymentMethodOrNull(value);
  if (canonical != null) {
    return canonical;
  }

  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  if (trimmed.toLowerCase() == 'null') {
    return 'manual_bank';
  }

  return trimmed;
}

bool _isWalletPurpose(String? purpose) {
  if (purpose == null) {
    return false;
  }
  final value = purpose.trim().toLowerCase();
  if (value.isEmpty) {
    return false;
  }
  if (value == manualPaymentWalletTopUpPurpose) {
    return true;
  }
  return value.contains('wallet');
}

String? _normalizePurposeForApi(String? purpose) {
  if (purpose == null) {
    return null;
  }
  final value = purpose.trim().toLowerCase();
  if (value.isEmpty) {
    return null;
  }
  if (value == 'order' || value == 'package') {
    return value;
  }

  if (_isWalletPurpose(value)) {
    return manualPaymentWalletTopUpPurpose;
  }

  return null;
}

int _currencyPrecision(String currencyCode) {
  if (_zeroDecimalCurrencies.contains(currencyCode)) {
    return 0;
  }
  return _currencyPrecisionOverrides[currencyCode] ?? 2;
}

String formatManualPaymentAmount(double amount, String currencyCode) =>
    _formatManualPaymentAmountInternal(amount, currencyCode);

String _formatManualPaymentAmountInternal(double amount, String currencyCode) {
  final normalizedCurrency = _normalizeCurrencyCode(currencyCode);
  final precision = _currencyPrecision(normalizedCurrency);

  if (precision == 0) {
    const epsilon = 1e-6;
    final rounded = amount.roundToDouble();
    final isNearlyWhole = (amount - rounded).abs() < epsilon;
    if (isNearlyWhole) {
      return rounded.toStringAsFixed(0);
    }
  }

  final decimals = precision == 0 ? 2 : precision;
  return amount.toStringAsFixed(decimals);
}

String _apiPaymentMethod(String uiValue) => _canonicalPaymentMethod(uiValue);

String? _apiPaymentMethodOrNull(String? uiValue) {
  final String? canonical = _canonicalPaymentMethodOrNull(uiValue);
  if (canonical != null) {
    return canonical;
  }

  if (uiValue == null) {
    return null;
  }
  final String trimmed = uiValue.trim();

  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.toLowerCase() == 'null') {
    return null;
  }

  return trimmed;
}

class ManualPaymentSettingsResult {
  ManualPaymentSettingsResult({
    required this.banks,
    this.eastYemenBank,
    this.paymentIntent,
    this.paymentIntentId,
    this.paymentTransaction,
    this.paymentTransactionId,
    Map<String, dynamic>? raw,
  }) : raw = raw == null
            ? const <String, dynamic>{}
            : Map<String, dynamic>.unmodifiable(
                Map<String, dynamic>.from(raw),
              );

  final List<BankAccount> banks;
  final EastYemenBankConfig? eastYemenBank;
  final Map<String, dynamic>? paymentIntent;
  final String? paymentIntentId;
  final Map<String, dynamic>? paymentTransaction;
  final String? paymentTransactionId;
  final Map<String, dynamic> raw;
}

class ManualPaymentSubmissionResult {
  ManualPaymentSubmissionResult({
    required this.success,
    this.manualPaymentId,
    this.paymentIntentId,
    this.paymentTransactionId,
    this.status,
    this.message,
    this.manualPaymentRequest,
    this.paymentTransaction,
    this.paymentIntent,
    this.requiresConfirmation = false,
    required this.raw,
  });

  final bool success;
  final String? manualPaymentId;
  final String? paymentTransactionId;
  final String? paymentIntentId;
  final String? status;
  final String? message;
  final Map<String, dynamic> raw;
  final Map<String, dynamic>? manualPaymentRequest;
  final Map<String, dynamic>? paymentTransaction;
  final Map<String, dynamic>? paymentIntent;
  final bool requiresConfirmation;

  Map<String, dynamic> toJson() => raw;

  static String? _parseIdentifier(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is int) return value.toString();
    if (value is num) return value.toString();
    final stringified = value.toString().trim();
    return stringified.isEmpty ? null : stringified;
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw as Map);
    }
    return {'data': raw};
  }

  static Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return (value as Map).map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  static bool _statusIndicatesSuccess(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;

    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return false;

    const acceptedSignals = {
      'true',
      'success',
      'accepted',
      'succeed',
      'succeeded',
    };

    return acceptedSignals.contains(normalized);
  }

  factory ManualPaymentSubmissionResult.fromResponse(dynamic response) {
    // Helpers
    bool _truthy(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' ||
            s == '1' ||
            s == 'ok' ||
            s == 'success' ||
            s == 'succeeded' ||
            s == 'accepted';
      }
      return false;
    }

    bool _codeOk(dynamic v) {
      if (v == null) return false;
      final n = int.tryParse(v.toString());
      return n != null && n >= 200 && n < 300;
    }

    final map = _asMap(response);
    final dataMap = _mapify(map['data']);

    Map<String, dynamic>? _firstNested(
        Map<String, dynamic>? source, List<String> keys) {
      if (source == null) return null;
      for (final key in keys) {
        if (!source.containsKey(key)) continue;
        final nested = _mapify(source[key]);
        if (nested != null) return nested;
      }
      return null;
    }

    final manualPaymentRequest = _firstNested(
            map, const ['manual_payment_request', 'manualPaymentRequest']) ??
        _firstNested(dataMap,
            const ['manual_payment_request', 'manualPaymentRequest']) ??
        _firstNested(map, const ['manual_payment', 'manualPayment']) ??
        _firstNested(dataMap, const ['manual_payment', 'manualPayment']) ??
        (dataMap != null &&
                (dataMap.containsKey('id') ||
                    dataMap.containsKey('manual_payment_id') ||
                    dataMap.containsKey('manualPaymentId') ||
                    dataMap.containsKey('manual_payment') ||
                    dataMap.containsKey('manualPayment') ||
                    dataMap.containsKey('manual_payment_request') ||
                    dataMap.containsKey('manualPaymentRequest') ||
                    dataMap.containsKey('payment_transaction') ||
                    dataMap.containsKey('paymentTransaction'))
            ? dataMap
            : null);

    final paymentTransaction = _firstNested(
            map, const ['payment_transaction', 'paymentTransaction']) ??
        _firstNested(
            dataMap, const ['payment_transaction', 'paymentTransaction']) ??
        _firstNested(manualPaymentRequest,
            const ['payment_transaction', 'paymentTransaction']);

    final paymentIntent = _firstNested(
            map, const ['payment_intent', 'paymentIntent', 'intent']) ??
        _firstNested(
            dataMap, const ['payment_intent', 'paymentIntent', 'intent']) ??
        _firstNested(paymentTransaction,
            const ['payment_intent', 'paymentIntent', 'intent']) ??
        _firstNested(manualPaymentRequest,
            const ['payment_intent', 'paymentIntent', 'intent']);

    String? lookupId(List<String> keys,
        {bool includeTransaction = false, bool includeIntent = false}) {
      final sources = <Map<String, dynamic>>[
        map,
        if (dataMap != null) dataMap,
        if (manualPaymentRequest != null) manualPaymentRequest,
        if (includeTransaction && paymentTransaction != null)
          paymentTransaction!,
        if (includeIntent && paymentIntent != null) paymentIntent!,
      ];
      for (final source in sources) {
        for (final key in keys) {
          if (!source.containsKey(key)) continue;
          final value = source[key];
          final parsed = _parseIdentifier(value);
          if (parsed != null) return parsed;
          final nested = _mapify(value);
          if (nested != null) {
            final nestedParsed = _parseIdentifier(nested['id']);
            if (nestedParsed != null) return nestedParsed;
          }
        }
      }
      return null;
    }

    final manualPaymentId = lookupId(const [
      'manual_payment_id',
      'manualPaymentId',
      'manual_payment',
      'manualPayment',
      'manual_payment_request',
      'manualPaymentRequest',
      'id',
    ]);

    final paymentTransactionId = lookupId(
          const [
            'payment_transaction_id',
            'paymentTransactionId',
            'payment_transaction',
            'paymentTransaction',
            'transaction_id',
            'transactionId',
            'transaction',
          ],
          includeTransaction: true,
        ) ??
        _parseIdentifier(paymentTransaction?['id']);

    final paymentIntentId = lookupId(
          const [
            'payment_intent_id',
            'paymentIntentId',
            'intent_id',
            'intentId',
            'payment_intent',
            'paymentIntent',
            'intent',
          ],
          includeTransaction: true,
          includeIntent: true,
        ) ??
        _parseIdentifier(paymentIntent?['id']) ??
        _parseIdentifier(paymentIntent?['intent_id']);

    final rawStatus = map['status'] ??
        dataMap?['status'] ??
        manualPaymentRequest?['status'] ??
        paymentTransaction?['status'] ??
        paymentIntent?['status'] ??
        map['payment_status'] ??
        dataMap?['payment_status'] ??
        manualPaymentRequest?['payment_status'] ??
        paymentTransaction?['payment_status'];
    final status = rawStatus?.toString();

    final message = (map['message'] ??
            dataMap?['message'] ??
            manualPaymentRequest?['message'] ??
            paymentTransaction?['message'] ??
            paymentIntent?['message'])
        ?.toString();

    final hasManualPaymentId = manualPaymentId?.isNotEmpty == true;

    // Server shape support: our backend returns {error:false, code:200, data:{...}}
    final errorKeyFalse = map.containsKey('error') && !_truthy(map['error']);
    final codeOk = _codeOk(map['code'] ?? dataMap?['code']);

    final success = _truthy(map['success']) ||
        _truthy(dataMap?['success']) ||
        _truthy(manualPaymentRequest?['success']) ||
        _truthy(paymentTransaction?['success']) ||
        _truthy(paymentIntent?['success']) ||
        errorKeyFalse ||
        codeOk ||
        _statusIndicatesSuccess(rawStatus) ||
        hasManualPaymentId ||
        (paymentTransactionId?.isNotEmpty == true) ||
        (paymentIntentId?.isNotEmpty == true);

    bool requiresConfirmation = _truthy(
          map['requires_confirmation'] ??
              map['requiresConfirmation'] ??
              dataMap?['requires_confirmation'] ??
              dataMap?['requiresConfirmation'] ??
              manualPaymentRequest?['requires_confirmation'] ??
              manualPaymentRequest?['requiresConfirmation'] ??
              paymentTransaction?['requires_confirmation'] ??
              paymentTransaction?['requiresConfirmation'] ??
              paymentIntent?['requires_confirmation'] ??
              paymentIntent?['requiresConfirmation'],
        ) ||
        (() {
          final dynamic nextAction = paymentIntent?['next_action'] ??
              paymentIntent?['nextAction'] ??
              manualPaymentRequest?['next_action'] ??
              manualPaymentRequest?['nextAction'];
          if (nextAction is String) {
            final normalized = nextAction.trim().toLowerCase();
            if (normalized.contains('confirm')) {
              return true;
            }
          }
          final intentStatus =
              paymentIntent?['status']?.toString().trim().toLowerCase();
          if (intentStatus != null &&
              intentStatus.isNotEmpty &&
              const {
                'requires_confirmation',
                'requires_action',
                'pending_confirmation',
                'pending',
              }.contains(intentStatus)) {
            return true;
          }
          return false;
        })();

    return ManualPaymentSubmissionResult(
      success: success,
      manualPaymentId: hasManualPaymentId ? manualPaymentId : null,
      paymentTransactionId: paymentTransactionId,
      paymentIntentId: paymentIntentId,
      status: status,
      message: message,
      manualPaymentRequest: manualPaymentRequest != null
          ? Map<String, dynamic>.unmodifiable(manualPaymentRequest)
          : null,
      paymentTransaction: paymentTransaction != null
          ? Map<String, dynamic>.unmodifiable(paymentTransaction)
          : null,
      paymentIntent: paymentIntent != null
          ? Map<String, dynamic>.unmodifiable(paymentIntent)
          : null,
      requiresConfirmation: requiresConfirmation,
      raw: Map<String, dynamic>.unmodifiable(map),
    );
  }
}

class ManualPaymentService {
  static const String walletTopUpPurpose = manualPaymentWalletTopUpPurpose;

  static bool isWalletPurpose(String? value) => _isWalletPurpose(value);

  static String formatManualPaymentAmount(double amount, String currencyCode) =>
      _formatManualPaymentAmountInternal(amount, currencyCode);

  ManualPaymentService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _normalizeBase(AppSettings.baseUrl),
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;

  static String paymentMethodForApi(String value) => _apiPaymentMethod(value);

  static String? paymentMethodForApiOrNull(String? value) =>
      _apiPaymentMethodOrNull(value);

  static String _normalizeBase(String u) {
    if (u.endsWith('/api/')) return u;
    if (u.endsWith('/')) return '${u}api/';
    return '$u/api/';
  }

  static Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return null;
  }

  static String? _stringify(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static List<Map<String, dynamic>> _collectBankMaps(dynamic payload) {
    final visited = <int>{};
    final results = <Map<String, dynamic>>[];

    void inspect(dynamic node) {
      if (node == null) return;

      if (node is Iterable) {
        for (final element in node) {
          if (element is Map || element is Map<String, dynamic>) {
            final map = _mapify(element);
            if (map != null) {
              results.add(Map<String, dynamic>.from(map));
            }
          } else {
            inspect(element);
          }
        }
        return;
      }

      final Map<String, dynamic>? map = _mapify(node);
      if (map == null) {
        return;
      }

      final int hash = identityHashCode(map);
      if (!visited.add(hash)) {
        return;
      }

      const bankListKeys = <String>{
        'manual_payment_banks',
        'manualPaymentBanks',
        'manual_banks',
        'banks',
        'bank_accounts',
        'accounts',
        'available_banks',
      };

      bool handledListKey = false;
      for (final key in bankListKeys) {
        if (!map.containsKey(key)) continue;
        handledListKey = true;
        final dynamic value = map[key];
        if (value is Iterable) {
          for (final element in value) {
            final Map<String, dynamic>? entry = _mapify(element);
            if (entry != null) {
              results.add(Map<String, dynamic>.from(entry));
            } else {
              inspect(element);
            }
          }
        } else {
          inspect(value);
        }
      }

      if (!handledListKey) {
        final bool looksLikeBank = map.containsKey('bank_name') ||
            map.containsKey('account_number') ||
            map.containsKey('iban') ||
            map.containsKey('swift');
        if (looksLikeBank) {
          results.add(Map<String, dynamic>.from(map));
        }
      }

      const containerKeys = <String>{
        'manual_bank',
        'manualPayment',
        'manual_payment',
        'manual',
        'payment_methods',
        'manual_payment_methods',
        'manualPaymentMethods',
        'methods',
        'options',
        'data',
        'attributes',
        'payload',
        'response',
        'meta',
        'metadata',
        'extra',
        'extras',
        'details',
      };

      for (final key in containerKeys) {
        if (map.containsKey(key)) {
          inspect(map[key]);
        }
      }

      for (final value in map.values) {
        if (value is Map || value is Iterable) {
          inspect(value);
        }
      }
    }

    inspect(payload);

    final deduped = <String, Map<String, dynamic>>{};
    for (final map in results) {
      final id = _stringify(map['id']) ??
          _stringify(map['bank_id']) ??
          _stringify(map['bankId']);
      final account =
          _stringify(map['account_number']) ?? _stringify(map['accountNumber']);
      final bankName = _stringify(map['bank_name']) ?? _stringify(map['name']);
      final key = '${id ?? ''}|${account ?? ''}|${bankName ?? ''}';
      deduped.putIfAbsent(key, () => map);
    }

    return deduped.values.toList();
  }

  @visibleForTesting
  static List<BankAccount> combineManualPaymentBanks({
    required Iterable<BankAccount> primaryBanks,
    required Iterable<BankAccount> fallbackBanks,
  }) {
    String _trimOrEmpty(String? value) {
      if (value == null) return '';
      final trimmed = value.trim();
      return trimmed;
    }

    String _bankKey(BankAccount bank) {
      final idPart = bank.id != 0 ? bank.id.toString() : '';
      final accountPart = _trimOrEmpty(bank.accountNumber);
      final namePart = _trimOrEmpty(bank.bankName);
      return '$idPart|$accountPart|$namePart';
    }

    String? _preferString(String? current, String? candidate) {
      final currentTrimmed = current?.trim();
      if (currentTrimmed != null && currentTrimmed.isNotEmpty) {
        return current;
      }
      final candidateTrimmed = candidate?.trim();
      if (candidateTrimmed != null && candidateTrimmed.isNotEmpty) {
        return candidate;
      }
      return current ?? candidate;
    }

    BankAccount _mergeAccounts(BankAccount base, BankAccount addition) {
      return BankAccount(
        id: base.id != 0 ? base.id : addition.id,
        bankName: _trimOrEmpty(base.bankName).isNotEmpty
            ? base.bankName
            : addition.bankName,
        accountName: _preferString(base.accountName, addition.accountName),
        accountNumber:
            _preferString(base.accountNumber, addition.accountNumber),
        iban: _preferString(base.iban, addition.iban),
        swift: _preferString(base.swift, addition.swift),
        branch: _preferString(base.branch, addition.branch),
        notes: _preferString(base.notes, addition.notes),
        logoUrl: _preferString(base.logoUrl, addition.logoUrl),
        isActive: base.isActive || addition.isActive,
        displayOrder: base.displayOrder ?? addition.displayOrder,
      );
    }

    final Map<String, BankAccount> merged = <String, BankAccount>{};

    for (final bank in primaryBanks) {
      merged[_bankKey(bank)] = bank;
    }

    for (final bank in fallbackBanks) {
      final key = _bankKey(bank);
      if (merged.containsKey(key)) {
        merged[key] = _mergeAccounts(merged[key]!, bank);
      } else {
        merged[key] = bank;
      }
    }

    final List<BankAccount> result = merged.values.toList();

    result.sort((a, b) {
      final int ao = a.displayOrder ?? 0;
      final int bo = b.displayOrder ?? 0;
      final int orderComparison = ao.compareTo(bo);
      if (orderComparison != 0) {
        return orderComparison;
      }
      return _trimOrEmpty(a.bankName).toLowerCase().compareTo(
            _trimOrEmpty(b.bankName).toLowerCase(),
          );
    });

    return result;
  }

  static EastYemenBankConfig? _parseEastYemenConfig(dynamic payload) {
    final visited = <int>{};

    Map<String, dynamic>? inspect(dynamic node) {
      if (node == null) return null;

      if (node is Iterable) {
        for (final element in node) {
          final Map<String, dynamic>? config = inspect(element);
          if (config != null && config.isNotEmpty) {
            return config;
          }
        }
        return null;
      }

      final Map<String, dynamic>? map = _mapify(node);
      if (map == null || map.isEmpty) {
        return null;
      }

      final int hash = identityHashCode(map);
      if (!visited.add(hash)) {
        return null;
      }

      Map<String, dynamic>? resolveContainer(Map<String, dynamic>? container) {
        if (container == null || container.isEmpty) {
          return null;
        }

        final Map<String, dynamic>? direct = _mapify(
          container['east_yemen_bank'] ?? container['eastYemenBank'],
        );
        if (direct != null && direct.isNotEmpty) {
          return direct;
        }

        const relatedKeys = <String>[
          'payment_gateways',
          'manual_payment_gateways',
          'payment_methods',
          'manual_payment_methods',
          'gateways',
          'methods',
          'options',
        ];

        for (final key in relatedKeys) {
          if (!container.containsKey(key)) {
            continue;
          }
          final dynamic candidate = container[key];
          final Map<String, dynamic>? candidateMap = _mapify(candidate);
          if (candidateMap != null && candidateMap.isNotEmpty) {
            final Map<String, dynamic>? nested = _mapify(
              candidateMap['east_yemen_bank'] ?? candidateMap['eastYemenBank'],
            );
            if (nested != null && nested.isNotEmpty) {
              return nested;
            }
          }

          final Map<String, dynamic>? resolved = inspect(candidate);
          if (resolved != null && resolved.isNotEmpty) {
            return resolved;
          }
        }

        return null;
      }

      final List<Map<String, dynamic>?> extrasCandidates =
          <Map<String, dynamic>?>[
        resolveContainer(_mapify(map['extras'])),
        resolveContainer(_mapify(map['extra'])),
        resolveContainer(_mapify(map['additional'])),
        resolveContainer(_mapify(map['meta'])),
        resolveContainer(_mapify(map['metadata'])),
      ];

      for (final Map<String, dynamic>? extras in extrasCandidates) {
        if (extras != null && extras.isNotEmpty) {
          return extras;
        }
      }

      final Map<String, dynamic>? direct = resolveContainer(map);
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }

      for (final value in map.values) {
        final Map<String, dynamic>? nested = inspect(value);
        if (nested != null && nested.isNotEmpty) {
          return nested;
        }
      }

      return null;
    }

    final Map<String, dynamic>? rawConfig = inspect(payload);
    if (rawConfig == null || rawConfig.isEmpty) {
      return null;
    }

    try {
      return EastYemenBankConfig.fromMap(rawConfig);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _mergeTransferReferenceMetadata(
      Map<String, dynamic>? metadata, String? referenceValue) {
    final String? trimmedReference = referenceValue?.trim();
    final bool hasReference =
        trimmedReference != null && trimmedReference.isNotEmpty;

    if (!hasReference && (metadata == null || metadata.isEmpty)) {
      return metadata;
    }

    final Map<String, dynamic> normalized = metadata == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(metadata);

    if (hasReference) {
      void ensureValue(String key) {
        if (!normalized.containsKey(key)) {
          normalized[key] = trimmedReference!;
          return;
        }

        final dynamic existing = normalized[key];
        if (existing == null) {
          normalized[key] = trimmedReference!;
          return;
        }

        if (existing is String && existing.trim().isEmpty) {
          normalized[key] = trimmedReference!;
          return;
        }

        final String existingString = existing.toString().trim();
        if (existingString.isEmpty) {
          normalized[key] = trimmedReference!;
        }
      }

      ensureValue('transfer_reference');
      ensureValue('transfer_code');
      ensureValue('transfer_number');
    }

    return normalized.isEmpty ? null : normalized;
  }

  static void _writeMetadataFields(
      Map<String, dynamic> target, Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return;

    void writeEntries(Map<String, dynamic> map, String prefix) {
      map.forEach((key, value) {
        if (key == null) return;
        final keyStr = '$key'.trim();
        if (keyStr.isEmpty || value == null) return;
        final fieldKey = prefix.isEmpty ? keyStr : '$prefix[$keyStr]';
        if (value is Map<String, dynamic>) {
          writeEntries(value, fieldKey);
          return;
        }
        if (value is Map) {
          writeEntries(Map<String, dynamic>.from(value as Map), fieldKey);
          return;
        }
        if (value is Iterable) {
          var index = 0;
          for (final element in value) {
            final itemKey = '$fieldKey[$index]';
            if (element == null) {
              index++;
              continue;
            }
            target[itemKey] = '$element';
            index++;
          }
          return;
        }
        target[fieldKey] =
            value is DateTime ? value.toIso8601String() : value.toString();
      });
    }

    writeEntries(metadata, 'metadata');
  }

  // GET /api/manual-payments/banks
  Future<List<BankAccount>> fetchBanks({
    required String token,
    String? purpose,
    String? currency,
    int? orderId,
    String? paymentMethod,
    double? amount,
  }) async {
    try {
      final ManualPaymentSettingsResult result =
          await fetchManualPaymentSettings(
        token: token,
        purpose: purpose,
        currency: currency,
        orderId: orderId,
        paymentMethod: paymentMethod,
        amount: amount,
      );
      return result.banks;
    } catch (_) {
      return [];
    }
  }

  Future<ManualPaymentSettingsResult> fetchManualPaymentSettings({
    required String token,
    String? purpose,
    String? currency,
    int? orderId,
    String? paymentMethod,
    double? amount,
    int? serviceId,
  }) async {
    List<BankAccount> banks = <BankAccount>[];
    EastYemenBankConfig? eastYemenBank;
    Map<String, dynamic>? paymentIntent;
    String? paymentIntentId;
    Map<String, dynamic>? paymentTransaction;
    String? paymentTransactionId;
    Map<String, dynamic> raw = const <String, dynamic>{};

    try {
      final normalizedCurrency = currency?.trim();
      final normalizedPaymentMethod = paymentMethod?.trim();
      final apiPaymentMethod = ManualPaymentService.paymentMethodForApiOrNull(
          normalizedPaymentMethod);

      final String? resolvedPurpose =
          _normalizePurposeForApi(purpose) ?? purpose?.trim();
      final bool walletPurpose = _isWalletPurpose(resolvedPurpose);

      final String? upperCurrency =
          (normalizedCurrency != null && normalizedCurrency.isNotEmpty)
              ? normalizedCurrency.toUpperCase()
              : null;

      String? formattedAmount;
      if (amount != null && amount > 0) {
        if (upperCurrency != null && upperCurrency.isNotEmpty) {
          formattedAmount = formatManualPaymentAmount(amount, upperCurrency);
        } else {
          formattedAmount = amount.toStringAsFixed(2);
        }
      }

      final int? sanitizedOrderId =
          (!walletPurpose && orderId != null && orderId > 0) ? orderId : null;

      final body = <String, dynamic>{
        if (resolvedPurpose != null && resolvedPurpose.isNotEmpty)
          'purpose': resolvedPurpose,
        if (upperCurrency != null && upperCurrency.isNotEmpty)
          'currency': upperCurrency,
        if (sanitizedOrderId != null) 'order_id': sanitizedOrderId,
        if (apiPaymentMethod != null && apiPaymentMethod.isNotEmpty)
          'payment_method': apiPaymentMethod,
        if (formattedAmount != null) 'amount': formattedAmount,
        if (serviceId != null && resolvedPurpose == 'service')
          'service_id': serviceId,
      };
      final response = await Api.postJson(
        url: Api.paymentsInitiateApi,
        data: body,
        extraHeaders: {
          'Authorization': 'Bearer $token',
          'Idempotency-Key': Api.generateIdempotencyKey(),
        },
      );

      final Map<String, dynamic> top =
          _mapify(response) ?? <String, dynamic>{'data': response};
      final Map<String, dynamic> root = _mapify(top['data']) ?? top;

      raw = Map<String, dynamic>.from(root);

      final bankMaps = _collectBankMaps(root);
      if (bankMaps.isNotEmpty) {
        banks = bankMaps.map(BankAccount.fromJson).toList();
      }

      eastYemenBank = _parseEastYemenConfig(root) ?? _parseEastYemenConfig(top);

      Map<String, dynamic>? firstNested(
          Map<String, dynamic>? source, List<String> keys) {
        if (source == null) return null;
        for (final key in keys) {
          if (!source.containsKey(key)) continue;
          final nested = _mapify(source[key]);
          if (nested != null) return nested;
        }
        return null;
      }

      paymentIntent = firstNested(
            root,
            const ['payment_intent', 'paymentIntent', 'intent'],
          ) ??
          firstNested(top, const ['payment_intent', 'paymentIntent', 'intent']);

      paymentTransaction = firstNested(
            root,
            const ['payment_transaction', 'paymentTransaction', 'transaction'],
          ) ??
          firstNested(top, const [
            'payment_transaction',
            'paymentTransaction',
            'transaction'
          ]);

      String? lookupIdentifier(List<String> keys) {
        final sources = <Map<String, dynamic>>[
          root,
          top,
          if (paymentIntent != null) paymentIntent!,
          if (paymentTransaction != null) paymentTransaction!,
        ];
        for (final source in sources) {
          for (final key in keys) {
            if (!source.containsKey(key)) continue;
            final dynamic value = source[key];
            if (value is Map || value is Map<String, dynamic>) {
              final nested = _mapify(value);
              if (nested != null) {
                final nestedId = _stringify(nested['id']);
                if (nestedId != null) return nestedId;
              }
              continue;
            }
            if (value is Iterable) {
              for (final element in value) {
                if (element is Map || element is Map<String, dynamic>) {
                  final nested = _mapify(element);
                  if (nested != null) {
                    final nestedId = _stringify(nested['id']);
                    if (nestedId != null) return nestedId;
                  }
                }
              }
              continue;
            }

            final parsed = _stringify(value);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      paymentIntentId = lookupIdentifier(const [
            'payment_intent_id',
            'paymentIntentId',
            'intent_id',
            'intentId',
            'payment_intent',
            'paymentIntent',
            'intent',
          ]) ??
          _stringify(paymentIntent?['id']) ??
          _stringify(paymentIntent?['intent_id']);

      paymentTransactionId = lookupIdentifier(const [
            'payment_transaction_id',
            'paymentTransactionId',
            'payment_transaction',
            'paymentTransaction',
            'transaction_id',
            'transactionId',
            'transaction',
          ]) ??
          _stringify(paymentTransaction?['id']);

      final bool hasIntent =
          paymentIntentId != null && paymentIntentId.trim().isNotEmpty;
      final bool hasTransaction = paymentTransactionId != null &&
          paymentTransactionId.trim().isNotEmpty;

      if (!hasIntent && hasTransaction) {
        paymentIntentId = paymentTransactionId;
      } else if (hasIntent && !hasTransaction) {
        paymentTransactionId = paymentIntentId;
      }

      paymentIntentId = paymentIntentId?.trim();
      paymentTransactionId = paymentTransactionId?.trim();
    } catch (_) {
      banks = const <BankAccount>[];
    }

    Map<String, dynamic>? fallbackPayload;
    Iterable<BankAccount> fallbackBanks = const <BankAccount>[];

    if (banks.isEmpty || eastYemenBank == null || !eastYemenBank.isEnabled) {
      try {
        final res = await _dio.get(
          Api.getPaymentSettingsApi,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        fallbackPayload =
            _mapify(res.data) ?? <String, dynamic>{'data': res.data};
        final Map<String, dynamic> fallbackRoot =
            _mapify(fallbackPayload['data']) ?? fallbackPayload;

        final fallbackBankMaps = _collectBankMaps(fallbackRoot);
        if (fallbackBankMaps.isNotEmpty) {
          fallbackBanks = fallbackBankMaps.map(BankAccount.fromJson);
        }

        final EastYemenBankConfig? fallbackEastYemen =
            _parseEastYemenConfig(fallbackRoot) ??
                _parseEastYemenConfig(fallbackPayload);
        if (fallbackEastYemen != null) {
          if (eastYemenBank == null || !eastYemenBank.isEnabled) {
            eastYemenBank = fallbackEastYemen;
          }
        }
      } catch (_) {}
    }

    banks = combineManualPaymentBanks(
      primaryBanks: banks,
      fallbackBanks: fallbackBanks,
    );

    return ManualPaymentSettingsResult(
      banks: banks,
      eastYemenBank: eastYemenBank != null && eastYemenBank.isEnabled
          ? eastYemenBank
          : null,
      paymentIntent: paymentIntent != null
          ? Map<String, dynamic>.unmodifiable(paymentIntent!)
          : null,
      paymentIntentId: paymentIntentId,
      paymentTransaction: paymentTransaction != null
          ? Map<String, dynamic>.unmodifiable(paymentTransaction!)
          : null,
      paymentTransactionId: paymentTransactionId,
      raw: raw,
    );
  }

  // POST /api/manual-payment-requests  (مع إيصال)

  Future<ManualPaymentSubmissionResult> submitManualPayment({
    required String token,
    required int bankId,
    required String intentId,
    String? transactionId,
    String? payableType,
    int? payableId,
    required double amount,
    required String currency,
    String? purpose,
    int? orderId,
    int? packageId,
    int? serviceId,
    String? reference,
    String? userNote,
    required DateTime transferredAt,
    Map<String, dynamic>? metadata,
    required String receiptImagePath,
  }) async {
    return _submitManualPayment(
      token: token,
      bankId: bankId,
      intentId: intentId,
      transactionId: transactionId,
      payableType: payableType,
      payableId: payableId,
      purpose: purpose,
      orderId: orderId,
      packageId: packageId,
      serviceId: serviceId,
      amount: amount,
      currency: currency,
      reference: reference,
      userNote: userNote,
      transferredAt: transferredAt,
      metadata: metadata,
      receiptImagePath: receiptImagePath,
    );
  }

  Future<ManualPaymentSubmissionResult> _submitManualPayment({
    required String token,
    required int bankId,
    required String intentId,
    String? transactionId,
    String? payableType,
    int? payableId,
    required double amount,
    required String currency,
    String? purpose,
    int? orderId,
    int? packageId,
    int? serviceId,
    String? reference,
    String? userNote,
    required DateTime transferredAt,
    Map<String, dynamic>? metadata,
    required String receiptImagePath,
  }) async {
    final referenceValue = reference?.trim();
    final userNoteValue = userNote?.trim();
    final payableTypeValue = payableType?.trim();
    final normalizedPurpose = _normalizePurposeForApi(purpose);
    final normalizedCurrency = _normalizeCurrencyCode(currency);
    final formattedAmount =
        formatManualPaymentAmount(amount, normalizedCurrency);

    final Map<String, dynamic>? metadataPayload =
        _mergeTransferReferenceMetadata(metadata, referenceValue);

    final Map<String, dynamic> formMap = {
      'payment_method': ManualPaymentService.paymentMethodForApi('manual_bank'),
      'bank_id': bankId,
      'bank_account_id': bankId,
      'amount': formattedAmount,
      'currency': normalizedCurrency,
      'intent_id': intentId,
      'payment_intent_id': intentId,
      if (transactionId != null && transactionId.isNotEmpty)
        'transaction_id': transactionId,
      if (transactionId != null && transactionId.isNotEmpty)
        'payment_transaction_id': transactionId,
      if (normalizedPurpose != null) 'purpose': normalizedPurpose,
      if (orderId != null) 'order_id': orderId,
      if (packageId != null) 'package_id': packageId,
      if (serviceId != null) 'service_id': serviceId,
      'transferred_at': transferredAt.toIso8601String(),
      if (referenceValue != null && referenceValue.isNotEmpty)
        'reference_number': referenceValue,
      if (referenceValue != null && referenceValue.isNotEmpty)
        'reference': referenceValue,
      if (userNoteValue != null && userNoteValue.isNotEmpty)
        'notes': userNoteValue,
      if (payableTypeValue != null && payableTypeValue.isNotEmpty)
        'payable_type': payableTypeValue,
      if (payableId != null) 'payable_id': payableId,
    };

    _writeMetadataFields(formMap, metadataPayload);

    if (receiptImagePath.isEmpty) {
      throw ArgumentError('receiptImagePath cannot be empty');
    }
    final receiptFile = File(receiptImagePath);
    formMap['receipt_image'] = receiptFile;
    formMap['receipt'] = receiptFile;

    final response = await Api.post(
      url: Api.submitManualPaymentApi,
      parameter: formMap,
      extraHeaders: {
        'Authorization': 'Bearer $token',
        'Idempotency-Key': Api.generateIdempotencyKey(),
      },
    );

    var result = ManualPaymentSubmissionResult.fromResponse(response);

    final String? resolvedIntentId = result.paymentIntentId ?? intentId;
    final String? resolvedTransactionId =
        result.paymentTransactionId ?? transactionId;

    if (result.requiresConfirmation &&
        resolvedIntentId != null &&
        resolvedIntentId.isNotEmpty) {
      result = await _confirmPayment(
        token: token,
        paymentMethod: 'manual_bank',
        intentId: resolvedIntentId,
        transactionId: resolvedTransactionId,
      );
    }

    return result;
  }

  Future<ManualPaymentSubmissionResult> _confirmPayment({
    required String token,
    required String paymentMethod,
    required String intentId,
    String? transactionId,
    Map<String, dynamic>? additionalData,
  }) async {
    final String normalizedMethod =
        ManualPaymentService.paymentMethodForApi(paymentMethod);

    final Map<String, dynamic> body = {
      'payment_method': normalizedMethod,
      'intent_id': intentId,
      'payment_intent_id': intentId,
      if (transactionId != null && transactionId.isNotEmpty)
        'transaction_id': transactionId,
      if (transactionId != null && transactionId.isNotEmpty)
        'payment_transaction_id': transactionId,
      if (additionalData != null) ...additionalData,
    };

    final response = await Api.postJson(
        url: Api.paymentsConfirmApi,
        data: body,
        extraHeaders: {
          'Authorization': 'Bearer $token',
          'Idempotency-Key': Api.generateIdempotencyKey(),
        });

    return ManualPaymentSubmissionResult.fromResponse(response);
  }

  Future<ManualPaymentSubmissionResult> submitEastYemenPayment({
    required String token,
    required String intentId,
    String? transactionId,
    String? payableType,
    int? payableId,
    String? purpose,
    int? orderId,
    int? packageId,
    int? serviceId,
    required double amount,
    required String currency,
    String? reference,
    String? userNote,
    Map<String, dynamic>? metadata,
  }) async {
    final referenceValue = reference?.trim();
    final userNoteValue = userNote?.trim();
    final payableTypeValue = payableType?.trim();
    final normalizedCurrency = _normalizeCurrencyCode(currency);
    final formattedAmount =
        formatManualPaymentAmount(amount, normalizedCurrency);
    final normalizedPurpose = _normalizePurposeForApi(purpose);
    final String normalizedMethod =
        ManualPaymentService.paymentMethodForApi('east_yemen_bank');
    final Map<String, dynamic>? metadataPayload =
        _mergeTransferReferenceMetadata(metadata, referenceValue);

    final Map<String, dynamic> formMap = {
      'payment_method': normalizedMethod,
      'amount': formattedAmount,
      'currency': normalizedCurrency,
      'intent_id': intentId,
      'payment_intent_id': intentId,
      if (transactionId != null && transactionId.isNotEmpty)
        'transaction_id': transactionId,
      if (normalizedPurpose != null) 'purpose': normalizedPurpose,
      if (orderId != null) 'order_id': orderId,
      if (packageId != null) 'package_id': packageId,
      if (serviceId != null) 'service_id': serviceId,
      if (transactionId != null && transactionId.isNotEmpty)
        'payment_transaction_id': transactionId,
      if (referenceValue != null && referenceValue.isNotEmpty)
        'reference': referenceValue,
      if (userNoteValue != null && userNoteValue.isNotEmpty)
        'notes': userNoteValue,
      if (payableTypeValue != null && payableTypeValue.isNotEmpty)
        'payable_type': payableTypeValue,
      if (payableId != null) 'payable_id': payableId,
    };

    _writeMetadataFields(formMap, metadataPayload);

    final response = await Api.post(
        url: Api.submitManualPaymentApi,
        parameter: formMap,
        extraHeaders: {
          'Authorization': 'Bearer $token',
          'Idempotency-Key': Api.generateIdempotencyKey(),
        });

    var result = ManualPaymentSubmissionResult.fromResponse(response);

    final String? resolvedIntentId = result.paymentIntentId ?? intentId;
    final String? resolvedTransactionId =
        result.paymentTransactionId ?? transactionId;

    if (result.requiresConfirmation &&
        resolvedIntentId != null &&
        resolvedIntentId.isNotEmpty) {
      result = await _confirmPayment(
        token: token,
        paymentMethod: normalizedMethod,
        intentId: resolvedIntentId,
        transactionId: resolvedTransactionId,
        additionalData: {
          if (referenceValue != null && referenceValue.isNotEmpty)
            'reference': referenceValue,
        },
      );
    }

    return result;
  }

  Future<ManualPaymentSubmissionResult> submitWalletPayment({
    required String token,
    required String intentId,
    String? transactionId,
    String? payableType,
    String? purpose,
    int? orderId,
    int? packageId,
    int? payableId,
    required double amount,
    required String currency,
    String? userNote,
    Map<String, dynamic>? metadata,
    int? serviceId,
  }) async {
    final trimmedIntentId = intentId.trim();
    if (trimmedIntentId.isEmpty) {
      throw ArgumentError('intentId cannot be empty for wallet payments');
    }

    final trimmedTransactionId = transactionId?.trim();
    if (trimmedTransactionId == null || trimmedTransactionId.isEmpty) {
      throw ArgumentError('transactionId cannot be empty for wallet payments');
    }
    final userNoteValue = userNote?.trim();
    final payableTypeValue = payableType?.trim();
    final normalizedCurrency = _normalizeCurrencyCode(currency);
    final formattedAmount =
        formatManualPaymentAmount(amount, normalizedCurrency);
    final normalizedPurpose = _normalizePurposeForApi(purpose);

    final Map<String, dynamic> additionalData = <String, dynamic>{
      'amount': formattedAmount,
      'currency': normalizedCurrency,
      if (normalizedPurpose != null) 'purpose': normalizedPurpose,
      if (orderId != null) 'order_id': orderId,
      if (packageId != null) 'package_id': packageId,
      if (userNoteValue != null && userNoteValue.isNotEmpty)
        'note': userNoteValue,
      if (payableTypeValue != null && payableTypeValue.isNotEmpty)
        'payable_type': payableTypeValue,
      if (payableId != null) 'payable_id': payableId,
      if (serviceId != null) 'service_id': serviceId,
    };

    final Map<String, dynamic> metadataFields = <String, dynamic>{};
    _writeMetadataFields(metadataFields, metadata);
    additionalData.addAll(metadataFields);

    return _confirmPayment(
      token: token,
      paymentMethod: 'wallet',
      intentId: trimmedIntentId,
      transactionId: trimmedTransactionId,
      additionalData: additionalData.isEmpty ? null : additionalData,
    );
  }

  final seen = <String>{};

  /// GET /api/manual-payment-requests

  String _normalizeGatewayKey(String? value) {
    final String? canonical = _canonicalPaymentMethodOrNull(value);
    if (canonical != null) {
      return canonical;
    }
    if (value == null) {
      return 'manual_bank';
    }

    final String normalized = value.trim().toLowerCase();

    if (normalized.isEmpty || normalized == 'null') {
      return 'manual_bank';
    }

    return normalized;
  }

  Future<List<ManualPayment>> fetchMyManualPayments({
    bool latestOnly = true,
    Set<String> paymentGateways = const {'manual_bank', 'east_yemen_bank'},
  }) async {
    try {
      final token = HiveUtils.getJWT();
      if (token == null || token.isEmpty) return [];

      final normalizedGateways = paymentGateways
          .map(_normalizeGatewayKey)
          .where((e) => e.isNotEmpty)
          .toSet();

      // طلب واحد بسيط بدون رمي أخطاء
      final res = await _dio.get(
        'manual-payment-requests',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      // تفريغ الشكل أياً كان
      List<Map<String, dynamic>> _unwrap(dynamic payload) {
        List<Map<String, dynamic>> toList(dynamic v) {
          if (v is List) {
            return v
                .whereType<Map>()
                .map((e) => e is Map<String, dynamic>
                    ? e
                    : Map<String, dynamic>.from(e as Map))
                .toList();
          }
          return const [];
        }

        if (payload is List) return toList(payload);
        if (payload is Map) {
          for (final k in const [
            'manual_payment_requests',
            'payment_transactions',
            'transactions',
            'data',
            'items',
            'results',
          ]) {
            if (payload.containsKey(k)) {
              final lst = _unwrap(payload[k]);
              if (lst.isNotEmpty) return lst;
            }
          }
        }
        return const [];
      }

      Map<String, dynamic> _normalize(Map<String, dynamic> m) {
        // أحيانًا تكون داخل payment_transaction
        if (m['payment_transaction'] is Map) {
          m = Map<String, dynamic>.from(m['payment_transaction'] as Map);
        }
        // تطبيع أسماء الحقول
        final gatewayValue = m.containsKey('payment_gateway')
            ? m['payment_gateway']
            : (m['payment_method'] ?? m['gateway']);

        m['payment_gateway'] = _normalizeGatewayKey(
          gatewayValue is String ? gatewayValue : gatewayValue?.toString(),
        );

        if (!m.containsKey('receipt_url') && m['receipt'] is String) {
          m['receipt_url'] = m['receipt'];
        }
        return m;
      }

      final top = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{'data': res.data};

      final rows = _unwrap(top['data'] ?? top);
      if (rows.isEmpty) return [];

      final out = <ManualPayment>[];
      for (final row in rows) {
        try {
          final mp = ManualPayment.fromJson(_normalize(
              row is Map<String, dynamic>
                  ? row
                  : Map<String, dynamic>.from(row)));
          final gatewayKey = _normalizeGatewayKey(mp.paymentGateway);

          if (normalizedGateways.isEmpty ||
              normalizedGateways.contains(gatewayKey)) {
            out.add(mp);
          }
        } catch (_) {
          // تجاهل السطر المعطوب
        }
      }

      // dedupe + sort
      final seen = <String>{};
      final deduped = <ManualPayment>[];
      for (final mp in out) {
        final key =
            '${mp.paymentTransactionId ?? ''}|${mp.manualPaymentId ?? ''}|${mp.paymentGateway.toLowerCase()}';
        if (seen.add(key)) deduped.add(mp);
      }
      deduped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deduped;
    } catch (_) {
      // لا نرمي خطأ للشاشة إطلاقًا
      return [];
    }
  }
}
