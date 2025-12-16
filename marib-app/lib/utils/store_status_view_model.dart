import 'package:intl/intl.dart';

class StoreStatusViewModel {
  const StoreStatusViewModel({
    required this.hasData,
    this.id,
    this.name,
    this.slug,
    this.logoUrl,
    this.isOpenNow = true,
    this.browseOnly = false,
    this.minOrderAmount,
    this.nextOpenAt,
    this.manualClosureReason,
    this.checkoutNotice,
    this.manualBankLabels = const <String>[],
    this.manualBankAccounts = const <StoreManualBankAccount>[],
    this.allowManualPayments = true,
  });

  final bool hasData;
  final int? id;
  final String? name;
  final String? slug;
  final String? logoUrl;
  final bool isOpenNow;
  final bool browseOnly;
  final double? minOrderAmount;
  final DateTime? nextOpenAt;
  final String? manualClosureReason;
  final String? checkoutNotice;
  final List<String> manualBankLabels;
  final List<StoreManualBankAccount> manualBankAccounts;
  final bool allowManualPayments;

  bool get hasManualBanks => manualBankAccounts.isNotEmpty;

  String? formatNextOpenLabel({String locale = 'en'}) {
    if (nextOpenAt == null) {
      return null;
    }

    try {
      final DateFormat formatter = DateFormat('EEEE d MMM، h:mm a', locale);
      return formatter.format(nextOpenAt!);
    } catch (_) {
      return nextOpenAt!.toLocal().toString();
    }
  }

  StoreStatusViewModel copyWith({
    bool? hasData,
    int? id,
    String? name,
    String? slug,
    String? logoUrl,
    bool? isOpenNow,
    bool? browseOnly,
    double? minOrderAmount,
    DateTime? nextOpenAt,
    String? manualClosureReason,
    String? checkoutNotice,
    List<String>? manualBankLabels,
    List<StoreManualBankAccount>? manualBankAccounts,
    bool? allowManualPayments,
  }) {
    return StoreStatusViewModel(
      hasData: hasData ?? this.hasData,
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logoUrl: logoUrl ?? this.logoUrl,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      browseOnly: browseOnly ?? this.browseOnly,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      nextOpenAt: nextOpenAt ?? this.nextOpenAt,
      manualClosureReason: manualClosureReason ?? this.manualClosureReason,
      checkoutNotice: checkoutNotice ?? this.checkoutNotice,
      manualBankLabels: manualBankLabels ?? this.manualBankLabels,
      manualBankAccounts: manualBankAccounts ?? this.manualBankAccounts,
      allowManualPayments: allowManualPayments ?? this.allowManualPayments,
    );
  }

  factory StoreStatusViewModel.fromMap(Map<String, dynamic>? store) {
    if (store == null || store.isEmpty) {
      return const StoreStatusViewModel(hasData: false);
    }

    final Map<String, dynamic>? status = store['status'] is Map<String, dynamic>
        ? store['status'] as Map<String, dynamic>
        : null;

    DateTime? nextOpenAt;
    final dynamic nextOpenRaw = status?['next_open_at'];
    if (nextOpenRaw is String && nextOpenRaw.trim().isNotEmpty) {
      nextOpenAt = DateTime.tryParse(nextOpenRaw)?.toLocal();
    }

    final List<StoreManualBankAccount> manualBankAccounts =
        <StoreManualBankAccount>[];
    final List<String> manualBankLabels = <String>[];
    final dynamic rawBanks = store['manual_banks'];
    if (rawBanks is Iterable) {
      for (final dynamic entry in rawBanks) {
        if (entry is Map) {
          final StoreManualBankAccount account =
              StoreManualBankAccount.fromDynamic(entry);
          manualBankAccounts.add(account);
          if (account.displayLabel.isNotEmpty) {
            manualBankLabels.add(account.displayLabel);
          }
        }
      }
    }

    double? minOrder;
    final dynamic minOrderRaw = status?['min_order_amount'];
    if (minOrderRaw is num) {
      minOrder = minOrderRaw.toDouble();
    } else if (minOrderRaw is String) {
      final double? parsed = double.tryParse(minOrderRaw);
      if (parsed != null) {
        minOrder = parsed;
      }
    }

    return StoreStatusViewModel(
      hasData: true,
      id: store['id'] is int
          ? store['id'] as int
          : int.tryParse('${store['id']}'),
      name: store['name']?.toString(),
      slug: store['slug']?.toString(),
      logoUrl: store['logo_url']?.toString(),
      isOpenNow: status?['is_open_now'] ?? true,
      browseOnly: (status?['closure_mode'] ?? 'full') == 'browse_only',
      minOrderAmount: minOrder,
      nextOpenAt: nextOpenAt,
      manualClosureReason: status?['closure_reason']?.toString(),
      checkoutNotice: status?['checkout_notice']?.toString(),
      manualBankLabels: manualBankLabels,
      manualBankAccounts: manualBankAccounts,
      allowManualPayments: status?['allow_manual_payments'] ?? true,
    );
  }
}

class StoreManualBankAccount {
  StoreManualBankAccount({
    this.name,
    this.beneficiaryName,
    this.accountNumber,
    this.iban,
    this.branch,
    this.gatewayName,
    this.storeGatewayAccountId,
    this.storeGatewayId,
    this.raw,
  });

  factory StoreManualBankAccount.fromDynamic(dynamic source) {
    if (source is Map<String, dynamic>) {
      return StoreManualBankAccount.fromMap(source);
    }
    if (source is Map) {
      return StoreManualBankAccount.fromMap(
        source.map((dynamic key, dynamic value) => MapEntry(
              key.toString(),
              value,
            )),
      );
    }
    return StoreManualBankAccount(raw: {});
  }

  factory StoreManualBankAccount.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic>? gateway = map['gateway'] is Map<String, dynamic>
        ? map['gateway'] as Map<String, dynamic>
        : (map['gateway'] is Map
            ? Map<String, dynamic>.from(map['gateway'] as Map)
            : null);

    return StoreManualBankAccount(
      name: map['name']?.toString(),
      beneficiaryName: map['beneficiary_name']?.toString(),
      accountNumber: map['account_number']?.toString(),
      iban: map['iban']?.toString(),
      branch: map['branch']?.toString(),
      gatewayName: gateway?['name']?.toString(),
      storeGatewayAccountId: map['store_gateway_account_id'] is int
          ? map['store_gateway_account_id'] as int
          : int.tryParse('${map['store_gateway_account_id']}'),
      storeGatewayId: map['store_gateway_id'] is int
          ? map['store_gateway_id'] as int
          : int.tryParse('${map['store_gateway_id']}'),
      raw: map,
    );
  }

  final String? name;
  final String? beneficiaryName;
  final String? accountNumber;
  final String? iban;
  final String? branch;
  final String? gatewayName;
  final int? storeGatewayAccountId;
  final int? storeGatewayId;
  final Map<String, dynamic>? raw;

  String get displayLabel {
    final String? primary = name?.trim();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }

    final String? gateway = gatewayName?.trim();
    if (gateway != null && gateway.isNotEmpty) {
      return gateway;
    }

    final String? beneficiary = beneficiaryName?.trim();
    if (beneficiary != null && beneficiary.isNotEmpty) {
      return beneficiary;
    }

    return 'الحساب البنكي';
  }
}
