import 'dart:async';

import 'package:flutter/material.dart';
import 'phase1_activity_info.dart';
import 'phase2_categories_hours.dart';
import 'phase3_store_policy.dart';
import 'phase4_payment_methods.dart';
import 'phase5_store_credentials.dart';
import 'phase6_final_submission.dart';
import 'phase5_store_credentials.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';

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

  @override
  void initState() {
    super.initState();
    _currentPage =
        widget.initialPage.clamp(0, _totalPages - 1);
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
    _goToPage(1);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase2Next(Phase2Data data) {
    _goToPage(2);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase3Next(StorePolicyData data) {
    _goToPage(3);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase4Next(PaymentOptionsData data) {
    _goToPage(4);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  void _onPhase5Next(StoreCredentialsData data) {
    _goToPage(5);
    UiUtils.showSoftSnackBar(context,
        message: 'dataSavedStage'.translate(context));
  }

  Future<void> _onPhase6Submit() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await HiveUtils.clearMerchantOnboardingProgress();
    if (!mounted) return;
    UiUtils.showSoftSnackBar(
      context,
      message: 'submittedSuccess'.translate(context),
    );
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
