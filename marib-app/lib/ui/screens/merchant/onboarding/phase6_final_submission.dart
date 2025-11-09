import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/profile_setting_cubit.dart';
import 'package:marib/ui/screens/classified_ads/app_html.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';

class Phase6FinalSubmission extends StatefulWidget {
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;
  final ValueNotifier<int> visibilityNotifier;
  final int pageIndex;

  const Phase6FinalSubmission({
    super.key,
    required this.onBack,
    required this.onSubmit,
    required this.visibilityNotifier,
    required this.pageIndex,
  });

  @override
  State<Phase6FinalSubmission> createState() => _Phase6FinalSubmissionState();
}

class _Phase6FinalSubmissionState extends State<Phase6FinalSubmission>
    with AutomaticKeepAliveClientMixin {
  late final ProfileSettingCubit _profileCubit;
  bool _agreed = false;
  bool _submitting = false;
  bool _refreshQueued = false;
  late final VoidCallback _visibilityListener;
  String _currentParam = Api.storeTermsConditions;
  bool _requestedFallback = false;

  @override
  void initState() {
    super.initState();
    _profileCubit = ProfileSettingCubit();
    _visibilityListener = _handleVisibilityChanged;
    widget.visibilityNotifier.addListener(_visibilityListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleVisibilityChanged());
  }

  @override
  void dispose() {
    widget.visibilityNotifier.removeListener(_visibilityListener);
    _profileCubit.close();
    super.dispose();
  }

  void _handleVisibilityChanged() {
    if (widget.visibilityNotifier.value == widget.pageIndex) {
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshQueued = false;
      _requestedFallback = false;
      _fetchTerms(Api.storeTermsConditions);
    });
  }

  void _fetchTerms(String param) {
    _currentParam = param;
    _profileCubit.fetchProfileSetting(
      context,
      param,
      forceRefresh: true,
    );
  }

  Future<void> _handleSubmit() async {
    if (!_agreed || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WillPopScope(
      onWillPop: () async {
        widget.onBack();
        return false;
      },
      child: BlocProvider<ProfileSettingCubit>.value(
        value: _profileCubit,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المراجعة النهائية والإرسال',
                    style: TextStyle(
                      fontSize: context.font.extraLarge,
                      fontWeight: FontWeight.w700,
                      color: context.color.textColorDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'راجع شروط الانضمام وأكّد موافقتك قبل إرسال طلبك لمراجعة الفريق. يمكنك الرجوع للخطوات السابقة إذا رغبت بتعديل أي معلومة.',
                    style: TextStyle(
                      fontSize: context.font.normal,
                      color: context.color.textColorDark.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTermsCard(),
                  const SizedBox(height: 24),
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: (value) =>
                        setState(() => _agreed = value ?? false),
                    title: Text(
                      'أقرّ بأنني قرأت جميع الشروط وأوافق على الالتزام بها، وأتحمل مسؤولية صحة البيانات التي قمت بتعبئتها.',
                      style: TextStyle(
                        color: context.color.textColorDark,
                        height: 1.3,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
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
                onPressed: _handleSubmit,
                buttonTitle: 'submitBtnLbl'.translate(context),
                disabled: !_agreed || _submitting,
                isInProgress: _submitting,
                autoManageState: false,
                autoDisableWhenInvalid: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCard() {
    return BlocBuilder<ProfileSettingCubit, ProfileSettingState>(
      builder: (context, state) {
        if (state is ProfileSettingFetchProgress ||
            state is ProfileSettingInitial) {
          return _TermsPlaceholder();
        }
        if (state is ProfileSettingFetchFailure) {
          return _TermsError(
            message: state.errmsg,
            onRetry: () => _profileCubit.fetchProfileSetting(
              context,
              _currentParam,
              forceRefresh: true,
            ),
          );
        }
        if (state is ProfileSettingFetchSuccess) {
          final String content = state.data;
          if (content.trim().isEmpty &&
              !_requestedFallback &&
              _currentParam == Api.storeTermsConditions) {
            _requestedFallback = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _fetchTerms(Api.termsAndConditions),
            );
            return _TermsPlaceholder();
          }
          if (content.trim().isEmpty) {
            return _TermsError(
              message: 'لا تتوفر شروط حالياً. يرجى المحاولة لاحقاً.',
              onRetry: () => _profileCubit.fetchProfileSetting(
                context,
                _currentParam,
                forceRefresh: true,
              ),
            );
          }
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.color.borderColor),
              color: context.color.secondaryColor,
            ),
            child: AppHtml(
              data: content,
              baseUrl: null,
              centerContent: false,
              preserveInlineStyles: true,
              selectable: true,
              outerPadding: EdgeInsets.zero,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _TermsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor),
        color: context.color.secondaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(height: 18, width: 180),
          SizedBox(height: 8),
          ShimmerBox(height: 14),
          SizedBox(height: 6),
          ShimmerBox(height: 14),
          SizedBox(height: 6),
          ShimmerBox(height: 14),
        ],
      ),
    );
  }
}

class _TermsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TermsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor),
        color: context.color.secondaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعذر تحميل الشروط',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.color.textColorDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: context.font.small,
              color: context.color.textColorDark.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
