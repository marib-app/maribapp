import 'package:flutter/material.dart';
import 'dart:collection';
import 'package:marib/data/constants/color_catalog.dart';

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
        physics: const BouncingScrollPhysics(),
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

    final color = context.color;
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),

      itemCount: options.attributes.length,
      itemBuilder: (BuildContext context, int index) {
        final ItemPurchaseAttributeOption attribute = options.attributes[index];
        final bool isColor = _isColorAttribute(attribute);

        final bool required = attribute.requiredForCheckout;
        late final Widget content;

        if (isColor) {
          final List<CustomFieldColorEntry> activeEntries = (() {
            final List<CustomFieldColorEntry> current =
                state.colorSelections[attribute.key] ?? const <CustomFieldColorEntry>[];
            if (current.isNotEmpty) {
              return List<CustomFieldColorEntry>.from(current);
            }
            if (attribute.colorEntries.isNotEmpty) {
              return List<CustomFieldColorEntry>.from(attribute.colorEntries);
            }

            final LinkedHashSet<String> codes = LinkedHashSet<String>();
            for (final String value in attribute.allowedValues) {
              final String? normalized = _normalizeColorValue(value);
              if (normalized != null) {
                codes.add(normalized);
              }
            }
            if (codes.isEmpty) {
              for (final String value in attribute.values) {
                final String? normalized = _normalizeColorValue(value);
                if (normalized != null) {
                  codes.add(normalized);
                }
              }
            }
            return codes
                .map((String code) => CustomFieldColorEntry(code: code))
                .toList(growable: false);
          })();

          final Set<String> suggestedCodes = <String>{
            for (final String value in attribute.allowedValues)
              if (_normalizeColorValue(value) != null)
                _normalizeColorValue(value)!,
            for (final String value in attribute.values)
              if (_normalizeColorValue(value) != null)
                _normalizeColorValue(value)!,
            for (final CustomFieldColorEntry entry in attribute.colorEntries)
              entry.code,
            for (final CustomFieldColorEntry entry in activeEntries)
              entry.code,
          }..removeWhere((String value) => value.isEmpty);

          content = _ColorAttributeManager(
            entries: activeEntries,
            onManage: () => _openColorAttributeEditor(
              context: context,
              attribute: attribute,
              currentEntries: activeEntries,
              suggestedCodes: suggestedCodes,
            ),
          );
        } else {
          final List<String> optionValues = attribute.allowedValues.isNotEmpty
              ? attribute.allowedValues
              : attribute.values;
          final bool hasValues = optionValues.isNotEmpty;
          final List<String> selected =
              state.attributeSelections[attribute.key] ?? const <String>[];

          if (hasValues) {
            final Set<String> normalizedSelected = <String>{
              for (final String value in selected) value,
            }..removeWhere((String value) => value.isEmpty);

            content = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: optionValues
                  .map<Widget>((String value) {
                final bool isSelected = normalizedSelected.contains(value);
                return _buildTextAttributeChip(
                  context: context,
                  theme: theme,
                  color: color,
                  label: value,
                  isSelected: isSelected,
                  onSelected: () => cubit.toggleAttributeValue(attribute.key, value),
                );
              })
                  .toList(growable: false),
            );
          } else {
            content = TextField(
              controller: _ensureTextController(
                attribute.key,
                state.textInputs[attribute.key] ?? '',
              ),
              decoration: _themedInputDecoration(
                context,
                label: 'قيمة السمة',
              ),
              onChanged: (String value) =>
                  cubit.setTextAttribute(attribute.key, value),
            );
          }
        }

        return Card(
          color: color.secondaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.borderColor.withOpacity(0.4)),
          ),

          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(18),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        attribute.name.isEmpty ? 'سمة بدون اسم' : attribute.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                content,

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


void _openColorAttributeEditor({
  required BuildContext context,
  required ItemPurchaseAttributeOption attribute,
  required List<CustomFieldColorEntry> currentEntries,
  required Set<String> suggestedCodes,
}) {
  final String title = attribute.name.isEmpty
      ? 'إدارة ألوان السمة'
      : 'إدارة ألوان ${attribute.name}';

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
              .setColorAttributeEntries(attribute.key, entries);
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
      color:
      isSelected ? color.territoryColor : color.textDefaultColor,
    ),
    selectedColor: color.territoryColor.withOpacity(0.12),
    backgroundColor: color.secondaryColor,
    side: BorderSide(
      color:
      isSelected ? color.territoryColor : color.borderColor.withOpacity(0.5),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    onSelected: (_) => onSelected(),
  );
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
              border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
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

class _ColorAttributeEditorSheetState extends State<_ColorAttributeEditorSheet> {
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
      _entries[code] = CustomFieldColorEntry(code: code, quantity: entry.quantity);
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                        children: paletteEntries.map((Map<String, String> entry) {
                          final String? rawHex = entry['hex'];
                          final String? normalized = _normalizeColorValue(rawHex);
                          if (normalized == null) {
                            return const SizedBox.shrink();
                          }
                          final bool selected = _entries.containsKey(normalized);
                          final bool isRecommended = recommendedSet.contains(normalized);
                          final String label =
                              entry['name'] ?? '#$normalized';
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
              border: Border.all(color: Colors.black.withOpacity(0.18), width: 1),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
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
        _entries[normalized] = CustomFieldColorEntry(code: normalized, quantity: 0);
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
        _entries[normalized] = CustomFieldColorEntry(code: normalized, quantity: 0);
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
    final String label = '#$code${quantity != null && quantity > 0 ? ' × $quantity' : ''}';

    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color:
          isSelected ? palette.territoryColor : palette.textDefaultColor,
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
        color:
        isSelected ? palette.territoryColor : palette.borderColor.withOpacity(0.5),
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

  if (normalizedKey.contains('color') ||
      normalizedKey.contains('colour') ||
      normalizedKey.contains('اللون')) {
    return true;
  }

  if (normalizedName.contains('color') ||
      normalizedName.contains('colour') ||
      normalizedName.contains('اللون')) {
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
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
          final String title = _describeVariant(form.attributes, options);

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
                        onPressed: () => cubit.toggleVariantVisibility(form.variantKey),
                        icon: Icon(
                          form.hidden ? Icons.visibility_off : Icons.visibility,
                          color: color.territoryColor,

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
                    decoration: _themedInputDecoration(
                      context,
                      hint: '0',
                    ).copyWith(
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
          backgroundColor: context.color.secondaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      String displayValue = value;
      if (attribute != null && _isColorAttribute(attribute)) {
        final String? normalized = _normalizeColorValue(value);
        if (normalized != null) {
          final CustomFieldColorEntry entry = attribute.colorEntries
              .firstWhere(
                  (CustomFieldColorEntry element) => element.code == normalized,
              orElse: () => CustomFieldColorEntry(code: normalized));
          final int? quantity = entry.quantity;
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
    final theme = Theme.of(context);
    final color = context.color;


    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
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
    final String displayValue = value == null ? 'غير محدد' : formatter.format(value!);

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

    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
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