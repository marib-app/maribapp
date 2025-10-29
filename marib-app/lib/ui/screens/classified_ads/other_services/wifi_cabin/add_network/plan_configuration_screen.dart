import 'dart:math' as math;
import 'dart:typed_data';
import 'package:marib/utils/api.dart';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/currency_utils.dart';
import 'add_network_form.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';

class WifiPlanConfigurationScreen extends StatefulWidget {
  const WifiPlanConfigurationScreen({
    super.key,
    required this.networkId,
    this.networkName,
    this.defaultCurrency = 'YER',
    WifiRepository? repository,
  }) : repository = repository ?? const WifiRepository();

  final int networkId;
  final String? networkName;
  final String defaultCurrency;
  final WifiRepository repository;

  static Route<Map<String, dynamic>?> route({
    required int networkId,
    String? networkName,
    String defaultCurrency = 'YER',
    WifiRepository? repository,
  }) {
    return AppPageRoute.build<Map<String, dynamic>?>(
      builder: (_) => WifiPlanConfigurationScreen(
        networkId: networkId,
        networkName: networkName,
        defaultCurrency: defaultCurrency,
        repository: repository,
      ),
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<WifiPlanConfigurationScreen> createState() =>
      WifiPlanConfigurationScreenState();
}

class WifiPlanConfigurationScreenState
    extends State<WifiPlanConfigurationScreen> {
  final TextEditingController _planNameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _dataAllowanceController =
      TextEditingController();
  final TextEditingController _validityController = TextEditingController();

  bool _dataUnlimited = false;
  bool _validityUnlimited = false;
  bool _isSubmitting = false;
  PlatformFile? _voucherFile;

  @override
  void dispose() {
    _planNameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _dataAllowanceController.dispose();
    _validityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                _buildHeader(context, onSurface),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _planNameController,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'اسم البطاقة',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _categoryController,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'فئة البطاقة',
                            hintText: 'مثال: بطاقات شهرية أو سياحية',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _priceController,
                          enabled: !_isSubmitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'السعر',
                            suffixText:
                                _resolveCurrencyLabel(widget.defaultCurrency),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'حجم البيانات',
                          style: TextStyle(
                            color: onSurface.withOpacity(.88),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _dataUnlimited,
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _dataUnlimited = value ?? false;
                                  });
                                },
                          title: const Text('بيانات غير محدودة'),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (!_dataUnlimited) ...[
                          TextField(
                            controller: _dataAllowanceController,
                            enabled: !_isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'البيانات (بالجيجابايت)',
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'صلاحية الاستخدام',
                          style: TextStyle(
                            color: onSurface.withOpacity(.88),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _validityUnlimited,
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _validityUnlimited = value ?? false;
                                  });
                                },
                          title: const Text('صلاحية غير محدودة'),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (!_validityUnlimited) ...[
                          TextField(
                            controller: _validityController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'الصلاحية (بالأيام)',
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        WifiFilePickerTile(
                          title: 'ملف أكواد القسائم',
                          placeholder:
                              'ارفع ملف CSV أو XLS أو XLSX يحتوي على الأكواد الجديدة',
                          fileName: _voucherFile?.name,
                          isBusy: _isSubmitting,
                          onTap: () {
                            _pickVoucherFile();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: _buildSubmitButton(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color onSurface) {
    final palette = context.color;
    final theme = Theme.of(context);

    final String title = widget.networkName == null
        ? 'إعداد فئة البطاقات'
        : 'فئة جديدة لـ ${widget.networkName}';
    final String subtitle = widget.networkName == null
        ? 'اضبط تفاصيل الباقة وارفع أكواد القسائم الجديدة قبل النشر.'
        : 'اضبط تفاصيل الباقة وارفع الأكواد المرتبطة بالشبكة.';

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: onSurface.withOpacity(.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.territoryColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: palette.territoryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final palette = context.color;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          backgroundColor: palette.territoryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.borderColor,
          disabledForegroundColor: Colors.white.withOpacity(0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ).merge(
          ButtonStyle(
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withOpacity(.08),
            ),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Text('حفظ ورفع الأكواد'),
      ),
    );
  }

  Future<void> _pickVoucherFile() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedVoucherExtensions,
        withData: kIsWeb,
      );

      if (result == null) {
        return;
      }

      final PlatformFile file = result.files.single;
      final MultipartFile? prepared = _prepareVoucherMultipart(file);
      if (prepared == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _voucherFile = file;
      });
    } catch (_) {
      _showError('تعذّر اختيار الملف، حاول مرة أخرى.');
    }
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;

    final String name = _planNameController.text.trim();
    if (name.isEmpty) {
      _showError('يرجى إدخال اسم البطاقة.');
      return;
    }

    final String category = _categoryController.text.trim();
    if (category.isEmpty) {
      _showError('يرجى تحديد فئة البطاقة.');
      return;
    }

    final num? price = _parseNumber(_priceController.text);
    if (price == null || price <= 0) {
      _showError('يرجى إدخال سعر صالح أكبر من صفر.');
      return;
    }

    num? dataAllowanceGb;
    if (!_dataUnlimited) {
      dataAllowanceGb = _parseNumber(_dataAllowanceController.text);
      if (dataAllowanceGb == null || dataAllowanceGb <= 0) {
        _showError('يرجى إدخال حجم بيانات صالح بالجيجابايت.');
        return;
      }
    }

    int? validityDays;
    if (!_validityUnlimited) {
      final num? parsed = _parseNumber(_validityController.text);
      if (parsed == null || parsed <= 0) {
        _showError('يرجى إدخال عدد أيام الصلاحية.');
        return;
      }
      validityDays = parsed.round();
      if (validityDays <= 0) {
        _showError('عدد الأيام يجب أن يكون أكبر من صفر.');
        return;
      }
    }

    if (_voucherFile == null) {
      _showError('يرجى رفع ملف أكواد القسائم.');
      return;
    }

    final MultipartFile? voucherMultipart =
        _prepareVoucherMultipart(_voucherFile!);
    if (voucherMultipart == null) {
      return;
    }

    final int durationMinutes = _resolveDurationMinutes(
      validityDays: validityDays,
      unlimitedValidity: _validityUnlimited,
    );

    final int? dataAllowanceMb = _dataUnlimited
        ? null
        : math.max(1, ((dataAllowanceGb ?? 0) * 1024).round());

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> planResponse =
          await widget.repository.createNetworkPlan(
        networkId: widget.networkId,
        name: name,
        description: category,
        durationMinutes: durationMinutes,
        price: price,
        currency: widget.defaultCurrency,
        dataAllowanceMb: dataAllowanceMb,
        validityDays: _validityUnlimited ? null : validityDays,
        meta: _buildPlanMeta(
          category: category,
          dataAllowanceGb: dataAllowanceGb,
          dataUnlimited: _dataUnlimited,
          validityDays: validityDays,
          validityUnlimited: _validityUnlimited,
        ),
      );

      final Map<String, dynamic> planPayload =
          _extractPlanPayload(planResponse);
      final int planId = _parseId(
        planPayload['id'] ?? planResponse['plan_id'] ?? planResponse['id'],
      );

      if (planId <= 0) {
        throw StateError('لم يتم إنشاء الفئة الجديدة بنجاح.');
      }

      final Map<String, dynamic> batchResponse =
          await widget.repository.createPlanBatch(
        planId: planId,
        file: voucherMultipart,
      );

      final Map<String, dynamic> batchPayload =
          _extractBatchPayload(batchResponse)..['plan_id'] = planId;

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      final String? planMessage = _stringify(
        planResponse['message'] ??
            planPayload['message'] ??
            'تم إنشاء الفئة "$name" بنجاح.',
      );
      final String batchMessage = _buildBatchMessage(batchPayload);

      final Map<String, dynamic> result = <String, dynamic>{
        'plan': planPayload,
        'planMessage': planMessage,
        'batch': batchPayload,
        'batchMessage': batchMessage,
      }..removeWhere((key, value) => value == null);

      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(error.toString());
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(
        error.toString().isEmpty
            ? 'تعذّر إكمال العملية، حاول مجددًا.'
            : error.toString(),
      );
    }
  }

