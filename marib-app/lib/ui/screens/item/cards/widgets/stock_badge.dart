import 'package:flutter/material.dart';

class StockBadge extends StatelessWidget {
  final int count;
  final bool dense;

  const StockBadge({super.key, required this.count, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final Color bg = (count <= 0)
        ? Colors.redAccent.withValues(alpha: 0.9)
        : count <= 3
            ? Colors.orange.withValues(alpha: 0.9)
            : Colors.green.withValues(alpha: 0.9);

    final double pad = dense ? 6 : 8;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad / 2.2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'المتبقي: $count',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: dense ? 11 : 12,
        ),
      ),
    );
  }
}
