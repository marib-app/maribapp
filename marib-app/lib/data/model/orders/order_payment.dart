import 'package:meta/meta.dart';

@immutable
class OrderPaymentMethod {
  const OrderPaymentMethod({
    required this.id,
    required this.label,
    this.gateway,
    this.isDefault = false,
    this.isManual = false,
    this.raw,
  });

  final String id;
  final String label;
  final String? gateway;
  final bool isDefault;
  final bool isManual;
  final Map<String, dynamic>? raw;

  OrderPaymentMethod copyWith({
    String? id,
    String? label,
    String? gateway,
    bool? isDefault,
    bool? isManual,
    Map<String, dynamic>? raw,
  }) {
    return OrderPaymentMethod(
      id: id ?? this.id,
      label: label ?? this.label,
      gateway: gateway ?? this.gateway,
      isDefault: isDefault ?? this.isDefault,
      isManual: isManual ?? this.isManual,
      raw: raw ?? this.raw,
    );
  }
}

@immutable
class OrderPaymentIntentResult {
  const OrderPaymentIntentResult({
    this.intentId,
    this.transactionId,
    this.gateway,
    this.status,
    this.message,
    this.authorizationUrl,
    this.reference,
    this.requiresAction = false,
    this.requiresConfirmation = false,
    this.availableMethods = const <OrderPaymentMethod>[],
    this.intent,
    this.transaction,
    this.gatewayResponse,
    this.raw = const <String, dynamic>{},
  });

  final String? intentId;
  final String? transactionId;
  final String? gateway;
  final String? status;
  final String? message;
  final String? authorizationUrl;
  final String? reference;
  final bool requiresAction;
  final bool requiresConfirmation;
  final List<OrderPaymentMethod> availableMethods;
  final Map<String, dynamic>? intent;
  final Map<String, dynamic>? transaction;
  final Map<String, dynamic>? gatewayResponse;
  final Map<String, dynamic> raw;


  OrderPaymentIntentResult copyWith({
    String? intentId,
    String? transactionId,
    String? gateway,
    String? status,
    String? message,
    String? authorizationUrl,
    String? reference,
    bool? requiresAction,
    bool? requiresConfirmation,
    List<OrderPaymentMethod>? availableMethods,
    Map<String, dynamic>? intent,
    Map<String, dynamic>? transaction,
    Map<String, dynamic>? gatewayResponse,
    Map<String, dynamic>? raw,
  }) {
    return OrderPaymentIntentResult(
      intentId: intentId ?? this.intentId,
      transactionId: transactionId ?? this.transactionId,
      gateway: gateway ?? this.gateway,
      status: status ?? this.status,
      message: message ?? this.message,
      authorizationUrl: authorizationUrl ?? this.authorizationUrl,
      reference: reference ?? this.reference,
      requiresAction: requiresAction ?? this.requiresAction,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      availableMethods: availableMethods ?? this.availableMethods,
      intent: intent ?? this.intent,
      transaction: transaction ?? this.transaction,
      gatewayResponse: gatewayResponse ?? this.gatewayResponse,
      raw: raw ?? this.raw,
    );
  }

  bool get isSuccessful {
    final String normalized = (status ?? message ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    const Set<String> accepted = <String>{
      'success',
      'succeeded',
      'paid',
      'completed',
      'confirmed',
      'ok',
      'true',
    };
    if (accepted.contains(normalized)) {
      return true;
    }
    if (normalized.startsWith('success')) {
      return true;
    }
    return false;
  }
}

@immutable
class OrderPaymentAction {
  const OrderPaymentAction({
    required this.authorizationUrl,
    this.reference,
    required this.method,
    required this.intent,
  });

