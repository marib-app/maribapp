import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // للخريطة في نموذج إضافة شبكة
import 'package:geolocator/geolocator.dart'; // للمسافة/إذن الموقع
import 'package:shimmer/shimmer.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:marib/data/model/wifi/wifi_purchase.dart';
import 'package:marib/data/model/wifi/wifi_purchase_result.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/data/model/wifi/wifi_payment_gateway.dart';
import 'package:intl/intl.dart';
import 'package:marib/utils/api.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:meta/meta.dart';
import 'package:marib/utils/helper_utils.dart';

class WifiCabinScreen extends StatefulWidget {
  const WifiCabinScreen({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const WifiCabinScreen(),
      settings: settings,
      maintainState: true,
    );
  }

  @override
  State<WifiCabinScreen> createState() => _WifiCabinScreenState();
}

class _WifiCabinScreenState extends State<WifiCabinScreen> {
  late final WifiCabinController _controller;

  final WifiRepository _repository = const WifiRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<List<WifiPurchase>> _purchasesNotifier =
      ValueNotifier<List<WifiPurchase>>(<WifiPurchase>[]);
  final ValueNotifier<bool> _purchasesLoadingNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<String?> _purchasesErrorNotifier =
      ValueNotifier<String?>(null);
  bool _hasLoadedPurchases = false;

