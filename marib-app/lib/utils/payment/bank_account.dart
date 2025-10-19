class BankAccount {
  final int manualBankId;
  final String? accountId;
  final String bankName;
  final String? accountName;
  final String? accountNumber;
  final String? iban;
  final String? swift;     // اختياري
  final String? branch;    // اختياري
  final String? notes;     // اختياري
  final String? logoUrl;
  final bool isActive;
  final int? displayOrder;

  int get id => manualBankId;

  const BankAccount({
    required this.manualBankId,
    this.accountId,
    required this.bankName,
    this.accountName,
    this.accountNumber,
    this.iban,
    this.swift,
    this.branch,
    this.notes,
    this.logoUrl,
    this.isActive = true,
    this.displayOrder,
  });

  factory BankAccount.fromJson(Map<String, dynamic> j) {
    bool asBool(dynamic v) => v == true || v == 1 || v?.toString() == '1';

    String? asString(dynamic value) {
      if (value == null) return null;
      final result = value is String ? value : value.toString();
      final trimmed = result.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    String? stringFromKeys(List<String> keys) {
      for (final key in keys) {
        if (!j.containsKey(key)) continue;
        final value = asString(j[key]);
        if (value != null) {
          return value;
        }
      }
      return null;
    }

    int? intFromKeys(List<String> keys) {
      for (final key in keys) {
        if (!j.containsKey(key)) continue;
        final value = j[key];
        if (value is int) return value;
        final stringValue = asString(value);
        if (stringValue == null) continue;
        final parsed = int.tryParse(stringValue);
        if (parsed != null) return parsed;
      }
      return null;
    }

    String? accountIdFromKeys(List<String> keys) {
      final value = stringFromKeys(keys);
      return value == null || value.isEmpty ? null : value;
    }


    return BankAccount(
      manualBankId: intFromKeys(const [
        'manual_bank_id',
        'manualBankId',
        'bank_id',
        'bankId',
        'bankID',
        'id',
      ]) ??
          0,
      accountId: accountIdFromKeys(const [


        'bank_account_id',
        'bankAccountId',
        'bankAccountID',
        'manual_bank_account_id',
        'manualBankAccountId',
        'account_id',
        'accountId',
        'accountID',
      ]),

      bankName: j['bank_name'] ?? j['name'] ?? '',
      accountName: stringFromKeys(const [
        'account_name',
        'beneficiary_name',
        'recipient_name',
        'account_holder',
        'holder',
      ]),
      accountNumber: stringFromKeys(
          const ['account_number', 'number', 'accountNumber']),


      iban: j['iban'],
      swift: j['swift'],
      branch: j['branch'],
      notes: j['notes'] ?? j['note'],
      logoUrl: j['logo_url'] ?? j['logo'],
      isActive: j['is_active'] == null ? true : asBool(j['is_active']),
      displayOrder: (j['display_order'] is int)
          ? j['display_order']
          : int.tryParse('${j['display_order'] ?? ''}'),
    );
  }
}
