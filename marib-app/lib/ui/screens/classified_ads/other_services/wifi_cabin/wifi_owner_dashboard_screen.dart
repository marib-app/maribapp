import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_owner_network_detail_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class WifiOwnerDashboardScreen extends StatefulWidget {
  const WifiOwnerDashboardScreen({super.key});

  static Route route() {
    return AppPageRoute.build(
      builder: (_) => const WifiOwnerDashboardScreen(),
    );
  }

  @override
  State<WifiOwnerDashboardScreen> createState() =>
      _WifiOwnerDashboardScreenState();
}

class _WifiOwnerDashboardScreenState extends State<WifiOwnerDashboardScreen> {
  final WifiRepository _repository = const WifiRepository();

  bool _loading = true;
  String? _error;
  List<WifiNetwork> _networks = const <WifiNetwork>[];
  final Map<int, List<WifiPlan>> _plansByNetwork = <int, List<WifiPlan>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final networks = await _repository.fetchOwnerNetworks(perPage: 50);
      final Map<int, List<WifiPlan>> plans = <int, List<WifiPlan>>{};

      for (final network in networks) {
        try {
          final fetchedPlans =
              await _repository.fetchManagedPlans(networkId: network.id);
          plans[network.id] = fetchedPlans;
        } catch (_) {
          plans[network.id] = const <WifiPlan>[];
        }
      }

      if (!mounted) return;
      setState(() {
        _networks = networks;
        _plansByNetwork
          ..clear()
          ..addAll(plans);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'إدارة شبكتك',
      ),
      backgroundColor: colors.backgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorPlaceholder(message: _error!, onRetry: _load)
                : _networks.isEmpty
                    ? const _EmptyPlaceholder()
                    : RefreshIndicator(
                        onRefresh: () => _load(),
                        displacement: 28,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemBuilder: (context, index) {
                            final network = _networks[index];

                            return _NetworkCard(
                              network: network,
                              onOpenDetail: () {
                                Navigator.of(context)
                                    .push(
                                      WifiOwnerNetworkDetailScreen.route(
                                          network),
                                    )
                                    .then((_) => _load());
                              },
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemCount: _networks.length,
                        ),
                      ),
      ),
    );
  }

}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.network,
    required this.onOpenDetail,
  });

  final WifiNetwork network;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    final String logoUrl = HelperUtils.absoluteImage(network.iconUrl);
    final bool hasLogo = logoUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenDetail,
        child: Container(
          decoration: BoxDecoration(
            color: colors.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.borderColor.withOpacity(.2),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: colors.secondaryColor,
                      border:
                          Border.all(color: colors.borderColor.withOpacity(.2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          network.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textDefaultColor,
                          ),
                        ),
                        if (network.address?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              network.address!,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colors.textLightColor),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.territoryColor.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      network.status?.isNotEmpty == true
                          ? network.status!
                          : '—',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.territoryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_tethering_rounded,
                size: 56, color: colors.territoryColor),
            const SizedBox(height: 12),
            Text(
              'لا توجد شبكات مفعلة لديك.',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textDefaultColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف شبكتك ثم عد لإدارتها من هنا.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colors.textLightColor),
            ),
          ],
        ),
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
        message: 'تحقق من الحقول المدخلة.',
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
          label: 'دفعة جديدة',
        );
      }

      if (!mounted) return;
      UiUtils.showSoftSnackBar(
        context,
        message: 'تمت إضافة الفئة بنجاح.',
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
                      'إضافة فئة جديدة',
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
                label: 'اسم الفئة',
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'حقل إجباري' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      controller: _priceCtrl,
                      label: 'السعر',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) =>
                          (value == null || double.tryParse(value) == null)
                              ? 'أدخل قيمة صحيحة'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      controller: _currencyCtrl,
                      label: 'العملة',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'حقل إجباري'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TextField(
                controller: _durationCtrl,
                label: 'مدة الصلاحية (أيام)',
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (value == null || int.tryParse(value) == null)
                        ? 'أدخل عدد الأيام'
                        : null,
              ),
              const SizedBox(height: 12),
              _TextField(
                controller: _descriptionCtrl,
                label: 'الوصف (اختياري)',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickVoucher,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                    _voucherName == null ? 'إرفاق ملف الأكواد (اختياري)' : _voucherName!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.territoryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ الفئة'),
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
