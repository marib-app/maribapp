import 'package:marib/utils/api.dart';
import 'package:flutter/services.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/data/model/wifi/wifi_purchase.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'add_network/add_network_sheet.dart';
import 'sheets/plans_sheet.dart';
import 'sheets/purchases_sheet.dart';
import 'wifi_cabin_controller.dart';
import 'widgets/common_states.dart';
import 'widgets/header_filter_bar.dart';
import 'widgets/network_grid.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:flutter/foundation.dart';
import 'package:marib/data/model/wifi/wifi_purchase_result.dart';
import 'package:marib/data/model/wifi/wifi_payment_gateway.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:meta/meta.dart';

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
                WifiSearchHeaderBar(
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
              const WifiLoadingOverlay(),
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
              WifiErrorBanner(
                message:
                    state.errorMessage ?? 'تعذّر تحديث الشبكات، حاول مجددًا.',
                onRetry: () => _controller.refreshNetworks(),
              ),
            ],
          );
        }
        return WifiErrorState(
          key: const ValueKey('failure'),
          message: state.errorMessage ?? 'تعذّر جلب الشبكات في الوقت الحالي.',
          onRetry: () => _controller.refreshNetworks(),
        );
    }
  }

  Widget _buildNetworksGrid(WifiCabinViewState state, {Key? key}) {
    return WifiNetworksGrid(
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
      builder: (_) => WifiPurchasesSheet(
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
                return WifiCodeTile(
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
      builder: (_) => WifiAddNetworkSheet(
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
      builder: (_) => WifiPlansSheet(
        network: network,
        onRegisterPurchase: _registerPurchase,
        onRefreshPurchases: _fetchPurchases,
        onShowCodes: _showCodesDialog,
      ),
    );
  }
}
