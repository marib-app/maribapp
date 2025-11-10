import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/merchant/onboarding/phase1_activity_info.dart';
import 'package:marib/ui/screens/merchant/onboarding/phase2_categories_hours.dart';
import 'package:marib/ui/screens/merchant/onboarding/phase3_store_policy.dart';
import 'package:marib/ui/screens/merchant/onboarding/phase4_payment_methods.dart';
import 'package:marib/ui/screens/merchant/onboarding/phase5_store_credentials.dart';
import 'package:marib/ui/screens/merchant/onboarding/phase6_final_submission.dart';

class MerchantOnboardingScreen extends StatefulWidget {
  final Map<String, dynamic>? signupDraft;
  final int initialPage;

  const MerchantOnboardingScreen({
    super.key,
    this.signupDraft,
    this.initialPage = 0,
  });

  static Route<void> route(RouteSettings settings) {
    Map<String, dynamic>? draft;
    int initialPage = HiveUtils.getMerchantOnboardingStep();
    final args = settings.arguments;
    if (args is Map<String, dynamic>) {
      final dynamic maybeDraft = args['signupDraft'];
      if (maybeDraft is Map<String, dynamic>) {
        draft = maybeDraft;
      }
      final dynamic maybeStep = args['resumeFromStep'];
      if (maybeStep is int) {
        initialPage = maybeStep;
      }
    }
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => MerchantOnboardingScreen(
        signupDraft: draft,
        initialPage: initialPage,
      ),
    );
  }

  @override
  State<MerchantOnboardingScreen> createState() =>
      _MerchantOnboardingScreenState();
}

