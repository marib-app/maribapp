import 'dart:async';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:flutter/material.dart';

import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/model/wifi/wifi_purchase.dart';
import 'package:marib/data/model/wifi/wifi_purchase_result.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'checkout_sheet.dart';
enum WifiPlansSheetResult { addPlan }

class WifiPlansSheet extends StatefulWidget {
  const WifiPlansSheet({
    super.key,
    required this.network,
    required this.onRegisterPurchase,
    required this.onRefreshPurchases,
    required this.onShowCodes,
    this.allowPlanCreation = false,
    this.repository = const WifiRepository(),

  });

  final WifiNetwork network;
  final ValueChanged<WifiPurchase> onRegisterPurchase;
  final Future<void> Function({bool force}) onRefreshPurchases;
  final Future<void> Function(WifiPurchase) onShowCodes;
  final bool allowPlanCreation;
  final WifiRepository repository;

  @override
  State<WifiPlansSheet> createState() => WifiPlansSheetState();
}

class WifiPlansSheetState extends State<WifiPlansSheet> {
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
      fetched = await widget.repository.fetchNetworkPlans(widget.network.id);
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
                    if (widget.allowPlanCreation) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pop(WifiPlansSheetResult.addPlan),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة فئة'),
                      ),
                    ],
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
                    final List<Widget> listChildren = <Widget>[];

                    if (_isLoading) {
                      listChildren.add(
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      );
                    }

                    if (_error != null) {
                      listChildren.add(
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
                      );
                    }

                    if (widget.network.loginScreenshotUrl != null) {
                      listChildren.addAll(
                        [
                          WifiLoginScreenshotPreview(
                            imageUrl: widget.network.loginScreenshotUrl!,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }

                    for (int i = 0; i < _plans.length; i++) {
                      if (i > 0) {
                        listChildren.add(const SizedBox(height: 10));
                      }
                      listChildren.add(
                        WifiPlanTile(
                          plan: _plans[i],
                          onSelect: () => _openCheckout(context, _plans[i]),
                        ),
                      );
                    }

                    listChildren.add(const SizedBox(height: 16));

                    return RefreshIndicator(
                      onRefresh: () => _fetchPlans(force: true),
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: listChildren,
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
      builder: (_) => WifiCheckoutSheet(plan: plan),
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

class WifiPlanTile extends StatelessWidget {
  const WifiPlanTile({super.key, required this.plan, required this.onSelect});

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
            WifiSheetPlanHighlights(plan: plan),
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

class WifiSheetPlanHighlights extends StatelessWidget {
  const WifiSheetPlanHighlights({super.key, required this.plan});

  final WifiPlan plan;

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    final List<String> labels = <String>[];

    if (plan.isUnlimited) {
      labels.add('بيانات غير محدودة');
    } else if (plan.dataCapGb != null) {
      final num cap = plan.dataCapGb!;
      if (cap >= 1) {
        final bool hasFraction = cap % 1 != 0;
        labels.add('${cap.toStringAsFixed(hasFraction ? 1 : 0)} جيجابايت');
      } else {
        final num mb = (cap * 1024).round();
        labels.add('$mb ميجابايت');
      }
    }

    if (plan.durationDays != null && plan.durationDays! > 0) {
      labels.add('صلاحية ${plan.durationDays} يوم');
    }

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: labels
            .map(
              (label) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: color.secondaryColor.withOpacity(0.35)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color.textDefaultColor.withOpacity(0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class WifiLoginScreenshotPreview extends StatelessWidget {
  const WifiLoginScreenshotPreview({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: color.secondaryColor.withOpacity(0.2),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  );
                },
                errorBuilder: (context, _, __) {
                  return Container(
                    color: color.secondaryColor.withOpacity(0.2),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: color.textDefaultColor.withOpacity(0.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تعذّر تحميل صورة صفحة الدخول',
                          style: TextStyle(
                            color: color.textDefaultColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'تأكد من تطابق صفحة الدخول قبل الشراء',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اضغط على الصورة لعرضها بالحجم الكامل والتحقق من هوية الشبكة.',
            style: TextStyle(
              color: color.textDefaultColor.withOpacity(0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, __) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
