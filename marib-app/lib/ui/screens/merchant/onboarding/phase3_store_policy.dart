import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class StorePolicyData {
  final String policy;
  final bool agreeToTerms;

  StorePolicyData({
    required this.policy,
    required this.agreeToTerms,
  });
}

class Phase3StorePolicy extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(StorePolicyData data) onNext;

  const Phase3StorePolicy({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<Phase3StorePolicy> createState() => _Phase3StorePolicyState();
}

class _Phase3StorePolicyState extends State<Phase3StorePolicy>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _policyCtrl = TextEditingController();

  bool _isReady = false;
  bool _agree = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _policyCtrl.addListener(_recomputeValidity);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        setState(() => _isReady = true);
      }
    });
  }

  @override
  void dispose() {
    _policyCtrl.removeListener(_recomputeValidity);
    _policyCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed => _policyCtrl.text.trim().length >= 30 && _agree;

  void _recomputeValidity() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleNext() async {
    if (_submitting || !_canProceed) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    widget.onNext(
      StorePolicyData(
        policy: _policyCtrl.text.trim(),
        agreeToTerms: _agree,
      ),
    );
    if (mounted) {
      setState(() => _submitting = false);
    }
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
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: UiUtils.buildButton(
              context,
              onPressed: () {},
              buttonTitle: 'nextStage'.translate(context),
              disabled: true,
              autoManageState: false,
            ),
          ),
        ),
      );
    }

    final theme = context.color;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سياسات المتجر',
                  style: TextStyle(
                    fontSize: context.font.extraLarge,
                    fontWeight: FontWeight.w700,
                    color: theme.textColorDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اكتب سياسة الاسترجاع والتبديل الخاصة بمتجرك. سيشاهدها العملاء قبل الدفع لزيادة الثقة.',
                  style: TextStyle(
                    fontSize: context.font.normal,
                    color: theme.textColorDark.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'سياسة الاسترجاع والتبديل',
                  style: TextStyle(
                    fontSize: context.font.large,
                    fontWeight: FontWeight.w600,
                    color: theme.textColorDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اشرح الخطوات، المدد الزمنية والشروط الخاصة بمتجرك. هذه السياسة تظهر للعميل قبل الدفع.',
                  style: TextStyle(
                    fontSize: context.font.small,
                    color: theme.textColorDark.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _policyCtrl,
                  minLines: 6,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText:
                        'مثال: يمكن الاسترجاع خلال 7 أيام مع إبراز الفاتورة الأصلية...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: theme.secondaryColor.withOpacity(0.4),
                    helperText: 'يُفضل أن لا تقل السياسة عن 30 كلمة.',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 30) {
                      return 'يرجى كتابة سياسة أوضح (30 حرفاً على الأقل).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _agree,
                  onChanged: (value) => setState(() => _agree = value ?? false),
                  title: Text(
                    'أقر بأن هذه السياسة أصلية وتعبّر عن التزامات متجري.',
                    style: TextStyle(color: theme.textColorDark),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
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
            disabled: !_canProceed,
            isInProgress: _submitting,
            autoManageState: false,
            autoDisableWhenInvalid: false,
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}



