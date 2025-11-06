import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/utils/extensions/extensions.dart';

import '../product_management_input_decorations.dart';
import '../widgets/common_widgets.dart';
import 'package:marib/ui/theme/theme.dart';



class DiscountTab extends StatefulWidget {
  const DiscountTab({super.key, required this.state});

  final ProductManagementState state;

  @override
  State<DiscountTab> createState() => _DiscountTabState();
}

class _DiscountTabState extends State<DiscountTab> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.state.discountValue?.toString() ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DiscountTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextValue = widget.state.discountValue?.toString() ?? '';
    final double? controllerValue = double.tryParse(
      _controller.text.replaceAll(',', '.'),
    );
    if (oldWidget.state.discountValue != widget.state.discountValue &&
        controllerValue != widget.state.discountValue &&
        _controller.text != nextValue) {
      _controller.text = nextValue;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProductManagementState state = widget.state;
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final NumberFormat currencyFormatter = NumberFormat('#,##0.##', 'ar');
    final theme = Theme.of(context);
    final color = context.color;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.borderColor.withOpacity(0.4)),
          ),
          child: SwitchListTile(
            value: state.discountEnabled,
            onChanged: cubit.setDiscountEnabled,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            activeColor: color.territoryColor,
            title: Text(
              'تفعيل الخصم',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: state.discountType,
          decoration: ProductManagementInputDecorations.themed(
            context,
            label: 'نوع الخصم',
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
            DropdownMenuItem(value: 'fixed', child: Text('قيمة ثابتة')),
          ],
          onChanged: state.discountEnabled
              ? (String? value) {
                  if (value != null) {
                    cubit.setDiscountType(value);
                  }
                }
              : null,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          enabled: state.discountEnabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: ProductManagementInputDecorations.themed(
            context,
            label: state.discountType == 'percent'
                ? 'قيمة الخصم (%)'
                : 'قيمة الخصم',
            helperText: state.discountType == 'percent' ? 'الحد الأقصى 90%' : null,
          ),
          onChanged: (String value) => cubit.setDiscountValue(
            double.tryParse(value.replaceAll(',', '.')),
          ),
        ),
        const SizedBox(height: 16),
        ProductManagementDatePickerField(
          label: 'بداية الخصم',
          value: state.discountStart,
          enabled: state.discountEnabled,
          onChanged: cubit.setDiscountStart,
        ),
        const SizedBox(height: 12),
        ProductManagementDatePickerField(
          label: 'نهاية الخصم',
          value: state.discountEnd,
          enabled: state.discountEnabled,
          onChanged: cubit.setDiscountEnd,
        ),
        const SizedBox(height: 24),
        ProductManagementSummaryTile(
          label: 'السعر الأساسي',
          value: currencyFormatter.format(state.basePrice),
        ),
        const SizedBox(height: 8),
        ProductManagementSummaryTile(
          label: 'السعر بعد الخصم',
          value: currencyFormatter.format(state.previewFinalPrice),
        ),
      ],
    );
  }
}