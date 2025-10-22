import 'package:flutter/material.dart';
import 'dart:collection';
import 'package:marib/data/constants/color_catalog.dart';
import 'package:marib/utils/ecommerce_department.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/item/product_management_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:flutter/services.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart'
    show CustomFieldColorEntry;
import 'package:marib/data/services/delivery_pricing_service.dart'
    show DeliveryPackageSize;

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key, required this.item});

  final ItemModel item;

  static Route<dynamic> route(RouteSettings settings) {
    final ItemModel item = _resolveItem(settings.arguments);

    return MaterialPageRoute(
      settings: settings,
      builder: (_) {
        if (!isEcommerceItem(item)) {
          return const _UnsupportedProductManagement();
        }

        return BlocProvider(
          create: (_) =>
              ProductManagementCubit(ItemPurchaseOptionsRepository(), item)
                ..initialize(),
          child: ProductManagementScreen(item: item),
        );
      },
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

class _UnsupportedProductManagement extends StatelessWidget {
  const _UnsupportedProductManagement();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        title: 'إدارة المنتج',
        showBackButton: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline,
                  size: 48, color: colorScheme.primary.withOpacity(0.8)),
              const SizedBox(height: 16),
              Text(
                'خيارات إدارة المنتج متاحة فقط لإعلانات أقسام المتجر أو الكمبيوتر أو شي إن.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('عودة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductManagementScreenState extends State<ProductManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this)..addListener(_onTabChanged);

  final Map<String, TextEditingController> _stockControllers =
      <String, TextEditingController>{};
  int _currentTabIndex = 0;

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();

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
        final color = context.color;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: UiUtils.getSystemUiOverlayStyle(
            context: context,
            statusBarColor: color.secondaryColor,
          ),
          child: Scaffold(
            backgroundColor: color.primaryColor,
            appBar: UiUtils.buildAppBar(
              context,
              title: 'إدارة المنتج',
              showBackButton: true,
              bottomHeight: 72,
              bottom: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildTabBar(context),
                ),
              ],
            ),
            body: _buildBody(context, state),
            bottomNavigationBar: _buildBottomBar(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ProductManagementState state) {
    final color = context.color;

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => context.read<ProductManagementCubit>().initialize(),
      );
    }

    return Container(
      color: color.primaryColor,
      child: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _AttributesTab(state: state),
          _StockTab(
            state: state,
            stockControllers: _stockControllers,
          ),
          _DiscountTab(state: state),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final color = context.color;
    final TextStyle? labelStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    return Container(
      decoration: BoxDecoration(
        color: color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.borderColor.withOpacity(0.4)),
      ),
      child: TabBar(
        controller: _tabController,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        indicator: BoxDecoration(
          color: color.territoryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: color.territoryColor,
        unselectedLabelColor: color.textDefaultColor.withOpacity(0.7),
        labelStyle: labelStyle,
        tabs: const <Tab>[
          Tab(text: 'السمات'),
          Tab(text: 'المخزون'),
          Tab(text: 'الخصم'),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ProductManagementState state) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();

    final bool isSaving =
        state.attributesSaving || state.stockSaving || state.discountSaving;
    final String saveLabel = <int, String>{
          0: 'حفظ السمات',
          1: 'حفظ المخزون',
          2: 'حفظ الخصم',
        }[_currentTabIndex] ??
        'حفظ';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(
          children: <Widget>[
            Expanded(
              child: UiUtils.buildButton(
                context,
                onPressed: () => _onSavePressed(context, cubit),
                buttonTitle: saveLabel,
                titleWhenProgress: 'جارٍ الحفظ...',
                isInProgress: isSaving,
                height: 48.rh(context),
                fontSize: context.font.large,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: UiUtils.buildButton(
                context,
                onPressed: () => _finish(context),
                buttonTitle: 'إنهاء',
                height: 48.rh(context),
                fontSize: context.font.large,
                buttonColor: context.color.secondaryColor,
                textColor: context.color.textDefaultColor,
                border: BorderSide(
                  color: context.color.borderColor.withOpacity(0.5),
                ),
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
        outcome = const SubmissionOutcome(
            success: false, message: 'إجراء غير معروف.');
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

class _AttributesTab extends StatefulWidget {
  const _AttributesTab({required this.state});

  final ProductManagementState state;

  @override
  State<_AttributesTab> createState() => _AttributesTabState();
}

class _AttributesTabState extends State<_AttributesTab> {
  final Map<String, TextEditingController> _nameControllers =
      <String, TextEditingController>{};
  final Map<String, List<TextEditingController>> _optionControllers =
      <String, List<TextEditingController>>{};

  static const List<String> _defaultSizeCatalog = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '2XL',
    '3XL',
    '4XL',
    '5XL',
    '6XL',
    '28',
    '30',
    '32',
    '34',
    '36',
    '38',
    '40',
    '42',
    '44',
    '46',
    '48',
    '50',
  ];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _AttributesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.managedAttributes != widget.state.managedAttributes ||
        oldWidget.state.attributeSelections !=
            widget.state.attributeSelections) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final List<TextEditingController> controllers
        in _optionControllers.values) {
      for (final TextEditingController controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _syncControllers() {
    final Set<String> keys = widget.state.managedAttributes
        .map((ManagedPurchaseAttribute attribute) => attribute.key)
        .toSet();

    final List<String> removedNameKeys = _nameControllers.keys
        .where((String key) => !keys.contains(key))
        .toList();
    for (final String key in removedNameKeys) {
      _nameControllers.remove(key)?.dispose();
    }

    final List<String> removedOptionKeys = _optionControllers.keys
        .where((String key) => !keys.contains(key))
        .toList();
    for (final String key in removedOptionKeys) {
      final List<TextEditingController>? controllers =
          _optionControllers.remove(key);
      if (controllers != null) {
        for (final TextEditingController controller in controllers) {
          controller.dispose();
        }
      }
    }

    for (final ManagedPurchaseAttribute attribute
        in widget.state.managedAttributes) {
      _ensureNameController(attribute.key, attribute.name);
      final List<TextEditingController> controllers = _optionControllers
          .putIfAbsent(attribute.key, () => <TextEditingController>[]);
      final int optionsLength = attribute.options.length;

      if (controllers.length > optionsLength) {
        final Iterable<TextEditingController> toDispose =
            controllers.sublist(optionsLength);
        for (final TextEditingController controller in toDispose) {
          controller.dispose();
        }
        controllers.removeRange(optionsLength, controllers.length);
      }
      while (controllers.length < optionsLength) {
        controllers.add(TextEditingController());
      }

      for (int index = 0; index < optionsLength; index++) {
        final String value = attribute.options[index];
        final TextEditingController controller = controllers[index];
        if (controller.text != value) {
          controller.text = value;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      }
    }
  }

  TextEditingController _ensureNameController(String key, String value) {
    final TextEditingController controller = _nameControllers.putIfAbsent(
        key, () => TextEditingController(text: value));
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    _syncControllers();
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final ProductManagementState state = widget.state;
    final List<ManagedPurchaseAttribute> attributes = state.managedAttributes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => _showAddAttributeMenu(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة سمة جديدة للمنتج'),
          ),
        ),
        const SizedBox(height: 16),
        _buildDeliverySizeCard(context, state),
        const SizedBox(height: 16),
        if (attributes.isEmpty)
          const _EmptyState(
            message:
                'لم يتم إضافة سمات بعد. استخدم زر "إضافة سمة جديدة للمنتج" لتخصيص المنتج.',
          )
        else
          ...attributes
              .map((ManagedPurchaseAttribute attribute) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildAttributeCard(context, attribute, cubit),
                  ))
              .toList(growable: false),
      ],
    );
  }

  Widget _buildDeliverySizeCard(
    BuildContext context,
    ProductManagementState state,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final DeliveryPackageSize? selectedSize = state.deliverySize;

    final Map<DeliveryPackageSize, String> labelKeys =
        <DeliveryPackageSize, String>{
      DeliveryPackageSize.small: 'deliverySizeSmall',
      DeliveryPackageSize.medium: 'deliverySizeMedium',
      DeliveryPackageSize.large: 'deliverySizeLarge',
    };

    final String currentLabelKey = selectedSize == null
        ? 'deliverySizeUnset'
        : labelKeys[selectedSize] ?? 'deliverySizeUnset';

    Widget buildChip({
      required DeliveryPackageSize? size,
      required String labelKey,
      required bool isSelected,
    }) {
      return _buildTextAttributeChip(
        context: context,
        theme: theme,
        color: palette,
        label: labelKey.translate(context),
        isSelected: isSelected,
        onSelected: () => cubit.setDeliverySize(size),
      );
    }

    return Card(
      color: palette.secondaryColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'deliverySizeCardTitle'.translate(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textDefaultColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'deliverySizeCardSubtitle'.translate(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textDefaultColor.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.territoryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    'deliverySizeCurrentLabel'.translate(context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.territoryColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    currentLabelKey.translate(context),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.textDefaultColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                buildChip(
                  size: DeliveryPackageSize.small,
                  labelKey: 'deliverySizeSmall',
                  isSelected: selectedSize == DeliveryPackageSize.small,
                ),
                buildChip(
                  size: DeliveryPackageSize.medium,
                  labelKey: 'deliverySizeMedium',
                  isSelected: selectedSize == DeliveryPackageSize.medium,
                ),
                buildChip(
                  size: DeliveryPackageSize.large,
                  labelKey: 'deliverySizeLarge',
                  isSelected: selectedSize == DeliveryPackageSize.large,
                ),
                buildChip(
                  size: null,
                  labelKey: 'deliverySizeClear',
                  isSelected: selectedSize == null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeCard(
    BuildContext context,
    ManagedPurchaseAttribute attribute,
    ProductManagementCubit cubit,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final ProductManagementState state = widget.state;

    final TextEditingController nameController =
        _ensureNameController(attribute.key, attribute.name);

    late final Widget content;
    switch (attribute.type) {
      case ManagedAttributeType.color:
        final List<CustomFieldColorEntry> entries =
            state.colorSelections[attribute.key] ?? attribute.colorEntries;
        final Set<String> suggestedCodes = <String>{
          for (final CustomFieldColorEntry entry in entries) entry.code,
          for (final String code
              in state.attributeSelections[attribute.key] ?? const <String>[])
            code,
        }..removeWhere((String code) => code.isEmpty);

        content = _ColorAttributeManager(
          entries: entries,
          onManage: () => _openColorAttributeEditor(
            context: context,
            attributeKey: attribute.key,
            attributeName: attribute.name,
            currentEntries: entries,
            suggestedCodes: suggestedCodes,
          ),
        );
        break;
      case ManagedAttributeType.size:
        content = _SizeAttributeManager(
          catalog: _defaultSizeCatalog,
          selected:
              state.attributeSelections[attribute.key] ?? const <String>[],
          onToggle: (String value) =>
              cubit.toggleAttributeValue(attribute.key, value),
        );
        break;
      case ManagedAttributeType.custom:
        content = _buildCustomOptions(context, attribute, cubit);
        break;
    }

    return Card(
      color: palette.secondaryColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: nameController,
              decoration: _themedInputDecoration(
                context,
                label: 'اسم السمة',
              ),
              onChanged: (String value) =>
                  cubit.setAttributeName(attribute.key, value),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: SwitchListTile(
                    value: attribute.requiredForCheckout,
                    onChanged: (bool value) =>
                        cubit.setAttributeRequired(attribute.key, value),
                    title: const Text('مطلوب عند الشراء'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    value: attribute.affectsStock,
                    onChanged: (bool value) =>
                        cubit.setAttributeAffectsStock(attribute.key, value),
                    title: const Text('يؤثر على المخزون'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                IconButton(
                  tooltip: 'حذف السمة',
                  onPressed: () => cubit.removeAttribute(attribute.key),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildCustomOptions(
    BuildContext context,
    ManagedPurchaseAttribute attribute,
    ProductManagementCubit cubit,
  ) {
    final ThemeData theme = Theme.of(context);
    final List<String> options = attribute.options;
    final List<TextEditingController> controllers = _optionControllers
        .putIfAbsent(attribute.key, () => <TextEditingController>[]);

    final List<Widget> children = <Widget>[];

    if (options.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'لم يتم إضافة خيارات بعد. أضف خيارات متعددة ليختار منها المشتري.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ),
      );
    }

    for (int index = 0; index < options.length; index++) {
      if (index >= controllers.length) {
        controllers.add(TextEditingController(text: options[index]));
      }
      final TextEditingController controller = controllers[index];
      final String optionValue = options[index];
      if (controller.text != optionValue) {
        controller.text = optionValue;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
      children.add(
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                decoration: _themedInputDecoration(
                  context,
                  label: 'الخيار ${index + 1}',
                ),
                onChanged: (String value) =>
                    cubit.updateAttributeOption(attribute.key, index, value),
              ),
            ),
            IconButton(
              tooltip: 'حذف الخيار',
              onPressed: () =>
                  cubit.removeAttributeOption(attribute.key, index),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
      if (index != options.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }
    children.add(
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => cubit.addAttributeOption(attribute.key),
          icon: const Icon(Icons.add),
          label: const Text('إضافة خيار'),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void _showAddAttributeMenu(BuildContext context) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final ColorScheme palette = context.color;
        final ThemeData theme = Theme.of(context);
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.secondaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title:
                      Text('إضافة سمة ألوان', style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.addColorAttribute();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.straighten),
                  title: Text('إضافة سمة مقاسات',
                      style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.addSizeAttribute();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.view_list_outlined),
                  title:
                      Text('إضافة سمة مخصصة', style: theme.textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    cubit.addCustomAttribute();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _openColorAttributeEditor({
  required BuildContext context,
  required String attributeKey,
  required String attributeName,
  required List<CustomFieldColorEntry> currentEntries,
  required Set<String> suggestedCodes,
}) {
  final String title = attributeName.isEmpty
      ? 'إدارة ألوان السمة'
      : 'إدارة ألوان $attributeName';

  final List<CustomFieldColorEntry> initial = currentEntries
      .map((CustomFieldColorEntry entry) =>
          CustomFieldColorEntry(code: entry.code, quantity: entry.quantity))
      .toList(growable: false);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _ColorAttributeEditorSheet(
        title: title,
        entries: initial,
        suggestedCodes: suggestedCodes,
        onSave: (List<CustomFieldColorEntry> entries) {
          context
              .read<ProductManagementCubit>()
              .setColorAttributeEntries(attributeKey, entries);
        },
      );
    },
  );
}

Widget _buildTextAttributeChip({
  required BuildContext context,
  required ThemeData theme,
  required ColorScheme color,
  required String label,
  required bool isSelected,
  required VoidCallback onSelected,
}) {
  return FilterChip(
    label: Text(label),
    selected: isSelected,
    labelStyle: theme.textTheme.bodyMedium?.copyWith(
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      color: isSelected ? color.territoryColor : color.textDefaultColor,
    ),
    selectedColor: color.territoryColor.withOpacity(0.12),
    backgroundColor: color.secondaryColor,
    side: BorderSide(
      color: isSelected
          ? color.territoryColor
          : color.borderColor.withOpacity(0.5),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    onSelected: (_) => onSelected(),
  );
}

class _SizeAttributeManager extends StatelessWidget {
  const _SizeAttributeManager({
    required this.catalog,
    required this.selected,
    required this.onToggle,
  });

  final List<String> catalog;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Set<String> selectedSet = selected.toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: catalog
          .map((String value) => _buildTextAttributeChip(
                context: context,
                theme: theme,
                color: palette,
                label: value,
                isSelected: selectedSet.contains(value),
                onSelected: () => onToggle(value),
              ))
          .toList(growable: false),
    );
  }
}

class _ColorAttributeManager extends StatelessWidget {
  const _ColorAttributeManager({
    required this.entries,
    required this.onManage,
  });

  final List<CustomFieldColorEntry> entries;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (entries.isEmpty)
          Text(
            'لم يتم اختيار ألوان بعد.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textDefaultColor.withOpacity(0.6),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: entries
                .map((CustomFieldColorEntry entry) =>
                    _ColorSelectionChip(entry: entry))
                .toList(growable: false),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onManage,
          icon: const Icon(Icons.palette_outlined),
          label: Text(entries.isEmpty ? 'اختيار الألوان' : 'تعديل الألوان'),
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.territoryColor,
            side: BorderSide(color: palette.territoryColor),
            textStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorSelectionChip extends StatelessWidget {
  const _ColorSelectionChip({required this.entry});

  final CustomFieldColorEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Color color = _colorFromHex(entry.code) ?? palette.borderColor;
    final int? quantity = entry.quantity;

    final String quantityLabel =
        quantity != null && quantity > 0 ? ' × $quantity' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border:
                  Border.all(color: Colors.black.withOpacity(0.18), width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '#${entry.code}$quantityLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.textDefaultColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorAttributeEditorSheet extends StatefulWidget {
  const _ColorAttributeEditorSheet({
    required this.title,
    required this.entries,
    required this.suggestedCodes,
    required this.onSave,
  });

  final String title;
  final List<CustomFieldColorEntry> entries;
  final Set<String> suggestedCodes;
  final ValueChanged<List<CustomFieldColorEntry>> onSave;

  @override
  State<_ColorAttributeEditorSheet> createState() =>
      _ColorAttributeEditorSheetState();
}

class _ColorAttributeEditorSheetState
    extends State<_ColorAttributeEditorSheet> {
  late LinkedHashMap<String, CustomFieldColorEntry> _entries;
  late Map<String, TextEditingController> _controllers;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _entries = LinkedHashMap<String, CustomFieldColorEntry>();
    _controllers = <String, TextEditingController>{};
    for (final CustomFieldColorEntry entry in widget.entries) {
      final String code = entry.code.toUpperCase();
      _entries[code] =
          CustomFieldColorEntry(code: code, quantity: entry.quantity);
      _controllers[code] =
          TextEditingController(text: entry.quantity?.toString() ?? '');
    }
    _hexController = TextEditingController();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final List<String> suggested = widget.suggestedCodes
        .map((String code) => code.toUpperCase())
        .toSet()
        .toList(growable: false)
      ..sort();

    final Set<String> recommendedSet = suggested.toSet();

    final List<Map<String, String>> paletteEntries = ColorCatalog.basePalette;

    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: palette.secondaryColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.borderColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'الألوان المحددة',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_entries.isEmpty)
                        Text(
                          'لم يتم اختيار أي لون بعد. اختر لونًا من اللوحات أو أضف لونًا مخصصًا.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textDefaultColor.withOpacity(0.7),
                          ),
                        )
                      else
                        Column(
                          children: _entries.values
                              .map((CustomFieldColorEntry entry) =>
                                  _buildSelectedColorTile(context, entry))
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 24),
                      if (suggested.isNotEmpty) ...<Widget>[
                        Text(
                          'الألوان المقترحة',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: suggested
                              .map((String code) => _ColorChoiceChip(
                                    code: code,
                                    label: '#$code',
                                    selected: _entries.containsKey(code),
                                    onTap: () => _toggleColor(code),
                                  ))
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        'الألوان الشائعة',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            paletteEntries.map((Map<String, String> entry) {
                          final String? rawHex = entry['hex'];
                          final String? normalized =
                              _normalizeColorValue(rawHex);
                          if (normalized == null) {
                            return const SizedBox.shrink();
                          }
                          final bool selected =
                              _entries.containsKey(normalized);
                          final bool isRecommended =
                              recommendedSet.contains(normalized);
                          final String label = entry['name'] ?? '#$normalized';
                          return _ColorChoiceChip(
                            code: normalized,
                            label: label,
                            selected: selected,
                            onTap: () => _toggleColor(normalized),
                            muted: isRecommended,
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'إضافة لون مخصص',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _hexController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _themedInputDecoration(
                                context,
                                hint: '#AABBCC',
                                label: 'كود اللون',
                              ),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9a-fA-F#]')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _addCustomColor,
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.territoryColor,
                              foregroundColor: palette.secondaryColor,
                            ),
                            child: const Text('إضافة'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.territoryColor,
                          foregroundColor: palette.secondaryColor,
                        ),
                        child: const Text('حفظ الألوان'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedColorTile(
      BuildContext context, CustomFieldColorEntry entry) {
    final ColorScheme palette = context.color;
    final ThemeData theme = Theme.of(context);
    final String code = entry.code.toUpperCase();
    final TextEditingController controller = _controllers.putIfAbsent(
      code,
      () => TextEditingController(text: entry.quantity?.toString() ?? ''),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderColor.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colorFromHex(code) ?? palette.borderColor,
              border:
                  Border.all(color: Colors.black.withOpacity(0.18), width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '#$code',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: _themedInputDecoration(
                    context,
                    label: 'الكمية المتوفرة',
                    hint: '0',
                  ),
                  onChanged: (String value) => _updateQuantity(code, value),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeColor(code),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'إزالة اللون',
          ),
        ],
      ),
    );
  }

  void _toggleColor(String code) {
    final String? normalized = _normalizeColorValue(code);
    if (normalized == null) {
      return;
    }

    setState(() {
      if (_entries.containsKey(normalized)) {
        _entries.remove(normalized);
        _controllers.remove(normalized)?.dispose();
      } else {
        _entries[normalized] =
            CustomFieldColorEntry(code: normalized, quantity: 0);
        _controllers[normalized] = TextEditingController(text: '0');
      }
    });
  }

  void _addCustomColor() {
    final String? normalized = _normalizeColorValue(_hexController.text);
    if (normalized == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'يرجى إدخال كود لون صالح مكوَّن من 6 خانات.',
      );
      return;
    }

    setState(() {
      if (!_entries.containsKey(normalized)) {
        _entries[normalized] =
            CustomFieldColorEntry(code: normalized, quantity: 0);
        _controllers[normalized] = TextEditingController(text: '0');
      }
      _hexController.clear();
    });
  }

  void _removeColor(String code) {
    setState(() {
      _entries.remove(code);
      _controllers.remove(code)?.dispose();
    });
  }

  void _updateQuantity(String code, String raw) {
    final int? parsed = int.tryParse(raw);
    setState(() {
      final CustomFieldColorEntry? current = _entries[code];
      if (current == null) {
        return;
      }
      final int? normalized = parsed == null ? null : parsed;
      _entries[code] = CustomFieldColorEntry(
        code: code,
        quantity: normalized,
      );
    });
  }

  void _save() {
    widget.onSave(_entries.values.toList(growable: false));
    Navigator.of(context).pop();
  }
}

class _ColorChoiceChip extends StatelessWidget {
  const _ColorChoiceChip({
    required this.code,
    required this.selected,
    required this.onTap,
    this.label,
    this.muted = false,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Color color = _colorFromHex(code) ?? palette.borderColor;
    final String displayLabel = label ?? '#$code';

    return ChoiceChip(
      label: Text(displayLabel),
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
        ),
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? palette.territoryColor
            : (muted
                ? palette.textDefaultColor.withOpacity(0.65)
                : palette.textDefaultColor),
      ),
      selectedColor: palette.territoryColor.withOpacity(0.18),
      backgroundColor: palette.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ColorAttributeChip extends StatelessWidget {
  const _ColorAttributeChip({
    required this.code,
    required this.entry,
    required this.isSelected,
    required this.onSelected,
  });

  final String code;
  final CustomFieldColorEntry? entry;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;
    final Color color = _colorFromHex(code) ?? palette.borderColor;
    final int? quantity = entry?.quantity;
    final String label =
        '#$code${quantity != null && quantity > 0 ? ' × $quantity' : ''}';

    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? palette.territoryColor : palette.textDefaultColor,
        ),
      ),
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
        ),
      ),
      selected: isSelected,
      selectedColor: palette.territoryColor.withOpacity(0.12),
      backgroundColor: palette.secondaryColor,
      side: BorderSide(
        color: isSelected
            ? palette.territoryColor
            : palette.borderColor.withOpacity(0.5),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

bool _isColorAttribute(ItemPurchaseAttributeOption attribute) {
  final String normalizedKey = attribute.key.toLowerCase();
  final String normalizedName = attribute.name.toLowerCase();
  final String? type = attribute.type?.toLowerCase();
  final String? uiType = attribute.uiType?.toLowerCase();

  if (type == 'color' || uiType == 'color') {
    return true;
  }

  const List<String> arabicColorKeywords = <String>[
    'لون',
    'اللون',
    'الوان',
    'ألوان',
    'الالوان'
  ];

  bool containsArabicColorKeyword(String value) {
    for (final String keyword in arabicColorKeywords) {
      if (value.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  if (normalizedKey.contains('color') ||
      normalizedKey.contains('colour') ||
      containsArabicColorKeyword(normalizedKey)) {
    return true;
  }

  if (normalizedName.contains('color') ||
      normalizedName.contains('colour') ||
      containsArabicColorKeyword(normalizedName)) {
    return true;
  }

  return false;
}

String? _normalizeColorValue(String? value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.replaceAll('#', '').trim().toUpperCase();
  final RegExp pattern = RegExp(r'^[0-9A-F]{6}$');
  return pattern.hasMatch(normalized) ? normalized : null;
}

Color? _colorFromHex(String value) {
  final String? normalized = _normalizeColorValue(value);
  if (normalized == null) {
    return null;
  }
  return Color(int.parse('0xFF$normalized'));
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.state, required this.stockControllers});

  final ProductManagementState state;
  final Map<String, TextEditingController> stockControllers;

  @override
  Widget build(BuildContext context) {
    final ProductManagementCubit cubit = context.read<ProductManagementCubit>();
    final ItemPurchaseOptions? options = state.options;
    final theme = Theme.of(context);
    final color = context.color;
    if (options == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!state.hasStockVariants) {
      final TextEditingController controller = _ensureStockController(
        '__general__',
        (state.generalStock ?? 0).toString(),
      );

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.borderColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'المخزون الكلي للمنتج',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: _themedInputDecoration(
                  context,
                  label: 'الكمية المتوفرة',
                  hint: '0',
                ),
                onChanged: (String value) =>
                    cubit.setGeneralStock(int.tryParse(value) ?? 0),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.isCombinationReady) {
      return const _EmptyState(
        message:
            'اختر قيم السمات المؤثرة على المخزون ثم احفظها لتوليد التركيبات.',
      );
    }

    if (state.variantForms.isEmpty) {
      return const _EmptyState(
          message: 'لا توجد توليفات متاحة للمخزون حالياً.');
    }

    final List<VariantStockFormState> forms = state.variantForms.values.toList()
      ..sort((VariantStockFormState a, VariantStockFormState b) =>
          a.variantKey.compareTo(b.variantKey));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              foregroundColor: color.territoryColor,
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
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
          final String title = _describeVariant(
            form.attributes,
            options,
            state.managedAttributes,
          );
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: color.secondaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: color.borderColor.withOpacity(0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            cubit.toggleVariantVisibility(form.variantKey),
                        icon: Icon(
                          form.hidden ? Icons.visibility_off : Icons.visibility,
                          color: color.territoryColor,
                        ),
                        tooltip:
                            form.hidden ? 'إظهار التوليفة' : 'إخفاء التوليفة',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: !form.hidden,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    decoration: _themedInputDecoration(
                      context,
                      hint: '0',
                    ).copyWith(
                      suffixText: form.hidden ? 'مخفي' : null,
                    ),
                    onChanged: (String value) => cubit.setVariantStock(
                        form.variantKey, int.tryParse(value) ?? 0),
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
          backgroundColor: context.color.secondaryColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تعبئة كمية موحدة',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: _themedInputDecoration(
              context,
              hint: 'مثال: 10',
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.color.textDefaultColor,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: context.color.secondaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
    final TextEditingController controller = stockControllers.putIfAbsent(
        key, () => TextEditingController(text: value));
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    return controller;
  }

  String _describeVariant(
    Map<String, String> attributes,
    ItemPurchaseOptions options,
    List<ManagedPurchaseAttribute> managedAttributes,
  ) {
    ManagedPurchaseAttribute? resolveManaged(String key) {
      for (final ManagedPurchaseAttribute attribute in managedAttributes) {
        if (attribute.key == key) {
          return attribute;
        }
      }
      return null;
    }

    final List<String> parts = <String>[];
    attributes.forEach((String key, String value) {
      final ManagedPurchaseAttribute? managed = resolveManaged(key);

      final ItemPurchaseAttributeOption? attribute =
          options.attributeByKey(key);
      final String managedName = managed?.name ?? '';
      final String attributeName = attribute?.name ?? '';
      final bool hasManagedName = managedName.trim().isNotEmpty;
      final String name = hasManagedName
          ? managedName
          : (attributeName.trim().isNotEmpty ? attributeName : key);
      String displayValue = value;
      final bool isColorAttribute =
          (managed?.type == ManagedAttributeType.color) ||
              (attribute?.type?.toLowerCase() == 'color') ||
              (attribute != null && _isColorAttribute(attribute));

      if (isColorAttribute) {
        final String? normalized = _normalizeColorValue(value);
        if (normalized != null) {
          final List<CustomFieldColorEntry> entries = (managed != null &&
                  managed.colorEntries.isNotEmpty)
              ? managed.colorEntries
              : (attribute?.colorEntries ?? const <CustomFieldColorEntry>[]);

          CustomFieldColorEntry? matched;
          for (final CustomFieldColorEntry entry in entries) {
            if (entry.code == normalized) {
              matched = entry;
              break;
            }
          }

          final int? quantity = matched?.quantity;
          displayValue = '#$normalized';
          if (quantity != null && quantity > 0) {
            displayValue = '$displayValue × $quantity';
          }
        }
      }
      parts.add('$name: $displayValue');
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
          decoration: _themedInputDecoration(
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
          decoration: _themedInputDecoration(
            context,
            label: state.discountType == 'percent'
                ? 'قيمة الخصم (%)'
                : 'قيمة الخصم',
            helperText:
                state.discountType == 'percent' ? 'الحد الأقصى 90%' : null,
          ),
          onChanged: (String value) => cubit.setDiscountValue(
            double.tryParse(value.replaceAll(',', '.')),
          ),
        ),
        const SizedBox(height: 16),
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
    final String displayValue =
        value == null ? 'غير محدد' : formatter.format(value!);

    final color = context.color;
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: GestureDetector(
        onTap: enabled ? () => _pickDateTime(context) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.borderColor.withOpacity(0.4)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.event, color: color.territoryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.textDefaultColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayValue,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: color.textDefaultColor.withOpacity(0.6),
              ),
            ],
          ),
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

    onChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.secondaryColor,
        border: Border.all(color: color.borderColor.withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color.territoryColor,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _themedInputDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final color = context.color;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helperText,
    filled: true,
    fillColor: color.secondaryColor,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color.borderColor.withOpacity(0.5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color.borderColor.withOpacity(0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color.territoryColor),
    ),
  );
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
    final color = context.color;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.territoryColor.withOpacity(0.12),
              ),
              child: Icon(
                Icons.info_outline,
                size: 36,
                color: color.territoryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.textDefaultColor.withOpacity(0.8),
              ),
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
    final color = context.color;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.error.withOpacity(0.1),
              ),
              child: Icon(
                Icons.error_outline,
                size: 36,
                color: color.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.textDefaultColor.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 16),
            UiUtils.buildButton(
              context,
              onPressed: onRetry,
              buttonTitle: 'إعادة المحاولة',
              height: 44,
              fontSize: context.font.large,
            ),
          ],
        ),
      ),
    );
  }
}
