class WalletOperationOptions {
  WalletOperationOptions({
    this.fields = const <Map<String, dynamic>>[],
    this.clientTag,
    this.amountFieldId,
    this.minimumAmount,
    this.maximumAmount,
    this.balance,
    this.currency,
    this.metadata = const <String, dynamic>{},
    this.raw = const <String, dynamic>{},
  });

  final List<Map<String, dynamic>> fields;
  final String? clientTag;
  final String? amountFieldId;
  final double? minimumAmount;
  final double? maximumAmount;
  final double? balance;
  final String? currency;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> raw;

  factory WalletOperationOptions.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> _parseFields(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<dynamic>()
            .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (raw is Map) {
        final list = <Map<String, dynamic>>[];
        raw.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            list.add(value);
          } else if (value is Map) {
            list.add(value.map((k, v) => MapEntry(k.toString(), v)));
          }
        });
        return list;
      }
      return const <Map<String, dynamic>>[];
    }

    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String && value.isNotEmpty) {
        return double.tryParse(value.replaceAll(',', ''));
      }
      return null;
    }

    String? _parseString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }

    final options = Map<String, dynamic>.from(map);

    final fields = _parseFields(
      options['fields'] ??
          options['inputs'] ??
          options['form'] ??
          options['schema'],
    );

    final metadata = <String, dynamic>{};
    for (final key in const ['meta', 'metadata', 'config', 'settings']) {
      final value = options[key];
      if (value is Map<String, dynamic>) {
        metadata.addAll(value);
      } else if (value is Map) {
        metadata.addAll(value.map((k, v) => MapEntry(k.toString(), v)));
      }
    }

    String? amountFieldId = _parseString(
      options['amount_field'] ??
          options['amountField'] ??
          metadata['amount_field'] ??
          metadata['amountField'] ??
          options['preferred_amount_field'],
    );

    amountFieldId ??= fields.firstWhere(
          (field) {
        final type = (field['type'] ?? field['input_type']).toString().toLowerCase();
        final name = (field['name'] ?? field['key'] ?? field['id']).toString().toLowerCase();
        return name.contains('amount') && (type.contains('number') || type.contains('text'));
      },
      orElse: () => const <String, dynamic>{},
    )['id']?.toString();

    final minimum = _parseDouble(
      options['minimum_amount'] ??
          options['min_amount'] ??
          metadata['minimum_amount'] ??
          metadata['min_amount'] ??
          metadata['minimum'],
    );

    final maximum = _parseDouble(
      options['maximum_amount'] ??
          options['max_amount'] ??
          metadata['maximum_amount'] ??
          metadata['max_amount'] ??
          metadata['maximum'],
    );

    final balance = _parseDouble(
      options['balance'] ??
          metadata['balance'] ??
          metadata['available_balance'],
    );

    final currency = _parseString(
      options['currency'] ??
          metadata['currency'] ??
          metadata['currency_code'],
    );

    return WalletOperationOptions(
      fields: fields,
      clientTag: _parseString(
        options['client_tag'] ?? metadata['client_tag'] ?? options['clientTag'],
      ),
      amountFieldId: amountFieldId,
      minimumAmount: minimum,
      maximumAmount: maximum,
      balance: balance,
      currency: currency,
      metadata: metadata,
      raw: options,
    );
  }

  WalletOperationOptions copyWith({
    List<Map<String, dynamic>>? fields,
    String? clientTag,
    String? amountFieldId,
    double? minimumAmount,
    double? maximumAmount,
    double? balance,
    String? currency,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? raw,
  }) {
    return WalletOperationOptions(
      fields: fields ?? this.fields,
      clientTag: clientTag ?? this.clientTag,
      amountFieldId: amountFieldId ?? this.amountFieldId,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumAmount: maximumAmount ?? this.maximumAmount,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      metadata: metadata ?? this.metadata,
      raw: raw ?? this.raw,
    );
  }
}