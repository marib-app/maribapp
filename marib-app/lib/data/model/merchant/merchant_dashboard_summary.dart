class MerchantDashboardSummary {
  MerchantDashboardSummary({
    required this.store,
    required this.overview,
    required this.status,
    required this.workingHours,
    required this.policies,
    required this.staff,
    required this.gatewayAccounts,
  });

  factory MerchantDashboardSummary.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantDashboardSummary(
      store: MerchantStoreInfo.fromJson(data['store'] ?? const {}),
      overview: MerchantOverviewMap.fromJson(data['overview'] ?? const {}),
      status: MerchantStoreStatus.fromJson(data['status'] ?? const {}),
      workingHours: (data['working_hours'] as List? ?? const [])
          .map((dynamic item) => MerchantWorkingHour.fromJson(item))
          .toList(),
      policies: (data['policies'] as List? ?? const [])
          .map((dynamic item) => MerchantPolicy.fromJson(item))
          .toList(),
      staff: data['staff'] == null
          ? null
          : MerchantStaffInfo.fromJson(data['staff']),
      gatewayAccounts: (data['gateway_accounts'] as List? ?? const [])
          .map((dynamic item) => MerchantGatewayAccount.fromJson(item))
          .toList(),
    );
  }

  final MerchantStoreInfo store;
  final MerchantOverviewMap overview;
  final MerchantStoreStatus status;
  final List<MerchantWorkingHour> workingHours;
  final List<MerchantPolicy> policies;
  final MerchantStaffInfo? staff;
  final List<MerchantGatewayAccount> gatewayAccounts;
}

class MerchantStoreInfo {
  MerchantStoreInfo({
    required this.id,
    required this.name,
    required this.status,
    required this.timezone,
    required this.logoUrl,
  });

  factory MerchantStoreInfo.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantStoreInfo(
      id: data['id'] as int? ?? 0,
      name: (data['name'] ?? '') as String,
      status: (data['status'] ?? '') as String,
      timezone: data['timezone'] as String?,
      logoUrl: data['logo_url'] as String?,
    );
  }

  final int id;
  final String name;
  final String status;
  final String? timezone;
  final String? logoUrl;
}

class MerchantOverviewMap {
  MerchantOverviewMap({
    required this.today,
    required this.week,
    required this.month,
  });

  factory MerchantOverviewMap.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantOverviewMap(
      today: MerchantMetricSnapshot.fromJson(data['today'] ?? const {}),
      week: MerchantMetricSnapshot.fromJson(data['week'] ?? const {}),
      month: MerchantMetricSnapshot.fromJson(data['month'] ?? const {}),
    );
  }

  MerchantMetricSnapshot operator [](String key) {
    switch (key) {
      case 'week':
        return week;
      case 'month':
        return month;
      case 'today':
      default:
        return today;
    }
  }

  final MerchantMetricSnapshot today;
  final MerchantMetricSnapshot week;
  final MerchantMetricSnapshot month;
}

class MerchantMetricSnapshot {
  MerchantMetricSnapshot({
    required this.from,
    required this.to,
    required this.visits,
    required this.productViews,
    required this.addToCart,
    required this.orders,
    required this.revenue,
  });

  factory MerchantMetricSnapshot.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    final Map<String, dynamic> range =
        data['range'] is Map<String, dynamic> ? data['range'] : const {};

