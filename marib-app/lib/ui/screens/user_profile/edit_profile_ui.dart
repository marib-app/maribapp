// lib/ui/screens/user_profile/edit_profile_ui.dart
// ظˆط§ط¬ظ‡ط© ط§ظ„ظ…ط³طھط®ط¯ظ… ظپظ‚ط· â€” طھظپط§ط¹ظ„ظٹط© + ط´ظٹظ…ط± + طھط­ظ…ظٹظ„ ظƒط³ظˆظ„.
// ظ…ظ‡ظ…: ظ…ظ„ظپ ط§ظ„ظ…ظ†ط·ظ‚ ظٹط¬ط¨ ط£ظ† ظٹط­طھظˆظٹ: part 'edit_profile_ui.dart';

part of 'edit_profile.dart';

/// ظٹط¨ظ†ظٹ ظˆط§ط¬ظ‡ط© ط´ط§ط´ط© ط§ظ„ظ…ظ„ظپ ط§ظ„ط´ط®طµظٹ ظƒط§ظ…ظ„ط©.
/// ظ…ظ„ط§ط­ط¸ط§طھ ط§ظ„طھظƒط§ظ…ظ„:
/// - isLazyLoading: ظ…ظ† ط§ظ„ظ…ظ†ط·ظ‚ (true ط£ط«ظ†ط§ط، ط§ظ„ط¬ظ„ط¨ ط§ظ„ظƒط³ظˆظ„طŒ false ط¨ط¹ط¯ظ‡)
/// - onStartLazyLoad: ظƒظˆظ„ط¨ط§ظƒ ظٹظڈط³طھط¯ط¹ظ‰ طھظ„ظ‚ط§ط¦ظٹظ‹ط§ ط£ظˆظ„ ظ…ط§ ط§ظ„ط´ط§ط´ط© طھظڈط¹ط±ط¶ ظ„ط¨ط¯ط، ط§ظ„ط¬ظ„ط¨
Widget buildUserProfileScreenUI(
    {
    // ط³ظٹط§ظ‚ ظˆط­ط§ظ„ط©
    required BuildContext context,
    required UserProfileScreenState state,

    // ظ…ظپط§طھظٹط­/ط­ط§ظ„ط© ط¹ط§ظ…ط©
    required GlobalKey<FormState> formKey,
    required bool? isLoading,
    required bool isNotificationsEnabled,
    required bool isPersonalDetailShow,
    required String? countryCode,
    required int? userType,

    // Controllers ط§ظ„ط£ط³ط§ط³ظٹط©
    required TextEditingController phoneController,
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController addressController,

    // Controllers ط¥ط¶ط§ظپظٹط© (طھط¬ط§ط±ظٹ/ط¹ظ‚ط§ط±ظٹ)
    required TextEditingController businessNameController,
    required TextEditingController businessLocationController,
    required TextEditingController businessPhoneController,
    required TextEditingController businessWhatsappController,
    required TextEditingController officeNameController,
    required TextEditingController officeLocationController,
    required TextEditingController officePhoneController,
    required TextEditingController officeWhatsappController,

    // ظ…ظ„ظپط§طھ/طµظˆط±
    required File? fileUserimg,
    required File? businessLogoImage,
    required String? existingBusinessLogoUrl,
    required String? existingCommercialRegisterUrl,
    required File? commercialRegisterFile,

    // ط£ظˆظ‚ط§طھ ط§ظ„ط¹ظ…ظ„
    required TimeOfDay? openingTime,
    required TimeOfDay? closingTime,

    // ط§ظ„ظ…ظˆظ‚ط¹
    required dynamic city,
    required dynamic stateName,
    required dynamic country,
    required double? latitude,
    required double? longitude,

    // ط±ط¯ظˆط¯ ط§ظ„ط£ظپط¹ط§ظ„ (Callbacks)
    required VoidCallback onSubmit,
    required VoidCallback onShowPicker,
    required VoidCallback onSelectCountryCode,
    required void Function(bool isOffice) onPickLogoImage,
    required VoidCallback onPickCommercialRegister,
    required Future<void> Function(bool isOpening) onSelectTime,
    required ValueChanged<bool> onToggleNotifications,
    required ValueChanged<bool> onTogglePersonalDetail,
    required ValueChanged<String?> setCountryCode,

    // ط­ط§ظ„ط§طھ ط£ط®ط±ظ‰
    required bool setPhoneReadOnly,

    // *** ط¬ط¯ظٹط¯: طھط­ظ…ظٹظ„ ظƒط³ظˆظ„ + ط´ظٹظ…ط± ***
    required bool isLazyLoading, // â†گ ط­ط§ظ„ط© ط§ظ„طھط­ظ…ظٹظ„ ط§ظ„ظƒط³ظˆظ„
    required VoidCallback
        onStartLazyLoad // â†گ ظٹط¨ط¯ط£ ظ„ظ…ط§ ط§ظ„ط´ط§ط´ط© طھظپطھط­
    }) {
  final UserModel _user = HiveUtils.getUserDetails();
  final String locationLabel = _compactLocation(city, stateName, country);
  final String walletLabel = _extractWalletBalance(_user);
  final String defaultCartLabel = _extractDefaultCartLabel(_user);
  return _safeAreaCondition(
    from: state.widget.from,
    child: Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: state.widget.from == "login"
          ? null
          : UiUtils.buildAppBar(context, showBackButton: true),

      // â¬‡ï¸ڈ ط²ط± "طھط­ط¯ظٹط« ط§ظ„ظ…ظ„ظپ ط§ظ„ط´ط®طµظٹ" ط«ط§ط¨طھ ط¨ط£ط³ظپظ„ ط§ظ„ط´ط§ط´ط©
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _Pressable(
            onTap: () {
              if (isLoading == true) return;
              onSubmit();
            },
            child: UiUtils.buildButton(
              context,
              onPressed: isLoading == true || isLazyLoading ? () {} : onSubmit,
              height: 48.rh(context),
              buttonTitle: "updateProfile".translate(context),
            ),
          ),
        ),
      ),

      body: _LazyInit(
        onInit:
            onStartLazyLoad, // â†گ ظٹط¨ط¯ط£ ط§ظ„ط¬ظ„ط¨ ظپظˆط± ظپطھط­ ط§ظ„ظˆط§ط¬ظ‡ط© ط¨ط¹ط¯ ط£ظˆظ„ ظپط±ظٹظ…
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: RemoveGlow(),
              child: SingleChildScrollView(
                physics: AppScrollBehavior.defaultPhysics,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // â€”â€”â€” طµظˆط±ط© ط§ظ„ظ…ظ„ظپ ط§ظ„ط´ط®طµظٹ
                        _Appear(
                          delayMs: 0,
                          child: isLazyLoading
                              ? const _HeroHeaderShimmer()
                              : _HeroHeader(
                                  state: state,
                                  fileUserimg: fileUserimg,
                                  onShowPicker: onShowPicker,
                                  locationLabel: locationLabel,
                                  name: nameController.text.isNotEmpty
                                      ? nameController.text
                                      : (_user.name ?? ""),
                                  email: emailController.text.isNotEmpty
                                      ? emailController.text
                                      : (_user.email ?? ""),
                                  phone: phoneController.text.isNotEmpty
                                      ? phoneController.text
                                      : (_user.mobile ?? ""),
                                ),
                        ),

                        const SizedBox(height: 12),
                        _Appear(
                          delayMs: 60,
                          child: isLazyLoading
                              ? const _InfoGridShimmer()
                              : _InfoGrid(
                                  location: locationLabel,
                                  wallet: walletLabel,
                                  defaultCart: defaultCartLabel,
                                ),
                        ),

                        const SizedBox(height: 18),
                        _Appear(
                          delayMs: 90,
                          child: _sectionHeader(
                            context,
                            title: "basicInformation".translate(context),
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 10),

                        _Appear(
                          delayMs: 110,
                          child: _SectionCard(
                            child: isLazyLoading
                                ? const _BasicSectionShimmer()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      buildTextField(
                                        context,
                                        title: "fullName",
                                        controller: nameController,
                                        validator:
                                            CustomTextFieldValidator.nullCheck,
                                      ),
                                      buildTextField(
                                        context,
                                        readOnly:
                                            HiveUtils.getUserDetails().type ==
                                                        AuthenticationType
                                                            .email.name ||
                                                    HiveUtils.getUserDetails()
                                                            .type ==
                                                        AuthenticationType
                                                            .google.name ||
                                                    HiveUtils.getUserDetails()
                                                            .type ==
                                                        AuthenticationType
                                                            .apple.name
                                                ? true
                                                : false,
                                        title: "emailAddress",
                                        controller: emailController,
                                      ),
                                      phoneWidget(
                                        context: context,
                                        state: state,
                                        phoneController: phoneController,
                                        setPhoneReadOnly: setPhoneReadOnly,
                                        countryCode: countryCode,
                                        onSelectCountryCode:
                                            onSelectCountryCode,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        _Appear(
                          delayMs: 140,
                          child: _sectionHeader(
                            context,
                            title: "privacyAndNotifications".translate(context),
                            icon: Icons.shield_outlined,
                          ),
                        ),
                        const SizedBox(height: 10),

                        _Appear(
                          delayMs: 170,
                          child: _SectionCard(
                            child: isLazyLoading
                                ? const _SwitchesShimmer()
                                : Column(
                                    children: [
                                      _SettingTileSwitch(
                                        title:
                                            "notification".translate(context),
                                        subtitle: "enableOrDisableNotifications"
                                            .translate(context),
                                        value: isNotificationsEnabled,
                                        onChanged: (v) {
                                          HapticFeedback.lightImpact();
                                          onToggleNotifications(v);
                                        },
                                        context: context,
                                      ),
                                      const SizedBox(height: 8),
                                      _SettingTileSwitch(
                                        title: "personalDetails"
                                            .translate(context),
                                        subtitle: "hideContactFromAds"
                                            .translate(context),
                                        value: isPersonalDetailShow,
                                        onChanged: (v) {
                                          HapticFeedback.lightImpact();
                                          onTogglePersonalDetail(v);
                                        },
                                        context: context,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 22),
                        _Appear(delayMs: 210, child: _sectionDivider(context)),

                        // â€”â€”â€” ط§ظ„ط­ط³ط§ط¨ط§طھ ط§ظ„ط¹ظ‚ط§ط±ظٹط©
                        if (userType == 2) ...[
                          const SizedBox(height: 22),
                          _Appear(
                            delayMs: 280,
                            child: _sectionHeader(
                              context,
                              title:
                                  "realEstateAccountDetails".translate(context),
                              icon: Icons.apartment_outlined,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (isLazyLoading)
                            _Appear(
                              delayMs: 320,
                              child: const _SectionCard(
                                child: _RealEstateSectionShimmer(),
                              ),
                            )
                          else
                            _Appear(
                              delayMs: 320,
                              child: _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fieldLabel(context, "officeLogo"),
                                    const SizedBox(height: 8),
                                    _buildLogoSelector(
                                      context: context,
                                      isOffice: true,
                                      businessLogoImage: businessLogoImage,
                                      existingBusinessLogoUrl:
                                          existingBusinessLogoUrl,
                                      onPickLogoImage: onPickLogoImage,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "officeName",
                                      controller: officeNameController,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "officeLocation",
                                      controller: officeLocationController,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "officePhone",
                                      controller: officePhoneController,
                                      validator:
                                          CustomTextFieldValidator.phoneNumber,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "officeWhatsapp",
                                      controller: officeWhatsappController,
                                      validator:
                                          CustomTextFieldValidator.phoneNumber,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],

                        // â€”â€”â€” ط§ظ„ط­ط³ط§ط¨ط§طھ ط§ظ„طھط¬ط§ط±ظٹط©
                        if (userType == 3) ...[
                          const SizedBox(height: 22),
                          _Appear(
                            delayMs: 280,
                            child: _sectionHeader(
                              context,
                              title:
                                  "commercialAccountDetails".translate(context),
                              icon: Icons.storefront_outlined,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (isLazyLoading)
                            _Appear(
                              delayMs: 320,
                              child: const _SectionCard(
                                child: _BusinessSectionShimmer(),
                              ),
                            )
                          else
                            _Appear(
                              delayMs: 320,
                              child: _SectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fieldLabel(context, "businessLogo"),
                                    const SizedBox(height: 8),
                                    _buildLogoSelector(
                                      context: context,
                                      isOffice: false,
                                      businessLogoImage: businessLogoImage,
                                      existingBusinessLogoUrl:
                                          existingBusinessLogoUrl,
                                      onPickLogoImage: onPickLogoImage,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "businessName",
                                      controller: businessNameController,
                                      validator:
                                          CustomTextFieldValidator.nullCheck,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "businessLocation",
                                      controller: businessLocationController,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "businessPhone",
                                      controller: businessPhoneController,
                                      validator:
                                          CustomTextFieldValidator.phoneNumber,
                                    ),
                                    buildTextField(
                                      context,
                                      title: "businessWhatsapp",
                                      controller: businessWhatsappController,
                                      validator:
                                          CustomTextFieldValidator.phoneNumber,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildWorkingHours(
                                      context: context,
                                      openingTime: openingTime,
                                      closingTime: closingTime,
                                      onSelectTime: onSelectTime,
                                    ),
                                    const SizedBox(height: 12),
                                    _fieldLabel(context, "commercialRegister"),
                                    const SizedBox(height: 8),
                                    _buildCommercialRegisterUpload(
                                      context: context,
                                      commercialRegisterFile:
                                          commercialRegisterFile,
                                      existingCommercialRegisterUrl:
                                          existingCommercialRegisterUrl,
                                      onPickCommercialRegister:
                                          onPickCommercialRegister,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],

                        // â¬‡ï¸ڈ ظ…ط³ط§ظپط© ط³ظپظ„ظٹط© ظƒط§ظپظٹط© ط­طھظ‰ ظ„ط§ ظٹطھط؛ط·ظ‘ظ‰ ط§ظ„ظ…ط­طھظˆظ‰ ط®ظ„ظپ ط§ظ„ط´ط±ظٹط· ط§ظ„ط³ظپظ„ظٹ
                        const SizedBox(height: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // â€”â€”â€” ظ…ط¤ط´ط± ط§ظ„طھط­ظ…ظٹظ„ ط¹ظ†ط¯ ط§ظ„ط­ظپط¸
            _LoadingOverlay(visible: isLoading == true),
          ],
        ),
      ),
    ),
  );
}

/// â€”â€”â€”â€”â€”â€” طھط­ظ…ظٹظ„ ظƒط³ظˆظ„: ظٹظ†ظپظ‘ط° onInit ط¨ط¹ط¯ ط£ظˆظ„ ط¨ظ†ط§ط، â€”â€”â€”â€”â€”â€”
class _LazyInit extends StatefulWidget {
  final Widget child;
  final VoidCallback onInit;
  const _LazyInit({required this.child, required this.onInit});

  @override
  State<_LazyInit> createState() => _LazyInitState();
}

class _LazyInitState extends State<_LazyInit> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // ط¨ط¹ط¯ ط£ظˆظ„ ظپط±ظٹظ…: ط´ط؛ظ‘ظ„ ط¬ظ„ط¨ ط§ظ„ط¨ظٹط§ظ†ط§طھ ط§ظ„ظƒط³ظˆظ„ ظ…ط±ظ‘ط© ظˆط§ط­ط¯ط©
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_done) {
        _done = true;
        widget.onInit();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// â€”â€”â€”â€”â€”â€” ط´ظٹظ…ط± ط¹ط§ظ… â€”â€”â€”â€”â€”â€”
class _Shimmer extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? radius;
  const _Shimmer({required this.height, this.width, this.radius});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.color.secondaryColor;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            borderRadius: widget.radius ?? BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment(-1, 0),
              end: Alignment(2, 0),
              colors: [
                base.withOpacity(.6),
                base.withOpacity(.9),
                base.withOpacity(.6),
              ],
              stops: [
                (_c.value - .3).clamp(0.0, 1.0),
                _c.value,
                (_c.value + .3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// â€”â€”â€”â€”â€”â€” ط´ظٹظ…ط±ط§طھ ط¬ط§ظ‡ط²ط© ظ„ظ„ط£ظ‚ط³ط§ظ… â€”â€”â€”â€”â€”â€”
class _BasicSectionShimmer extends StatelessWidget {
  const _BasicSectionShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 110),
      ],
    );
  }
}

class _SwitchesShimmer extends StatelessWidget {
  const _SwitchesShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _Shimmer(height: 64),
        SizedBox(height: 10),
        _Shimmer(height: 64),
      ],
    );
  }
}

class _RealEstateSectionShimmer extends StatelessWidget {
  const _RealEstateSectionShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Shimmer(height: 18, width: 120),
        SizedBox(height: 8),
        _Shimmer(height: 120, width: 120),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
      ],
    );
  }
}

class _BusinessSectionShimmer extends StatelessWidget {
  const _BusinessSectionShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Shimmer(height: 18, width: 120),
        SizedBox(height: 8),
        _Shimmer(height: 120, width: 120),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 12),
        _Shimmer(height: 52),
        SizedBox(height: 14),
        _Shimmer(height: 52),
        SizedBox(height: 14),
        _Shimmer(height: 18, width: 160),
        SizedBox(height: 8),
        _Shimmer(height: 64),
        SizedBox(height: 12),
        _Shimmer(height: 18, width: 160),
        SizedBox(height: 8),
        _Shimmer(height: 80),
      ],
    );
  }
}

/// â€”â€”â€”â€”â€”â€” طھط£ط«ظٹط±ط§طھ ظˆطھط±ط§ظƒظٹط¨ طھظپط§ط¹ظ„ظٹط© ظ…ظˆط¬ظˆط¯ط© ط³ط§ط¨ظ‚ط§ظ‹ â€”â€”â€”â€”â€”â€”

class _Appear extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _Appear({required this.child, this.delayMs = 0});

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: _show ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        opacity: _show ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final bg = context.color.secondaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.darken(10).withOpacity(.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(.02),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingTileSwitch extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final BuildContext context;
  const _SettingTileSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.context,
    this.subtitle,
  });

  @override
  State<_SettingTileSwitch> createState() => _SettingTileSwitchState();
}

