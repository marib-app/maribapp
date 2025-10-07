part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _CodeTile extends StatelessWidget {
  const _CodeTile({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.secondaryColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: TextStyle(
                color: color.textDefaultColor,
                fontFamily: 'monospace',
                letterSpacing: 1.05,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'نسخ الكود',
            icon: const Icon(Icons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PurchasesSheet extends StatefulWidget {
  const _PurchasesSheet({
    required this.purchasesListenable,
    required this.loadingListenable,
    required this.errorListenable,
    required this.onRefresh,
  });

  final ValueListenable<List<WifiPurchase>> purchasesListenable;
  final ValueListenable<bool> loadingListenable;
  final ValueListenable<String?> errorListenable;
  final Future<void> Function() onRefresh;

  @override
  State<_PurchasesSheet> createState() => _PurchasesSheetState();
}

class _PurchasesSheetState extends State<_PurchasesSheet> {
  late List<WifiPurchase> _purchases;
  late bool _isLoading;
  String? _error;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _syncFromListenable();

    widget.purchasesListenable.addListener(_onChanged);
    widget.loadingListenable.addListener(_onChanged);
    widget.errorListenable.addListener(_onChanged);
  }

  void _syncFromListenable() {
    _purchases = widget.purchasesListenable.value.toList();
    _isLoading = widget.loadingListenable.value;
    _error = widget.errorListenable.value;
  }

  void _onChanged() {
    if (!mounted) return;
    setState(_syncFromListenable);
  }

  @override
  void dispose() {
    widget.purchasesListenable.removeListener(_onChanged);
    widget.loadingListenable.removeListener(_onChanged);
    widget.errorListenable.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: color.backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: color.secondaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سجل المشتريات',
                          style: TextStyle(
                            color: color.textDefaultColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildBody(context, controller),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ScrollController controller,
  ) {
    final color = context.color;
    if (_isLoading && _purchases.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _purchases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 38, color: color.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: color.textDefaultColor),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.onRefresh,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_purchases.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          children: [
            const SizedBox(height: 30),
            Icon(Icons.shopping_bag_outlined,
                size: 48, color: color.secondaryColor),
            const SizedBox(height: 12),
            Text(
              'لم تقم بشراء أي خطة بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.75),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'عند إتمام عمليات شراء جديدة ستظهر الأكواد هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemBuilder: (context, index) {
          if (_error != null) {
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: color.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onRefresh,
                      child: const Text('تحديث'),
                    ),
                  ],
                ),
              );
            }
            final purchase = _purchases[index - 1];
            return _PurchaseTile(
              purchase: purchase,
              dateFormat: _dateFormat,
            );
          }
          final purchase = _purchases[index];
          return _PurchaseTile(
            purchase: purchase,
            dateFormat: _dateFormat,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemCount: _error != null ? _purchases.length + 1 : _purchases.length,
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase, required this.dateFormat});

  final WifiPurchase purchase;
  final DateFormat dateFormat;

  bool _isPending(String status) {
    final lower = status.toLowerCase();
    return lower.contains('pending') ||
        lower.contains('processing') ||
        lower.contains('await') ||
        lower.contains('انتظار') ||
        lower.contains('قيد');
  }

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    final String status = purchase.statusLabel ?? 'غير محدد';
    final bool pending = _isPending(status);
    final DateTime? createdAt = purchase.createdAt;
    final String? created =
        createdAt != null ? dateFormat.format(createdAt.toLocal()) : null;
    final String? totalText = purchase.total != null
        ? '${purchase.total!.toStringAsFixed(2)} ${purchase.currency ?? ''}'
        : null;
    final List<Widget> meta = <Widget>[
      Text(
        'الكمية: ${purchase.quantity}',
        style: TextStyle(
          color: color.textDefaultColor.withOpacity(0.7),
          fontSize: 12.5,
        ),
      ),
    ];
    if (totalText != null && totalText.trim().isNotEmpty) {
      meta.add(
        Text(
          'الإجمالي: $totalText',
          style: TextStyle(
            color: color.textDefaultColor.withOpacity(0.7),
            fontSize: 12.5,
          ),
        ),
      );
    }
    if (purchase.paymentGateway != null &&
        purchase.paymentGateway!.trim().isNotEmpty) {
      meta.add(
        Text(
          'بوابة الدفع: ${purchase.paymentGateway}',
          style: TextStyle(
            color: color.textDefaultColor.withOpacity(0.7),
            fontSize: 12.5,
          ),
        ),
      );
    }
    if (purchase.reference != null && purchase.reference!.trim().isNotEmpty) {
      meta.add(
        Text(
          'مرجع: ${purchase.reference}',
          style: TextStyle(
            color: color.textDefaultColor.withOpacity(0.65),
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.secondaryColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            purchase.planName ?? 'خطة غير معروفة',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (purchase.networkName != null) ...[
            const SizedBox(height: 4),
            Text(
              purchase.networkName!,
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.75),
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pending
                      ? Colors.orange.withOpacity(0.2)
                      : color.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: pending ? Colors.orange : color.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (purchase.paymentStatusLabel != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    purchase.paymentStatusLabel!,
                    style: TextStyle(
                      color: color.textDefaultColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (created != null)
                Text(
                  created,
                  style: TextStyle(
                    color: color.textDefaultColor.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: meta,
          ),
          const SizedBox(height: 12),
          if (purchase.codes.isNotEmpty) ...[
            Text(
              'الأكواد المصدرة',
              style: TextStyle(
                color: color.textDefaultColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: purchase.codes
                  .map(
                    (code) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: color.secondaryColor.withOpacity(0.4),
                        ),
                      ),
                      child: SelectableText(
                        code,
                        style: TextStyle(
                          color: color.textDefaultColor,
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else
            Text(
              'لم يتم إصدار أكواد بعد — بانتظار اكتمال الدفع.',
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.6),
                fontSize: 12.5,
              ),
            ),
        ],
      ),
    );
  }
}
