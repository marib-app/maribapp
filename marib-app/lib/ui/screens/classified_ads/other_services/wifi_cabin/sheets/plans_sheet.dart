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
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                _buildSheetHeader(theme),
                const Divider(height: 1),
                Expanded(
                  child: Builder(
                    builder: (_) => _buildSheetBody(context, controller),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader(ThemeData theme) {
    final color = context.color;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: onSurface.withOpacity(.18),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.secondaryColor.withOpacity(.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.wifi,
                    size: 20,
                    color: color.territoryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.network.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'خطط الشبكة',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onSurface.withOpacity(.65),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.allowPlanCreation) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: color.territoryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(WifiPlansSheetResult.addPlan),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة فئة'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetBody(BuildContext context, ScrollController controller) {
    const contentPadding = EdgeInsets.fromLTRB(20, 16, 20, 24);
    final theme = Theme.of(context);
    final color = context.color;

    if (_plans.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchPlans(force: true),
        child: ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentPadding,
          children: [
            const SizedBox(height: 64),
            if (_isLoading) ...[
              Center(child: CircularProgressIndicator()),
            ] else if (_error != null) ...[
              Icon(Icons.error_outline, size: 44, color: color.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _fetchPlans(force: true),
                child: const Text('إعادة المحاولة'),
              ),
            ] else ...[
              Icon(Icons.layers_outlined,
                  size: 48, color: color.secondaryColor),
              const SizedBox(height: 16),
              Text(
                'لا توجد خطط متاحة حالياً',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'جرّب تحديث الشبكة لاحقاً لمعرفة أحدث العروض.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(.65),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 64),
          ],
        ),
      );
    }

    final List<Widget> listChildren = <Widget>[];

    if (_isLoading) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(minHeight: 3),
        ),
      );
    }

    if (_error != null) {
      listChildren.add(
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: color.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color.error,
                    height: 1.3,
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
        listChildren.add(const SizedBox(height: 12));
      }
      listChildren.add(
        WifiPlanTile(
          plan: _plans[i],
          onSelect: () => _openCheckout(context, _plans[i]),
        ),
      );
    }

    listChildren.add(const SizedBox(height: 24));

    return RefreshIndicator(
      onRefresh: () => _fetchPlans(force: true),
      child: ListView(
        controller: controller,
        padding: contentPadding,
        children: listChildren,
      ),
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
