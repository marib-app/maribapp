import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/settings.dart' as app_settings;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/payment/east_yemen_bank_config.dart';
import 'package:marib/data/model/store_gateway_option.dart';
import 'package:marib/utils/store_status_view_model.dart';
import 'package:marib/utils/ui_utils.dart';

class PaymentOptionsData {
  final bool smartEnabled;
  final String? smartAccountNumber;
  final List<StoreGatewayAccountDraft> manualDrafts;

  const PaymentOptionsData({
    required this.smartEnabled,
    this.smartAccountNumber,
    required this.manualDrafts,
  });
}

class StoreGatewayAccountDraft {
  const StoreGatewayAccountDraft({
    required this.gatewayId,
    required this.beneficiaryName,
    required this.accountNumber,
  });

  final int gatewayId;
  final String beneficiaryName;
  final String accountNumber;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'store_gateway_id': gatewayId,
      'beneficiary_name': beneficiaryName,
      'account_number': accountNumber,
    };
  }
}

class Phase4PaymentMethods extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(PaymentOptionsData data) onNext;
  final ValueNotifier<int> visibilityNotifier;
  final int pageIndex;

  const Phase4PaymentMethods({
    super.key,
    required this.onBack,
    required this.onNext,
    required this.visibilityNotifier,
    required this.pageIndex,
  });

  @override
  State<Phase4PaymentMethods> createState() => _Phase4PaymentMethodsState();
}

