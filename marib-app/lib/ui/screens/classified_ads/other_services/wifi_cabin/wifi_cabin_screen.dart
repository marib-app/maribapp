import 'package:marib/utils/api.dart';
import 'package:flutter/services.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/data/model/wifi/wifi_purchase.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'widgets/service_overview.dart';

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
import 'package:flutter/foundation.dart';
import 'add_network/plan_configuration_screen.dart';

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

        final backgroundColor = context.color.backgroundColor;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: 'wifiCabin'.translate(context),
          ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WifiSearchHeaderBar(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        isLoading:
                            state.status == WifiCabinLoadStatus.loading &&
                                !state.hasData,
                        onChanged: (value) => _controller.updateQuery(value),
                        onSubmitted: (value) =>
                            _controller.updateQuery(value, immediate: true),
                        onClear: _controller.clearQuery,
                        onRefresh: () =>
                            _controller.refreshNetworks(force: true),
                      ),
                      const SizedBox(height: 12),
                      const WifiServiceOverview(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        fit: StackFit.passthrough,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          for (final child in previousChildren)
                            Positioned.fill(child: child),
                          if (currentChild != null)
                            Positioned.fill(child: currentChild),
                        ],
                      );
                    },
                    child: _buildBodyForState(context, state),
                  ),
                ),
              ),
            ],
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
      shrinkWrap: true,
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

    if (result == null) {
      return;
    }

    await _controller.refreshNetworks(force: true);
    if (!mounted) return;

    final Map<String, dynamic> payload = _normalizeNetworkSubmission(result);
    final String? networkName = payload['name'] as String?;
    final String? networkStatus = payload['status'] as String?;
    final String? networkMessage = payload['message'] as String? ??
        _buildNetworkSubmissionMessage(networkName, networkStatus);
    final int? networkId =
        _parsePositiveInt(payload['networkId'] ?? payload['id']);
    final Map<String, dynamic>? networkData =
        payload['network'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(
                payload['network'] as Map<String, dynamic>,
              )
            : null;

    String? combinedMessage = networkMessage;

    if (networkId != null && networkId > 0) {
      final Map<String, dynamic>? planResult = await _openPlanConfiguration(
        networkId: networkId,
        networkName: networkName,
        defaultCurrency: _resolveCurrencyFromPayload(networkData),
      );

      if (!mounted) return;

      if (planResult != null) {
        combinedMessage = _joinMessages([
          networkMessage,
          planResult['planMessage'] as String?,
          planResult['batchMessage'] as String?,
        ]);
        await _controller.refreshNetworks(force: true);
      }

      combinedMessage ??= networkMessage ?? 'تم إرسال طلب الشبكة بنجاح';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(combinedMessage!)),
      );
    }
  }

  Future<void> _openPlansSheet(
      BuildContext context, WifiNetwork network) async {
    final WifiPlansSheetResult? result =
        await showModalBottomSheet<WifiPlansSheetResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => WifiPlansSheet(
        network: network,
        onRegisterPurchase: _registerPurchase,
        onRefreshPurchases: _fetchPurchases,
        onShowCodes: _showCodesDialog,
        allowPlanCreation: shouldAllowPlanCreationForNetwork(network),
      ),
    );

    if (!mounted) return;

    if (result == WifiPlansSheetResult.addPlan) {
      final Map<String, dynamic>? planResult = await _openPlanConfiguration(
        networkId: network.id,
        networkName: network.name,
        defaultCurrency: _resolveCurrencyForNetwork(network),
      );

      if (!mounted) return;

      if (planResult != null) {
        final String? message = _joinMessages([
          planResult['planMessage'] as String?,
          planResult['batchMessage'] as String?,
        ]);
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        await _controller.refreshNetworks(force: true);
      }
    }
  }

  Future<Map<String, dynamic>?> _openPlanConfiguration({
    required int networkId,
    String? networkName,
    String? defaultCurrency,
  }) {
    return Navigator.of(context).push<Map<String, dynamic>?>(
      WifiPlanConfigurationScreen.route(
        networkId: networkId,
        networkName: networkName,
        defaultCurrency: (defaultCurrency ?? 'YER').toUpperCase(),
        repository: _repository,
      ),
    );
  }

  Map<String, dynamic> _normalizeNetworkSubmission(dynamic result) {
    if (result is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result);
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result as Map);
    }
    if (result is String) {
      return <String, dynamic>{'name': result};
    }
    return <String, dynamic>{};
  }

  String? _buildNetworkSubmissionMessage(String? name, String? status) {
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
  }

  String? _joinMessages(List<String?> messages) {
    final List<String> filtered = messages
        .map((message) => message?.trim())
        .whereType<String>()
        .where((message) => message.isNotEmpty)
        .toList();
    if (filtered.isEmpty) {
      return null;
    }
    return filtered.join('\n');
  }

  int? _parsePositiveInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      final int parsed = value.toInt();
      return parsed > 0 ? parsed : null;
    }
    final int? parsed = int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String _resolveCurrencyForNetwork(WifiNetwork network) {
    if (network.currencies.isNotEmpty) {
      return network.currencies.first.toUpperCase();
    }
    final dynamic metaCurrency =
        network.meta?['currency'] ?? network.meta?['default_currency'];
    if (metaCurrency is String && metaCurrency.trim().isNotEmpty) {
      return metaCurrency.toUpperCase();
    }
    return 'YER';
  }

  String _resolveCurrencyFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return 'YER';
    final dynamic currency = payload['currency'];
    if (currency is String && currency.trim().isNotEmpty) {
      return currency.toUpperCase();
    }
    final dynamic currencies = payload['currencies'];
    if (currencies is List) {
      for (final dynamic element in currencies) {
        final String? text = element?.toString();
        if (text != null && text.trim().isNotEmpty) {
          return text.toUpperCase();
        }
      }
    }
    return 'YER';
  }

  bool _shouldAllowPlanCreation(WifiNetwork network) {
    return shouldAllowPlanCreationForNetwork(network);
  }
}