  Map<String, dynamic> _buildPlanMeta({
    required String category,
    required num? dataAllowanceGb,
    required bool dataUnlimited,
    required int? validityDays,
    required bool validityUnlimited,
  }) {
    return <String, dynamic>{
      'card_category': category,
      'data': <String, dynamic>{
        'allowance_type': dataUnlimited ? 'unlimited' : 'limited',
        if (!dataUnlimited) 'allowance_gb': dataAllowanceGb,
      },
      'validity': <String, dynamic>{
        'type': validityUnlimited ? 'unlimited' : 'days',
        if (!validityUnlimited) 'days': validityDays,
      },
    };
  }

  MultipartFile? _prepareVoucherMultipart(PlatformFile file) {
    final String extension = (file.extension ?? '').toLowerCase();
    if (!_allowedVoucherExtensions.contains(extension)) {
      _showError(
        'صيغة ملف القسائم غير مدعومة. يرجى اختيار ملف بصيغة CSV أو XLS أو XLSX.',
      );
      return null;
    }

    if (file.size > _maxVoucherUploadSizeBytes) {
      _showError('حجم ملف القسائم يتجاوز الحد المسموح (5 ميجابايت).');
      return null;
    }

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

  Map<String, dynamic> _extractPlanPayload(dynamic response) {
    final dynamic rawData = response is Map<String, dynamic>
        ? response['data'] ?? response['plan']
        : null;
    if (rawData is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData as Map);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _extractBatchPayload(dynamic response) {
    final dynamic rawData = response is Map<String, dynamic>
        ? response['data'] ?? response['batch']
        : null;
    if (rawData is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData as Map);
    }
    return <String, dynamic>{};
  }

  String _buildBatchMessage(Map<String, dynamic> batch) {
    final int accepted = _parseId(batch['accepted']);
    final int rejected = _parseId(batch['rejected']);
    final int total = _parseId(batch['total']);

    return 'تم رفع ملف الأكواد بنجاح (مقبول: $accepted، مرفوض: $rejected، الإجمالي: $total).';
  }

  int _resolveDurationMinutes({
    required int? validityDays,
    required bool unlimitedValidity,
  }) {
    if (unlimitedValidity) {
      return 24 * 60;
    }
    final int days = math.max<int>(1, validityDays ?? 1);
    return days * 24 * 60;
  }

  int _parseId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  num? _parseNumber(String input) {
    final String normalized = input.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  String? _stringify(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  void _showError(String message) {
    HelperUtils.showSnackBarMessage(
      context,
      message,
      type: MessageType.error,
    );
  }

  String _resolveCurrencyLabel(String currency) {

    final String? preferred = CurrencyUtils.preferredDisplayFor(currency);
    if (preferred != null) {
      return preferred;
    }

    switch (currency.toUpperCase()) {

      case 'OMR':
        return 'ر.ع';
      case 'AED':
        return 'د.إ';
      default:
        return CurrencyUtils.preferredDisplayFor('YER') ?? 'YER';
    }
  }

  static const int _maxVoucherUploadSizeBytes = 5 * 1024 * 1024;
  static const List<String> _allowedVoucherExtensions = <String>[
    'csv',
    'xls',
    'xlsx'
  ];

  @visibleForTesting
  void debugSetVoucherFile(PlatformFile? file) {
    _voucherFile = file;
  }

  @visibleForTesting
  TextEditingController get planNameController => _planNameController;

  @visibleForTesting
  TextEditingController get categoryController => _categoryController;

  @visibleForTesting
  TextEditingController get priceController => _priceController;

  @visibleForTesting
  TextEditingController get dataAllowanceController => _dataAllowanceController;

  @visibleForTesting
  TextEditingController get validityController => _validityController;

  @visibleForTesting
  bool get dataUnlimited => _dataUnlimited;

  @visibleForTesting
  bool get validityUnlimited => _validityUnlimited;
}


