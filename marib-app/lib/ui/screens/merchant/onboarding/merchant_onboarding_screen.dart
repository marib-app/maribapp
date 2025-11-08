import 'package:flutter/material.dart';
import 'phase1_activity_info.dart';
import 'phase2_categories_hours.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class MerchantOnboardingScreen extends StatefulWidget {
  const MerchantOnboardingScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const MerchantOnboardingScreen());
  }

  @override
  State<MerchantOnboardingScreen> createState() => _MerchantOnboardingScreenState();
}

class _MerchantOnboardingScreenState extends State<MerchantOnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  void _goToPage(int next) {
    if (next < 0 || next >= _totalPages) return;
    setState(() {
      _currentPage = next;
    });
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 400), curve: Curves.ease);
  }

  void _onPhase1Next(ActivityInfoData data) {
    _goToPage(1);
    UiUtils.showSoftSnackBar(context, message: 'dataSavedStage'.translate(context));
  }

  void _onPhase2Next(Phase2Data data) {
    _goToPage(2);
    UiUtils.showSoftSnackBar(context, message: 'dataSavedStage'.translate(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gutters = context.color;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: context.color.textDefaultColor),
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
                ),
                Center(child: Text('phase3_pending'.translate(context))),
                Center(child: Text('phase4_pending'.translate(context))),
                Center(child: Text('phase5_pending'.translate(context))),
                Center(child: Text('phase6_pending'.translate(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