  @override
  void initState() {
    super.initState();
    _controller = WifiCabinController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.bootstrap();
      _fetchPurchases();
    });
  }

  @override
  void dispose() {
    _purchasesNotifier.dispose();
    _purchasesLoadingNotifier.dispose();
    _purchasesErrorNotifier.dispose();
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.viewState;
        if (_searchController.text != _controller.query) {
          _searchController.value = _searchController.value.copyWith(
            text: _controller.query,
            selection: TextSelection.collapsed(
              offset: _controller.query.length,
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: 'wifiCabin'.translate(context),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _SearchHeaderBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  isLoading: state.status == WifiCabinLoadStatus.loading &&
                      !state.hasData,
                  onChanged: (value) => _controller.updateQuery(value),
                  onSubmitted: (value) =>
                      _controller.updateQuery(value, immediate: true),
                  onClear: _controller.clearQuery,
                  onRefresh: () => _controller.refreshNetworks(force: true),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildBodyForState(context, state),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openAddNetworkSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة شبكة جديدة'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyForState(BuildContext context, WifiCabinViewState state) {
    final grid = _buildNetworksGrid(state);

    switch (state.status) {
      case WifiCabinLoadStatus.loading:
        if (state.hasData) {
          return Stack(
            key: const ValueKey('loading_with_data'),
            children: [
              grid,
              const _LoadingOverlay(),
            ],
          );
        }
        return _buildShimmerGrid();
      case WifiCabinLoadStatus.success:
        return _buildNetworksGrid(state, key: const ValueKey('success'));
      case WifiCabinLoadStatus.failure:
        if (state.hasData) {
          return Stack(
            key: const ValueKey('failure_with_data'),
            children: [
              grid,
              _ErrorBanner(
                message:
                    state.errorMessage ?? 'تعذّر تحديث الشبكات، حاول مجددًا.',
                onRetry: () => _controller.refreshNetworks(),
              ),
            ],
          );
        }
        return _ErrorState(
          key: const ValueKey('failure'),
          message: state.errorMessage ?? 'تعذّر جلب الشبكات في الوقت الحالي.',
          onRetry: () => _controller.refreshNetworks(),
        );
    }
  }

  Widget _buildNetworksGrid(WifiCabinViewState state, {Key? key}) {
    return _NetworksGrid(
      key: key,
      networks: state.networks,
      onSelect: (network) => _openPlansSheet(context, network),
      onRefresh: () => _controller.refreshNetworks(force: true),
      searchQuery: _controller.query,
    );
  }

  Widget _buildShimmerGrid() {
    final color = context.color.secondaryColor;
    final base = color.withOpacity(0.35);
    final highlight = color.withOpacity(0.18);

    return GridView.builder(
      key: const ValueKey('loading_shimmer'),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: 6,
      itemBuilder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(
                  height: 70,
                  width: double.infinity,
                  color: base,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                height: 12,
                width: 90,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                height: 10,
                width: 60,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchPurchases({bool force = false}) async {
    if (_purchasesLoadingNotifier.value) return;
    if (!force && _hasLoadedPurchases) return;
    _hasLoadedPurchases = true;
    _purchasesLoadingNotifier.value = true;
    _purchasesErrorNotifier.value = null;
    try {
      final purchases = await _repository.fetchPurchases();
      _purchasesNotifier.value = purchases;
    } catch (error) {
      _purchasesErrorNotifier.value = _describeError(error);
    } finally {
      _purchasesLoadingNotifier.value = false;
    }
  }

  void _registerPurchase(WifiPurchase purchase) {
    final List<WifiPurchase> current =
        List<WifiPurchase>.from(_purchasesNotifier.value);
    final int index =
        current.indexWhere((element) => element.id == purchase.id);
    if (index >= 0) {
      current[index] = purchase;
    } else {
      current.insert(0, purchase);
    }
    _purchasesNotifier.value = current;
    _purchasesErrorNotifier.value = null;
    _hasLoadedPurchases = true;
  }

  Future<void> _openPurchasesSheet(BuildContext context) async {
    unawaited(_fetchPurchases());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => _PurchasesSheet(
        purchasesListenable: _purchasesNotifier,
        loadingListenable: _purchasesLoadingNotifier,
        errorListenable: _purchasesErrorNotifier,
        onRefresh: () => _fetchPurchases(force: true),
      ),
    );
  }

  Future<void> _showCodesDialog(WifiPurchase purchase) async {
    final List<String> codes = purchase.codes;
    if (codes.isEmpty) return;
    final int codeId = purchase.id;

    if (codeId > 0) {
      unawaited(
        _repository
            .logCodeEvent(codeId: codeId, action: 'view')
            .catchError((_) {}),
      );
    }
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final color = dialogContext.color;
        return AlertDialog(
          title: Text(
            'أكواد ${purchase.planName ?? 'الخطة'}',
            style: TextStyle(color: color.textDefaultColor),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: codes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final code = codes[index];
                return _CodeTile(
                  code: code,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: code));
                    if (codeId > 0) {
                      unawaited(
                        _repository
                            .logCodeEvent(codeId: codeId, action: 'copy')
                            .catchError((_) {}),
                      );
                    }
                    messenger.showSnackBar(
                      SnackBar(content: Text('تم نسخ الكود: $code')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            if (codes.length > 1)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: codes.join('\n')));
                  if (codeId > 0) {
                    unawaited(
                      _repository
                          .logCodeEvent(codeId: codeId, action: 'copy')
                          .catchError((_) {}),
                    );
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('تم نسخ جميع الأكواد.')),
                  );
                },
                child: const Text('نسخ الكل'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('تم'),
            ),
          ],
        );
      },
    );
  }

  String _describeError(Object error) {
    if (error is ApiHttpException) {
      final Map<String, dynamic> payload = error.payload is Map<String, dynamic>
          ? Map<String, dynamic>.from(error.payload as Map)
          : error.payload is Map
              ? Map<String, dynamic>.from(error.payload as Map)
              : <String, dynamic>{};
      final String? base = _stringify(
        payload['message'] ?? payload['error'] ?? payload['detail'],
      );
      final List<String> details = _flattenErrors(payload['errors']);
      final List<String> parts = <String>[
        if (base != null && base.isNotEmpty) base,
        if (details.isNotEmpty) details.join('\n'),
      ];
      if (parts.isEmpty) {
        return error.toString();
      }
      return parts.join('\n');
    }
    if (error is ApiException) {
      return error.toString();
    }
    return error.toString();
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    return value.toString();
  }

  List<String> _flattenErrors(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .map((dynamic element) => _stringify(element))
          .whereType<String>()
          .where((element) => element.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      final List<String> results = <String>[];
      value.forEach((_, dynamic element) {
        final List<String> nested = _flattenErrors(element);
        if (nested.isEmpty) {
          final String? candidate = _stringify(element);
          if (candidate != null && candidate.isNotEmpty) {
            results.add(candidate);
          }
        } else {
          results.addAll(nested);
        }
      });
      return results;
    }
    final String? single = _stringify(value);
    if (single == null || single.isEmpty) {
      return const <String>[];
    }
    return <String>[single];
  }

  Future<void> _openAddNetworkSheet(BuildContext context) async {
    final dynamic result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => _AddNetworkSheet(
        repository: _repository,
      ),
    );

    if (result != null) {
      await _controller.refreshNetworks(force: true);
      if (!mounted) return;
      String? message;
      if (result is Map) {
        final map = Map<String, dynamic>.from(result as Map);
        message = (map['message'] as String?) ??
            (() {
              final String? name = map['name'] as String?;
              final String? status = map['status'] as String?;
              if (name != null && status != null) {
                return 'تم إرسال طلب الشبكة "$name" (الحالة: $status)';
              }
              if (name != null) {
                return 'تمت إضافة الشبكة "$name" بنجاح';
              }
              if (status != null) {
                return 'تم إرسال الطلب (الحالة: $status)';
              }
              return null;
            })();
      } else if (result is String) {
        message = 'تمت إضافة الشبكة "$result" بنجاح';
      }
      message ??= 'تم إرسال طلب الشبكة بنجاح';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _openPlansSheet(
      BuildContext context, WifiNetwork network) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => _PlansSheet(
        network: network,
        onRegisterPurchase: _registerPurchase,
        onRefreshPurchases: _fetchPurchases,
        onShowCodes: _showCodesDialog,
      ),
    );
  }
}

