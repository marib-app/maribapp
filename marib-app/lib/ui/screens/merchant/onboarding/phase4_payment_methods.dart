import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/data/model/store_gateway_option.dart';
import 'package:marib/settings.dart' as app_settings;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/payment/east_yemen_bank_config.dart';
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

  Future<bool> _confirmRemoveGateway(
      BuildContext context, String gatewayName) async {
    final theme = context.color;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'إزالة بوابة الدفع',
            style: TextStyle(
              color: theme.textColorDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'هل تريد إلغاء بوابة "$gatewayName"؟',
            style: TextStyle(color: theme.textColorDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
    return result == true;
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

  Future<void> _loadStoreGateways() async {
    if (!mounted) return;
    setState(() {
      _storeGatewaysLoading = true;
      _storeGatewaysError = null;
    });
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
          .where((g) => g.isActive && g.id > 0)
          .toList();
      if (!mounted) return;
      setState(() {
        _storeGateways
          ..clear()
          ..addAll(parsed);
        _storeGatewaysLoading = false;
      });
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

  List<StoreGatewayAccountDraft> _collectGatewayDrafts() {
    final List<StoreGatewayAccountDraft> drafts = <StoreGatewayAccountDraft>[];
    for (final int id in _selectedGatewayIds) {
      final beneficiary = _beneficiaryControllers[id]?.text.trim() ?? '';
      final account = _accountControllers[id]?.text.trim() ?? '';
      if (beneficiary.isEmpty || account.isEmpty) continue;
      drafts.add(StoreGatewayAccountDraft(
          gatewayId: id, beneficiaryName: beneficiary, accountNumber: account));
    }
    return drafts;
  }

  Future<void> _openGatewaySheet(StoreGatewayOption gateway) async {
    _ensureGatewayControllers(gateway.id);
    final beneficiaryCtrl = _beneficiaryControllers[gateway.id]!;
    final accountCtrl = _accountControllers[gateway.id]!;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        return Padding(
          padding:
              EdgeInsets.only(bottom: viewInsets.bottom, left: 16, right: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  gateway.name,
                  style: TextStyle(
                    fontSize: context.font.large,
                    fontWeight: FontWeight.w700,
                    color: context.color.textColorDark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: beneficiaryCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المستفيد',
                    hintText: 'مثال: اسم صاحب الحساب البنكي',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountCtrl,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'رقم الحساب / الآيبان',
                    hintText: 'اكتب رقم الحساب أو الآيبان المعتمد لنفس المتجر',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9 ._\\-]'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (beneficiaryCtrl.text.trim().isEmpty ||
                              accountCtrl.text.trim().isEmpty) {
                            UiUtils.showSoftSnackBar(
                              sheetContext,
                              message: 'يرجى تعبئة كل الحقول المطلوبة.',
                            );
                            return;
                          }
                          setState(() => _selectedGatewayIds.add(gateway.id));
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
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
        'يرجى إدخال رقم الحساب الذكي.',
      );
      return;
    }
    final List<StoreGatewayAccountDraft> drafts = _collectGatewayDrafts();
    if (_selectedGatewayIds.isNotEmpty &&
        drafts.length != _selectedGatewayIds.length) {
      HelperUtils.showSnackBarMessage(
        context,
        'أكمل بيانات جميع طرق الدفع المحددة.',
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
        resizeToAvoidBottomInset: false,
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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'خيارات الدفع في متجرك',
                style: TextStyle(
                  fontSize: context.font.extraLarge,
                  fontWeight: FontWeight.w700,
                  color: theme.textColorDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اضبط قنوات الدفع التي يدعمها متجرك ليتابع العميل عملية الشراء بسهولة.',
                style: TextStyle(
                  fontSize: context.font.normal,
                  color: theme.textColorDark.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabController,
                indicatorColor: theme.territoryColor,
                labelColor: theme.textColorDark,
                unselectedLabelColor:
                    theme.textColorDark.withValues(alpha: 0.65),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: context.font.normal,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: context.font.normal,
                ),
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

    if (_storeGatewaysLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_storeGatewaysError != null) {
      return _InformativeCard(
        message: 'حدث خطأ أثناء تحميل طرق الدفع المتاحة.',
        buttonLabel: 'إعادة المحاولة',
        onPressed: _loadStoreGateways,
      );
    }
    if (_storeGateways.isEmpty) {
      return _InformativeCard(
        message: 'لا توجد طرق دفع متاحة حالياً.',
        icon: Icons.info_outline,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      children: [
        Container(
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
                'طرق الدفع المتاحة',
                style: TextStyle(
                  fontSize: context.font.large,
                  fontWeight: FontWeight.w600,
                  color: theme.textColorDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'يمكنك تفعيل أكثر من خيار واستكمال الحقول المطلوبة لكل طريقة.',
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
                    'لم يتم اختيار أي طريقة بعد. اضغط على الطريقة لإدخال بياناتها.',
                    style: TextStyle(
                      fontSize: context.font.small,
                      color: theme.textColorDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGatewayTile(StoreGatewayOption gateway) {
    final theme = context.color;
    final bool isSelected = _selectedGatewayIds.contains(gateway.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          onTap: () async {
            if (isSelected) {
              final bool confirmed =
                  await _confirmRemoveGateway(context, gateway.name);
              if (confirmed && mounted) {
                setState(() => _selectedGatewayIds.remove(gateway.id));
              }
              return;
            }
            _openGatewaySheet(gateway);
          },
          contentPadding: EdgeInsets.zero,
          leading: gateway.logoUrl != null
              ? ClipRRect(
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
                )
              : Icon(
                  Icons.account_balance,
                  color: theme.primaryColor,
                ),
          title: Text(
            gateway.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textColorDark,
            ),
          ),
          subtitle: Text(
            'اضغط لإدخال بيانات الحساب لهذا الخيار',
            style: TextStyle(
              fontSize: context.font.small,
              color: theme.textColorDark.withValues(alpha: 0.7),
            ),
          ),
          trailing: Icon(
            isSelected ? Icons.check_circle : Icons.chevron_right,
            color: isSelected
                ? theme.territoryColor
                : theme.textColorDark.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 12),
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
            'لا يتوفر مزود للدفع الذكي حالياً. حاول مرة أخرى لاحقاً.',
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
            title: const Text('تفعيل الدفع الذكي'),
            subtitle: Text(
              _eastConfig!.note ??
                  'تأكد من إدخال بيانات الحساب الصحيحة عند التفعيل.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _smartAccountCtrl,
            enabled: _smartEnabled,
            decoration: InputDecoration(
              labelText: 'رقم الحساب في البنك',
              hintText: 'أدخل رقم الحساب كما في البنك',
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
  if (error == null) return null;
  if (error is ApiHttpException) {
    if (error.statusCode == 401) {
      return 'يرجى تسجيل الدخول ثم إعادة المحاولة.';
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