    return MerchantMetricSnapshot(
      from: (range['from'] ?? '') as String,
      to: (range['to'] ?? '') as String,
      visits: _asInt(data['visits']),
      productViews: _asInt(data['product_views']),
      addToCart: _asInt(data['add_to_cart']),
      orders: _asInt(data['orders']),
      revenue: _asDouble(data['revenue']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  final String from;
  final String to;
  final int visits;
  final int productViews;
  final int addToCart;
  final int orders;
  final double revenue;
}

class MerchantStoreStatus {
  MerchantStoreStatus({
    required this.status,
    required this.isManuallyClosed,
    required this.closureMode,
    required this.closureReason,
    required this.closureExpiresAt,
    required this.minOrderAmount,
    required this.allowDelivery,
    required this.allowPickup,
    required this.allowManualPayments,
    required this.allowWallet,
    required this.allowCod,
    required this.isOpenNow,
    required this.nextOpenAt,
  });

  factory MerchantStoreStatus.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantStoreStatus(
      status: (data['status'] ?? '') as String,
      isManuallyClosed: data['is_manually_closed'] as bool? ?? false,
      closureMode: (data['closure_mode'] ?? '') as String,
      closureReason: data['closure_reason'] as String?,
      closureExpiresAt: data['closure_expires_at'] as String?,
      minOrderAmount: (data['min_order_amount'] as num?)?.toDouble(),
      allowDelivery: data['allow_delivery'] as bool? ?? false,
      allowPickup: data['allow_pickup'] as bool? ?? false,
      allowManualPayments: data['allow_manual_payments'] as bool? ?? false,
      allowWallet: data['allow_wallet'] as bool? ?? false,
      allowCod: data['allow_cod'] as bool? ?? false,
      isOpenNow: data['is_open_now'] as bool? ?? false,
      nextOpenAt: data['next_open_at'] as String?,
    );
  }

  final String status;
  final bool isManuallyClosed;
  final String closureMode;
  final String? closureReason;
  final String? closureExpiresAt;
  final double? minOrderAmount;
  final bool allowDelivery;
  final bool allowPickup;
  final bool allowManualPayments;
  final bool allowWallet;
  final bool allowCod;
  final bool isOpenNow;
  final String? nextOpenAt;
}

class MerchantWorkingHour {
  MerchantWorkingHour({
    required this.weekday,
    required this.isOpen,
    required this.opensAt,
    required this.closesAt,
  });

  factory MerchantWorkingHour.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantWorkingHour(
      weekday: data['weekday'] as int? ?? 0,
      isOpen: data['is_open'] as bool? ?? false,
      opensAt: data['opens_at'] as String?,
      closesAt: data['closes_at'] as String?,
    );
  }

  final int weekday;
  final bool isOpen;
  final String? opensAt;
  final String? closesAt;
}

class MerchantPolicy {
  MerchantPolicy({
    required this.type,
    required this.title,
    required this.content,
  });

  factory MerchantPolicy.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantPolicy(
      type: (data['type'] ?? '') as String,
      title: data['title'] as String?,
      content: data['content'] as String? ?? '',
    );
  }

  final String type;
  final String? title;
  final String content;
}

class MerchantStaffInfo {
  MerchantStaffInfo({
    required this.email,
    required this.status,
    required this.role,
  });

  factory MerchantStaffInfo.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantStaffInfo(
      email: data['email'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      role: data['role'] as String? ?? 'staff',
    );
  }

  final String email;
  final String status;
  final String role;
}

class MerchantGatewayAccount {
  MerchantGatewayAccount({
    required this.id,
    required this.beneficiaryName,
    required this.accountNumber,
    required this.isActive,
    required this.gateway,
  });

  factory MerchantGatewayAccount.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantGatewayAccount(
      id: data['id'] as int? ?? 0,
      beneficiaryName: (data['beneficiary_name'] ?? '') as String,
      accountNumber: (data['account_number'] ?? '') as String,
      isActive: data['is_active'] as bool? ?? false,
      gateway: data['store_gateway'] == null
          ? null
          : MerchantGatewayInfo.fromJson(data['store_gateway']),
    );
  }

  final int id;
  final String beneficiaryName;
  final String accountNumber;
  final bool isActive;
  final MerchantGatewayInfo? gateway;
}

class MerchantGatewayInfo {
  MerchantGatewayInfo({
    required this.id,
    required this.name,
    required this.logoUrl,
  });

  factory MerchantGatewayInfo.fromJson(dynamic json) {
    final Map<String, dynamic> data =
        json is Map<String, dynamic> ? json : <String, dynamic>{};

    return MerchantGatewayInfo(
      id: data['id'] as int? ?? 0,
      name: (data['name'] ?? '') as String,
      logoUrl: data['logo_url'] as String?,
    );
  }

  final int id;
  final String name;
  final String? logoUrl;
}
