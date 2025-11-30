import 'package:flutter/material.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_owner_code.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/partials/manage_plans_tab.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

class WifiOwnerNetworkDetailScreen extends StatefulWidget {
  const WifiOwnerNetworkDetailScreen({super.key, required this.network});

  final WifiNetwork network;

  static Route route(WifiNetwork network) {
    return MaterialPageRoute(
      builder: (_) => WifiOwnerNetworkDetailScreen(network: network),
    );
  }

  @override
  State<WifiOwnerNetworkDetailScreen> createState() =>
      _WifiOwnerNetworkDetailScreenState();
}

class _WifiOwnerNetworkDetailScreenState
    extends State<WifiOwnerNetworkDetailScreen> {
  final WifiRepository _repository = const WifiRepository();

  bool _loading = true;
  String? _error;
  List<WifiPlan> _plans = const <WifiPlan>[];
  List<WifiOwnerCode> _codes = const <WifiOwnerCode>[];
  int _codesTotal = 0;
  int _codesAvailable = 0;
  int _codesSold = 0;
  bool _codesLoading = false;
  String? _codesError;
  String _codesStatus = '';
  final TextEditingController _codeSearchCtrl = TextEditingController();
  Map<String, int> _statsData = const <String, int>{};
  bool _plansMutating = false;
  WifiNetwork? _network;

  @override
  void initState() {
    super.initState();
    _network = widget.network;
    _load();
  }

  @override
  void dispose() {
    _codeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final statsFuture =
          _repository.fetchOwnerNetworkStats(widget.network.id);
      final plansFuture =
          _repository.fetchManagedPlans(networkId: widget.network.id);
      final codesFuture = _repository.fetchOwnerNetworkCodes(
        networkId: widget.network.id,
      );

      final statsResponse = await statsFuture;
      final plans = await plansFuture;
      final codesResult = await codesFuture;

      final Map<String, int> parsedStats = <String, int>{
        'plans': _intify(statsResponse['plans']?['total']) ?? plans.length,
        'batches': plans.fold<int>(
            0, (sum, plan) => sum + plan.codeBatches.length),
        'total': _intify(statsResponse['codes']?['total']) ??
            codesResult.total,
        'available': _intify(statsResponse['codes']?['available']) ??
            codesResult.available,
        'sold':
            _intify(statsResponse['codes']?['sold']) ?? codesResult.sold,
      };

      setState(() {
        _plans = plans;
        _codes = codesResult.codes;
        _codesTotal = codesResult.total;
        _codesAvailable = codesResult.available;
        _codesSold = codesResult.sold;
        _statsData = parsedStats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ErrorFilter.check(error).error;
        _loading = false;
      });
    }
  }

  Map<String, int> _stats() {
    final totalCodes = _statsData['total'] ?? _codesTotal;
    final availableCodes = _statsData['available'] ?? _codesAvailable;
    final sold = _statsData['sold'] ?? _codesSold;
    final batches =
        _statsData['batches'] ?? _plans.fold<int>(0, (sum, plan) => sum + plan.codeBatches.length);
    return {
      'plans': _statsData['plans'] ?? _plans.length,
      'batches': batches,
      'total': totalCodes,
      'available': availableCodes,
      'sold': sold < 0 ? 0 : sold,
    };
  }

  int? _intify(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final network = _network ?? widget.network;
    final String logoUrl = HelperUtils.absoluteImage(network.iconUrl);
    final bool hasLogo = logoUrl.isNotEmpty;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: colors.backgroundColor,
        foregroundColor: colors.textDefaultColor,
        elevation: 0,
        title: const Text('لوحة الشبكة'),
        bottom: TabBar(
          labelColor: colors.territoryColor,
          unselectedLabelColor: colors.textLightColor,
          indicatorColor: colors.territoryColor,
          tabs: const [
            Tab(text: 'الإحصائيات'),
            Tab(text: 'الأكواد'),
            Tab(text: 'الفئات'),
            Tab(text: 'البلاغات'),
            Tab(text: 'الإعدادات'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorPlaceholder(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Container(
                      margin:
                          const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.secondaryColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                              color: colors.borderColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: colors.backgroundColor,
                              border: Border.all(
                              color: colors.borderColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: hasLogo
                                  ? Image.network(
                                      logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.wifi_rounded,
                                        color: colors.textLightColor,
                                      ),
                                    )
                                  : Icon(
                                      Icons.wifi_rounded,
                                      color: colors.textLightColor,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  network.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                if (network.address?.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      network.address!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.textLightColor,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.territoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              network.status ?? '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: colors.territoryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _StatsTab(stats: _stats(), plans: _plans),
                          _CodesTab(
                            total: _codesTotal,
                            sold: _codesSold,
                            available: _codesAvailable,
                            codes: _codes,
                            loading: _codesLoading,
                            error: _codesError,
                            searchController: _codeSearchCtrl,
                            selectedStatus: _codesStatus,
                            onSearch: _reloadCodes,
                            onStatusChange: (value) => _reloadCodes(status: value),
                          ),
                          ManagePlansTab(
                            plans: _plans,
                            onAddPlan: _openAddPlanSheet,
                            onDeletePlan: _confirmDeletePlan,
                            mutating: _plansMutating,
                          ),
                          const _ReportsTab(),
                          _SettingsTab(
                            onChangeLogo: _showLogoToast,
                            onChangeLogin: _showLoginToast,
                            onToggleStatus: _showToggleToast,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _reloadCodes({String? search, String? status}) async {
    setState(() {
      _codesLoading = true;
      _codesError = null;
      if (status != null) _codesStatus = status;
    });

    try {
      final result = await _repository.fetchOwnerNetworkCodes(
        networkId: widget.network.id,
        search: search ?? _codeSearchCtrl.text,
        status: _codesStatus.trim().isEmpty ? null : _codesStatus,
      );
      if (!mounted) return;
      setState(() {
        _codes = result.codes;
        _codesTotal = result.total;
        _codesAvailable = result.available;
        _codesSold = result.sold;
        _codesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _codesError = ErrorFilter.check(error).error;
        _codesLoading = false;
      });
    }
  }

  Future<void> _openAddPlanSheet() async {
    if (_plansMutating) return;
    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddPlanSheet(
        network: _network ?? widget.network,
        repository: _repository,
      ),
    );
    if (created == true) {
      await _load();
    }
  }
  Future<void> _confirmDeletePlan(WifiPlan plan) async {
    if (_plansMutating) return;
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final colors = sheetContext.color;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '????? ?????',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '?? ?????? ??? "${plan.name}". ?? ???? ?????????',
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.textLightColor),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('?????'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('???'),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _plansMutating = true);
    try {
      await _repository.deleteNetworkPlan(plan.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: ErrorFilter.check(error).error,
      );
    } finally {
      if (mounted) setState(() => _plansMutating = false);
    }
  }

  void _showLogoToast() {
    UiUtils.showSoftSnackBar(
      context,
      message: 'يمكن تغيير الشعار من داخل التطبيق قريباً.',
    );
  }

  void _showLoginToast() {
    UiUtils.showSoftSnackBar(
      context,
      message: 'يمكن تغيير صورة تسجيل الدخول من داخل التطبيق قريباً.',
    );
  }

  void _showToggleToast() {
    UiUtils.showSoftSnackBar(
      context,
      message: 'سيتم دعم إيقاف/تفعيل الشبكة عبر التطبيق قريباً.',
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.stats, required this.plans});

  final Map<String, int> stats;
  final List<WifiPlan> plans;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatCard(label: 'الخطط', value: stats['plans'] ?? 0),
              _StatCard(label: 'الدُفعات', value: stats['batches'] ?? 0),
              _StatCard(label: 'الأكواد الكلية', value: stats['total'] ?? 0),
              _StatCard(label: 'المتاح', value: stats['available'] ?? 0),
              _StatCard(label: 'المباع', value: stats['sold'] ?? 0),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'الفئات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textDefaultColor,
                ),
          ),
          const SizedBox(height: 8),
          if (plans.isEmpty)
            Text(
              'لا توجد فئات بعد.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.textLightColor),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: colors.borderColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  _PlanRow.header(),
                  const Divider(height: 1),
                  ...plans.map(_PlanRow.fromPlan),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CodesTab extends StatelessWidget {
  const _CodesTab({
    required this.total,
    required this.sold,
    required this.available,
    required this.codes,
    required this.loading,
    required this.error,
    required this.searchController,
    required this.selectedStatus,
    required this.onSearch,
    required this.onStatusChange,
  });

  final int total;
  final int sold;
  final int available;
  final List<WifiOwnerCode> codes;
  final bool loading;
  final String? error;
  final TextEditingController searchController;
  final String selectedStatus;
  final Future<void> Function({String? search, String? status}) onSearch;
  final ValueChanged<String> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  onSubmitted: (value) => onSearch(search: value),
                  decoration: InputDecoration(
                    hintText: 'بحث عن كود أو عميل',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colors.secondaryColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colors.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: selectedStatus.isEmpty ? '' : selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'الحالة',
                    filled: true,
                    fillColor: colors.secondaryColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colors.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('الكل')),
                    DropdownMenuItem(value: 'available', child: Text('متاح')),
                    DropdownMenuItem(value: 'sold', child: Text('مباع')),
                  ],
                  onChanged: (value) => onStatusChange(value ?? ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatCard(label: 'الإجمالي', value: total),
              _StatCard(label: 'المتاح', value: available),
              _StatCard(label: 'المباع', value: sold),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error!,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.textLightColor),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => onSearch(),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            )
          else if (codes.isEmpty)
            Text(
              'لا توجد أكواد بعد.',
              style:
                  textTheme.bodyMedium?.copyWith(color: colors.textLightColor),
            )
          else
            Column(
              children: codes.map((code) {
                final bool isSold =
                    (code.status ?? '').toLowerCase() == 'sold';
                final Color statusColor =
                    isSold ? Colors.redAccent : Colors.green;
                final String codeLabel =
                    (code.codeSuffix?.isNotEmpty == true)
                        ? code.codeSuffix!
                        : (code.codeLast4?.isNotEmpty == true
                            ? code.codeLast4!
                            : '—');
                final String buyer = (code.allocatedUserName ??
                        code.allocatedUserEmail ??
                        '—')
                    .toString();
                final String dateLabel = (code.soldAt ??
                        code.deliveredAt ??
                        code.allocatedAt ??
                        code.revealedAt)
                    ?.toLocal()
                    .toString()
                    .split('.')
                    .first ??
                    '—';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(
                            color: colors.borderColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          code.status ?? '—',
                          style: textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الكود: $codeLabel',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المشتري: $buyer',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textLightColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'التاريخ: $dateLabel',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.name,
    required this.price,
    required this.currency,
    required this.available,
    required this.total,
  });

  final String name;
  final String price;
  final String currency;
  final int available;
  final int total;

  factory _PlanRow.fromPlan(WifiPlan plan) {
    final int totalCodes =
        plan.codeBatches.fold<int>(0, (sum, b) => sum + b.totalCodes);
    final int availableCodes =
        plan.codeBatches.fold<int>(0, (sum, b) => sum + b.availableCodes);
    final int sold = totalCodes - availableCodes;
    return _PlanRow(
      name: plan.name,
      price: plan.price.toString(),
      currency: plan.currency ?? '',
      available: availableCodes,
      total: sold < 0 ? totalCodes : totalCodes,
    );
  }

  factory _PlanRow.header() => const _PlanRow(
        name: 'الفئة',
        price: 'السعر',
        currency: 'العملة',
        available: -1,
        total: -1,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final bool isHeader = available == -1 && total == -1;
    final TextStyle base = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textDefaultColor,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
            ) ??
        const TextStyle();

    final String availableText =
        isHeader ? 'المتاح' : available.toString();
    final int soldValue = total - available;
    final String soldText = isHeader ? 'المباع' : soldValue.clamp(0, total).toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: isHeader ? colors.secondaryColor : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('$price $currency', style: base),
          ),
          Expanded(
            flex: 2,
            child: Text(availableText, style: base),
          ),
          Expanded(
            flex: 2,
            child: Text(soldText, style: base),
          ),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'لا توجد بلاغات مسجلة.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.textLightColor),
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.onChangeLogo,
    required this.onChangeLogin,
    required this.onToggleStatus,
  });

  final VoidCallback onChangeLogo;
  final VoidCallback onChangeLogin;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ListTile(
          leading: Icon(Icons.image_rounded, color: colors.territoryColor),
          title: const Text('تغيير الشعار'),
          onTap: onChangeLogo,
        ),
        ListTile(
          leading: Icon(Icons.login_rounded, color: colors.territoryColor),
          title: const Text('تغيير صورة تسجيل الدخول'),
          onTap: onChangeLogin,
        ),
        ListTile(
          leading: Icon(Icons.power_settings_new_rounded,
              color: colors.territoryColor),
          title: const Text('إيقاف / تفعيل الشبكة'),
          subtitle: const Text('تغيير حالة الشبكة من داخل التطبيق'),
          onTap: onToggleStatus,
        ),
      ],
    );
  }
}