class _SearchHeaderBar extends StatelessWidget {
  const _SearchHeaderBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.secondaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ابحث عن شبكة Wi-Fi بالاسم',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'مثال: شبكة الحارة أو اسم المقهى',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                icon: const Icon(Icons.clear),
                                onPressed: onClear,
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                width: 46,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onRefresh,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من مطابقة صورة صفحة الدخول قبل الشراء، وأبلغ صاحب الشبكة عن أي مشكلة.',
            style: TextStyle(
              color: color.textDefaultColor.withOpacity(0.75),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworksGrid extends StatelessWidget {
  const _NetworksGrid({
    super.key,
    required this.networks,
    required this.onSelect,
    required this.onRefresh,
    required this.searchQuery,
  });

  final List<WifiNetwork> networks;
  final ValueChanged<WifiNetwork> onSelect;
  final VoidCallback onRefresh;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (networks.isEmpty) {
      final String trimmed = searchQuery.trim();
      final String subtitle = trimmed.isEmpty
          ? 'ابدأ بالبحث عن اسم الشبكة أو راجع قائمة الشبكات المتاحة من مزودي الخدمة.'
          : 'لم يتم العثور على نتائج لـ "$trimmed". جرّب جزءًا من الاسم أو تحقق من التهجئة.';
      return _EmptyState(
        title: 'لم يتم العثور على شبكات',
        subtitle: subtitle,
        onAction: onRefresh,
        actionLabel: 'تحديث القائمة',
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: networks.length,
      itemBuilder: (context, index) {
        final WifiNetwork network = networks[index];
        final String subtitle = network.planCount > 0
            ? 'عدد الفئات: ${network.planCount}'
            : 'اطلع على تفاصيل الشبكة';
        final String? currencyBadge =
            network.currencies.isNotEmpty ? network.currencies.first : null;

        return _WifiNetworkCard(
          name: network.name,
          subtitle: subtitle,
          imageUrl: network.iconUrl ?? network.loginScreenshotUrl,
          currencyBadge: currencyBadge,
          onTap: () => onSelect(network),
        );
      },
    );
  }
}

class _WifiNetworkCard extends StatelessWidget {
  const _WifiNetworkCard({
    required this.name,
    required this.subtitle,
    this.imageUrl,
    this.currencyBadge,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final String? currencyBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    Widget buildImage() {
      if (imageUrl == null || imageUrl!.isEmpty) {
        return Container(
          height: 70,
          width: double.infinity,
          color: color.secondaryColor,
          alignment: Alignment.center,
          child: const Icon(Icons.wifi, size: 36),
        );
      }

      return Image.network(
        imageUrl!,
        height: 70,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 70,
            width: double.infinity,
            color: color.secondaryColor,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, _, __) {
          return Container(
            height: 70,
            width: double.infinity,
            color: color.secondaryColor,
            alignment: Alignment.center,
            child: const Icon(Icons.wifi, size: 36),
          );
        },
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(child: buildImage()),
                  if (currencyBadge != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currencyBadge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.textDefaultColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.textDefaultColor.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                      return RefreshIndicator(
                        onRefresh: () => _fetchPlans(force: true),
                        child: ListView(
                          controller: controller,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 32,
                          ),
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
                          if (widget.network.loginScreenshotUrl != null) ...[
                            _LoginScreenshotPreview(
                              imageUrl: widget.network.loginScreenshotUrl!,
                            ),
                            const SizedBox(height: 12),
                          ],
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

class _LoginScreenshotPreview extends StatelessWidget {
  const _LoginScreenshotPreview({required this.imageUrl});

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
            const SizedBox(height: 10),
            _WifiPlanHighlights(plan: plan),
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

class _WifiPlanHighlights extends StatelessWidget {
  const _WifiPlanHighlights({required this.plan});

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

class _CheckoutSheet extends StatefulWidget {
  final WifiPlan plan;

  const _CheckoutSheet({required this.plan});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final WifiRepository _repository = const WifiRepository();
  final Map<String, WifiPaymentGateway> _gatewayEntities =
      <String, WifiPaymentGateway>{};

  int _quantity = 1;
  String _gateway = 'wallet';
  List<PaymentGatewayView> _gateways = <PaymentGatewayView>[];
  bool _loadingGateways = false;
  String? _gatewaysError;
  bool _isSubmitting = false;
  bool _acknowledged = false;

  num get total => widget.plan.price * _quantity;

  @override
  void initState() {
    super.initState();
    _loadGateways();
  }

  Future<void> _loadGateways() async {
    if (_loadingGateways) return;
    setState(() {
      _loadingGateways = true;
      _gatewaysError = null;
    });

    List<PaymentGatewayView> views = _gateways;
    Map<String, WifiPaymentGateway> lookup = <String, WifiPaymentGateway>{};
    String? selectedId;
    String? errorMessage;

    try {
      final gateways = await _repository.fetchPaymentGateways();
      lookup = {for (final gateway in gateways) gateway.id: gateway};
      views = gateways
          .map(
            (gateway) => PaymentGatewayView(
              id: gateway.id,
              name: gateway.name,
              description: gateway.description,
            ),
          )
          .toList();

      if (views.isEmpty) {
        final WifiPaymentGateway fallback = const WifiPaymentGateway(
            id: 'wallet', name: 'المحفظة', isWallet: true);
        lookup = <String, WifiPaymentGateway>{fallback.id: fallback};
        views = const <PaymentGatewayView>[
          PaymentGatewayView(id: 'wallet', name: 'المحفظة'),
        ];
      }

      selectedId = _pickDefaultGatewayId(gateways, views.first.id);
    } catch (error) {
      errorMessage = error is ApiHttpException
          ? _extractErrorMessage(error.payload) ?? error.toString()
          : error.toString();
      if (_gateways.isEmpty) {
        final WifiPaymentGateway fallback = const WifiPaymentGateway(
            id: 'wallet', name: 'المحفظة', isWallet: true);
        lookup = <String, WifiPaymentGateway>{fallback.id: fallback};
        views = const <PaymentGatewayView>[
          PaymentGatewayView(id: 'wallet', name: 'المحفظة'),
        ];
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingGateways = false;
        _gateways = views;
        if (lookup.isNotEmpty) {
          _gatewayEntities
            ..clear()
            ..addAll(lookup);
        } else if (_gateways.isNotEmpty &&
            !_gatewayEntities.containsKey(_gateways.first.id)) {
          _gatewayEntities[_gateways.first.id] = WifiPaymentGateway(
            id: _gateways.first.id,
            name: _gateways.first.name,
            isWallet: _gateways.first.id.toLowerCase() == 'wallet',
          );
        }
        if (selectedId != null) {
          _gateway = selectedId!;
        } else if (!_gateways.any((gateway) => gateway.id == _gateway) &&
            _gateways.isNotEmpty) {
          _gateway = _gateways.first.id;
        }
        _gatewaysError = errorMessage;
      });
    }
  }

  String _pickDefaultGatewayId(
    List<WifiPaymentGateway> gateways,
    String fallbackId,
  ) {
    for (final gateway in gateways) {
      if (gateway.isDefault) {
        return gateway.id;
      }
    }
    for (final gateway in gateways) {
      if (gateway.isWallet) {
        return gateway.id;
      }
    }
    return fallbackId;
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    return value.toString();
  }

  List<String> _flattenErrors(dynamic value) {
    if (value == null) return const <String>[];
    if (value is List) {
      return value
          .map((dynamic element) => _stringify(element))
          .whereType<String>()
          .where((element) => element.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      final List<String> results = <String>[];
      value.forEach((_, dynamic element) {
        final List<String> nested = _flattenErrors(element);
        if (nested.isEmpty) {
          final String? candidate = _stringify(element);
          if (candidate != null && candidate.isNotEmpty) {
            results.add(candidate);
          }
        } else {
          results.addAll(nested);
        }
      });
      return results;
    }
    final String? single = _stringify(value);
    if (single == null || single.isEmpty) {
      return const <String>[];
    }
    return <String>[single];
  }

  String? _extractErrorMessage(dynamic payload) {
    if (payload is Map) {
      final Map<String, dynamic> map = payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map);
      final String? base = _stringify(
        map['message'] ?? map['error'] ?? map['detail'],
      );
      final List<String> details = _flattenErrors(map['errors']);
      final List<String> parts = <String>[
        if (base != null && base.isNotEmpty) base,
        if (details.isNotEmpty) details.join('\n'),
      ];
      if (parts.isEmpty) {
        return null;
      }
      return parts.join('\n');
    }
    return _stringify(payload);
  }

  void _showErrorMessage(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onConfirm() async {
    if (_isSubmitting) return;
    if (!_acknowledged) {
      _showErrorMessage('يجب الموافقة على الإقرار قبل المتابعة.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _repository.purchasePlan(
        planId: widget.plan.id,
        quantity: _quantity,
        paymentGateway: _gateway,
        termsAcknowledged: _acknowledged,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiHttpException catch (error) {
      final String message =
          _extractErrorMessage(error.payload) ?? error.toString();
      _showErrorMessage(message);
    } on ApiException catch (error) {
      _showErrorMessage(error.toString());
    } catch (error) {
      _showErrorMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
        initialChildSize: 0.6,
        minChildSize: 0.45,
        maxChildSize: 0.92,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.name,
                        style: TextStyle(
                          color: color.textDefaultColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.plan.description ??
                            'راجع تفاصيل الخطة قبل المتابعة.',
                        style: TextStyle(
                          color: color.textDefaultColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Row(
                        children: [
                          Text(
                            'الكمية',
                            style: TextStyle(
                              color: color.textDefaultColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _QtyStepper(
                            value: _quantity,
                            onChanged: (value) =>
                                setState(() => _quantity = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _TotalBar(
                        total: total,
                        currency: widget.plan.currency,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'طريقة الدفع',
                        style: TextStyle(
                          color: color.textDefaultColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_loadingGateways && _gateways.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        if (_gateways.isNotEmpty)
                          _GatewayPicker(
                            gateways: _gateways,
                            value: _gateway,
                            enabled: !_isSubmitting,
                            onChanged: (value) =>
                                setState(() => _gateway = value),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: color.secondaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'لا توجد طرق دفع متاحة حالياً.',
                              style: TextStyle(
                                color: color.textDefaultColor.withOpacity(0.75),
                              ),
                            ),
                          ),
                        if (_loadingGateways && _gateways.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_gatewaysError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _gatewaysError!,
                                  style: TextStyle(
                                    color: color.error,
                                    fontSize: 12.5,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadGateways,
                                  child: const Text('إعادة محاولة تحميل الطرق'),
                                ),
                              ],
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _loadGateways,
                              child: const Text('تحديث طرق الدفع'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.secondaryColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 20,
                                color: color.textDefaultColor.withOpacity(0.8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'الكرت يباع من صاحب الشبكة مباشرة. التطبيق يوفر وسيط الدفع فقط ولا يضمن صلاحية الكود أو الخدمة.',
                                  style: TextStyle(
                                    color:
                                        color.textDefaultColor.withOpacity(0.8),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _acknowledged,
                          onChanged: _isSubmitting
                              ? null
                              : (value) => setState(
                                  () => _acknowledged = value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'أؤكد أنني تحققت من صورة صفحة الدخول وأقر بأن أي مشكلة تُحل مباشرة مع صاحب الشبكة.',
                            style: TextStyle(
                              color: color.textDefaultColor,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          (_isSubmitting || !_acknowledged) ? null : _onConfirm,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSubmitting
                            ? Row(
                                key: const ValueKey('processing'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('جارٍ معالجة الدفع'),
                                ],
                              )
                            : Row(
                                key: const ValueKey('confirm'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_circle_outline),
                                  SizedBox(width: 8),
                                  Text('تأكيد الدفع'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ========================== Widgets صغيرة مساعدة ========================== */
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.secondaryColor.withOpacity(0.2),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total, this.currency});

  final num total;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.secondaryColor.withOpacity(0.2),
      ),
      child: Row(
        children: [
          Text(
            'الإجمالي',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${total.toStringAsFixed(2)} ${currency ?? 'ريال'}',
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayPicker extends StatelessWidget {
  const _GatewayPicker({
    required this.gateways,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<PaymentGatewayView> gateways;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Column(
      children: gateways
          .map(
            (gateway) => RadioListTile<String>(
              value: gateway.id,
              groupValue: value,
              onChanged: enabled
                  ? (val) {
                      if (val != null) onChanged(val);
                    }
                  : null,
              title: Text(
                gateway.name,
                style: TextStyle(color: color.textDefaultColor),
              ),
              subtitle: gateway.description != null
                  ? Text(
                      gateway.description!,
                      style: TextStyle(
                        color: color.textDefaultColor.withOpacity(0.65),
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          )
          .toList(),
    );
  }
}

/* ========================== BottomSheet إضافة شبكة (مالك) ========================== */
class PaymentGatewayView {
  const PaymentGatewayView({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
}

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
              if (created != null)
                Text(
                  created,
                  style: TextStyle(
                    color: color.textDefaultColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              if (created != null) const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pending
                      ? color.secondaryColor.withOpacity(0.3)
                      : color.secondaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: pending
                        ? color.textDefaultColor
                        : color.backgroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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

class _AddNetworkSheet extends StatefulWidget {
  const _AddNetworkSheet({WifiRepository? repository})
      : repository = repository ?? const WifiRepository();

  final WifiRepository repository;

  @override
  State<_AddNetworkSheet> createState() => _AddNetworkSheetState();
}

class _AddNetworkSheetState extends _OwnerRequestFormState<_AddNetworkSheet> {
  @override
  WifiRepository get repository => widget.repository;

  @override
  void handleCompletion(Map<String, dynamic> result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Material(
        color: colors.surface,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (sheetContext, controller) {
            return Column(
              children: [
                _buildSheetHeader(sheetContext),
                const Divider(height: 1),
                Expanded(
                  child: buildFormContent(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    showHeading: false,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: buildSubmitButton(padding: EdgeInsets.zero),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onSurface = colors.onSurface;
    final accent = colors.territoryColor;
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withOpacity(.18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'أضف شبكتك',
                      style:
                          (textTheme.titleMedium ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أدخل بيانات الشبكة وملفات الاعتماد ليتمكن فريقنا من مراجعتها ونشرها.',
                      style:
                          (textTheme.bodySmall ?? const TextStyle()).copyWith(
                        color: onSurface.withOpacity(.7),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تأكد من صحة وسيلة التواصل والملفات المرفقة قبل الإرسال.',
                      style:
                          (textTheme.bodySmall ?? const TextStyle()).copyWith(
                        color: onSurface.withOpacity(.6),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'إغلاق',
                  splashRadius: 22,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddNetworkScreen extends StatefulWidget {
  const _AddNetworkScreen({WifiRepository? repository})
      : repository = repository ?? const WifiRepository();

  final WifiRepository repository;

  @override
  State<_AddNetworkScreen> createState() => _AddNetworkScreenState();
}

class _AddNetworkScreenState extends _OwnerRequestFormState<_AddNetworkScreen> {
  @override
  WifiRepository get repository => widget.repository;

  @override
  void handleCompletion(Map<String, dynamic> result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أضف شبكتك'),
      ),
      backgroundColor: context.color.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: buildFormContent(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              ),
            ),
            buildSubmitButton(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class _OwnerRequestFormState<T extends StatefulWidget>
    extends State<T> {
  static const int _maxUploadSizeBytes = 4 * 1024 * 1024;
  static const List<String> _allowedImageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  PlatformFile? _logoFile;
  PlatformFile? _loginScreenshotFile;
  bool _isSubmitting = false;

  WifiRepository get repository;

  @protected
  void handleCompletion(Map<String, dynamic> result);

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Widget buildFormContent({
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    bool showHeading = true,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final onSurface = theme.colorScheme.onSurface;
    final EdgeInsetsGeometry effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16);

    final List<Widget> children = <Widget>[];

    if (showHeading) {
      children
        ..add(
          Text(
            'أضف شبكتك',
            style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
        )
        ..add(const SizedBox(height: 16));
    }

    children.addAll([
      TextField(
        controller: _nameController,
        enabled: !_isSubmitting,
        decoration: const InputDecoration(
          labelText: 'اسم الشبكة',
        ),
      ),
      const SizedBox(height: 16),
      _OwnerRequestFilePickerTile(
        title: 'شعار الشبكة',
        placeholder: 'ارفع صورة الشعار',
        fileName: _logoFile?.name,
        isBusy: _isSubmitting,
        onTap: () => _pickImage(isLogo: true),
      ),
      const SizedBox(height: 16),
      _OwnerRequestFilePickerTile(
        title: 'صورة صفحة الدخول',
        placeholder: 'ارفع صورة توضح صفحة الدخول',
        fileName: _loginScreenshotFile?.name,
        isBusy: _isSubmitting,
        onTap: () => _pickImage(isLogo: false),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _contactController,
        enabled: !_isSubmitting,
        decoration: const InputDecoration(
          labelText: 'وسيلة التواصل',
          hintText: 'مثال: 777123456 أو @account',
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _notesController,
        enabled: !_isSubmitting,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'ملاحظات إضافية (اختياري)',
        ),
      ),
    ]);

    return ListView(
      controller: controller,
      padding: effectivePadding,
      children: children,
    );
  }

  Widget buildSubmitButton(
      {EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _onSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('إرسال الطلب'),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('يرجى إدخال اسم الشبكة.');
      return;
    }

    final String contact = _contactController.text.trim();
    if (contact.isEmpty) {
      _showError('يرجى إدخال وسيلة للتواصل.');
      return;
    }

    if (_logoFile == null) {
      _showError('يرجى رفع صورة شعار الشبكة.');
      return;
    }

    if (_loginScreenshotFile == null) {
      _showError('يرجى رفع صورة لصفحة الدخول.');
      return;
    }

    final MultipartFile? logoMultipart = _prepareMultipart(_logoFile!);
    final MultipartFile? loginMultipart =
        _prepareMultipart(_loginScreenshotFile!);

    if (logoMultipart == null || loginMultipart == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> response = await repository.createOwnerRequest(
        name: name,
        contact: contact,
        logo: logoMultipart,
        loginScreenshot: loginMultipart,
        notes: _stringify(_notesController.text),
      );

      Map<String, dynamic> payload = <String, dynamic>{};
      final dynamic rawData = response['data'] ??
          response['network'] ??
          response['request'] ??
          response['payload'];
      if (rawData is Map<String, dynamic>) {
        payload = Map<String, dynamic>.from(rawData);
      } else if (rawData is Map) {
        payload = Map<String, dynamic>.from(rawData as Map);
      }

      final Map<String, dynamic> result = <String, dynamic>{
        'name': payload['name'] ?? name,
        'status': payload['status'] ??
            payload['state'] ??
            payload['request_status'] ??
            response['status'] ??
            response['state'],
        'message': _stringify(
          response['message'] ??
              response['note'] ??
              payload['message'] ??
              payload['status_message'],
        ),
        'id': payload['id'] ?? response['id'],
      }..removeWhere((key, value) => value == null);

      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);
      handleCompletion(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.toString());
      setState(() => _isSubmitting = false);
    } catch (_) {
      if (!mounted) return;
      _showError('تعذّر إرسال الطلب، حاول لاحقًا.');
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickImage({required bool isLogo}) async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedImageExtensions,
        withData: kIsWeb,
      );

      if (result == null) {
        return;
      }

      final PlatformFile file = result.files.single;
      final String extension = (file.extension ?? '').toLowerCase();
      if (!_allowedImageExtensions.contains(extension)) {
        _showError(
            'صيغة الملف غير مدعومة. يرجى اختيار صورة بصيغة PNG أو JPG أو WEBP.');
        return;
      }

      if (file.size > _maxUploadSizeBytes) {
        _showError('حجم الملف يتجاوز الحد المسموح (4 ميجابايت).');
        return;
      }

      if (!mounted) return;

      setState(() {
        if (isLogo) {
          _logoFile = file;
        } else {
          _loginScreenshotFile = file;
        }
      });
    } catch (_) {
      _showError('تعذّر اختيار الملف، حاول مرة أخرى.');
    }
  }

  MultipartFile? _prepareMultipart(PlatformFile file) {
    try {
      if (!kIsWeb && file.path != null) {
        return MultipartFile.fromFileSync(
          file.path!,
          filename: file.name,
        );
      }

      final Uint8List? bytes = file.bytes;
      if (bytes != null) {
        return MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        );
      }
    } catch (_) {
      _showError('تعذّر تجهيز الملف المرفوع (${file.name}).');
      return null;
    }

    _showError('تعذّر قراءة الملف المرفوع (${file.name}).');
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}

class _OwnerRequestFilePickerTile extends StatelessWidget {
  const _OwnerRequestFilePickerTile({
    required this.title,
    required this.placeholder,
    required this.onTap,
    required this.isBusy,
    this.fileName,
  });

  final String title;
  final String placeholder;
  final String? fileName;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final color = context.color;
    final bool hasFile = fileName != null && fileName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color.textDefaultColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isBusy ? null : onTap,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.borderColor.darken(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: color.territoryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasFile ? fileName! : placeholder,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasFile
                          ? color.textDefaultColor
                          : color.textDefaultColor.withOpacity(0.6),
                    ),
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

/* ========================== نماذج عرض (View Models) ========================== */
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.12),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.error.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 48, color: color.error),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.textDefaultColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final color = context.color;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_find, size: 52, color: color.secondaryColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.textDefaultColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.textDefaultColor.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (onAction != null)
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel ?? 'إعادة المحاولة'),
            ),
        ],
      ),
    );
  }
}
