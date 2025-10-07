class OrderOutstandingInfo {
  const OrderOutstandingInfo(this.amount, {this.label, this.currency});

  final double amount;
  final String? label;
  final String? currency;

  OrderOutstandingInfo copyWith({
    double? amount,
    String? label,
    String? currency,
  }) {
    return OrderOutstandingInfo(
      amount ?? this.amount,
      label: label ?? this.label,
      currency: currency ?? this.currency,
    );
  }
}