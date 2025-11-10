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
  final Set<int> _selectedGatewayIds = <int>{};
  final Map<int, TextEditingController> _beneficiaryControllers =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _accountControllers =
      <int, TextEditingController>{};

  EastYemenBankConfig? _eastConfig;

  bool _smartEnabled = false;
  bool _isReady = false;
  bool _submitting = false;
  bool _manualLoading = true;
  String? _manualError;
  bool _storeGatewaysLoading = true;
  String? _storeGatewaysError;
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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleVisibilityChanged());
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
        _existingManualAccounts
          ..clear()
          ..addAll(aggregated);
        _manualError =
            aggregated.isEmpty ? _resolveErrorMessage(failure) : null;
        _manualLoading = false;
      });
    }
  }

  Future<void> _loadStoreGateways() async {
    if (!mounted) return;
    setState(() {
      _storeGatewaysLoading = true;
      _storeGatewaysError = null;
    });
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
          .map((dynamic map) =>
              StoreGatewayOption.fromJson(Map<String, dynamic>.from(map)))
          .toList();
      if (!mounted) return;
      final Set<int> availableIds = parsed
          .where((gateway) => gateway.isActive && gateway.id > 0)
          .map((gateway) => gateway.id)
          .toSet();
      _selectedGatewayIds.removeWhere(
        (int id) => !availableIds.contains(id),
      );
      _cleanupGatewayControllers();
      setState(() {
        _storeGateways
          ..clear()
          ..addAll(parsed.where((gateway) => gateway.isActive));
        _storeGatewaysLoading = false;
      });
      for (final int id in _selectedGatewayIds) {
        _ensureGatewayControllers(id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storeGatewaysError = error.toString();
        _storeGatewaysLoading = false;
      });
    }
  }

  void _ensureGatewayControllers(int gatewayId) {
    _beneficiaryControllers.putIfAbsent(
      gatewayId,
      () => TextEditingController(),
    );
    _accountControllers.putIfAbsent(
      gatewayId,
      () => TextEditingController(),
    );
  }

  void _cleanupGatewayControllers() {
    final List<int> removable = _beneficiaryControllers.keys
        .where((int id) => !_selectedGatewayIds.contains(id))
        .toList();
    for (final int id in removable) {
      _beneficiaryControllers.remove(id)?.dispose();
      _accountControllers.remove(id)?.dispose();
    }
    final List<int> removableAccounts = _accountControllers.keys
        .where((int id) => !_selectedGatewayIds.contains(id))
        .toList();
    for (final int id in removableAccounts) {
      _accountControllers.remove(id)?.dispose();
    }
  }

  void _toggleGatewaySelection(int gatewayId, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selectedGatewayIds.add(gatewayId)) {
          _ensureGatewayControllers(gatewayId);
        }
      } else {
        if (_selectedGatewayIds.remove(gatewayId)) {
          _beneficiaryControllers.remove(gatewayId)?.dispose();
          _accountControllers.remove(gatewayId)?.dispose();
        }
      }
    });
  }

  List<StoreGatewayAccountDraft> _collectGatewayDrafts() {
    final List<StoreGatewayAccountDraft> drafts = <StoreGatewayAccountDraft>[];
    for (final int gatewayId in _selectedGatewayIds) {
      final String beneficiary =
          _beneficiaryControllers[gatewayId]?.text.trim() ?? '';
      final String accountNumber =
          _accountControllers[gatewayId]?.text.trim() ?? '';
      if (beneficiary.isEmpty || accountNumber.isEmpty) {
        continue;
      }
      drafts.add(
        StoreGatewayAccountDraft(
          gatewayId: gatewayId,
          beneficiaryName: beneficiary,
          accountNumber: accountNumber,
        ),
      );
    }
    return drafts;
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
      final Map<String, dynamic> root =
          rootData is Map<String, dynamic> ? rootData : payload;

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
            Map<String, dynamic>.from(candidate);

        final dynamic accounts = normalized['accounts'];
        final List<dynamic>? accountList = _unwrapCollection(accounts);
        if (accountList != null) {
          for (final dynamic account in accountList) {
            if (account is Map) {
              final Map<String, dynamic> accountMap =
                  Map<String, dynamic>.from(account);
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

  @override
  void dispose() {
    widget.visibilityNotifier.removeListener(_visibilityListener);
    _smartAccountCtrl.dispose();
    for (final controller in _beneficiaryControllers.values) {
      controller.dispose();
    }
    for (final controller in _accountControllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_submitting) return;
    final String smartAccount = _smartAccountCtrl.text.trim();
    if (_smartEnabled && smartAccount.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'يرجى إدخال رقم الحساب المرتبط ببنك الشرق.',
      );
      return;
    }
    final List<StoreGatewayAccountDraft> drafts = _collectGatewayDrafts();
    if (_selectedGatewayIds.isNotEmpty &&
        drafts.length != _selectedGatewayIds.length) {
      HelperUtils.showSnackBarMessage(
        context,
        'أكمل بيانات كل بوابة تم اختيارها قبل المتابعة.',
      );
      return;
    }
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    widget.onNext(
      PaymentOptionsData(
        smartEnabled: _smartEnabled,
        smartAccountNumber: _smartEnabled ? smartAccount : null,
        manualDrafts: drafts,
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
                  color: theme.textColorDark.withValues(alpha: 0.75),
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

    Widget buildSelectionCard() {
      if (_storeGatewaysLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_storeGatewaysError != null) {
        return _InformativeCard(
          message: 'تعذر تحميل قائمة بوابات الدفع. حاول مرة أخرى.',
          buttonLabel: 'إعادة المحاولة',
          onPressed: _loadStoreGateways,
        );
      }
      if (_storeGateways.isEmpty) {
        return _InformativeCard(
          message: 'لا تتوفر بوابات دفع يدوي لربطها حالياً.',
          icon: Icons.info_outline,
        );
      }

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
              'اختر بوابات الدفع اليدوي',
              style: TextStyle(
                fontSize: context.font.large,
                fontWeight: FontWeight.w600,
                color: theme.textColorDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'يمكنك إضافة أكثر من بوابة، وسيتم عرض هذه البيانات للعملاء في شاشة الدفع.',
              style: TextStyle(
                fontSize: context.font.small,
                color: theme.textColorDark.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ..._storeGateways.map(_buildGatewayTile),
            if (_selectedGatewayIds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'يمكنك استكمال هذه الخطوة لاحقاً من إعدادات المتجر.',
                  style: TextStyle(
                    fontSize: context.font.small,
                    color: theme.textColorDark.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    Widget? buildExistingAccounts() {
      if (_manualLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_manualError != null && _existingManualAccounts.isEmpty) {
        return _InformativeCard(
          message: 'تعذر تحميل الحسابات المرتبطة بمتجرك.',
          buttonLabel: 'إعادة المحاولة',
          onPressed: _loadManualGateways,
        );
      }
      if (_existingManualAccounts.isEmpty) {
        return null;
      }
      return Container(
        margin: const EdgeInsets.only(top: 24),
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
              'الحسابات المرتبطة حالياً',
              style: TextStyle(
                fontSize: context.font.large,
                fontWeight: FontWeight.w600,
                color: theme.textColorDark,
              ),
            ),
            const SizedBox(height: 12),
            ..._existingManualAccounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                    if (account.branch != null)
                      Text('الفرع: ${account.branch}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      children: [
        buildSelectionCard(),
        if (buildExistingAccounts() != null) buildExistingAccounts()!,
      ],
    );
  }

  Widget _buildGatewayTile(StoreGatewayOption gateway) {
    final theme = context.color;
    final bool isSelected = _selectedGatewayIds.contains(gateway.id);
    if (isSelected) {
      _ensureGatewayControllers(gateway.id);
    }
    final TextEditingController? beneficiaryCtrl =
        _beneficiaryControllers[gateway.id];
    final TextEditingController? accountCtrl = _accountControllers[gateway.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: isSelected,
          onChanged: (value) =>
              _toggleGatewaySelection(gateway.id, value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Row(
            children: [
              if (gateway.logoUrl != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      gateway.logoUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 44,
                        height: 44,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Icon(
                    Icons.account_balance,
                    color: theme.primaryColor,
                  ),
                ),
              Expanded(
                child: Text(
                  gateway.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textColorDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isSelected) ...[
          const SizedBox(height: 8),
          TextField(
            controller: beneficiaryCtrl,
            decoration: InputDecoration(
              labelText: 'اسم المستفيد',
              hintText: 'مثال: مؤسسة متجري التجارية',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: accountCtrl,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'رقم الحساب/الآيبان',
              hintText: 'أدخل رقم الحساب أو الآيبان المرتبط بالبوابة',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-Za-z0-9 ._\-]'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
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
            style: TextStyle(
              color: theme.textColorDark.withValues(alpha: 0.7),
            ),
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

class _InformativeCard extends StatelessWidget {
  final String message;
  final IconData? icon;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const _InformativeCard({
    required this.message,
    this.icon,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: theme.territoryColor,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColorDark,
              fontSize: context.font.normal,
            ),
          ),
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onPressed,
              child: Text(buttonLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

String? _resolveErrorMessage(Object? error) {
  if (error == null) {
    return null;
  }
  if (error is ApiHttpException) {
    if (error.statusCode == 401) {
      return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول ثم المحاولة مجدداً.';
    }
    final dynamic message = error.payload?['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return error.errorMessage?.toString();
  }
  if (error is ApiException) {
    return error.errorMessage?.toString();
  }
  return error.toString();
}