  final String authorizationUrl;
  final String? reference;
  final OrderPaymentMethod method;
  final OrderPaymentIntentResult intent;
}

OrderPaymentIntentResult parseOrderPaymentIntent(dynamic response) {
  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
            (dynamic key, dynamic value) => MapEntry<String, dynamic>('${key ?? ''}', value),
      );
    }
    return <String, dynamic>{'data': value};
  }

  Map<String, dynamic>? _mapify(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
            (dynamic key, dynamic value) => MapEntry<String, dynamic>('${key ?? ''}', value),
      );
    }
    return null;
  }

  Iterable<dynamic> _iterable(dynamic value) {
    if (value is Iterable) {
      return value;
    }
    if (value is Map) {
      return value.entries
          .map((dynamic entry) => entry is MapEntry ? entry.value : entry)
          .where((dynamic element) => element != null);
    }
    if (value == null) {
      return const <dynamic>[];
    }
    return <dynamic>[value];
  }

  String? _stringify(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    final String converted = value.toString().trim();
    return converted.isEmpty ? null : converted;
  }

  bool _truthy(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    const Set<String> accepted = <String>{
      'true',
      '1',
      'yes',
      'success',
      'succeeded',
      'approved',
      'completed',
      'paid',
      'confirmed',
      'requires_action',
    };
    return accepted.contains(normalized);
  }

  Map<String, dynamic> top = _asMap(response);
  final Map<String, dynamic> data =
      _mapify(top['data']) ?? _mapify(top['result']) ?? top;

  final Map<String, dynamic>? intent = _mapify(
    data['payment_intent'] ??
        data['paymentIntent'] ??
        data['intent'] ??
        data['payment'],
  ) ??
      _mapify(top['payment_intent'] ?? top['paymentIntent']);

  final Map<String, dynamic>? transaction = _mapify(
    data['payment_transaction'] ??
        data['paymentTransaction'] ??
        data['transaction'] ??
        data['payment_attempt'],
  ) ??
      _mapify(top['payment_transaction'] ?? top['paymentTransaction']);

  Map<String, dynamic>? gatewayResponse = _mapify(
    data['payment_gateway_response'] ??
        data['gateway_response'] ??
        intent?['payment_gateway_response'] ??
        intent?['gateway_response'] ??
        transaction?['payment_gateway_response'] ??
        transaction?['gateway_response'],
  );

  gatewayResponse ??= _mapify(top['payment_gateway_response'] ?? top['gateway_response']);

  final List<dynamic> methodCandidates = <dynamic>[
    data['payment_methods'],
    data['available_payment_methods'],
    data['available_methods'],
    data['allowed_payment_methods'],
    data['payment_method_tokens'],
    data['methods'],
    data['payment_method_options'],
    data['payment_gateways'],
    data['gateways'],
    data['payment_options'],
    top['payment_methods'],
    top['available_payment_methods'],
    top['allowed_payment_methods'],
    top['payment_gateways'],
    intent?['available_payment_methods'],
    intent?['allowed_payment_methods'],
    intent?['methods'],
    transaction?['available_payment_methods'],
    transaction?['allowed_payment_methods'],
  ].whereType<dynamic>().toList();

  List<OrderPaymentMethod> methods = <OrderPaymentMethod>[];

  void addMethod({String? id, String? label, Map<String, dynamic>? raw}) {
    final String? resolvedId = _stringify(id);
    if (resolvedId == null || resolvedId.isEmpty) {
      return;
    }
    final String resolvedLabel =
        _stringify(label) ?? resolvedId.toUpperCase();
    final Map<String, dynamic>? normalizedRaw = raw == null
        ? null
        : Map<String, dynamic>.from(raw);

    final bool isManual = (resolvedId.contains('manual') ||
        resolvedId.contains('bank') ||
        resolvedId.contains('transfer'));
    final bool isDefault = _truthy(raw?['is_default'] ?? raw?['default']);
    final String? gateway = _stringify(
      raw?['gateway'] ??
          raw?['payment_gateway'] ??
          raw?['payment_method'] ??
          raw?['method'],
    );

    methods.add(
      OrderPaymentMethod(
        id: resolvedId,
        label: resolvedLabel,
        gateway: gateway,
        isDefault: isDefault,
        isManual: isManual,
        raw: normalizedRaw,
      ),
    );
  }

  for (final dynamic candidate in methodCandidates) {
    if (candidate == null) {
      continue;
    }
    if (candidate is List) {
      for (final dynamic entry in candidate) {
        if (entry is Map<String, dynamic>) {
          addMethod(
            id: entry['id'] ??
                entry['payment_method'] ??
                entry['method'] ??
                entry['gateway'] ??
                entry['code'],
            label: entry['label'] ??
                entry['name'] ??
                entry['title'] ??
                entry['display'],
            raw: entry,
          );
        } else if (entry is Map) {
          final Map<String, dynamic> map =
          Map<String, dynamic>.from(entry as Map);
          addMethod(
            id: map['id'] ??
                map['payment_method'] ??
                map['method'] ??
                map['gateway'] ??
                map['code'],
            label: map['label'] ??
                map['name'] ??
                map['title'] ??
                map['display'],
            raw: map,
          );
        } else if (entry is String) {
          addMethod(id: entry, label: entry);
        }
      }
      continue;
    }
    if (candidate is Map<String, dynamic>) {
      if (candidate.containsKey('methods')) {
        for (final dynamic entry in _iterable(candidate['methods'])) {
          if (entry is Map || entry is Map<String, dynamic>) {
            final Map<String, dynamic> map =
            Map<String, dynamic>.from(entry as Map);
            addMethod(
              id: map['id'] ??
                  map['payment_method'] ??
                  map['method'] ??
                  map['gateway'] ??
                  map['code'],
              label: map['label'] ??
                  map['name'] ??
                  map['title'] ??
                  map['display'],
              raw: map,
            );
          } else if (entry is String) {
            addMethod(id: entry, label: entry);
          }
        }
        continue;
      }
      if (candidate.keys.every((dynamic key) => key is String)) {
        for (final MapEntry<String, dynamic> entry in candidate.entries) {
          final String key = entry.key;
          final dynamic value = entry.value;
          if (value is Map) {
            final Map<String, dynamic> map =
            Map<String, dynamic>.from(value as Map);
            addMethod(
              id: map['id'] ??
                  map['payment_method'] ??
                  map['method'] ??
                  map['gateway'] ??
                  key,
              label: map['label'] ??
                  map['name'] ??
                  map['title'] ??
                  map['display'] ??
                  key,
              raw: map,
            );
            continue;
          }
          addMethod(id: key, label: value?.toString() ?? key);
        }
      }
      continue;
    }
    if (candidate is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(candidate);
      for (final MapEntry<String, dynamic> entry in map.entries) {
        final String key = entry.key;
        final dynamic value = entry.value;
        if (value is Map) {
          final Map<String, dynamic> nested =
          Map<String, dynamic>.from(value as Map);
          addMethod(
            id: nested['id'] ??
                nested['payment_method'] ??
                nested['method'] ??
                nested['gateway'] ??
                key,
            label: nested['label'] ??
                nested['name'] ??
                nested['title'] ??
                nested['display'] ??
                key,
            raw: nested,
          );
        } else {
          addMethod(id: key, label: value?.toString() ?? key);
        }
      }
      continue;
    }
    if (candidate is String) {
      addMethod(id: candidate, label: candidate);
    }
  }

  final String? defaultMethodId = _stringify(
    data['default_payment_method'] ??
        data['preferred_payment_method'] ??
        intent?['default_payment_method'],
  );

  if (defaultMethodId != null && defaultMethodId.isNotEmpty) {
    methods = methods
        .map(
          (OrderPaymentMethod method) => method.copyWith(
        isDefault: method.isDefault ||
            method.id.toLowerCase() == defaultMethodId.toLowerCase(),
      ),
    )
        .toList();
  }

  String? intentId = _stringify(
    data['payment_intent_id'] ??
        data['intent_id'] ??
        data['intentId'] ??
        intent?['id'] ??
        intent?['payment_intent'] ??
        intent?['reference'] ??
        top['payment_intent_id'],
  );
  intentId ??= _stringify(transaction?['payment_intent_id']);

  String? transactionId = _stringify(
    data['payment_transaction_id'] ??
        data['transaction_id'] ??
        data['transactionId'] ??
        transaction?['id'] ??
        transaction?['reference'] ??
        transaction?['transaction_id'] ??
        top['payment_transaction_id'],
  );

  final String? gateway = _stringify(
    data['payment_method'] ??
        data['payment_gateway'] ??
        intent?['payment_method'] ??
        intent?['payment_gateway'] ??
        transaction?['payment_method'] ??
        transaction?['payment_gateway'],
  );

  final String? status = _stringify(
    data['status'] ??
        data['payment_status'] ??
        intent?['status'] ??
        intent?['payment_status'] ??
        transaction?['status'] ??
        transaction?['payment_status'],
  );

  final String? message = _stringify(
    data['message'] ??
        top['message'] ??
        intent?['message'] ??
        transaction?['message'] ??
        intent?['status_message'],
  );

  final bool requiresAction = _truthy(
    data['requires_action'] ??
        intent?['requires_action'] ??
        transaction?['requires_action'],
  );

  final bool requiresConfirmation = _truthy(
    data['requires_confirmation'] ??
        intent?['requires_confirmation'] ??
        transaction?['requires_confirmation'],
  );

  final String? authorizationUrl = _stringify(
    gatewayResponse?['authorization_url'] ??
        gatewayResponse?['authorizationUrl'] ??
        gatewayResponse?['auth_url'] ??
        gatewayResponse?['checkout_url'] ??
        gatewayResponse?['url'] ??
        data['authorization_url'] ??
        data['auth_url'],
  );

  final String? reference = _stringify(
    gatewayResponse?['reference'] ??
        gatewayResponse?['transaction_reference'] ??
        gatewayResponse?['payment_reference'] ??
        gatewayResponse?['id'] ??
        transaction?['reference'] ??
        transaction?['transaction_reference'] ??
        transaction?['payment_reference'] ??
        data['payment_reference'] ??
        data['transaction_reference'],
  );

  return OrderPaymentIntentResult(
    intentId: intentId,
    transactionId: transactionId,
    gateway: gateway,
    status: status,
    message: message,
    authorizationUrl: authorizationUrl,
    reference: reference,
    requiresAction: requiresAction,
    requiresConfirmation: requiresConfirmation,
    availableMethods: methods,
    intent: intent,
    transaction: transaction,
    gatewayResponse: gatewayResponse,
    raw: data,
  );
}