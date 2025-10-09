import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/utils/helper_utils.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key, required this.item});

  final ItemModel item;

  static Route<dynamic> route(RouteSettings settings) {
    final ItemModel item = _resolveItem(settings.arguments);

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => BlocProvider(
        create: (_) =>
        ProductManagementCubit(ItemPurchaseOptionsRepository(), item)
          ..initialize(),
        child: ProductManagementScreen(item: item),
      ),
    );
  }

  static ItemModel _resolveItem(dynamic arguments) {
    if (arguments is ItemModel) {
      return arguments;
    }

    if (arguments is Map) {
      final dynamic candidate = arguments['model'] ?? arguments['item'];
      if (candidate is ItemModel) {
        return candidate;
      }
    }

    throw ArgumentError('ProductManagementScreen expects an ItemModel.');
  }

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this)
    ..addListener(_onTabChanged);
  final Map<String, TextEditingController> _textControllers =
  <String, TextEditingController>{};
  final Map<String, TextEditingController> _stockControllers =
  <String, TextEditingController>{};
  int _currentTabIndex = 0;

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    for (final TextEditingController controller in _textControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    setState(() => _currentTabIndex = _tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductManagementCubit, ProductManagementState>(
      builder: (BuildContext context, ProductManagementState state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('إدارة المنتج'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const <Tab>[
                Tab(text: 'السمات'),
                Tab(text: 'المخزون'),
                Tab(text: 'الخصم'),
              ],
            ),
          ),
          body: _buildBody(context, state),
          bottomNavigationBar: _buildBottomBar(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ProductManagementState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => context.read<ProductManagementCubit>().initialize(),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        _AttributesTab(
          state: state,
          textControllers: _textControllers,
        ),
        _StockTab(
          state: state,
          stockControllers: _stockControllers,
        ),
        _DiscountTab(state: state),
      ],
    );
  }

  Widget _buildBottomBar(
      BuildContext context, ProductManagementState state) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();

    final bool isSaving = state.attributesSaving || state.stockSaving || state.discountSaving;
    final String saveLabel = <int, String>{
      0: 'حفظ السمات',
      1: 'حفظ المخزون',
      2: 'حفظ الخصم',
    }[_currentTabIndex] ?? 'حفظ';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: isSaving ? null : () => _onSavePressed(context, cubit),
                child: isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(saveLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _finish(context),
                child: const Text('إنهاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSavePressed(
      BuildContext context, ProductManagementCubit cubit) async {
    SubmissionOutcome outcome;
    switch (_currentTabIndex) {
      case 0:
        outcome = await cubit.saveAttributes();
        break;
      case 1:
        outcome = await cubit.saveStock();
        break;
      case 2:
        outcome = await cubit.saveDiscount();
        break;
      default:
        outcome = const SubmissionOutcome(success: false, message: 'إجراء غير معروف.');
    }

    if (outcome.success) {
      HelperUtils.showSnackBarMessage(context, outcome.message);
    } else {
      HelperUtils.showSnackBarMessage(context, outcome.message);
    }
  }

  void _finish(BuildContext context) {
    Navigator.popUntil(context, (Route<dynamic> route) => route.isFirst);
    Navigator.pushNamed(
      context,
      Routes.adDetailsScreen,
      arguments: <String, dynamic>{'model': widget.item},
    );
  }
}

class _AttributesTab extends StatelessWidget {
  const _AttributesTab({required this.state, required this.textControllers});

  final ProductManagementState state;
  final Map<String, TextEditingController> textControllers;

  @override
  Widget build(BuildContext context) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final ItemPurchaseOptions? options = state.options;

    if (options == null || options.attributes.isEmpty) {
      return const _EmptyState(message: 'لا توجد سمات لإدارتها لهذا المنتج.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: options.attributes.length,
      itemBuilder: (BuildContext context, int index) {
        final ItemPurchaseAttributeOption attribute = options.attributes[index];
        final bool hasValues = attribute.allowedValues.isNotEmpty;
        final List<String> selected =
            state.attributeSelections[attribute.key] ?? const <String>[];
        final bool required = attribute.requiredForCheckout;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        attribute.name.isEmpty ? 'سمة بدون اسم' : attribute.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (required)
                      const _StatusChip(
                        icon: Icons.lock_outline,
                        label: 'مطلوب عند الشراء',
                        color: Color(0xFFFF9800),
                      ),
                    if (attribute.affectsStock)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 8),
                        child: _StatusChip(
                          icon: Icons.inventory_2_outlined,
                          label: 'يؤثر على المخزون',
                          color: Color(0xFF1976D2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasValues)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attribute.allowedValues.map((String value) {
                      final bool isSelected = selected.contains(value);
                      return FilterChip(
                        label: Text(value),
                        selected: isSelected,
                        onSelected: (_) =>
                            cubit.toggleAttributeValue(attribute.key, value),
                      );
                    }).toList(),
                  )
                else
                  TextField(
                    controller: _ensureTextController(
                      attribute.key,
                      state.textInputs[attribute.key] ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'قيمة السمة',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String value) =>
                        cubit.setTextAttribute(attribute.key, value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  TextEditingController _ensureTextController(String key, String value) {
    final TextEditingController controller =
    textControllers.putIfAbsent(key, () => TextEditingController(text: value));
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.state, required this.stockControllers});

  final ProductManagementState state;
  final Map<String, TextEditingController> stockControllers;

  @override
  Widget build(BuildContext context) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final ItemPurchaseOptions? options = state.options;
    if (options == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!state.hasStockVariants) {
      final TextEditingController controller = _ensureStockController(
        '__general__',
        (state.generalStock ?? 0).toString(),
      );

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'المخزون الكلي للمنتج',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '0',
              ),
              onChanged: (String value) =>
                  cubit.setGeneralStock(int.tryParse(value) ?? 0),
            ),
          ],
        ),
      );
    }

    if (!state.isCombinationReady) {
      return const _EmptyState(
        message: 'اختر قيم السمات المؤثرة على المخزون ثم احفظها لتوليد التركيبات.',
      );
    }

    if (state.variantForms.isEmpty) {
      return const _EmptyState(message: 'لا توجد توليفات متاحة للمخزون حالياً.');
    }

    final List<VariantStockFormState> forms = state.variantForms.values.toList()
      ..sort((VariantStockFormState a, VariantStockFormState b) =>
          a.variantKey.compareTo(b.variantKey));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _showBulkFillDialog(context),
            icon: const Icon(Icons.playlist_add),
            label: const Text('تعبئة كمية موحدة'),
          ),
        ),
        const SizedBox(height: 12),
        ...forms.map((VariantStockFormState form) {
          final TextEditingController controller = _ensureStockController(
            form.variantKey,
            form.stock.toString(),
          );
          final String title = _describeVariant(form.attributes, options);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => cubit.toggleVariantVisibility(form.variantKey),
                        icon: Icon(
                          form.hidden ? Icons.visibility_off : Icons.visibility,
                        ),
                        tooltip: form.hidden ? 'إظهار التوليفة' : 'إخفاء التوليفة',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: !form.hidden,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: '0',
                      suffixText: form.hidden ? 'مخفي' : null,
                    ),
                    onChanged: (String value) =>
                        cubit.setVariantStock(form.variantKey, int.tryParse(value) ?? 0),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showBulkFillDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تعبئة كمية موحدة'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'مثال: 10',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final int value = int.tryParse(controller.text) ?? 0;
                context.read<ProductManagementCubit>().applyBulkStock(value);
                Navigator.pop(context);
              },
              child: const Text('تطبيق'),
            ),
          ],
        );
      },
    );
  }

  TextEditingController _ensureStockController(String key, String value) {
    final TextEditingController controller =
    stockControllers.putIfAbsent(key, () => TextEditingController(text: value));
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }

  String _describeVariant(
      Map<String, String> attributes, ItemPurchaseOptions options) {
    final List<String> parts = <String>[];
    attributes.forEach((String key, String value) {
      final ItemPurchaseAttributeOption? attribute = options.attributeByKey(key);
      final String name = attribute?.name ?? key;
      parts.add('$name: $value');
    });
    return parts.join(' • ');
  }
}

