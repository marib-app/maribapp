import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

import 'merchant_location_picker_screen.dart';

class ActivityInfoData {
  final String storeName;
  final String description;
  final String address;
  final double? latitude;
  final double? longitude;
  final File? logo;
  final File? cover;

  ActivityInfoData({
    required this.storeName,
    required this.description,
    required this.address,
    required this.longitude,
    required this.latitude,
    required this.logo,
    required this.cover,
  });
}

class Phase1ActivityInfo extends StatefulWidget {
  final void Function(ActivityInfoData data) onNext;

  const Phase1ActivityInfo({super.key, required this.onNext});

  @override
  State<Phase1ActivityInfo> createState() => _Phase1ActivityInfoState();
}

class _Phase1ActivityInfoState extends State<Phase1ActivityInfo>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _storeNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _isReady = false;
  bool _locationLoading = false;
  bool _logoPicking = false;
  bool _coverPicking = false;
  bool _submitting = false;
  bool _canProceed = false;

  File? _logoFile;
  File? _coverFile;
  double? _latitude;
  double? _longitude;

  Timer? _logoSuccessTimer;
  Timer? _coverSuccessTimer;
  bool _logoSuccessVisible = false;
  bool _coverSuccessVisible = false;

  bool get _hasLocation => _latitude != null && _longitude != null;
  bool get _hasLogo => _logoFile != null;
  bool get _hasCover => _coverFile != null;

  Future<void> _prepare() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isReady = true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
    _storeNameCtrl.addListener(_recomputeValidity);
    _descriptionCtrl.addListener(_recomputeValidity);
    _addressCtrl.addListener(_recomputeValidity);
  }

  @override
  void dispose() {
    _logoSuccessTimer?.cancel();
    _coverSuccessTimer?.cancel();
    _storeNameCtrl.removeListener(_recomputeValidity);
    _descriptionCtrl.removeListener(_recomputeValidity);
    _addressCtrl.removeListener(_recomputeValidity);
    _storeNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _recomputeValidity() {
    final bool ready = _storeNameCtrl.text.trim().isNotEmpty &&
        _descriptionCtrl.text.trim().isNotEmpty &&
        _hasLocation &&
        _hasLogo &&
        _hasCover;
    if (ready != _canProceed) {
      setState(() => _canProceed = ready);
    }
  }

  void _scheduleLogoSuccessHide() {
    _logoSuccessTimer?.cancel();
    _logoSuccessTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _logoSuccessVisible = false);
    });
  }

  void _scheduleCoverSuccessHide() {
    _coverSuccessTimer?.cancel();
    _coverSuccessTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _coverSuccessVisible = false);
    });
  }

  Future<void> _pickLogo() async {
    setState(() => _logoPicking = true);
    try {
      final XFile? selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (selected != null) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        setState(() {
          _logoFile = File(selected.path);
          _logoSuccessVisible = true;
        });
        _scheduleLogoSuccessHide();
        _recomputeValidity();
      }
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        "تعذر تحميل الشعار، حاول مرة أخرى.",
        messageDuration: 3,
      );
    } finally {
      if (mounted) setState(() => _logoPicking = false);
    }
  }

  Future<void> _pickCover() async {
    setState(() => _coverPicking = true);
    try {
      final XFile? selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (selected != null) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        setState(() {
          _coverFile = File(selected.path);
          _coverSuccessVisible = true;
        });
        _scheduleCoverSuccessHide();
        _recomputeValidity();
      }
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        "تعذر تحميل الغلاف، حاول مرة أخرى.",
        messageDuration: 3,
      );
    } finally {
      if (mounted) setState(() => _coverPicking = false);
    }
  }

  Future<void> _openLocationPicker() async {
    setState(() => _locationLoading = true);
    try {
      final result =
          await Navigator.of(context).push<MerchantLocationPickerResult>(
        MaterialPageRoute(
          builder: (_) => MerchantLocationPickerScreen(
            initialPosition: (_latitude != null && _longitude != null)
                ? LatLng(_latitude!, _longitude!)
                : null,
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _latitude = result.latitude;
          _longitude = result.longitude;
          // العنوان المدخل يدويًا مستقل عن موقع الخريطة؛ نملأه فقط إن كان فارغًا لمساعدة المستخدم.
          if ((_addressCtrl.text).trim().isEmpty && (result.address?.isNotEmpty ?? false)) {
            _addressCtrl.text = result.address!;
          }
        });
        _recomputeValidity();
      }
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        "errorGettingLocation".translate(context),
        messageDuration: 3,
      );
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _onNext() async {
    if (_submitting || !_canProceed) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_hasLocation) {
      HelperUtils.showSnackBarMessage(
        context,
        "يرجى تحديد موقع المتجر على الخريطة.",
        messageDuration: 3,
      );
      return;
    }
    if (!_hasLogo) {
      HelperUtils.showSnackBarMessage(
        context,
        "يرجى اختيار شعار المتجر.",
        messageDuration: 3,
      );
      return;
    }
    if (!_hasCover) {
      HelperUtils.showSnackBarMessage(
        context,
        "يرجى اختيار غلاف المتجر.",
        messageDuration: 3,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      widget.onNext(ActivityInfoData(
        storeName: _storeNameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        logo: _logoFile,
        cover: _coverFile,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            ShimmerBox(height: 22, width: 160),
            SizedBox(height: 12),
            ShimmerBox(height: 18, width: 220),
            SizedBox(height: 24),
            ShimmerBox(height: 48),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 140)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(height: 140)),
              ],
            ),
            SizedBox(height: 16),
            ShimmerBox(height: 100),
            SizedBox(height: 16),
            ShimmerBox(height: 48, width: 200),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: UiUtils.buildButton(
            context,
            onPressed: () async {},
            buttonTitle: "nextStage".translate(context),
            disabled: true,
            autoManageState: false,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = context.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: context.font.large,
            fontWeight: FontWeight.w700,
            color: theme.textColorDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: context.font.normal,
            color: theme.textColorDark.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context,
      {required String title, required String subtitle}) {
    final theme = context.color;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt_outlined,
            size: 36, color: theme.textColorDark.withOpacity(0.4)),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: theme.textColorDark.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: theme.textColorDark.withOpacity(0.6),
            fontSize: context.font.small,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLogoPicker(BuildContext context) {
    final theme = context.color;
    final hasLogo = _logoFile != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "شعار المتجر (1:1)",
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.textColorDark,
              fontSize: context.font.normal),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _logoPicking ? null : _pickLogo,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.territoryColor),
              color: theme.secondaryColor,
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: hasLogo
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_logoFile!, fit: BoxFit.cover),
                    )
                  : _buildPlaceholder(
                      context,
                      title: "تحميل شعار المتجر",
                      subtitle: "jpg, png, jpeg, gif بحد أقصى 2 ميجابايت",
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPicker(BuildContext context) {
    final theme = context.color;
    final hasCover = _coverFile != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "غلاف المتجر (3:1)",
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.textColorDark,
              fontSize: context.font.normal),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _coverPicking ? null : _pickCover,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.territoryColor),
              color: theme.secondaryColor,
            ),
            child: AspectRatio(
              aspectRatio: 3 / 1,
              child: hasCover
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_coverFile!, fit: BoxFit.cover),
                    )
                  : _buildPlaceholder(
                      context,
                      title: "تحميل غلاف المتجر",
                      subtitle: "jpg, png, jpeg, gif بحد أقصى 2 ميجابايت",
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationNotice(BuildContext context) {
    final theme = context.color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.territoryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.territoryColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.territoryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "حدد موقع المتجر بدقة على الخريطة لتسهيل الوصول والتوصيل.",
              style: TextStyle(
                color: theme.textColorDark.withOpacity(0.8),
                fontSize: context.font.small,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_isReady) {
      return _buildLoadingSkeleton(context);
    }

    final theme = context.color;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _buildSectionHeader(
                context,
                title: "بيانات المتجر الأساسية",
                subtitle:
                    "أدخل اسم المتجر والوصف وصور الهوية ليظهر متجرك بالشكل الصحيح للعملاء.",
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _storeNameCtrl,
                decoration: InputDecoration(
                  labelText: "storeName".translate(context),
                  hintText: "storeNameHint".translate(context),
                  helperText:
                      "يفضل اسم واضح يطابق السجل التجاري وسيظهر للمتسوقين.",
                  fillColor: theme.secondaryColor,
                  filled: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "requiredField".translate(context);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(flex: 2, child: _buildCoverPicker(context)),
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: _buildLogoPicker(context)),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionCtrl,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: "storeDescription".translate(context),
                  hintText: "brieflyDescribeYourStore".translate(context),
                  helperText: "وصف مختصر عن نشاط المتجر وخدماته وما يميزه.",
                  fillColor: theme.secondaryColor,
                  filled: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "requiredField".translate(context);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildLocationNotice(context),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _hasLocation
                    ? Container(
                        key: const ValueKey('location_summary'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "الموقع المختار",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.textColorDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${_latitude?.toStringAsFixed(5)}, ${_longitude?.toStringAsFixed(5)}",
                              style: TextStyle(
                                fontSize: context.font.normal,
                                color: theme.textColorDark.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "storeAddress".translate(context),
                  hintText: "اكتب عنوان المتجر (المدينة، الحي، الشارع)",
                  helperText:
                      "اختياري: أضف تفاصيل العنوان النصي بجانب الموقع على الخريطة.",
                  fillColor: theme.secondaryColor,
                  filled: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _locationLoading ? null : _openLocationPicker,
                icon: _locationLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.map_outlined, color: theme.textDefaultColor),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    "تحديد موقع المتجر على الخريطة",
                    style: TextStyle(
                      color: theme.textDefaultColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.territoryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
            onPressed: _onNext,
            buttonTitle: "nextStage".translate(context),
            radius: 16,
            height: 50,
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
