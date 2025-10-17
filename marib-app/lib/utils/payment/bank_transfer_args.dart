class BankTransferArgs {
  final String token;
  final int packageId;
  final double amount;
  final String? currency;
  final String packageType;
  final int? itemId;
  final String? purpose;
  final String? initialGateway;


  const BankTransferArgs({
    required this.token,
    required this.packageId,
    required this.amount,

    required this.packageType,
    this.currency,
    this.itemId,
    this.purpose,
    this.initialGateway,


  });
}

// اترك تعريف BankTransferArgs لديك كما هو، وأضف الامتداد التالي:
extension BankTransferArgsX on BankTransferArgs {
  Map<String, dynamic> toContext() => {
    if (packageId > 0) 'package_id': packageId,
    'package_type': packageType,
    if (itemId != null) 'item_id': itemId,
  };


  String get normalizedPurpose {
    final explicit = purpose?.trim();
    if (explicit != null && explicit.isNotEmpty) {

      final normalized = explicit.toLowerCase();
      if (normalized.contains('wallet')) {
        return 'wallet_top_up';
      }
      if (normalized.contains('order')) {
        return 'order';
      }
      if (normalized == 'general') {
        return 'general';
      }

      return explicit;
    }

    final rawType = packageType.trim().toLowerCase();

    if (rawType.contains('wallet')) {
      return 'wallet_top_up';
    }

    if (rawType.contains('order')) {
      return 'order';
    }

    if (rawType.isEmpty) {
      return 'general';
    }

    return 'package';
  }

  String? get normalizedCurrency {
    final c = currency?.trim();
    if (c == null || c.isEmpty) {
      return null;
    }
    return c.toUpperCase();
  }
  String? get normalizedGateway {
    final gateway = initialGateway?.trim();
    if (gateway == null || gateway.isEmpty) {
      return null;
    }
    return gateway.toLowerCase();
  }


}
