class WalletRecipient {
  const WalletRecipient({
    required this.id,
    required this.name,
    this.mobile,
  });

  final int id;
  final String name;
  final String? mobile;

  factory WalletRecipient.fromMap(Map<String, dynamic> map) {
    int _parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      if (value is num) {
        return value.toInt();
      }
      return 0;
    }

    String _parseName(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    String? _parseMobile(dynamic value) {
      if (value == null) {
        return null;
      }
      final candidate = value.toString();
      return candidate.isEmpty ? null : candidate;
    }

    final id = _parseId(map['id'] ?? map['user_id'] ?? map['recipient_id']);
    final name = _parseName(map['name'] ?? map['full_name']);
    final mobile = _parseMobile(
      map['mobile'] ?? map['masked_mobile'] ?? map['phone'],
    );

    return WalletRecipient(
      id: id,
      name: name,
      mobile: mobile,
    );
  }
}