class _Phase4PaymentMethodsState extends State<Phase4PaymentMethods>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _smartAccountCtrl = TextEditingController();
  final List<StoreManualBankAccount> _existingManualAccounts =
      <StoreManualBankAccount>[];
  final List<StoreGatewayOption> _storeGateways = <StoreGatewayOption>[];

  EastYemenBankConfig? _eastConfig;

  bool _smartEnabled = false;
  bool _isReady = false;
  bool _submitting = false;
  bool _manualLoading = true;
  String? _manualError;
  bool _refreshQueued = false;

  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  late final VoidCallback _visibilityListener;

  @override
  void initState() {
    super.initState();
    _eastConfig = app_settings.AppSettings.eastYemenBankConfig;
    _visibilityListener = _handleVisibilityChanged;
    widget.visibilityNotifier.addListener(_visibilityListener);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _isReady = true);
      _handleVisibilityChanged();
    });
  }

  @override
  void didUpdateWidget(covariant Phase4PaymentMethods oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibilityNotifier != widget.visibilityNotifier) {
      oldWidget.visibilityNotifier.removeListener(_visibilityListener);
      widget.visibilityNotifier.addListener(_visibilityListener);
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleVisibilityChanged());
    }
  }

  void _handleVisibilityChanged() {
    if (widget.visibilityNotifier.value == widget.pageIndex) {
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _refreshQueued = false;
      await _loadStoreGateways();
    });
  }

  Future<void> _loadManualGateways() async {
    setState(() {
      _manualLoading = true;
      _manualError = null;
    });
    List<StoreManualBankAccount> aggregated = <StoreManualBankAccount>[];
    Object? failure;

    try {
      aggregated = await _fetchStoreGatewayAccounts();
    } catch (error) {
      failure = error;
    }

    if (mounted) {
      setState(() {
        _manualGateways
          ..clear()
          ..addAll(aggregated);
        _manualError = aggregated.isEmpty ? failure?.toString() : null;
        _manualLoading = false;
      });
    }
  }

  Future<void> _loadStoreGateways() async {
    if (!mounted) return;
    await _loadManualGateways();
    try {
      final Map<String, dynamic> response =
      await Api.get(url: Api.storeGatewaysCatalogApi());
      final List<dynamic> rawList = response['data'] is List
          ? response['data'] as List<dynamic>
          : (response['storeGateways'] is List
              ? response['storeGateways'] as List<dynamic>
              : const <dynamic>[]);
      final List<StoreGatewayOption> parsed = rawList
          .whereType<Map>()
          .map((dynamic map) => StoreGatewayOption.fromJson(
              Map<String, dynamic>.from(map as Map<dynamic, dynamic>)))
          .toList();
      if (mounted) {
        setState(() {
          _storeGateways
            ..clear()
            ..addAll(parsed.where((gateway) => gateway.isActive));
        });
      }
    } catch (_) {}
  }

  Future<List<StoreManualBankAccount>> _fetchStoreGatewayAccounts() async {
    final Set<String> seenKeys = <String>{};
    final List<StoreManualBankAccount> aggregated = <StoreManualBankAccount>[];

    void merge(List<StoreManualBankAccount> accounts) {
      for (final StoreManualBankAccount account in accounts) {
        final String key = _accountKey(account);
        if (seenKeys.add(key)) {
          aggregated.add(account);
        }
      }
    }

    Map<String, dynamic>? onboarding;
    try {
      onboarding = await Api.get(url: Api.storeOnboardingApi);
    } catch (_) {
      onboarding = null;
    }

    merge(_extractGatewayAccounts(onboarding));

    try {
      final Map<String, dynamic> gateways =
      await Api.get(url: Api.storeGatewaysCatalogApi());
      merge(_extractGatewayAccounts(gateways));
    } catch (_) {}

    try {
      final Map<String, dynamic> accounts =
          await Api.get(url: Api.storeGatewayAccountsApi);
      merge(_extractGatewayAccounts(accounts));
    } catch (_) {}

    if (aggregated.isEmpty) {
      merge(_fallbackManualGateways());
    }

    return aggregated;
  }

  List<StoreManualBankAccount> _extractGatewayAccounts(
      Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return const <StoreManualBankAccount>[];
    }

    final dynamic rootData = payload['data'];
    List<dynamic> candidates = const <dynamic>[];

    if (rootData is List) {
      candidates = List<dynamic>.from(rootData);
    } else {
      final Map<String, dynamic> root = rootData is Map<String, dynamic>
          ? rootData as Map<String, dynamic>
          : payload;

      candidates = _resolveCandidateList(root, const <String>[
        'store_gateway_accounts',
        'storeGateways',
        'store_gateways',
        'manual_gateway_accounts',
        'manual_banks',
        'manualBanks',
        'data',
      ]);
    }

    if (candidates.isEmpty) {
      return const <StoreManualBankAccount>[];
    }

    final List<StoreManualBankAccount> parsed = <StoreManualBankAccount>[];

    for (final dynamic candidate in candidates) {
      if (candidate is Map) {
        final Map<String, dynamic> normalized =
            Map<String, dynamic>.from(candidate as Map<dynamic, dynamic>);

        final dynamic accounts = normalized['accounts'];
        final List<dynamic>? accountList = _unwrapCollection(accounts);
        if (accountList != null) {
          for (final dynamic account in accountList) {
            if (account is Map) {
              final Map<String, dynamic> accountMap =
                  Map<String, dynamic>.from(account as Map<dynamic, dynamic>);
              accountMap['gateway'] ??= <String, dynamic>{
                'name': normalized['name'],
                'logo_url': normalized['logo_url'],
              };
              parsed.add(StoreManualBankAccount.fromMap(accountMap));
            }
          }
          continue;
        }

        if (normalized.containsKey('store_gateway') &&
            normalized['gateway'] == null) {
          normalized['gateway'] = normalized['store_gateway'];
        }
        parsed.add(StoreManualBankAccount.fromMap(normalized));
      }
    }

    return parsed.where((account) => account.displayLabel.isNotEmpty).toList();
  }

  List<dynamic> _resolveCandidateList(
      Map<String, dynamic> map, List<String> keys) {

    for (final String key in keys) {
      final dynamic candidate = map[key];
      final List<dynamic>? list = _unwrapCollection(candidate);
      if (list != null) {
        return list;
      }
    }

    final List<dynamic> fallback = <dynamic>[];
    for (final dynamic value in map.values) {
      if (value is Map<String, dynamic>) {
        final List<dynamic> nested = _resolveCandidateList(value, keys);
        if (nested.isNotEmpty) return nested;
      } else if (value is Map) {
        final List<dynamic> nested = _resolveCandidateList(
          Map<String, dynamic>.from(
            value.map((dynamic key, dynamic v) => MapEntry(
                  key.toString(),
                  v,
                )),
          ),
          keys,
        );
        if (nested.isNotEmpty) return nested;
      }
    }

    return fallback;
  }


  List<dynamic>? _unwrapCollection(dynamic value) {
    if (value == null) return null;
    if (value is List<dynamic>) {
      return List<dynamic>.from(value);
    }
    if (value is Iterable) {
      return List<dynamic>.from(value);
    }
    if (value is Map<String, dynamic>) {
      final dynamic data = value['data'];
      final List<dynamic>? dataList = _unwrapCollection(data);
      if (dataList != null) {
        return dataList;
      }
      final dynamic items = value['items'];
      final List<dynamic>? itemList = _unwrapCollection(items);
      if (itemList != null) {
        return itemList;
      }
      return null;
    }
    if (value is Map) {
      return _unwrapCollection(Map<String, dynamic>.from(
        value.map(
              (dynamic key, dynamic val) => MapEntry(key.toString(), val),
        ),
      ));
    }
    return null;
  }

  String _accountKey(StoreManualBankAccount account) {
    if (account.storeGatewayAccountId != null) {
      return 'id_${account.storeGatewayAccountId}';
    }
    final String gateway =
        account.gatewayName?.toLowerCase().trim() ?? 'unknown';
    final String beneficiary =
        account.beneficiaryName?.toLowerCase().trim() ?? '';
    final String number = account.accountNumber?.toLowerCase().trim() ?? '';
    return '$gateway|$beneficiary|$number';
  }

  List<StoreManualBankAccount> _fallbackManualGateways() {
    if (app_settings.AppSettings.manualPaymentBanks.isEmpty) {
      return const <StoreManualBankAccount>[];
    }
    return app_settings.AppSettings.manualPaymentBanks
        .map(
          (bank) => StoreManualBankAccount.fromMap(<String, dynamic>{
            'name': bank.bankName,
            'beneficiary_name': bank.accountName,
            'account_number': bank.accountNumber,
            'iban': bank.iban,
            'branch': bank.branch,
            'gateway': <String, dynamic>{'name': bank.bankName},
          }),
        )
        .toList();
  }

  List<StoreManualBankAccount> _collectManualAccounts(dynamic source) {
    final List<StoreManualBankAccount> result = <StoreManualBankAccount>[];

    void collect(dynamic node) {
      if (node == null) return;
      if (node is List) {
        for (final dynamic element in node) {
          collect(element);
        }
        return;
      }
      if (node is Map<String, dynamic>) {
        if (_looksLikeGatewayAccount(node)) {
          result.add(StoreManualBankAccount.fromMap(node));
        }
        for (final dynamic value in node.values) {
          collect(value);
        }
        return;
      }
      if (node is Map) {
        collect(Map<String, dynamic>.from(
          node.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value)),
        ));
      }
    }

    collect(source);

    if (result.isEmpty) {
      return _fallbackManualGateways();
    }

    return result;
  }

  bool _looksLikeGatewayAccount(Map<String, dynamic> map) {
    return map.containsKey('store_gateway_account_id') ||
        map.containsKey('store_gateway_id') ||
        map.containsKey('beneficiary_name') ||
        map.containsKey('account_number') ||
        map.containsKey('store_gateway');
  }

  @override
  void dispose() {
    widget.visibilityNotifier.removeListener(_visibilityListener);
    _smartAccountCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    widget.onNext(
      PaymentOptionsData(
        smartEnabled: _smartEnabled,
        smartAccountNumber:
            _smartEnabled ? _smartAccountCtrl.text.trim() : null,
        manualGateways: List<StoreManualBankAccount>.from(_manualGateways),
      ),
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_isReady) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              ShimmerBox(height: 22, width: 200),
              SizedBox(height: 12),
              ShimmerBox(height: 18, width: 260),
              SizedBox(height: 20),
              ShimmerBox(height: 140),
              SizedBox(height: 12),
              ShimmerBox(height: 140),
            ],
          ),
        ),
      );
    }

    final theme = context.color;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'طرق الدفع في متجرك',
                style: TextStyle(
                  fontSize: context.font.extraLarge,
                  fontWeight: FontWeight.w700,
                  color: theme.textColorDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'المعلومات التالية تُعرض للعملاء أثناء الدفع ويمكن تعديلها لاحقاً من الإعدادات.',
                style: TextStyle(
                  fontSize: context.font.normal,
                  color: theme.textColorDark.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabController,
                indicatorColor: theme.territoryColor,
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'الدفع اليدوي'),
                  Tab(text: 'الدفع الذكي'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildManualPaymentTab(),
                    _buildSmartPaymentTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: UiUtils.buildButton(
           context,
           onPressed: _handleNext,
           buttonTitle: 'nextStage'.translate(context),
            isInProgress: _submitting,
            autoManageState: false,
            autoDisableWhenInvalid: false,
          ),
        ),
      ),
    );
  }

  Widget _buildManualPaymentTab() {
    final theme = context.color;
    if (_manualLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_manualError != null && _manualGateways.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تعذر تحميل بوابات الدفع اليدوية.',
                style: TextStyle(color: theme.textColorDark),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadManualGateways,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_manualGateways.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بوابات دفع يدوية مفعلة حالياً.',
          style: TextStyle(color: theme.textColorDark.withOpacity(0.7)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 24),
      itemCount: _manualGateways.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final account = _manualGateways[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.secondaryColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.gatewayName ?? account.displayLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: context.font.normal,
                  color: theme.textColorDark,
                ),
              ),
              if (account.beneficiaryName != null)
                Text('المستفيد: ${account.beneficiaryName}'),
              if (account.accountNumber != null)
                Text('رقم الحساب: ${account.accountNumber}'),
              if (account.iban != null) Text('IBAN: ${account.iban}'),
              if (account.branch != null) Text('الفرع: ${account.branch}'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmartPaymentTab() {
    final theme = context.color;
    if (_eastConfig == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'لم يتم ربط بوابة بنك الشرق حتى الآن. تواصل مع فريق الدعم للتفعيل.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColorDark.withOpacity(0.7)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_eastConfig!.logoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _eastConfig!.logoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.account_balance, color: theme.primaryColor),
                  ),
                )
              else
                Icon(Icons.account_balance,
                    color: theme.primaryColor, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _eastConfig!.displayName,
                  style: TextStyle(
                    fontSize: context.font.large,
                    fontWeight: FontWeight.w600,
                    color: theme.textColorDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: _smartEnabled,
            onChanged: (value) => setState(() => _smartEnabled = value),
            title: const Text('تفعيل بوابة بنك الشرق'),
            subtitle: Text(
              _eastConfig!.note ??
                  'عند التفعيل يتمكن عملاؤك من الدفع عبر بنك الشرق مباشرة.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _smartAccountCtrl,
            enabled: _smartEnabled,
            decoration: InputDecoration(
              labelText: 'رقم حسابك في بنك الشرق',
              hintText: 'أدخل رقم الحساب أو معرف العميل',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
