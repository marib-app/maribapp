import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import '../product_management_input_decorations.dart';

class DeliverySizeTab extends StatefulWidget {
  const DeliverySizeTab({super.key, required this.state});

  final ProductManagementState state;

  @override
  State<DeliverySizeTab> createState() => _DeliverySizeTabState();
}

class _DeliverySizeTabState extends State<DeliverySizeTab> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.deliverySizeInput);
  }

  @override
  void didUpdateWidget(covariant DeliverySizeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextValue = widget.state.deliverySizeInput;
    if (oldWidget.state.deliverySizeInput != widget.state.deliverySizeInput &&
        _controller.text != nextValue) {
      _controller.text = nextValue;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClear(ProductManagementCubit cubit) {
    if (_controller.text.isNotEmpty) {
      _controller.clear();
    }
    cubit.setDeliverySize(null);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final double? liveSize = widget.state.deliverySize;

    const List<Map<String, String>> examples = <Map<String, String>>[
      {'label': '100 جم', 'value': '0.10 كجم'},
      {'label': '500 جم', 'value': '0.50 كجم'},
      {'label': '1 كجم', 'value': '1.00 كجم'},
      {'label': '2 كجم', 'value': '2.00 كجم'},
      {'label': '5 كجم', 'value': '5.00 كجم'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Card(
          color: palette.secondaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.borderColor.withOpacity(0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعليمات تعبئة الوزن (كجم)',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'اكتب الوزن بالكيلوجرام أو أجزائه (مثال: 0.75 يعني 750 جم). تجنب إضافة رموز أو حروف.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orange.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تنبيه: حجم المنتج يؤثر مباشرة على رسوم التوصيل.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: palette.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: palette.borderColor.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: examples
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e['label']!,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  e['value']!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: palette.territoryColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: palette.secondaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.borderColor.withOpacity(0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'أدخل وزن المنتج',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: ProductManagementInputDecorations.themed(
                    context,
                    hint: 'مثال: 0.75',
                    helperText: 'أدخل الرقم فقط بالكيلوجرام (0.10 إلى 500).',
                    suffixText: 'كجم',
                  ),
                  onChanged: cubit.setDeliverySize,
                ),
                const SizedBox(height: 8),
                if (liveSize != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.scale, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'وزن منتجك الآن: ${liveSize.toStringAsFixed(3)} كجم',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _handleClear(cubit),
                    icon: const Icon(Icons.clear),
                    label: const Text('مسح الحقل'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