@visibleForTesting
bool shouldAllowPlanCreationForNetwork(WifiNetwork network) {
  final Map<String, dynamic>? meta = network.meta;
  final Iterable<String> statuses = _extractNetworkStatuses(meta);

  final bool hasApprovedStatus = statuses.any(_isApprovedNetworkStatus);
  if (hasApprovedStatus) {
    return true;
  }

  if (network.planCount > 0) {
    return true;
  }

  final bool hasPendingStatus = statuses.any(_isPendingNetworkStatus);
  final bool statusMissing = statuses.isEmpty;
  final bool isOwner = _isNetworkOwnedByCurrentUser(meta);
  final bool originatedFromOwnerFlow = _originatedFromMobileOwnerFlow(meta);

  if (originatedFromOwnerFlow) {
    return true;
  }

  if (isOwner && (hasPendingStatus || statusMissing)) {
    return true;
  }

  return false;
}

Iterable<String> _extractNetworkStatuses(Map<String, dynamic>? meta) {
  if (meta == null || meta.isEmpty) {
    return const Iterable<String>.empty();
  }

  final List<String> statuses = <String>[];

  void addStatus(dynamic value) {
    final String? normalized = _normalizeText(value);
    if (normalized != null) {
      statuses.add(normalized);
    }
  }

  final dynamic ownerRequest = meta['owner_request'];
  if (ownerRequest is Map) {
    addStatus(ownerRequest['status']);
  } else if (ownerRequest is Iterable) {
    for (final dynamic element in ownerRequest) {
      addStatus(element);
    }
  } else {
    addStatus(ownerRequest);
  }

  addStatus(meta['owner_request_status']);
  addStatus(meta['status']);

  return statuses;
}

bool _isApprovedNetworkStatus(String status) {
  const Set<String> approvedStatuses = <String>{
    'approved',
    'active',
    'published',
    'enabled',
    'live',
  };

  return approvedStatuses.contains(status);
}