class _AddPlanSheet extends StatefulWidget {
  const _AddPlanSheet({
    required this.network,
    required this.repository,
  });

  final WifiNetwork network;
  final WifiRepository repository;

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _currencyCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  File? _voucherFile;
  String? _voucherName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _currencyCtrl.text =
        widget.network.currencies.isNotEmpty ? widget.network.currencies.first : 'YER';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _currencyCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVoucher() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const ['csv', 'txt', 'xls', 'xlsx'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() {
      _voucherFile = File(file.path!);
      _voucherName = file.name;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String name = _nameCtrl.text.trim();
    final double? price = double.tryParse(_priceCtrl.text.trim());
    final int? duration = int.tryParse(_durationCtrl.text.trim());
    final String currency = _currencyCtrl.text.trim();
    final String description = _descriptionCtrl.text.trim();

    if (price == null || duration == null) {
      UiUtils.showSoftSnackBar(
        context,
        message: '???????? ???? ???????????? ??????????????.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final plan = await widget.repository.createNetworkPlan(
        networkId: widget.network.id,
        name: name,
        description: description.isEmpty ? null : description,
        durationDays: duration,
        price: price,
        currency: currency,
      );

      if (_voucherFile != null) {
        final formFile = await MultipartFile.fromFile(
          _voucherFile!.path,
          filename: _voucherName ?? 'vouchers.csv',
        );
        await widget.repository.createPlanBatch(
          planId: plan.id,
          sourceFile: formFile,
          label: '???????? ??????????',
        );
      }

      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: '?????? ?????????? ?????????? ??????????.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: ErrorFilter.check(error).error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final colors = context.color;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: viewInsets + 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '?????????? ?????? ??????????',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TextField(
                controller: _nameCtrl,
                label: '?????? ??????????',
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '?????? ????????????' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      controller: _priceCtrl,
                      label: '??????????',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) =>
                          (value == null || double.tryParse(value) == null)
                              ? '??????? ???????? ??????????'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      controller: _currencyCtrl,
                      label: '????????????',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? '?????? ????????????'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TextField(
                controller: _durationCtrl,
                label: '?????? ???????????????? (???????)',
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (value == null || int.tryParse(value) == null)
                        ? '??????? ?????? ???????????'
                        : null,
              ),
              const SizedBox(height: 12),
              _TextField(
                controller: _descriptionCtrl,
                label: '?????????? (??????????????)',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickVoucher,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_voucherName ?? '?????????? ???????? ????????????'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('?????????? ????????????'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: colors.secondaryColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.territoryColor),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textLightColor,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textDefaultColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            )
          ],
        ),
      ),
    );
  }
}
