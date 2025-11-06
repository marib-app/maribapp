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
    const String helperText =
        'أدخل وزن الطرد بالكيلوجرام (مثل 2 أو 2.75). يسمح بثلاث منازل عشرية كحد أقصى ولن تُقبل أي حروف أو رموز أخرى.';

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
              children: <Widget>[
                Text(
                  'وزن الطرد',
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
                    hint: 'مثال: 2.5',
                    helperText: helperText,
                    suffixText: 'كلجم',
                  ),
                  onChanged: cubit.setDeliverySize,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _handleClear(cubit),
                    icon: const Icon(Icons.clear),
                    label: const Text('مسح الوزن'),
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