import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/custom_field/custom_field_model.dart'
    show CustomFieldColorEntry;
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/variant_key.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';

class ProductReviewScreen extends StatefulWidget {
  const ProductReviewScreen({
    super.key,
    required this.item,
    this.initialOptions,
    this.initialMessage,
  });

  final ItemModel item;
  final ItemPurchaseOptions? initialOptions;
  final String? initialMessage;

  static Route<dynamic> route(RouteSettings settings) {
    ItemModel? item;
    ItemPurchaseOptions? options;
    String? message;

    final dynamic arguments = settings.arguments;
    if (arguments is ItemModel) {
      item = arguments;
    } else if (arguments is Map) {
      final dynamic itemCandidate =
          arguments['item'] ?? arguments['model'] ?? arguments['ad'];
      if (itemCandidate is ItemModel) {
        item = itemCandidate;
      }
      final dynamic optionsCandidate = arguments['options'];
      if (optionsCandidate is ItemPurchaseOptions) {
        options = optionsCandidate;
      }
      final dynamic messageCandidate = arguments['message'];
      if (messageCandidate is String && messageCandidate.trim().isNotEmpty) {
        message = messageCandidate;
      }
    }

    if (item == null) {
      throw ArgumentError(
        'ProductReviewScreen expects an ItemModel in the arguments.',
      );
    }

    return AppPageRoute.build(
      settings: settings,
      builder: (_) => ProductReviewScreen(
        item: item!,
        initialOptions: options,
        initialMessage: message,
      ),
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  late ItemModel _item;
  ItemPurchaseOptions? _options;
  bool _isFetching = false;
  String? _error;
  bool _publishing = false;

  final ItemPurchaseOptionsRepository _optionsRepository =
      ItemPurchaseOptionsRepository();
  final ItemRepository _itemRepository = ItemRepository();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _options = widget.initialOptions;

    if (_options == null && _item.id != null) {
      _fetchOptions();
    }

    final String? message = widget.initialMessage;
    if (message != null && message.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        HelperUtils.showSnackBarMessage(context, message);
      });
    }
  }

  Future<void> _fetchOptions() async {
    if (_isFetching) {
      return;
    }

    final int? itemId = _item.id;
    if (itemId == null) {
      setState(() {
        _error = 'لا يمكن تحميل بيانات المراجعة بدون معرّف الإعلان.';
      });
      return;
    }

    setState(() {
      _isFetching = true;
      if (_options == null) {
        _error = null;
      }
    });

    try {
      final ItemPurchaseOptions options =
          await _optionsRepository.fetch(itemId);
      if (!mounted) {
        return;
      }
      setState(() {
        _options = options;
        _error = null;
      });
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = message.isNotEmpty
            ? message
            : 'تعذر تحميل بيانات المراجعة حالياً. حاول مجدداً لاحقاً.';
      });
    } finally {
      if (!mounted) {
        _isFetching = false;
        return;
      }
      setState(() {
        _isFetching = false;
      });
    }
  }

  Future<void> _publishNow() async {
    if (_publishing) {
      return;
    }

    final int? itemId = _item.id;
    if (itemId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'لا يمكن نشر الإعلان قبل الحصول على معرّف صالح.',
      );
      return;
    }

    final String status = (_item.status ?? '').toLowerCase();
    if (status == 'review') {
      HelperUtils.showSnackBarMessage(
        context,
        'الإعلان قيد المراجعة بالفعل.',
      );
      return;
    }

    const Set<String> publishedStates = <String>{
      'approved',
      'active',
      'published',
      'enabled',
    };
    if (publishedStates.contains(status)) {
      HelperUtils.showSnackBarMessage(
        context,
        'الإعلان منشور بالفعل.',
      );
      return;
    }

    if (status == 'rejected') {
      HelperUtils.showSnackBarMessage(
        context,
        'لا يمكن نشر الإعلان وهو مرفوض. يرجى تعديل البيانات وإعادة المحاولة.',
      );
      return;
    }

    setState(() {
      _publishing = true;
    });

    bool loaderDismissed = false;
    Widgets.showLoader(context);
    try {
      await _itemRepository.changeMyItemStatus(
        itemId: itemId,
        status: 'active',
      );

      final ItemModel? refreshed = await _reloadItem(itemId);
      if (!mounted) {
        return;
      }

      Widgets.hideLoder(context);
      loaderDismissed = true;

      if (refreshed != null) {
        _item = refreshed;
      } else {
        _item.status = 'review';
      }

      HelperUtils.showSnackBarMessage(
        context,
        'تم إرسال الإعلان للمراجعة بنجاح.',
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.adDetailsScreen,
        (Route<dynamic> route) => route.isFirst,
        arguments: <String, dynamic>{'model': _item},
      );
    } catch (error) {
      final String message =
          ErrorFilter.check(error).error?.toString() ?? error.toString();
      if (mounted) {
        if (!loaderDismissed) {
          Widgets.hideLoder(context);
          loaderDismissed = true;
        }
        HelperUtils.showSnackBarMessage(
          context,
          message.isNotEmpty
              ? message
              : 'تعذر نشر الإعلان حالياً. حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
        });
        if (!loaderDismissed) {
          Widgets.hideLoder(context);
        }
      }
    }
  }

  Future<ItemModel?> _reloadItem(int itemId) async {
    try {
      final DataOutput<ItemModel> response =
          await _itemRepository.fetchItemFromItemId(itemId);
      if (response.modelList.isNotEmpty) {
        return response.modelList.first;
      }
    } catch (_) {
      // تجاهل الخطأ في التحديث الخلفي، سنعتمد على الحالة الحالية.
    }
    return null;
  }

  String _resolveCurrency() {
    final String? currency = _item.currency ?? _item.currencyCode;
    return currency?.trim() ?? '';
  }

  String _formatPrice(double value) {
    final NumberFormat formatter = NumberFormat('#,##0.00', 'ar');
    final String currency = _resolveCurrency();
    final String formatted = formatter.format(value);
    return currency.isEmpty ? formatted : '$formatted $currency';
  }

  String _formatDeliverySize(double value) {
    final NumberFormat formatter = NumberFormat('#,##0.###', 'ar');
    return formatter.format(value);
  }

  String? _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    final DateFormat formatter = DateFormat('yyyy/MM/dd • HH:mm', 'ar');
    return formatter.format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final bool showOverlay = _isFetching && _options != null;

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        title: 'مراجعة الإعلان',
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: _isFetching ? null : _fetchOptions,
            tooltip: 'إعادة التحميل',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (showOverlay)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_options == null) {
      if (_isFetching) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_error != null) {
        return _ErrorView(message: _error!, onRetry: _fetchOptions);
      }

      return _ErrorView(
        message: 'لم نعثر على بيانات لعرضها. حاول إعادة التحميل.',
        onRetry: _fetchOptions,
      );
    }

    final ItemPurchaseOptions options = _options!;

    return RefreshIndicator(
      color: context.color.territoryColor,
      onRefresh: () async {
        await _fetchOptions();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSummaryCard(options),
          const SizedBox(height: 16),
          _buildAttributesSection(options),
          const SizedBox(height: 16),
          _buildStockSection(options),
          const SizedBox(height: 16),
          _buildDiscountSection(options),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final String status = (_item.status ?? '').trim().toLowerCase();
    const Set<String> blockedStatuses = <String>{
      'review',
      'approved',
      'active',
      'published',
      'enabled',
      'rejected',
    };

    final bool hasBlockedStatus = blockedStatuses.contains(status);
    final bool disablePublish =
        _publishing || _item.id == null || hasBlockedStatus;
    final String buttonTitle =
        hasBlockedStatus ? _resolveDisabledButtonTitle(status) : 'نشر الآن';
    final String? disabledMessage =
        hasBlockedStatus ? _resolveDisabledMessage(status) : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _publishing ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.color.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('عودة'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiUtils.buildButton(
                    context,
                    onPressed: () async {
                      if (disablePublish) {
                        return;
                      }
                      await _publishNow();
                    },
                    buttonTitle: buttonTitle,
                    titleWhenProgress: 'جارٍ النشر...',
                    height: 48,
                    isInProgress: _publishing,
                    disabled: disablePublish,
                    onTapDisabledButton: disabledMessage == null
                        ? null
                        : () => HelperUtils.showSnackBarMessage(
                              context,
                              disabledMessage,
                            ),
                  ),
                  if (disabledMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      disabledMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.color.textColor.withOpacity(0.8),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveDisabledButtonTitle(String status) {
    switch (status) {
      case 'review':
        return 'بانتظار المراجعة';
      case 'approved':
      case 'active':
      case 'published':
      case 'enabled':
        return 'منشور بالفعل';
      case 'rejected':
        return 'غير متاح للنشر';
      default:
        return 'نشر الآن';
    }
  }

  String? _resolveDisabledMessage(String status) {
    switch (status) {
      case 'review':
        return 'الإعلان قيد المراجعة بالفعل.';
      case 'approved':
      case 'active':
      case 'published':
      case 'enabled':
        return 'الإعلان منشور بالفعل.';
      case 'rejected':
        return 'لا يمكن نشر الإعلان وهو مرفوض. يرجى تعديل البيانات وإعادة المحاولة.';
      default:
        return null;
    }
  }

  Widget _buildSummaryCard(ItemPurchaseOptions options) {
    final ThemeData theme = Theme.of(context);

    final List<_SummaryRow> rows = <_SummaryRow>[
      _SummaryRow('سعر الأساس', _formatPrice(options.basePrice)),
      _SummaryRow('السعر النهائي', _formatPrice(options.finalPrice)),
    ];

    if (options.deliverySize != null) {
      rows.add(
        _SummaryRow(
            'وزن الشحن (كجم)', _formatDeliverySize(options.deliverySize!)),
      );
    }

    return _SectionCard(
      title: 'ملخص الأسعار',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map((_SummaryRow row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _buildKeyValueRow(theme, row.label, row.value),
                ))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAttributesSection(ItemPurchaseOptions options) {
    final List<ItemPurchaseAttributeOption> attributes = options.attributes;

    if (attributes.isEmpty) {
      return _SectionCard(
        title: 'سمات المنتج',
        child: const _EmptyState('لم يتم إعداد سمات للمنتج.'),
      );
    }

    return _SectionCard(
      title: 'سمات المنتج',
      child: Column(
        children: attributes
            .map((ItemPurchaseAttributeOption attribute) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAttributeTile(attribute),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildAttributeTile(ItemPurchaseAttributeOption attribute) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    final List<Widget> chips = <Widget>[];
    if (attribute.requiredForCheckout) {
      chips.add(_buildFlagChip('إلزامي عند الشراء', palette.territoryColor));
    }
    if (attribute.affectsStock) {
      chips.add(_buildFlagChip('يؤثر على المخزون', palette.secondaryColor));
    }

    final List<Widget> metadata = chips.isNotEmpty
        ? [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            const SizedBox(height: 12),
          ]
        : <Widget>[];

    final bool isColorAttribute = attribute.colorEntries.isNotEmpty ||
        (attribute.type?.toLowerCase() == 'color');

    Widget valuesWidget;
    if (isColorAttribute) {
      final List<CustomFieldColorEntry> entries = attribute.colorEntries.isEmpty
          ? attribute.allowedValues
              .map((String value) => CustomFieldColorEntry(code: value))
              .toList(growable: false)
          : attribute.colorEntries;

      if (entries.isEmpty) {
        valuesWidget = const _EmptyState('لم يتم تحديد ألوان لهذه السمة.');
      } else {
        valuesWidget = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entries.map(_buildColorSwatch).toList(),
        );
      }
    } else {
      final List<String> values = attribute.values.isNotEmpty
          ? attribute.values
          : (attribute.allowedValues.isNotEmpty
              ? attribute.allowedValues
              : attribute.selectedValues);

      if (values.isEmpty) {
        valuesWidget = const _EmptyState('لم يتم تحديد خيارات لهذه السمة.');
      } else {
        valuesWidget = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (String value) => Chip(
                  label: Text(value, style: theme.textTheme.bodyMedium),
                  backgroundColor: palette.secondaryColor.withOpacity(0.7),
                ),
              )
              .toList(),
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.secondaryColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attribute.name.isNotEmpty ? attribute.name : 'سمة بدون اسم',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...metadata,
          valuesWidget,
        ],
      ),
    );
  }

  Widget _buildStockSection(ItemPurchaseOptions options) {
    final List<ItemVariantStockOption> variantStocks = options.variantStocks;
    if (variantStocks.isEmpty) {
      return _SectionCard(
        title: 'المخزون',
        child: const _EmptyState('لم يتم تعيين مخزون للإعلان بعد.'),
      );
    }

    ItemVariantStockOption? generalStock;
    for (final ItemVariantStockOption entry in variantStocks) {
      if (entry.variantKey.trim().isEmpty) {
        generalStock = entry;
        break;
      }
    }

    final List<ItemVariantStockOption> variants = variantStocks
        .where(
            (ItemVariantStockOption element) => element.variantKey.isNotEmpty)
        .toList(growable: false);

    final List<Widget> children = <Widget>[];
    if (generalStock != null) {
      children.add(_buildGeneralStockTile(generalStock));
    }

    if (variants.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }
      children.add(
        Text(
          'تفاصيل التوليفات',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
      children.add(const SizedBox(height: 12));
      children.addAll(variants.map(_buildVariantTile));
    }

    return _SectionCard(
      title: 'المخزون',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildGeneralStockTile(ItemVariantStockOption option) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المخزون العام', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStockPill('الإجمالي', option.stock),
              _buildStockPill('المتوفر', option.availableStock),
              _buildStockPill('المحجوز', option.reservedStock),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantTile(ItemVariantStockOption option) {
    final ThemeData theme = Theme.of(context);
    final Map<String, String> attributes =
        VariantKeyCodec.decode(option.variantKey);
    final String label = attributes.entries
        .map((MapEntry<String, String> entry) =>
            entry.value.isEmpty ? entry.key : '${entry.key}: ${entry.value}')
        .join(' | ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.primaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.isNotEmpty ? label : 'توليفة غير مسماة',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStockPill('الإجمالي', option.stock),
              _buildStockPill('المتوفر', option.availableStock),
              _buildStockPill('المحجوز', option.reservedStock),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockPill(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.color.secondaryColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value'),
    );
  }

  Widget _buildDiscountSection(ItemPurchaseOptions options) {
    final ItemDiscount? discount = options.discount;
    final bool hasDiscount =
        discount != null && ((discount.value ?? 0) > 0 || discount.isActive);

    return _SectionCard(
      title: 'الخصومات',
      child: hasDiscount
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKeyValueRow(
                  Theme.of(context),
                  'نوع الخصم',
                  discount!.type == 'fixed' ? 'قيمة ثابتة' : 'نسبة مئوية',
                ),
                const SizedBox(height: 8),
                _buildKeyValueRow(
                  Theme.of(context),
                  'قيمة الخصم',
                  discount.type == 'fixed'
                      ? _formatPrice(discount.value ?? 0)
                      : '${NumberFormat('#,##0.##', 'ar').format(discount.value ?? 0)}%',
                ),
                if (discount.start != null || discount.end != null) ...[
                  const SizedBox(height: 8),
                  _buildKeyValueRow(
                    Theme.of(context),
                    'بداية الخصم',
                    _formatDate(discount.start) ?? 'غير محدد',
                  ),
                  const SizedBox(height: 8),
                  _buildKeyValueRow(
                    Theme.of(context),
                    'نهاية الخصم',
                    _formatDate(discount.end) ?? 'غير محدد',
                  ),
                ],
                const SizedBox(height: 12),
                _buildKeyValueRow(
                  Theme.of(context),
                  'السعر بعد الخصم',
                  _formatPrice(options.finalPrice),
                ),
              ],
            )
          : const _EmptyState('لم يتم تفعيل أي خصومات حالياً.'),
    );
  }

  Widget _buildKeyValueRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlagChip(String label, Color color) {
    final Color background = color.withOpacity(0.85);
    return Chip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.color.textAutoAdapt(background),
            ),
      ),
      backgroundColor: background,
    );
  }

  Widget _buildColorSwatch(CustomFieldColorEntry entry) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    Color? parsedColor;
    try {
      parsedColor = Color(int.parse('0xFF${entry.code}'));
    } catch (_) {
      parsedColor = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: parsedColor ?? palette.secondaryColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.borderColor.withOpacity(0.4)),
          ),
        ),
        const SizedBox(height: 6),
        Text('#${entry.code}', style: theme.textTheme.bodySmall),
        if (entry.quantity != null)
          Text(
            'المخزون: ${entry.quantity}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textLightColor,
            ),
          ),
      ],
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme palette = context.color;

    return Card(
      margin: EdgeInsets.zero,
      color: palette.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}


