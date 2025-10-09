import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/item/fetch_item_purchase_options_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';
import 'package:marib/data/model/item/purchase_options.dart';

class ProductPurchaseOptionsScreen extends StatefulWidget {
  const ProductPurchaseOptionsScreen({super.key, required this.item});

  final ItemModel item;

  static Route<dynamic> route(RouteSettings settings) {
    final ItemModel item = _resolveItem(settings.arguments);

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => BlocProvider(
        create: (_) =>
            FetchItemPurchaseOptionsCubit(ItemPurchaseOptionsRepository()),
        child: ProductPurchaseOptionsScreen(item: item),
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

    throw ArgumentError('ProductPurchaseOptionsScreen expects an ItemModel.');
  }

  @override
  State<ProductPurchaseOptionsScreen> createState() =>
      _ProductPurchaseOptionsScreenState();
}

class _ProductPurchaseOptionsScreenState
    extends State<ProductPurchaseOptionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<FetchItemPurchaseOptionsCubit>();
      final int? itemId = widget.item.id;
      if (itemId != null) {
        cubit.fetch(itemId: itemId, forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خيارات المنتج'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'السمات'),
            Tab(text: 'المخزون'),
            Tab(text: 'الخصم'),
          ],
        ),
      ),
      body:
      BlocBuilder<FetchItemPurchaseOptionsCubit, FetchItemPurchaseOptionsState>(
        builder: (BuildContext context, FetchItemPurchaseOptionsState state) {
          if (state is FetchItemPurchaseOptionsInProgress ||
              state is FetchItemPurchaseOptionsInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is FetchItemPurchaseOptionsFailure) {
            return _FailureView(
              message: state.message,
              onRetry: () {
                final int? itemId = widget.item.id;
                if (itemId != null) {
                  context
                      .read<FetchItemPurchaseOptionsCubit>()
                      .fetch(itemId: itemId, forceRefresh: true);
                }
              },
            );
          }

          if (state is FetchItemPurchaseOptionsSuccess) {
            final ItemPurchaseOptions options = state.options;
            return TabBarView(
              controller: _tabController,
              children: [
                _AttributesTab(options: options),
                _StockTab(options: options),
                _DiscountTab(options: options, currency: widget.item.currency),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message.isNotEmpty
                  ? message
                  : 'تعذر تحميل خيارات المنتج حالياً.',
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

class _AttributesTab extends StatelessWidget {
  const _AttributesTab({required this.options});

  final ItemPurchaseOptions options;

  @override
  Widget build(BuildContext context) {
    if (options.attributes.isEmpty) {
      return const _EmptyState(message: 'لا توجد سمات مطلوبة لهذا المنتج.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: options.attributes.length,
      itemBuilder: (BuildContext context, int index) {
        final ItemPurchaseAttributeOption attribute = options.attributes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        attribute.name.isNotEmpty
                            ? attribute.name
                            : 'سمة بدون اسم',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (attribute.requiredForCheckout)
                      _StatusChip(
                        icon: Icons.lock_outline,
                        label: 'مطلوب عند الشراء',
                        color: Colors.orange.shade600,
                      ),
                    if (attribute.affectsStock)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: _StatusChip(
                          icon: Icons.inventory_2_outlined,
                          label: 'يؤثر على المخزون',
                          color: Colors.blue.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (attribute.allowedValues.isNotEmpty)
                  _ValuesList(
                    title: 'القيم المسموح بها',
                    values: attribute.allowedValues,
                  )
                else if (attribute.values.isNotEmpty)
                  _ValuesList(
                    title: 'القيم المتاحة',
                    values: attribute.values,
                  )
                else
                  Text(
                    'لا توجد قائمة قيم محددة لهذه السمة.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).hintColor),
                  ),
                if (attribute.defaultValue != null &&
                    attribute.defaultValue!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'القيمة الافتراضية: ${attribute.defaultValue}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.options});

  final ItemPurchaseOptions options;

  @override
  Widget build(BuildContext context) {
    if (options.variantStocks.isEmpty) {
      return const _EmptyState(message: 'لا توجد سجلات مخزون للمتغيرات حالياً.');
    }

    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('مفتاح المتغير')),
            DataColumn(label: Text('المخزون الكلي')),
            DataColumn(label: Text('محجوز')),
            DataColumn(label: Text('المتوفر')),
          ],
          rows: options.variantStocks
              .map(
                (ItemVariantStockOption stock) => DataRow(
              cells: [
                DataCell(Text(stock.variantKey.isNotEmpty
                    ? stock.variantKey
                    : '—')),
                DataCell(Text(stock.stock.toString(), style: textTheme.bodyMedium)),
                DataCell(Text(stock.reservedStock.toString(),
                    style: textTheme.bodyMedium)),
                DataCell(Text(stock.availableStock.toString(),
                    style: textTheme.bodyMedium?.copyWith(
                        color: stock.availableStock > 0
                            ? Colors.green
                            : Colors.red))),
              ],
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}

class _DiscountTab extends StatelessWidget {
  const _DiscountTab({required this.options, this.currency});

  final ItemPurchaseOptions options;
  final String? currency;

  String _formatPrice(double value) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'ar',
      symbol: '',
      decimalDigits: 2,
    );
    final String formatted = formatter.format(value).trim();
    final String suffix = currency?.trim() ?? '';
    if (suffix.isEmpty) {
      return formatted;
    }
    return '$formatted $suffix';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '—';
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  String _readableType(String? type) {
    switch (type) {
      case 'percentage':
        return 'نسبة مئوية';
      case 'fixed':
        return 'قيمة ثابتة';
      default:
        return type ?? 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ItemDiscount? discount = options.discount;
    final bool hasDiscount =
        discount != null && (discount.isActive || options.finalPrice < options.basePrice);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _KeyValueTile(
          label: 'السعر الأساسي',
          value: _formatPrice(options.basePrice),
        ),
        const SizedBox(height: 8),
        _KeyValueTile(
          label: 'السعر بعد الخصم',
          value: _formatPrice(options.finalPrice),
        ),
        const SizedBox(height: 16),
        if (discount == null)
          const _EmptyState(message: 'لا يوجد خصم مفعل لهذا المنتج.')
        else ...[
          _KeyValueTile(
            label: 'نوع الخصم',
            value: _readableType(discount.type),
          ),
          const SizedBox(height: 8),
          _KeyValueTile(
            label: 'قيمة الخصم',
            value: discount.value != null
                ? NumberFormat('#,##0.##', 'ar').format(discount.value)
                : '—',
          ),
          const SizedBox(height: 8),
          _KeyValueTile(
            label: 'بداية الخصم',
            value: _formatDate(discount.start),
          ),
          const SizedBox(height: 8),
          _KeyValueTile(
            label: 'نهاية الخصم',
            value: _formatDate(discount.end),
          ),
          const SizedBox(height: 12),
          _StatusChip(
            icon: hasDiscount ? Icons.check_circle_outline : Icons.pause_circle_outline,
            label: hasDiscount ? 'الخصم مفعل' : 'الخصم غير مفعل',
            color: hasDiscount ? Colors.green.shade600 : Colors.grey,
          ),
        ],
      ],
    );
  }
}

class _KeyValueTile extends StatelessWidget {
  const _KeyValueTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ValuesList extends StatelessWidget {
  const _ValuesList({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values
              .map(
                (String value) => Chip(
              label: Text(value),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
          )
              .toList(),
        ),
      ],
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
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsetsDirectional.only(start: 6, end: 10, top: 4, bottom: 4),
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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}