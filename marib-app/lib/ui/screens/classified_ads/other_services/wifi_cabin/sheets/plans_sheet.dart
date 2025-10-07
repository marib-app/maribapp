part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _PlansSheet extends StatefulWidget {
  const _PlansSheet({
    required this.network,
    required this.onRegisterPurchase,
    required this.onRefreshPurchases,
    required this.onShowCodes,
  });

  final WifiNetwork network;
  final ValueChanged<WifiPurchase> onRegisterPurchase;
  final Future<void> Function({bool force}) onRefreshPurchases;
  final Future<void> Function(WifiPurchase) onShowCodes;

  @override
  State<_PlansSheet> createState() => _PlansSheetState();
}

class _PlansSheetState extends State<_PlansSheet> {
  final WifiRepository _repository = const WifiRepository();
  List<WifiPlan> _plans = <WifiPlan>[];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plans = List<WifiPlan>.from(widget.network.plans);
    _fetchPlans();
  }

  Future<void> _fetchPlans({bool force = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (force) {
        _error = null;
      }
    });

    List<WifiPlan> fetched = _plans;
    String? errorMessage;

    try {
      fetched = await _repository.fetchNetworkPlans(widget.network.id);
    } catch (error) {
      errorMessage = error.toString();
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (errorMessage != null) {
        _error = errorMessage;
      } else {
        _plans = fetched;
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: color.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                    const Icon(Icons.wifi),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.network.name,
                        style: TextStyle(
                          color: color.textDefaultColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      'خطط الشبكة',
                      style: TextStyle(
                        color: color.textDefaultColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Builder(
                  builder: (_) {
                    if (_isLoading && _plans.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_error != null && _plans.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 36, color: color.error),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: color.textDefaultColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _fetchPlans(force: true),
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (_plans.isEmpty) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 32,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Icon(Icons.layers_outlined,
                                size: 48, color: color.secondaryColor),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد خطط متاحة حالياً',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: color.textDefaultColor.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'جرّب تحديث الشبكة لاحقاً لمعرفة أحدث العروض.',
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
                      onRefresh: () => _fetchPlans(force: true),
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
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
                                    onPressed: () => _fetchPlans(force: true),
                                    child: const Text('تحديث'),
                                  ),
                                ],
                              ),
                            ),
                          for (int i = 0; i < _plans.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _PlanTile(
                              plan: _plans[i],
                              onSelect: () => _openCheckout(context, _plans[i]),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCheckout(BuildContext context, WifiPlan plan) async {
    final result = await showModalBottomSheet<WifiPurchaseResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => _CheckoutSheet(plan: plan),
    );
    if (result == null) return;

    final WifiPurchase? purchase = result.purchase;
    if (purchase != null) {
      widget.onRegisterPurchase(purchase);
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (result.isPending) {
      final String message =
          result.message ?? 'تم إرسال طلب الدفع. سنخطرك عند اكتمال المعالجة.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      unawaited(widget.onRefreshPurchases(force: true));
      return;
    }

    if (purchase != null) {
      if (purchase.codes.isNotEmpty) {
        await widget.onShowCodes(purchase);
      } else {
        final String message = result.message ?? 'تمت عملية الشراء بنجاح.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      unawaited(widget.onRefreshPurchases(force: true));
      return;
    }

    if (result.message != null && result.message!.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(result.message!)));
    }
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.onSelect});

  final WifiPlan plan;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.secondaryColor.withOpacity(0.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.name,
              style: TextStyle(
                color: color.textDefaultColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plan.description ?? 'تفاصيل الخطة ستظهر هنا.',
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.75),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${plan.price.toStringAsFixed(2)} ${plan.currency ?? 'ريال'}',
                  style: TextStyle(
                    color: color.textDefaultColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