class _SettingTileSwitchState extends State<_SettingTileSwitch> {
  @override
  Widget build(BuildContext _) {
    final activeBg = widget.context.color.territoryColor.withOpacity(.08);
    final inactiveBg = Colors.transparent;

    void _toggle() {
      HapticFeedback.lightImpact();
      widget.onChanged(!widget.value);
    }

    return InkWell(
      onTap: _toggle, // â†گ ط§ظ„ظ†ظ‚ط± ط¨ط£ظٹ ظ…ظƒط§ظ† ظٹظ‚ظ„ط¨ ط§ظ„ط³ظˆظٹطھط´
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: widget.value ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.context.color.borderColor.darken(10),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // ط¹ظ†ظˆط§ظ† + ظˆطµظپ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title)
                      .size(widget.context.font.normal)
                      .bold()
                      .color(widget.context.color.textDefaultColor),
                  if ((widget.subtitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: widget.context.font.small,
                        color:
                            widget.context.color.textColorDark.withOpacity(.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(
              activeColor: widget.context.color.territoryColor,
              value: widget.value,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                widget.onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final ValueChanged<bool>? onPressChanged;
  const _Pressable(
      {required this.child, required this.onTap, this.onPressChanged});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
    widget.onPressChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: (_) => _setDown(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _down ? .98 : 1,
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: context.color.territoryColor.withOpacity(.08),
            highlightColor: context.color.territoryColor.withOpacity(.04),
            onTap: () {}, // GestureDetector ظ‡ظˆ ط§ظ„ظ„ظٹ ظٹظ†ظپظ‘ط° onTap
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

Widget _sectionHeader(BuildContext context,
    {required String title, required IconData icon}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.color.territoryColor.withOpacity(.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: context.color.territoryColor),
      ),
      const SizedBox(width: 10),
      Text(title)
          .size(context.font.large)
          .bold()
          .color(context.color.textDefaultColor),
    ],
  );
}

Widget _sectionDivider(BuildContext context) {
  return Container(
    height: 1.5,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          context.color.borderColor.darken(25).withOpacity(.7),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    ),
  );
}

String _compactLocation(dynamic city, dynamic stateName, dynamic country) {
  final parts = [city, stateName, country]
      .map((e) => e?.toString().trim() ?? "")
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return "ط؛ظٹط± ظ…ط­ط¯ط¯";
  return parts.join(", ");
}

String _extractWalletBalance(UserModel user) {
  final info = user.additionalInfo;
  if (info is Map) {
    for (final key in ['wallet', 'wallet_balance', 'balance']) {
      final value = info[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
  }
  return "0";
}

String _extractDefaultCartLabel(UserModel user) {
  final info = user.additionalInfo;
  if (info is Map) {
    for (final key in ['default_cart', 'defaultCart', 'cart_default']) {
      final value = info[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
  }
  return "ط؛ظٹط± ظ…ط­ط¯ط¯ط©";
}

class _HeroHeader extends StatelessWidget {
  final UserProfileScreenState state;
  final File? fileUserimg;
  final VoidCallback onShowPicker;
  final String locationLabel;
  final String name;
  final String email;
  final String phone;

  const _HeroHeader({
    required this.state,
    required this.fileUserimg,
    required this.onShowPicker,
    required this.locationLabel,
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final String displayName =
        name.isNotEmpty ? name : (HiveUtils.getUserDetails().name ?? "");
    final String displayEmail =
        email.isNotEmpty ? email : (HiveUtils.getUserDetails().email ?? "");
    final String displayPhone =
        phone.isNotEmpty ? phone : (HiveUtils.getUserDetails().mobile ?? "");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: context.color.secondaryColor,
        border: Border.all(
          color: context.color.borderColor.darken(12),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.color.secondaryColor,
            context.color.secondaryColor.withOpacity(.9),
            context.color.secondaryColor.withOpacity(.85),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProfilePicture(
                context: context,
                state: state,
                fileUserimg: fileUserimg,
                onShowPicker: onShowPicker,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName.isEmpty ? "..." : displayName)
                        .size(context.font.larger)
                        .bold()
                        .color(context.color.textDefaultColor),
                    const SizedBox(height: 4),
                    if (displayPhone.isNotEmpty)
                      Text(displayPhone)
                          .size(context.font.normal)
                          .color(context.color.textColorDark.withOpacity(.85)),
                    if (displayEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(displayEmail)
                          .size(context.font.small)
                          .color(context.color.textColorDark.withOpacity(.8)),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.color.territoryColor.withOpacity(.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.color.territoryColor.withOpacity(.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_outlined,
                              size: 16, color: context.color.territoryColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(locationLabel.isEmpty
                                    ? "ط؛ظٹط± ظ…ط­ط¯ط¯"
                                    : locationLabel)
                                .size(context.font.small)
                                .color(context.color.textDefaultColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "ط¹ط¯ظ„ ط¨ظٹط§ظ†ط§طھظƒ ظˆطµظ„ط§ط­ظٹط§طھ ط¸ظ‡ظˆط±ظ‡ط§ ظ…ظ† ظ‡ظ†ط§.",
            style: TextStyle(
              fontSize: context.font.normal,
              color: context.color.textColorDark.withOpacity(.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeaderShimmer extends StatelessWidget {
  const _HeroHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return const _Shimmer(
        height: 150, radius: BorderRadius.all(Radius.circular(18)));
  }
}

class _InfoGrid extends StatelessWidget {
  final String location;
  final String wallet;
  final String defaultCart;
  const _InfoGrid({
    required this.location,
    required this.wallet,
    required this.defaultCart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            title: "ط§ظ„ظ…ظˆظ‚ط¹",
            value: location.isEmpty ? "ط؛ظٹط± ظ…ط­ط¯ط¯" : location,
            icon: Icons.place_outlined,
            color: context.color.territoryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InfoTile(
            title: "ط§ظ„ظ…ط­ظپط¸ط©",
            value: wallet,
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.greenAccent.shade400,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InfoTile(
            title: "ط§ظ„ط³ظ„ط© ط§ظ„ط§ظپطھط±ط§ط¶ظٹط©",
            value: defaultCart,
            icon: Icons.shopping_basket_outlined,
            color: context.color.textLightColor,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _InfoTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: context.color.borderColor.darken(10), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title)
                      .size(context.font.small)
                      .color(context.color.textColorDark.withOpacity(.75)),
                  const SizedBox(height: 4),
                  Text(value.isEmpty ? "-" : value)
                      .size(context.font.normal)
                      .bold()
                      .color(context.color.textDefaultColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGridShimmer extends StatelessWidget {
  const _InfoGridShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
            child: _Shimmer(
                height: 72, radius: BorderRadius.all(Radius.circular(14)))),
        SizedBox(width: 10),
        Expanded(
            child: _Shimmer(
                height: 72, radius: BorderRadius.all(Radius.circular(14)))),
        SizedBox(width: 10),
        Expanded(
            child: _Shimmer(
                height: 72, radius: BorderRadius.all(Radius.circular(14)))),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  final bool visible;
  const _LoadingOverlay({required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          children: [
            if (visible) Container(color: Colors.black.withOpacity(.12)),
            if (visible)
              Center(
                child: UiUtils.progress(
                  normalProgressColor: context.color.territoryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// â€”â€”â€”â€”â€”â€” ط§ظ„ط¯ظˆط§ظ„ ط§ظ„ط¨طµط±ظٹط© ط§ظ„ظ…ظ†ظ‚ظˆظ„ط© â€”â€”â€”â€”â€”â€”

Widget phoneWidget({
  required BuildContext context,
  required UserProfileScreenState state,
  required TextEditingController phoneController,
  required bool setPhoneReadOnly,
  required String? countryCode,
  required VoidCallback onSelectCountryCode,
}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(height: 10.rh(context)),
    Text("phoneNumber".translate(context))
        .color(context.color.textDefaultColor),
    SizedBox(height: 10.rh(context)),
    CustomTextFormField(
      controller: phoneController,
      validator: CustomTextFieldValidator.phoneNumber,
      keyboard: TextInputType.phone,
      isReadOnly: setPhoneReadOnly,
      fillColor: context.color.secondaryColor,
      onChange: (value) => state.setState(() {}),
      isMobileRequired: false,
      fixedPrefix: SizedBox(
        width: 55,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: GestureDetector(
            onTap: () {
              if (HiveUtils.getUserDetails().type !=
                  AuthenticationType.phone.name) {
                onSelectCountryCode();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              child: Center(
                child: Text(_formatCountryCode(countryCode ?? ''))
                    .size(context.font.large)
                    .centerAlign(),
              ),
            ),
          ),
        ),
      ),
      hintText: "phoneNumber".translate(context),
    ),
  ]);
}

String _formatCountryCode(String countryCode) {
  if (!countryCode.startsWith('+')) return '+$countryCode';
  return countryCode;
}

Widget buildTextField(
  BuildContext context, {
  required String title,
  required TextEditingController controller,
  CustomTextFieldValidator? validator,
  bool? readOnly,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 10.rh(context)),
      Text(title.translate(context)).color(context.color.textDefaultColor),
      SizedBox(height: 10.rh(context)),
      CustomTextFormField(
        controller: controller,
        isReadOnly: readOnly,
        validator: validator,
        fillColor: context.color.secondaryColor,
        isCustomStyle: false,
        hintText: title.translate(context),
      ),
    ],
  );
}

Widget buildAddressTextField(
  BuildContext context, {
  required String title,
  required TextEditingController controller,
  CustomTextFieldValidator? validator,
  bool? readOnly,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 10.rh(context)),
      Text(title.translate(context)),
      SizedBox(height: 10.rh(context)),
      CustomTextFormField(
        controller: controller,
        maxLine: 5,
        action: TextInputAction.newline,
        isReadOnly: readOnly,
        fillColor: context.color.secondaryColor,
        isCustomStyle: false,
        hintText: title.translate(context),
      ),
      /* ط§ظ„ظ‚ط·ط¹ ط§ظ„ظ…ط¹ظ„ظ‘ظ‚ط© طھظڈط±ظƒطھ ظƒظ…ط§ ظ‡ظٹ */
    ],
  );
}

Widget _getProfileImage({
  required BuildContext context,
  required UserProfileScreenState state,
  required File? fileUserimg,
}) {
  if (fileUserimg != null) {
    return Image.file(fileUserimg, fit: BoxFit.cover);
  } else {
    if (state.widget.from == "login") {
      if (HiveUtils.getUserDetails().profile != "" &&
          HiveUtils.getUserDetails().profile != null) {
        return UiUtils.getImage(
          HiveUtils.getUserDetails().profile!,
          fit: BoxFit.cover,
        );
      }
      return UiUtils.getSvg(
        AppIcons.defaultPersonLogo,
        color: context.color.territoryColor,
        fit: BoxFit.none,
      );
    } else {
      if ((HiveUtils.getUserDetails().profile ?? "").isEmpty) {
        return UiUtils.getSvg(
          AppIcons.defaultPersonLogo,
          color: context.color.territoryColor,
          fit: BoxFit.none,
        );
      } else {
        return UiUtils.getImage(
          HiveUtils.getUserDetails().profile!,
          fit: BoxFit.cover,
        );
      }
    }
  }
}

Widget _buildProfilePicture({
  required BuildContext context,
  required UserProfileScreenState state,
  required File? fileUserimg,
  required VoidCallback onShowPicker,
}) {
  return Stack(
    children: [
      Container(
        height: 124.rh(context),
        width: 124.rw(context),
        alignment: AlignmentDirectional.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.color.territoryColor, width: 2),
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.color.territoryColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          width: 106.rw(context),
          height: 106.rh(context),
          child: _getProfileImage(
            context: context,
            state: state,
            fileUserimg: fileUserimg,
          ),
        ),
      ),
      PositionedDirectional(
        bottom: 0,
        end: 0,
        child: InkWell(
          onTap: onShowPicker,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            height: 37.rh(context),
            width: 37.rw(context),
            alignment: AlignmentDirectional.center,
            decoration: BoxDecoration(
              border: Border.all(color: context.color.buttonColor, width: 1.5),
              shape: BoxShape.circle,
              color: context.color.territoryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SizedBox(
              width: 15.rw(context),
              height: 15.rh(context),
              child: UiUtils.getSvg(AppIcons.edit),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildLogoSelector({
  required BuildContext context,
  required bool isOffice,
  required File? businessLogoImage,
  required String? existingBusinessLogoUrl,
  required void Function(bool isOffice) onPickLogoImage,
}) {
  return _Pressable(
    onTap: () => onPickLogoImage(isOffice),
    child: Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.darken(10),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: businessLogoImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(businessLogoImage, fit: BoxFit.cover),
            )
          : existingBusinessLogoUrl != null &&
                  existingBusinessLogoUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: UiUtils.getImage(
                    existingBusinessLogoUrl,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 40, color: context.color.territoryColor),
                    const SizedBox(height: 8),
                    Text(
                      "chooseLogo".translate(context),
                      style: TextStyle(
                        fontSize: context.font.small,
                        color: context.color.textColorDark.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
    ),
  );
}

Widget _buildWorkingHours({
  required BuildContext context,
  required TimeOfDay? openingTime,
  required TimeOfDay? closingTime,
  required Future<void> Function(bool isOpening) onSelectTime,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("workingHours".translate(context))
          .size(context.font.normal)
          .color(context.color.textDefaultColor),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _Pressable(
              onTap: () => onSelectTime(true),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.color.borderColor.darken(10),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      openingTime != null
                          ? openingTime.format(context)
                          : "openingTime".translate(context),
                      style: TextStyle(
                        fontSize: context.font.normal,
                        color: openingTime != null
                            ? context.color.textDefaultColor
                            : context.color.textColorDark.withOpacity(0.6),
                      ),
                    ),
                    Icon(Icons.access_time,
                        color: context.color.territoryColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Pressable(
              onTap: () => onSelectTime(false),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.color.borderColor.darken(10),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      closingTime != null
                          ? closingTime.format(context)
                          : "closingTime".translate(context),
                      style: TextStyle(
                        fontSize: context.font.normal,
                        color: closingTime != null
                            ? context.color.textDefaultColor
                            : context.color.textColorDark.withOpacity(0.6),
                      ),
                    ),
                    Icon(Icons.access_time,
                        color: context.color.territoryColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildCommercialRegisterUpload({
  required BuildContext context,
  required File? commercialRegisterFile,
  required String? existingCommercialRegisterUrl,
  required VoidCallback onPickCommercialRegister,
}) {
  return _Pressable(
    onTap: onPickCommercialRegister,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.color.borderColor.darken(10),
          width: 1.5,
        ),
      ),
      child: commercialRegisterFile != null
          ? Row(
              children: [
                Icon(Icons.picture_as_pdf,
                    size: 40, color: context.color.territoryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    commercialRegisterFile.path.split('/').last,
                    style: TextStyle(
                      fontSize: context.font.normal,
                      color: context.color.textDefaultColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : (existingCommercialRegisterUrl != null &&
                  existingCommercialRegisterUrl.isNotEmpty)
              ? Row(
                  children: [
                    Icon(Icons.picture_as_pdf,
                        size: 40, color: context.color.territoryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "currentFile".translate(context),
                        style: TextStyle(
                          fontSize: context.font.normal,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(Icons.upload_file,
                        size: 40, color: context.color.territoryColor),
                    const SizedBox(height: 8),
                    Text(
                      "uploadCommercialRegister".translate(context),
                      style: TextStyle(
                        fontSize: context.font.normal,
                        color: context.color.textColorDark.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
    ),
  );
}

// ط¹ظ†ظˆط§ظ† طµط؛ظٹط± ظ‚ط¨ظ„ ط¹ظ†طµط± (ظ…ط«ظ„ طµظˆط±ط©/طھط­ظ…ظٹظ„ ظ…ظ„ظپ)
Widget _fieldLabel(BuildContext context, String key) {
  return Text(key.translate(context))
      .size(context.font.normal)
      .color(context.color.textDefaultColor);
}

/// SafeArea ط­ط³ط¨ ط´ط±ط· "from == login"
Widget _safeAreaCondition({required String from, required Widget child}) {
  if (from == "login") return SafeArea(child: child);
  return child;
}
