import 'package:flutter/material.dart';

/// Stock info is intentionally hidden; kept as a placeholder for future use.
class VariantStockInfo extends StatelessWidget {
  const VariantStockInfo({
    super.key,
    this.availableStock,
    this.hasVariantStocks = false,
  });

  final int? availableStock;
  final bool hasVariantStocks;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