class _MerchantOnboardingScreenState extends State<MerchantOnboardingScreen> {
  late final PageController _controller;
  late int _currentPage;
  final int _totalPages = 6;
  final ValueNotifier<int> _pageVisibilityNotifier = ValueNotifier<int>(0);
  ActivityInfoData? _activityInfo;
  Phase2Data? _categoriesHoursData;
  StorePolicyData? _policyData;
  PaymentOptionsData? _paymentOptions;
  StoreCredentialsData? _credentialsData;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _totalPages - 1);
    _controller = PageController(initialPage: _currentPage);
    final Map<String, dynamic>? draft = widget.signupDraft;
    if (draft != null && draft.isNotEmpty) {
      unawaited(HiveUtils.saveMerchantOnboardingDraft(draft));
    }
    unawaited(
      HiveUtils.beginMerchantOnboardingSession(
        initialStep: _currentPage,
        draft: draft,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageVisibilityNotifier.value = _currentPage;
    });
  }

  void _goToPage(int next) {
    if (next < 0 || next >= _totalPages) return;
    setState(() {
      _currentPage = next;
    });
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 400), curve: Curves.ease);
    unawaited(HiveUtils.setMerchantOnboardingStep(next));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageVisibilityNotifier.value = next;
    });
  }

  void _onPhase1Next(ActivityInfoData data) {
    _activityInfo = data;
    _goToPage(1);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase2Next(Phase2Data data) {
    _categoriesHoursData = data;
    _goToPage(2);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase3Next(StorePolicyData data) {
    _policyData = data;
    _goToPage(3);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase4Next(PaymentOptionsData data) {
    _paymentOptions = data;
    _goToPage(4);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase5Next(StoreCredentialsData data) {
    _credentialsData = data;
    _goToPage(5);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  Future<void> _onPhase6Submit() async {
    if (!_ensurePhaseData()) {
      return;
    }
    try {
      final Map<String, dynamic> payload = await _buildOnboardingPayload();
      await Api.post(url: Api.storeOnboardingApi, parameter: payload);
      await _syncManualGatewayAccounts(
          _paymentOptions?.manualDrafts ?? const []);
      await HiveUtils.clearMerchantOnboardingProgress();
      await NotificationService.resendPendingTokenIfNeeded();
      await FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
        context,
        clearCacheBeforeFetch: true,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MerchantOnboardingSuccessScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      HelperUtils.showSnackBarMessage(
        context,
        _mapSubmissionError(error),
        messageDuration: 4,
      );
    }
  }

  bool _ensurePhaseData() {
    if (_activityInfo == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'أكمل بيانات النشاط التجاري أولاً.',
      );
      _goToPage(0);
      return false;
    }
    if (_categoriesHoursData == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'حدد الأقسام وساعات العمل قبل المتابعة.',
      );
      _goToPage(1);
      return false;
    }
    if (_policyData == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'أدخل سياسة الاسترجاع والتبديل قبل الإرسال.',
      );
      _goToPage(2);
      return false;
    }
    if (_paymentOptions == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'اختر طرق الدفع الخاصة بمتجرك.',
      );
      _goToPage(3);
      return false;
    }
    if (_credentialsData == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'حدد معرف المتجر وكلمة المرور قبل الإرسال.',
      );
      _goToPage(4);
      return false;
    }
    return true;
  }

  Future<Map<String, dynamic>> _buildOnboardingPayload() async {
    final ActivityInfoData info = _activityInfo!;
    final Phase2Data categoriesData = _categoriesHoursData!;
    final StorePolicyData policy = _policyData!;
    final PaymentOptionsData payments = _paymentOptions!;
    final StoreCredentialsData credentials = _credentialsData!;

    final Map<String, dynamic> payload = <String, dynamic>{
      'name': info.storeName.trim(),
    };

    final String description = info.description.trim();
    if (description.isNotEmpty) {
      payload['description'] = description;
    }
    final String address = info.address.trim();
    if (address.isNotEmpty) {
      payload['address'] = address;
    }
    if (info.latitude != null) {
      payload['latitude'] = info.latitude;
    }
    if (info.longitude != null) {
      payload['longitude'] = info.longitude;
    }

    final String? encodedLogo = await _encodeFileToBase64(info.logo);
    if (encodedLogo != null) {
      payload['logo'] = encodedLogo;
    }

    final List<Map<String, dynamic>> workingHours =
        _buildWorkingHoursPayload(categoriesData);
    if (workingHours.isNotEmpty) {
      payload['working_hours'] = workingHours;
    }

    final Map<String, dynamic> meta = <String, dynamic>{};
    if (categoriesData.categoryIds.isNotEmpty) {
      meta['categories'] = List<int>.from(categoriesData.categoryIds);
    }
    final List<String> paymentMethods = _resolvePaymentMethods(payments);
    if (paymentMethods.isNotEmpty) {
      meta['payment_methods'] = paymentMethods;
    }
    if (meta.isNotEmpty) {
      payload['meta'] = meta;
    }

    payload['policies'] = <Map<String, dynamic>>[
      <String, dynamic>{
        'policy_type': 'return_policy',
        'title': 'سياسة الاسترجاع والتبديل',
        'content': policy.policy.trim(),
        'is_required': true,
        'is_active': true,
        'display_order': 1,
      },
    ];

    final Map<String, dynamic> settings = <String, dynamic>{
      'allow_manual_payments': payments.manualDrafts.isNotEmpty,
    }..removeWhere((key, value) => value == null);
    if (settings.isNotEmpty) {
      payload['settings'] = settings;
    }

    if (payments.smartEnabled &&
        (payments.smartAccountNumber?.trim().isNotEmpty ?? false)) {
      payload['financial'] = <String, dynamic>{
        'policy_type': 'east_yemen_bank',
        'policy_payload': <String, dynamic>{
          'account_number': payments.smartAccountNumber!.trim(),
        },
      };
    }

    final String staffHandle = _normalizeStaffHandle(credentials.username);
    if (staffHandle.isNotEmpty) {
      payload['staff'] = <String, dynamic>{
        'invited_email': staffHandle,
      };
    }

    return payload;
  }

  List<Map<String, dynamic>> _buildWorkingHoursPayload(Phase2Data data) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    final List<MapEntry<int, DaySchedule>> entries = data.workingHours.entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final MapEntry<int, DaySchedule> entry in entries) {
      final DaySchedule schedule = entry.value;
      final Map<String, dynamic> row = <String, dynamic>{
        'weekday': entry.key,
        'is_open': schedule.enabled,
      };
      if (schedule.enabled) {
        row['opens_at'] = _formatTimeOfDay(schedule.from);
        row['closes_at'] = _formatTimeOfDay(schedule.to);
      }
      result.add(row);
    }
    return result;
  }

  List<String> _resolvePaymentMethods(PaymentOptionsData data) {
    final Set<String> methods = <String>{};
    if (data.manualDrafts.isNotEmpty) {
      methods.add('store_gateway');
    }
    if (data.smartEnabled &&
        (data.smartAccountNumber?.trim().isNotEmpty ?? false)) {
      methods.add('east_yemen_bank');
    }
    return methods.toList();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<String?> _encodeFileToBase64(File? file) async {
    if (file == null) return null;
    try {
      final List<int> bytes = await file.readAsBytes();
      final String mimeType = _inferMimeType(file.path);
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  String _inferMimeType(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _normalizeStaffHandle(String raw) {
    String candidate = raw.trim().toLowerCase();
    if (candidate.contains('@')) {
      candidate = candidate.split('@').first;
    }
    candidate = candidate.replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    return candidate;
  }

  Future<void> _syncManualGatewayAccounts(
      List<StoreGatewayAccountDraft> drafts) async {
    List<int> existingAccountIds = const <int>[];
    try {
      final Map<String, dynamic> response =
          await Api.get(url: Api.storeGatewayAccountsApi);
      existingAccountIds = _extractGatewayAccountIds(response);
    } catch (_) {
      existingAccountIds = const <int>[];
    }

    for (final int id in existingAccountIds) {
      try {
        await Api.delete(url: Api.storeGatewayAccountApi(id));
      } catch (_) {}
    }

    for (final StoreGatewayAccountDraft draft in drafts) {
      try {
        final Map<String, dynamic> payload =
            Map<String, dynamic>.from(draft.toJson())..['is_active'] = true;
        await Api.post(
          url: Api.storeGatewayAccountsApi,
          parameter: payload,
        );
      } catch (_) {}
    }
  }

  List<int> _extractGatewayAccountIds(dynamic source) {
    final List<int> ids = <int>[];
    void collect(dynamic node) {
      if (node is List) {
        for (final dynamic element in node) {
          collect(element);
        }
        return;
      }
      if (node is Map<String, dynamic>) {
        final dynamic idValue = node['id'];
        final dynamic gatewayIdValue = node['store_gateway_id'];
        if (idValue != null && gatewayIdValue != null) {
          final int? parsedId = int.tryParse('$idValue');
          if (parsedId != null) {
            ids.add(parsedId);
          }
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
    return ids;
  }

  String _mapSubmissionError(Object error) {
    if (error is ApiHttpException) {
      final dynamic message = error.payload?['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    if (error is ApiException) {
      final String fallback = error.toString();
      if (fallback.isNotEmpty) {
        return fallback;
      }
    }
    return 'تعذر إرسال طلب الانضمام حالياً. حاول مرة أخرى.';
  }

  void _handleBackPressed() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageVisibilityNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gutters = context.color;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: context.color.textDefaultColor,
          onPressed: _handleBackPressed,
        ),
        title: Text('merchantOnboarding'.translate(context)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: LinearProgressIndicator(
              value: (_currentPage + 1) / _totalPages,
              color: gutters.territoryColor,
              backgroundColor: gutters.secondaryColor,
            ),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Phase1ActivityInfo(onNext: _onPhase1Next),
                Phase2CategoriesHours(
                  onBack: () => _goToPage(0),
                  onNext: _onPhase2Next,
                  visibilityNotifier: _pageVisibilityNotifier,
                  pageIndex: 1,
                ),
                Phase3StorePolicy(
                  onBack: () => _goToPage(1),
                  onNext: _onPhase3Next,
                ),
                Phase4PaymentMethods(
                  onBack: () => _goToPage(2),
                  onNext: _onPhase4Next,
                  visibilityNotifier: _pageVisibilityNotifier,
                  pageIndex: 3,
                ),
                Phase5StoreCredentials(
                  onBack: () => _goToPage(3),
                  onNext: _onPhase5Next,
                ),
                Phase6FinalSubmission(
                  onBack: () => _goToPage(4),
                  onSubmit: _onPhase6Submit,
                  visibilityNotifier: _pageVisibilityNotifier,
                  pageIndex: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MerchantOnboardingSuccessScreen extends StatelessWidget {
  const MerchantOnboardingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.verified_rounded,
                  color: theme.territoryColor, size: 96),
              const SizedBox(height: 24),
              Text(
                'تم إرسال طلب الانضمام بنجاح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.font.extraLarge,
                  fontWeight: FontWeight.w700,
                  color: theme.textColorDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'سيقوم فريقنا بمراجعة بيانات متجرك، وستتلقى إشعاراً فور تفعيل الحساب.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.font.normal,
                  color: theme.textColorDark.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              UiUtils.buildButton(
                context,
                onPressed: () {
                  HelperUtils.killPreviousPages(
                    context,
                    Routes.main,
                    {'from': 'merchant_onboarding_success'},
                  );
                },
                buttonTitle: 'الانتقال إلى الرئيسية',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
