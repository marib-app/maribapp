class PendingProductOptions {
  const PendingProductOptions({
    this.attributes = const <Map<String, dynamic>>[],
    this.stockRows = const <Map<String, dynamic>>[],
    this.discountPayload = const <String, dynamic>{},
    this.deliverySize,
  });

  final List<Map<String, dynamic>> attributes;
  final List<Map<String, dynamic>> stockRows;
  final Map<String, dynamic> discountPayload;
  final double? deliverySize;

  bool get hasPendingData =>
      attributes.isNotEmpty ||
      stockRows.isNotEmpty ||
      discountPayload.isNotEmpty ||
      deliverySize != null;

  PendingProductOptions copyWith({
    List<Map<String, dynamic>>? attributes,
    List<Map<String, dynamic>>? stockRows,
    Map<String, dynamic>? discountPayload,
    Object? deliverySize = _sentinel,
  }) {
    return PendingProductOptions(
      attributes: attributes ?? this.attributes,
      stockRows: stockRows ?? this.stockRows,
      discountPayload: discountPayload ?? this.discountPayload,
      deliverySize: identical(deliverySize, _sentinel)
          ? this.deliverySize
          : deliverySize as double?,
    );
  }
}

const Object _sentinel = Object();
