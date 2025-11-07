class MerchantManualPayment {
  const MerchantManualPayment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentStatus,
    required this.reference,
    required this.manualBankName,
    required this.orderNumber,
    required this.receiptUrl,
    required this.userNote,
    required this.adminNote,
    required this.createdAt,
    required this.manualBank,
    required this.attachments,
    required this.transferDetails,
  });

  factory MerchantManualPayment.fromJson(Map<String, dynamic> json) {
    final manualBankMap = _parseMap(json['manual_bank']);
    final attachmentsJson = json['attachments'];
    final transferDetailsMap = _parseMap(json['transfer_details']);

    final attachments = attachmentsJson is List
        ? List<MerchantManualPaymentAttachment>.unmodifiable(
            attachmentsJson
                .whereType<Map<String, dynamic>>()
                .map(MerchantManualPaymentAttachment.fromJson),
          )
        : const <MerchantManualPaymentAttachment>[];

    return MerchantManualPayment(
      id: _parseInt(json['id']),
      amount: _parseDouble(json['amount']),
      currency: _parseString(json['currency']) ?? 'ر.ي',
      status: _parseString(json['status']) ?? '',
      paymentStatus: _parseString(json['payment_status']) ?? '',
      reference: _parseString(json['reference']),
      manualBankName: _parseString(json['manual_bank_name']),
      orderNumber: _parseString(json['order_number']),
      receiptUrl: _parseString(json['receipt_url']),
      userNote: _parseString(json['user_note']),
      adminNote: _parseString(json['admin_note']),
      createdAt: _parseDate(json['created_at']),
      manualBank: manualBankMap != null
          ? MerchantManualBank.fromJson(manualBankMap)
          : null,
      attachments: attachments,
      transferDetails: transferDetailsMap,
    );
  }

  final int id;
  final double amount;
  final String currency;
  final String status;
  final String paymentStatus;
  final String? reference;
  final String? manualBankName;
  final String? orderNumber;
  final String? receiptUrl;
  final String? userNote;
  final String? adminNote;
  final DateTime? createdAt;
  final MerchantManualBank? manualBank;
  final List<MerchantManualPaymentAttachment> attachments;
  final Map<String, dynamic>? transferDetails;
}

class MerchantManualBank {
  const MerchantManualBank({
    this.id,
    this.name,
    this.bankName,
    this.beneficiaryName,
    this.accountName,
    this.accountNumber,
    this.iban,
    this.logoUrl,
    this.qrCodeUrl,
    this.note,
  });

  factory MerchantManualBank.fromJson(Map<String, dynamic> json) {
    return MerchantManualBank(
      id: _parseInt(json['id']),
      name: _parseString(json['name']),
      bankName: _parseString(json['bank_name']),
      beneficiaryName: _parseString(json['beneficiary_name']),
      accountName: _parseString(json['account_name']),
      accountNumber: _parseString(json['account_number']),
      iban: _parseString(json['iban']),
      logoUrl: _parseString(json['logo_url']),
      qrCodeUrl: _parseString(json['qr_code_url']),
      note: _parseString(json['note']),
    );
  }

  final int? id;
  final String? name;
  final String? bankName;
  final String? beneficiaryName;
  final String? accountName;
  final String? accountNumber;
  final String? iban;
  final String? logoUrl;
  final String? qrCodeUrl;
  final String? note;
}

class MerchantManualPaymentAttachment {
  const MerchantManualPaymentAttachment({
    this.type,
    this.name,
    this.url,
    this.mimeType,
    this.size,
  });

  factory MerchantManualPaymentAttachment.fromJson(Map<String, dynamic> json) {
    return MerchantManualPaymentAttachment(
      type: _parseString(json['type']),
      name: _parseString(json['name']),
      url: _parseString(json['url']) ?? _parseString(json['path']),
      mimeType: _parseString(json['mime_type']),
      size: json['size'] is num ? (json['size'] as num).toDouble() : null,
    );
  }

  final String? type;
  final String? name;
  final String? url;
  final String? mimeType;
  final double? size;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  final String result = value.toString().trim();
  return result.isEmpty ? null : result;
}

DateTime? _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }
  return null;
}

Map<String, dynamic>? _parseMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic v) => MapEntry(key.toString(), v));
  }
  return null;
}