class _DiscountTab extends StatefulWidget {
  const _DiscountTab({required this.state});

  final ProductManagementState state;

  @override
  State<_DiscountTab> createState() => _DiscountTabState();
}

class _DiscountTabState extends State<_DiscountTab> {
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
  void didUpdateWidget(covariant _DiscountTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextValue =
        widget.state.discountValue?.toString() ?? '';
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SwitchListTile(
          value: state.discountEnabled,
          onChanged: cubit.setDiscountEnabled,
          title: const Text('تفعيل الخصم'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: state.discountType,
          decoration: const InputDecoration(
            labelText: 'نوع الخصم',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
            DropdownMenuItem(value: 'fixed', child: Text('قيمة ثابتة')),
          ],
          onChanged: state.discountEnabled ? cubit.setDiscountType : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          enabled: state.discountEnabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: state.discountType == 'percent'
                ? 'قيمة الخصم (%)'
                : 'قيمة الخصم',
            border: const OutlineInputBorder(),
            helperText: state.discountType == 'percent'
                ? 'الحد الأقصى 90%'
                : null,
          ),
          onChanged: (String value) => cubit.setDiscountValue(
            double.tryParse(value.replaceAll(',', '.')),
          ),
        ),
        const SizedBox(height: 12),
        _DatePickerField(
          label: 'بداية الخصم',
          value: state.discountStart,
          enabled: state.discountEnabled,
          onChanged: cubit.setDiscountStart,
        ),
        const SizedBox(height: 12),
        _DatePickerField(
          label: 'نهاية الخصم',
          value: state.discountEnd,
          enabled: state.discountEnabled,
          onChanged: cubit.setDiscountEnd,
        ),
        const SizedBox(height: 24),
        _SummaryTile(
          label: 'السعر الأساسي',
          value: currencyFormatter.format(state.basePrice),
        ),
        const SizedBox(height: 8),
        _SummaryTile(
          label: 'السعر بعد الخصم',
          value: currencyFormatter.format(state.previewFinalPrice),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
    final String displayValue = value == null ? 'غير محدد' : formatter.format(value!);

    return InkWell(
      onTap: enabled ? () => _pickDateTime(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.event),
            const SizedBox(width: 12),
            Expanded(child: Text(displayValue)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = value ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (date == null) {
      return;
    }

    final TimeOfDay initialTime = TimeOfDay.fromDateTime(value ?? now);
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time == null) {
      return;
    }

    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.info_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}