bool _isPendingNetworkStatus(String status) {
  const Set<String> pendingStatuses = <String>{
    'pending',
    'draft',
    'awaiting_approval',
    'in_review',
    'under_review',
    'submitted',
    'processing',
  };

  return pendingStatuses.contains(status);
}

bool _isNetworkOwnedByCurrentUser(Map<String, dynamic>? meta) {
  if (meta == null || meta.isEmpty) {
    return false;
  }

  final Iterable<dynamic> ownerFlags = <dynamic>[
    meta['is_owner'],
    meta['owned_by_me'],
    meta['owned_by_user'],
    meta['is_my_network'],
    meta['is_current_user_owner'],
    meta['current_user_is_owner'],
    meta['owner_is_current_user'],
    meta['is_owner_flag'],
    meta['is_owned_by_current_user'],
  ];

  for (final dynamic candidate in ownerFlags) {
    final bool? parsed = _tryParseBool(candidate);
    if (parsed == true) {
      return true;
    }
  }

  final dynamic owner = meta['owner'];
  if (owner is Map<String, dynamic>) {
    final Iterable<dynamic> ownerMapFlags = <dynamic>[
      owner['is_owner'],
      owner['is_me'],
      owner['is_current_user'],
      owner['is_mine'],
      owner['owned_by_me'],
    ];

    for (final dynamic candidate in ownerMapFlags) {
      final bool? parsed = _tryParseBool(candidate);
      if (parsed == true) {
        return true;
      }
    }

    final int? ownerId = _tryParseInt(owner['id'] ?? owner['user_id']);
    final int? currentUserId = _tryParseInt(
      meta['current_user_id'] ?? meta['user_id'] ?? meta['owner_user_id'],
    );

    if (ownerId != null && currentUserId != null && ownerId == currentUserId) {
      return true;
    }
  }

  return false;
}

bool _originatedFromMobileOwnerFlow(Map<String, dynamic>? meta) {
  if (meta == null || meta.isEmpty) {
    return false;
  }

  const Set<String> ownerFlowTokens = <String>{
    'mobile_owner_flow',
    'owner_network',
    'mobile-owner-flow',
    'mobile_owner',
    'owner_mobile',
  };

  const Set<String> sourceTokens = <String>{
    'mobile_app',
    'mobile-app',
  };

  bool hasToken(dynamic value) {
    return _containsToken(value, <String>{
      ...ownerFlowTokens,
      ...sourceTokens,
    });
  }

  final Iterable<dynamic> directCandidates = <dynamic>[
    meta['source'],
    meta['origin'],
    meta['request_type'],
    meta['requestType'],
    meta['request_source'],
    meta['requestSource'],
    meta['request_origin'],
    meta['requestOrigin'],
    meta['creation_source'],
    meta['creationSource'],
    meta['created_via'],
    meta['createdVia'],
  ];

  for (final dynamic candidate in directCandidates) {
    if (hasToken(candidate)) {
      return true;
    }
  }

  if (hasToken(meta['owner_request'])) {
    return true;
  }

  return false;
}

bool? _tryParseBool(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    const Set<String> truthy = <String>{'true', '1', 'yes', 'y'};
    const Set<String> falsy = <String>{'false', '0', 'no', 'n'};

    if (truthy.contains(normalized)) {
      return true;
    }
    if (falsy.contains(normalized)) {
      return false;
    }
  }

  return null;
}

int? _tryParseInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim());
  }

  return int.tryParse(value.toString());
}

bool _containsToken(dynamic value, Set<String> tokens) {
  if (value == null) {
    return false;
  }

  if (value is String) {
    final String? normalized = _normalizeText(value);
    if (normalized == null) {
      return false;
    }
    return tokens.contains(normalized);
  }

  if (value is Iterable) {
    for (final dynamic element in value) {
      if (_containsToken(element, tokens)) {
        return true;
      }
    }
    return false;
  }

  if (value is Map) {
    for (final dynamic element in value.values) {
      if (_containsToken(element, tokens)) {
        return true;
      }
    }
    return false;
  }

  return _containsToken(value.toString(), tokens);
}

String? _normalizeText(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  return _normalizeText(value.toString());
}
