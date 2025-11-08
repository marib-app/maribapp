import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class StoreCredentialsData {
  final String username;
  final String password;

  StoreCredentialsData({
    required this.username,
    required this.password,
  });
}

class Phase5StoreCredentials extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(StoreCredentialsData data) onNext;

  const Phase5StoreCredentials({
    super.key,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<Phase5StoreCredentials> createState() =>
      _Phase5StoreCredentialsState();
}

class _Phase5StoreCredentialsState extends State<Phase5StoreCredentials>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _handleCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  static final RegExp _handlePattern = RegExp(r'^[a-zA-Z0-9._-]+$');
  static final RegExp _letters = RegExp(r'[A-Za-z]');
  static final RegExp _numbers = RegExp(r'[0-9]');
  static const Set<String> _reservedHandles = <String>{
    'admin',
    'support',
    'marib',
    'store',
    'demo',
  };

  Timer? _handleDebounce;
  bool _isReady = false;
  bool _checkingHandle = false;
  bool? _handleAvailable;
  bool _handleChecked = false;
  String? _handleMessage;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _handleCtrl.addListener(_onHandleChanged);
    _passwordCtrl.addListener(_refreshState);
    _confirmCtrl.addListener(_refreshState);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _isReady = true);
    });
  }

  @override
  void dispose() {
    _handleDebounce?.cancel();
    _handleCtrl.removeListener(_onHandleChanged);
    _passwordCtrl.removeListener(_refreshState);
    _confirmCtrl.removeListener(_refreshState);
    _handleCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _refreshState() {
    if (mounted) setState(() {});
  }

  void _onHandleChanged() {
    _handleDebounce?.cancel();
    setState(() {
      _handleAvailable = null;
      _handleMessage = null;
      _handleChecked = false;
    });

    final String current = _handleCtrl.text.trim();
    if (!_isHandleFormatValid(current)) {
      setState(() {});
      return;
    }

    _handleDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkHandleAvailability(current.toLowerCase());
    });
  }

  Future<void> _checkHandleAvailability(String handle) async {
    setState(() {
      _checkingHandle = true;
      _handleMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    final bool taken = _reservedHandles.contains(handle);

    if (!mounted) return;
    setState(() {
      _checkingHandle = false;
      _handleChecked = true;
      _handleAvailable = !taken;
      _handleMessage = taken
          ? 'ط§ظ„ظ…ط¹ط±ظپ ظ…ط³طھط®ط¯ظ… ط¨ط§ظ„ظپط¹ظ„طŒ ط¬ط±ظ‘ط¨ ط§ط³ظ…ط§ظ‹ ظ…ط®طھظ„ظپط§ظ‹.'
          : 'ط§ظ„ظ…ط¹ط±ظپ ظ…طھط§ط­طŒ ظˆط³ظٹظڈظ†ط´ط£ ط§ظ„ط¨ط±ظٹط¯ ${handle}@${Constant.storeStaffEmailDomain}.';
    });
  }

  bool _isHandleFormatValid(String handle) {
    if (handle.length < Constant.storeStaffEmailMinLength ||
        handle.length > Constant.storeStaffEmailMaxLength) {
      return false;
    }
    return _handlePattern.hasMatch(handle);
  }

  bool get _isPasswordValid {
    final String pwd = _passwordCtrl.text;
    if (pwd.length < 8) return false;
    return _letters.hasMatch(pwd) && _numbers.hasMatch(pwd);
  }

  bool get _passwordsMatch =>
      _passwordCtrl.text.isNotEmpty &&
      _passwordCtrl.text == _confirmCtrl.text;

  bool get _canProceed =>
      _isHandleFormatValid(_handleCtrl.text.trim()) &&
      _handleChecked &&
      (_handleAvailable ?? true) &&
      _isPasswordValid &&
      _passwordsMatch &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canProceed) {
      HelperUtils.showSnackBarMessage(
        context,
        'طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ظ…ط¹ط±ظ‘ظپ ظˆظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظ‚ط¨ظ„ ط§ظ„ظ…طھط§ط¨ط¹ط©.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final String username = _handleCtrl.text.trim().toLowerCase();
    widget.onNext(
      StoreCredentialsData(
        username: username,
        password: _passwordCtrl.text,
      ),
    );

    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.color;
    final Widget content = !_isReady
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBox(height: 26, width: 220),
              SizedBox(height: 10),
              ShimmerBox(height: 18, width: 280),
              SizedBox(height: 24),
              ShimmerBox(height: 64),
              SizedBox(height: 12),
              ShimmerBox(height: 64),
              SizedBox(height: 12),
              ShimmerBox(height: 64),
            ],
          )
        : Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ظ…ط¹ط±ظپ ط§ظ„ظ…طھط¬ط± ظˆظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
                  style: TextStyle(
                    fontSize: context.font.extraLarge,
                    fontWeight: FontWeight.w700,
                    color: colors.textColorDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ط³ظٹظڈط³طھط®ط¯ظ… ظ‡ط°ط§ ط§ظ„ط­ط³ط§ط¨ ظ„ظ„ط¯ط®ظˆظ„ ط¥ظ„ظ‰ ظ„ظˆط­ط© ط§ظ„طھط§ط¬ط± ط¹ظ„ظ‰ ط§ظ„ظˆظٹط¨. ط§ط®طھط± ظ…ط¹ط±ظپط§ظ‹ ظپط±ظٹط¯ط§ظ‹ ظˆظƒظ„ظ…ط© ظ…ط±ظˆط± ظ‚ظˆظٹط©.',
                  style: TextStyle(
                    fontSize: context.font.normal,
                    color: colors.textColorDark.withOpacity(0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                _buildHandleSection(),
                const SizedBox(height: 28),
                _buildPasswordSection(),
              ],
            ),
          );

    return WillPopScope(
      onWillPop: () async {
        widget.onBack();
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
            child: content,
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: UiUtils.buildButton(
              context,
              onPressed: _submit,
              buttonTitle: 'nextStage'.translate(context),
              disabled: !_isReady || !_canProceed,
              isInProgress: _submitting,
              autoManageState: false,
              autoDisableWhenInvalid: false,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHandleSection() {
    final theme = context.color;
    final String loginPreview = _handleCtrl.text.trim().isEmpty
        ? 'store@'
        : '@';

    final Color availabilityColor;
    if (_handleAvailable == true) {
      availabilityColor = Colors.green.shade600;
    } else if (_handleAvailable == false) {
      availabilityColor = Colors.red.shade600;
    } else {
      availabilityColor = theme.textColorDark.withOpacity(0.7);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.badge_rounded, color: theme.territoryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'اختيار معرف لوحة التاجر',
                style: TextStyle(
                  fontSize: context.font.large,
                  fontWeight: FontWeight.w600,
                  color: theme.textColorDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _handleCtrl,
          decoration: InputDecoration(
            labelText: 'معرف المتجر',
            hintText: 'مثال: marib.store',
            suffixText: '@',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (_checkingHandle)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_handleChecked)
              Icon(
                _handleAvailable == false
                    ? Icons.error_outline
                    : Icons.check_circle,
                size: 20,
                color: availabilityColor,
              )
            else
              Icon(Icons.info_outline, size: 20, color: availabilityColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _handleMessage ??
                    'يجب أن يكون المعرف بين ${Constant.storeStaffEmailMinLength} و ${Constant.storeStaffEmailMaxLength} رمزاً (أحرف إنجليزية، أرقام، - . _).',
                style: TextStyle(
                  fontSize: context.font.small,
                  color: availabilityColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'البريد الذي سيُستخدم في لوحة الويب',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.textColorDark,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                loginPreview,
                style: TextStyle(
                  fontSize: context.font.normal,
                  color: theme.territoryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ستستلم اعتماد القبول على هذا البريد عند الموافقة.',
                style: TextStyle(
                  fontSize: context.font.small,
                  color: theme.textColorDark.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildPasswordSection() {
    final theme = context.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_rounded, color: theme.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'طھط¹ظٹظٹظ† ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
                style: TextStyle(
                  fontSize: context.font.large,
                  fontWeight: FontWeight.w600,
                  color: theme.textColorDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
            hintText: 'ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„ 8 ط±ظ…ظˆط² ظ…ط¹ ط£ط±ظ‚ط§ظ… ظˆط­ط±ظˆظپ',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'طھط£ظƒظٹط¯ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildPasswordChecklist(),
      ],
    );
  }

  Widget _buildPasswordChecklist() {
    final theme = context.color;
    final List<_ChecklistItem> items = [
      _ChecklistItem(
        fulfilled: _passwordCtrl.text.length >= 8,
        label: '8 ط±ظ…ظˆط² ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„.',
      ),
      _ChecklistItem(
        fulfilled: _letters.hasMatch(_passwordCtrl.text),
        label: 'طھط­طھظˆظٹ ط¹ظ„ظ‰ ط­ط±ظپ ظˆط§ط­ط¯ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„.',
      ),
      _ChecklistItem(
        fulfilled: _numbers.hasMatch(_passwordCtrl.text),
        label: 'طھط­طھظˆظٹ ط¹ظ„ظ‰ ط±ظ‚ظ… ظˆط§ط­ط¯ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„.',
      ),
      _ChecklistItem(
        fulfilled: _passwordsMatch && _confirmCtrl.text.isNotEmpty,
        label: 'طھط·ط§ط¨ظ‚ ط¨ظٹظ† ط§ظ„ط­ظ‚ظ„ظٹظ†.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                item.fulfilled ? Icons.check_circle : Icons.radio_button_unchecked,
                color: item.fulfilled
                    ? Colors.green.shade600
                    : theme.textColorDark.withOpacity(0.4),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: context.font.small,
                  color: item.fulfilled
                      ? theme.textColorDark
                      : theme.textColorDark.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ChecklistItem {
  final bool fulfilled;
  final String label;

  const _ChecklistItem({
    required this.fulfilled,
    required this.label,
  });
}


