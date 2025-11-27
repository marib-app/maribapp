// FILE: lib/ui/screens/auth/sign_up/signup_screen.dart
// Refactored: ?§?„?…?†?·?‚ ?‡?†?§ ???‚?· + ?§?????????§?? ???§?¬?‡?§?? ?…?† signup_sections.dart ?? account_type_selector.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter_svg/svg.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:marib/data/cubits/system/user_details.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/api.dart';
import 'package:country_picker/country_picker.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:marib/ui/screens/auth/sign_up/email_verification_screen.dart';

// ?§?„???§?¬?‡?§?? ?§?„?…???µ???„?©
import 'Widgets/account_type_selector.dart';
import 'Widgets/signup_shared_widgets.dart';
import 'Widgets/real_estate_section.dart';
import 'Widgets/business_section.dart';
import 'dart:async'; // ?„?„?€ Timer
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/utils/notification/notification_service.dart';
import '../widgets/auth_status_bar.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/data/model/store_gateway_option.dart';

class SignupScreen extends StatefulWidget {
  final String? selectedAccountType;
  final String? phoneNumber;
  final String? countryCode;
  final bool? fromSocialLogin;

  const SignupScreen({
    super.key,
    this.selectedAccountType,
    this.phoneNumber,
    this.countryCode,
    this.fromSocialLogin,
  });

  static Route route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;

    return AppPageRoute.build(
      builder: (context) {
        return SignupScreen(
          selectedAccountType: args?['selectedAccountType'],
          phoneNumber: args?['phoneNumber'],
          countryCode: args?['countryCode'],
          fromSocialLogin: args?['fromSocialLogin'] ?? false,
        );
      },
      settings: settings,
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  CloudState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends CloudState<SignupScreen> {
  static final RegExp _staffUsernamePattern = RegExp(r'^[a-zA-Z0-9._-]+$');
  final GlobalKey<FormState> _formKey = GlobalKey();
  final TextEditingController _emailController = TextEditingController();

  // ?­?‚???„ ?§?„???‚?§?±?? (?†???? 2)
  final TextEditingController _officeNameController = TextEditingController();
  final TextEditingController _officePhoneController = TextEditingController();
  final TextEditingController _officeWhatsappController =
      TextEditingController();
  final TextEditingController _officeLocationController =
      TextEditingController();

  // ?­?‚???„ ?§?„???¬?§?±?? (?†???? 3)
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessPhoneController =
      TextEditingController();
  final TextEditingController _businessWhatsappController =
      TextEditingController();
  final TextEditingController _businessLocationController =
      TextEditingController();
  final TextEditingController _commercialRegisterController =
      TextEditingController();
  final TextEditingController _storeStaffEmailController =
      TextEditingController();

  // ?‚???§?¦?… ?„?„?­???§?¨ ?§?„???¬?§?±??
  List<int> selectedBusinessCategories = [];
  List<StoreGatewayOption> _storeGateways = const <StoreGatewayOption>[];
  final Set<int> _selectedStoreGatewayIds = <int>{};
  final Map<int, TextEditingController> _storeGatewayBeneficiaryControllers =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _storeGatewayAccountControllers =
      <int, TextEditingController>{};
  bool _isLoadingStoreGateways = false;
  String? _storeGatewaysError;

  // ?µ???±/?…?„???§??
  File? _officeLogoImage;
  File? _businessLogoImage;
  File? _commercialRegisterFile;
  final ImagePicker _picker = ImagePicker();

  // ?§?„?…???‚??
  double? _latitude, _longitude;
  String? _selectedAddress;
  bool _isLocationLoading = false;

  // ?§?„?…???‚?? ?„???„ ?†????
  double? _officeLatitude, _officeLongitude;
  String? _officeSelectedAddress;
  double? _businessLatitude, _businessLongitude;
  String? _businessSelectedAddress;

  // ?????‚?§?? ?§?„???…?„ (???¬?§?±??)
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;

  bool _officeLogoUploading = false;
  double? _officeLogoProgress;
  bool _officeLogoPreviewHint = false;

  bool _businessLogoUploading = false;
  double? _businessLogoProgress;
  bool _businessLogoPreviewHint = false;

  bool isCommercialUploading = false;
  double? commercialUploadProgress;
  bool showCommercialPreviewHint = false;

  bool isUploading = false;

  // ?????‚?§?? ?§?„???…?„ (?§?????±?§?¶??: ?¬?…???? ?§?„?????§?… ?????± ?…???§?­?©)
  Map<String, dynamic> _workingHours = {
    "sat": {"enabled": false, "from": null, "to": null},
    "sun": {"enabled": false, "from": null, "to": null},
    "mon": {"enabled": false, "from": null, "to": null},
    "tue": {"enabled": false, "from": null, "to": null},
    "wed": {"enabled": false, "from": null, "to": null},
    "thu": {"enabled": false, "from": null, "to": null},
    "fri": {"enabled": false, "from": null, "to": null},
  };

  String? countryCode;
  String? flagEmoji = "??‡???‡?";

  // Social login
  String? currentSelectedAccountType;

  @override
  void initState() {
    super.initState();
    countryCode = widget.countryCode;
    if (widget.selectedAccountType == "3") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<FetchCategoryCubit>().fetchCategories();
        _loadStoreGateways();
      });
    }
  }

  Future<void> _openAccountTypeBottomSheet() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String? localValue = currentSelectedAccountType;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: AccountTypeSelector(
                    value: localValue,
                    onChanged: (v) => setSheetState(() => localValue = v),
                    onContinue: () => Navigator.pop(ctx, localValue),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (selected != null) {
      setState(() => currentSelectedAccountType = selected);
      Navigator.pushReplacement(
        context,
        AppPageRoute.build(
          builder: (context) => SignupScreen(
            selectedAccountType: selected,
            phoneNumber: widget.phoneNumber,
            countryCode: widget.countryCode,
            fromSocialLogin: false,
          ),
          motionPattern: AppMotionPattern.glide,
        ),
      );
    }
  }

  // ?§?®?????§?± ?µ???±?©
  Future<void> _pickImage(String type) async {
    try {
      // ?§?¨???? "?±????" ???§?¬?‡?©?‹
      if (type == 'office_logo') {
        setState(() {
          _officeLogoUploading = true;
          _officeLogoProgress =
              null; // ???? ?‚???…?© 0..1 ???°?§ ???†???? ???‚???… ?­?‚???‚??
        });
      } else if (type == 'business_logo') {
        setState(() {
          _businessLogoUploading = true;
          _businessLogoProgress = null;
        });
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (type == 'office_logo') {
            _officeLogoImage = File(image.path);
          } else {
            _businessLogoImage = File(image.path);
          }
        });
      }

      // ?…?­?§???§?© ?±???? ???±???? ?„???¸?‡?§?± ?§?„?„?????± (?§?­?°?? ?§?„?????®???± ?„?? ???†???? ?±???? ?­?‚???‚??)
      await Future.delayed(const Duration(milliseconds: 400));

      // ???†?‡?? ?§?„?±???? + ?????‘?„ ???„?…???­ ?§?„?†?¬?§?­ 3 ?«???§?†??
      if (type == 'office_logo') {
        if (mounted) {
          setState(() {
            _officeLogoUploading = false;
            _officeLogoPreviewHint = true;
          });
          Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            setState(() => _officeLogoPreviewHint = false);
          });
        }
      } else if (type == 'business_logo') {
        if (mounted) {
          setState(() {
            _businessLogoUploading = false;
            _businessLogoPreviewHint = true;
          });
          Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            setState(() => _businessLogoPreviewHint = false);
          });
        }
      }
    } catch (e) {
      // ???†?‡?? ?§?„?±???? ???? ?­?§?„ ?§?„?®?·??
      if (mounted) {
        setState(() {
          _officeLogoUploading = false;
          _businessLogoUploading = false;
        });
      }
      HelperUtils.showSnackBarMessage(
        context,
        "errorPickingImage".translate(context),
        messageDuration: 3,
      );
    }
  }

  // ?§?®?????§?± ?…?„?? ?§?„???¬?„ ?§?„???¬?§?±??

// ?„?? ?¨???????®???… kIsWeb:

  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const _allowedExt = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];

  Future<void> _pickFile() async {
    try {
      // 1) ?????­ ?…?†???‚?? ?§?„?…?„???§?? (?…?§ ?†?????‘?„ ?§?„?„?????± ?‡?†?§ ?„???† ?†?§???°?© ?§?„?†?¸?§?… ?????·?? ?§?„???§?¬?‡?©)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExt,
        withData: true, // ?…?‡?… ?„?„?????¨
      );

      if (result == null) return; // ?§?„?…?????®???… ???„???‰

      final picked = result.files.single;
      final ext = (picked.extension ?? '').toLowerCase();

      // ???­?‚?‚ ?§?„?§?…?????§??
      if (!_allowedExt.contains(ext)) {
        HelperUtils.showSnackBarMessage(
          context,
          "fileTypeNotAllowed".translate(context),
          messageDuration: 3,
        );
        return;
      }

      // ???­?‚?‚ ?§?„?­?¬?…
      final size = picked.size;
      if (size > _maxFileSizeBytes) {
        HelperUtils.showSnackBarMessage(
          context,
          "fileTooLarge".translate(context), // "?§?„?­?¬?… ?????¬?§???? 10MB"
          messageDuration: 3,
        );
        return;
      }

      // 2) ?§?­???¸ ?§?„?…?„?? ?§?„?…?®???§?±
      if (kIsWeb) {
        if (picked.bytes == null) {
          HelperUtils.showSnackBarMessage(
            context,
            "fileReadError".translate(context),
            messageDuration: 3,
          );
          return;
        }
        // ?­???¸/?±???? ?…?¨?§?´?±?© ?¨?§?„?€ bytes ???†???? ???† ?§?­???¬??:
        // _webFileBytes = picked.bytes!;
        // _webFileName  = picked.name;
        setState(() {
          _commercialRegisterFile =
              null; // ?„?§ ?†?…?„?? File ???„?‰ ?§?„?????¨?? ?§?­?????¸ ?¨?§?„?§???… ???‚?· ???† ?´?¦??
        });
      } else {
        final path = picked.path;
        if (path == null) {
          HelperUtils.showSnackBarMessage(
            context,
            "fileReadError".translate(context),
            messageDuration: 3,
          );
          return;
        }
        setState(() {
          _commercialRegisterFile = File(path);
        });
      }

      // 3) ?????‘?„ ?§?„?„?????± ???«?†?§?? "?§?„?±???? ?§?„?????„??"
      setState(() => isUploading = true);
      try {
        // TODO: ?§?±???? ?§?„?…?„?? ?„?„?????±???± ?‡?†?§
        // await api.uploadCommercialRegister(_commercialRegisterFile or picked.bytes);
        await Future.delayed(const Duration(seconds: 1)); // ?…?­?§???§?© ?±????
      } finally {
        if (mounted) setState(() => isUploading = false);
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "errorPickingFile".translate(context),
        messageDuration: 3,
      );
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _removePickedFile() {
    setState(() {
      _commercialRegisterFile = null;
      // _webFileBytes = null; _webFileName = null; // ?„?„?????¨ ???† ???¬????
    });
  }

  // ?§?®?????§?± ?§?„???‚??
  Future<void> _selectTime(BuildContext context, bool isOpeningTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: isOpeningTime
          ? "selectOpeningTime".translate(context)
          : "selectClosingTime".translate(context),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.color.territoryColor,
              onPrimary: Colors.white,
              surface: context.color.primaryColor,
              onSurface: context.color.textDefaultColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: context.color.territoryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpeningTime) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  // ?§?„?…???‚?? ?§?„?­?§?„??
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          HelperUtils.showSnackBarMessage(
            context,
            "locationPermissionDenied".translate(context),
            messageDuration: 3,
          );
          setState(() {
            _isLocationLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        HelperUtils.showSnackBarMessage(
          context,
          "locationPermissionDeniedForever".translate(context),
          messageDuration: 3,
        );
        setState(() {
          _isLocationLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        if (widget.selectedAccountType == "2") {
          // ???‚?§?±??
          _officeLatitude = position.latitude;
          _officeLongitude = position.longitude;
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            _officeSelectedAddress =
                "${placemark.street}, ${placemark.locality}, ${placemark.country}";
            _officeLocationController.text = _officeSelectedAddress ?? "";
          }
        } else if (widget.selectedAccountType == "3") {
          // ???¬?§?±??
          _businessLatitude = position.latitude;
          _businessLongitude = position.longitude;
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            _businessSelectedAddress =
                "${placemark.street}, ${placemark.locality}, ${placemark.country}";
            _businessLocationController.text = _businessSelectedAddress ?? "";
          }
        } else {
          // ???±????
          _latitude = position.latitude;
          _longitude = position.longitude;
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            _selectedAddress =
                "${placemark.street}, ${placemark.locality}, ${placemark.country}";
          }
        }
        _isLocationLoading = false;
      });

      HelperUtils.showSnackBarMessage(
        context,
        "locationSelectedSuccessfully".translate(context),
        messageDuration: 2,
      );
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "errorGettingLocation".translate(context),
        messageDuration: 3,
      );
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  // ???± ?§?„?…???‚??
  VoidCallback _getLocationCallback() {
    return _isLocationLoading ? () {} : _getCurrentLocation;
  }

  // ?…?†???‚?? ?§?„?????„?©
  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(11),
      ),
      onSelect: (value) {
        setState(() {
          flagEmoji = value.flagEmoji;
          countryCode = "+${value.phoneCode}";
        });
      },
    );
  }

  void _ensureGatewayControllers(int gatewayId) {
    _storeGatewayBeneficiaryControllers.putIfAbsent(
      gatewayId,
      () => TextEditingController(),
    );
    _storeGatewayAccountControllers.putIfAbsent(
      gatewayId,
      () => TextEditingController(),
    );
  }

  void _disposeGatewayControllers(Iterable<int> gatewayIds) {
    for (final int id in gatewayIds) {
      _storeGatewayBeneficiaryControllers.remove(id)?.dispose();
      _storeGatewayAccountControllers.remove(id)?.dispose();
    }
  }

  void _toggleStoreGateway(int gatewayId, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selectedStoreGatewayIds.add(gatewayId)) {
          _ensureGatewayControllers(gatewayId);
        }
      } else {
        if (_selectedStoreGatewayIds.remove(gatewayId)) {
          _disposeGatewayControllers(<int>[gatewayId]);
        }
      }
    });
  }

  Future<void> _loadStoreGateways() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStoreGateways = true;
      _storeGatewaysError = null;
    });

    try {
      final Map<String, dynamic> response =
          await Api.get(url: 'store-gateways');

      final List<StoreGatewayOption> parsed = _parseStoreGateways(response);
      if (!mounted) return;

      final Set<int> availableIds =
          parsed.where((g) => g.isActive && g.id > 0).map((g) => g.id).toSet();
      final List<int> removedSelection = _selectedStoreGatewayIds
          .where((int id) => !availableIds.contains(id))
          .toList();

      _disposeGatewayControllers(removedSelection);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedStoreGatewayIds
            .removeWhere((int id) => !availableIds.contains(id));
        _storeGateways = parsed;
      });
      for (final int id in _selectedStoreGatewayIds) {
        _ensureGatewayControllers(id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storeGateways = const <StoreGatewayOption>[];
        _storeGatewaysError = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingStoreGateways = false;
      });
    }
  }

  List<StoreGatewayOption> _parseStoreGateways(
    Map<String, dynamic> payload,
  ) {
    final dynamic rawData = payload['data'] ?? payload['gateways'] ?? payload;

    Iterable<dynamic> candidates;
    if (rawData is List) {
      candidates = rawData;
    } else if (rawData is Map<String, dynamic>) {
      if (rawData['data'] is List) {
        candidates = rawData['data'] as List<dynamic>;
      } else if (rawData['items'] is List) {
        candidates = rawData['items'] as List<dynamic>;
      } else {
        candidates = rawData.values
            .where((value) => value is List)
            .cast<List<dynamic>>()
            .expand((element) => element);
      }
    } else {
      candidates = const <dynamic>[];
    }

    final List<StoreGatewayOption> parsed = <StoreGatewayOption>[];
    for (final dynamic element in candidates) {
      if (element is Map<String, dynamic>) {
        parsed.add(StoreGatewayOption.fromJson(element));
      } else if (element is Map) {
        parsed.add(
          StoreGatewayOption.fromJson(
            Map<String, dynamic>.from(
              element as Map<dynamic, dynamic>,
            ),
          ),
        );
      }
    }

    parsed.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return parsed;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _officeNameController.dispose();
    _officePhoneController.dispose();
    _officeWhatsappController.dispose();
    _officeLocationController.dispose();
    _businessNameController.dispose();
    _businessPhoneController.dispose();
    _businessWhatsappController.dispose();
    _businessLocationController.dispose();
    _commercialRegisterController.dispose();
    _storeStaffEmailController.dispose();
    for (final controller in _storeGatewayBeneficiaryControllers.values) {
      controller.dispose();
    }
    for (final controller in _storeGatewayAccountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? accountType = widget.selectedAccountType;
    final bool isCommercialFlow =
        accountType == "3" || accountType?.toLowerCase() == "commercial";
    if (isCommercialFlow) {
      return _buildCommercialLayout(context);
    }

    final statusBarBase = LoginStatusBar.resolveBaseColor(
      context,
      override: context.color.territoryColor,
    );

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LoginStatusBar.overlayFor(
        context,
        baseColor: statusBarBase,
      ),
      child: Scaffold(
        // ?§?„?®?„?????© ?§?„???§?…?©
        backgroundColor: context.color.backgroundColor,

        // ?§?„?¬???…: ?®?„?????© ?…?????±?¬?© + ?…?­?????‰ ???§?®?„ SafeArea (top: false) ?…?? ?­?¬?? ?§?„?…???§?­?© ?????????‹?§
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              colors: [
                context.color.territoryColor,
                context.color.territoryColor,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            // ?®?„???‡ ???±???… ?­???‰ ???®?± ?§?„?´?§?´?© (?†?¶?¨?· ?§?„?€ inset ?¨?§?„?????„ ???†?? ?§?„?????¨???±?? ?????????‹?§)
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: LoginStatusBar.topSpacer(
                    context,
                    baseColor: statusBarBase,
                  ),
                ),
                // ===== ?§?„?‡?????±: ?´???§?± + ???¨?§?±?© ???±?­???¨???© =====
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  expandedHeight: 160,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.color.territoryColor,
                            context.color.territoryColor.withOpacity(0.92),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/svg/Logo.svg',
                            height: 84,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Text("readytoserve".translate(context))
                              .size(context.font.large)
                              .color(Colors.white.withOpacity(0.95)),
                        ],
                      ),
                    ),
                  ),
                ),

                // ===== ?§?„?…?­?????‰ (?¬???… ?§?„?†?…???°?¬) =====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(6, 8, 6, 16 + bottomInset),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.color.primaryColor,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_getTitle())
                                .size(context.font.extraLarge)
                                .color(context.color.textDefaultColor),
                            const SizedBox(height: 24),

                            if (widget.fromSocialLogin == true &&
                                widget.selectedAccountType == null) ...[
                              Text("chooseAccountType".translate(context))
                                  .size(context.font.large)
                                  .color(context.color.textDefaultColor),
                              const SizedBox(height: 8),
                              Text("mustSelectAccountType".translate(context))
                                  .size(context.font.small)
                                  .color(context.color.textColorDark
                                      .withOpacity(0.7)),
                              const SizedBox(height: 12),
                              UiUtils.buildButton(
                                context,
                                onPressed: _openAccountTypeBottomSheet,
                                buttonTitle:
                                    "chooseAccountType".translate(context),
                                radius: 12,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 8),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // ?§?„???‚?§?±??
                            if (widget.selectedAccountType == "2") ...[
                              RealEstateSection(
                                logo: _officeLogoImage,
                                onPickLogo: () => _pickImage('office_logo'),
                                officeName: _officeNameController,
                                officePhone: _officePhoneController,
                                officeWhatsapp: _officeWhatsappController,
                                officeLocation: _officeLocationController,
                                prefixText:
                                    "${flagEmoji ?? "??‡???‡?"} ${countryCode ?? "+967"}",
                                onPickCountry: _showCountryPicker,
                                isLocationLoading: _isLocationLoading,
                                onGetLocation: _getLocationCallback(),
                                showLogoPicker: false,

                                // â¬‡?¸? ?…?‡?… ?„???±?¶ ?§?„?„?????±/?§?„???„?…???­
                                isLogoUploading: _officeLogoUploading,
                                logoUploadProgress: _officeLogoProgress,
                                showLogoPreviewHint: _officeLogoPreviewHint,
                              )
                            ],
                            // ?§?„?????±?§??
                            if (widget.selectedAccountType == "1" ||
                                widget.selectedAccountType == "individual") ...[
                              EmailOnlySection(
                                  emailController: _emailController),
                            ],

                            const SizedBox(height: 20),
                            UiUtils.buildButton(
                              context,
                              onPressed: _submitForm,
                              buttonTitle:
                                  "completeRegistration".translate(context),
                              radius: 10,
                              height: 46,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommercialLayout(BuildContext context) {
    final statusBarBase = LoginStatusBar.resolveBaseColor(
      context,
      override: context.color.backgroundColor,
    );
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: LoginStatusBar.overlayFor(
        context,
        baseColor: statusBarBase,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        body: Column(
          children: [
            LoginStatusBar.topSpacer(
              context,
              baseColor: statusBarBase,
            ),
            _buildCommercialAppBar(context),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    Text(_getTitle())
                        .size(context.font.extraLarge)
                        .color(context.color.textDefaultColor),
                    const SizedBox(height: 8),
                    Text(
                      "readytoserve".translate(context),
                      style: TextStyle(
                        fontSize: context.font.normal,
                        color: context.color.textLightColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
                      builder: (context, catState) {
                        List<CategoryModel> cats = [];
                        if (catState is FetchCategorySuccess) {
                          final CategoryModel category6 =
                              catState.categories.firstWhere(
                            (c) => c.id == 6,
                            orElse: () => CategoryModel(),
                          );
                          cats = category6.children ?? [];
                        }
                        return BusinessSection(
                          logo: _businessLogoImage,
                          onPickLogo: () => _pickImage('business_logo'),
                          commercialFile: _commercialRegisterFile,
                          onPickFile: _pickFile,
                          isUploading: isUploading,
                          name: _businessNameController,
                          phone: _businessPhoneController,
                          whatsapp: _businessWhatsappController,
                          location: _businessLocationController,
                          prefixText:
                              "${flagEmoji ?? "??‡???‡?"} ${countryCode ?? "+967"}",
                          onPickCountry: _showCountryPicker,
                          isLocationLoading: _isLocationLoading,
                          onGetLocation: _getLocationCallback(),
                          showLogoPicker: false,
                          categories: cats,
                          selectedCategoryIds: selectedBusinessCategories,
                          onToggleCategory: (id) {
                            setState(() {
                              if (selectedBusinessCategories.contains(id)) {
                                selectedBusinessCategories.remove(id);
                              } else {
                                selectedBusinessCategories.add(id);
                              }
                            });
                          },
                          openingTime: _openingTime,
                          closingTime: _closingTime,
                          onPickOpening: () => _selectTime(context, true),
                          onPickClosing: () => _selectTime(context, false),
                          storeGateways: _storeGateways,
                          selectedGatewayIds: _selectedStoreGatewayIds,
                          beneficiaryControllers:
                              _storeGatewayBeneficiaryControllers,
                          accountControllers: _storeGatewayAccountControllers,
                          onToggleGateway: _toggleStoreGateway,
                          isGatewaysLoading: _isLoadingStoreGateways,
                          gatewaysError: _storeGatewaysError,
                          onRetryGateways: _loadStoreGateways,
                          workingHours: _workingHours,
                          onChangedWorkingHours: (updated) {
                            setState(() {
                              _workingHours = updated;
                            });
                          },
                          staffEmailController: _storeStaffEmailController,
                          staffEmailDomain: Constant.storeStaffEmailDomain,
                          isLogoUploading: _businessLogoUploading,
                          logoUploadProgress: _businessLogoProgress,
                          showLogoPreviewHint: _businessLogoPreviewHint,
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: UiUtils.buildButton(
                context,
                onPressed: _submitForm,
                buttonTitle: "completeRegistration".translate(context),
                radius: 14,
                height: 52,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommercialAppBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(
                Icons.arrow_back,
                color: context.color.textDefaultColor,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _getTitle(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: context.color.textDefaultColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed(Routes.login),
              child: Text("login".translate(context))
                  .underline()
                  .color(context.color.territoryColor),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (widget.fromSocialLogin == true && widget.selectedAccountType == null) {
      return "completeAccountSetup".translate(context);
    }

    switch (widget.selectedAccountType) {
      case "2":
        return "realEstateAccountSetup".translate(context);
      case "3":
        return "commercialAccountSetup".translate(context);
      default:
        return "emailConfirmation".translate(context);
    }
  }

  bool _validateAdditionalFields() {
    if (widget.selectedAccountType == "3") {
      if (_businessNameController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterBusinessName".translate(context),
          messageDuration: 3,
        );
        return false;
      }
      if (_businessPhoneController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterBusinessPhone".translate(context),
          messageDuration: 3,
        );
        return false;
      }
      if (_businessWhatsappController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterBusinessWhatsapp".translate(context),
          messageDuration: 3,
        );
        return false;
      }
      if (_businessLocationController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterBusinessLocation".translate(context),
          messageDuration: 3,
        );
        return false;
      }
      if (selectedBusinessCategories.isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseSelectAtLeastOneBusinessCategory".translate(context),
          messageDuration: 3,
        );
        return false;
      }

      for (final int gatewayId in _selectedStoreGatewayIds) {
        final String beneficiary =
            _storeGatewayBeneficiaryControllers[gatewayId]?.text.trim() ?? '';
        final String accountNumber =
            _storeGatewayAccountControllers[gatewayId]?.text.trim() ?? '';

        if (beneficiary.isEmpty || accountNumber.isEmpty) {
          HelperUtils.showSnackBarMessage(
            context,
            "pleaseCompleteGatewayAccountDetails".translate(context),
            messageDuration: 3,
          );
          return false;
        }
      }
    }

    if (widget.selectedAccountType == "2") {
      if (_officePhoneController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterOfficePhone".translate(context),
          messageDuration: 3,
        );
        return false;
      }
      if (_officeWhatsappController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterOfficeWhatsapp".translate(context),
          messageDuration: 3,
        );
        return false;
      }
    }

    return true;
  }

  bool _validateWithoutPhone() {
    // ?†???? 3 (???¬?§?±??): ?†???­?‚?‚ ?…?† ?§?„?§???…/?§?„?…???‚??/?§?„???‚???§?… ???‚?· â€” ?¨?????† ?‡?§????/???§?????§?¨
    if (widget.selectedAccountType == "3") {
      if (_businessNameController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterBusinessName".translate(context),
          messageDuration: 3,
        );
        return false;
      }
      if (_businessLocationController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseEnterBusinessLocation".translate(context),
          messageDuration: 3,
        );
        return false;
      }
      if (selectedBusinessCategories.isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "pleaseSelectAtLeastOneBusinessCategory".translate(context),
          messageDuration: 3,
        );
        return false;
      }

      final String staffUsername = _storeStaffEmailController.text.trim();
      if (staffUsername.isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "???? ????? ??? ???????? ????? ????? ???? ??????.",
          messageDuration: 3,
        );
        return false;
      }
      if (staffUsername.length < Constant.storeStaffEmailMinLength ||
          staffUsername.length > Constant.storeStaffEmailMaxLength ||
          !_staffUsernamePattern.hasMatch(staffUsername)) {
        HelperUtils.showSnackBarMessage(
          context,
          "??????? ??? ?? ???? ?? ${Constant.storeStaffEmailMinLength} ??? ${Constant.storeStaffEmailMaxLength} ????? ?????? ??? ???? ???????? ?? ????? ?? (. - _).",
          messageDuration: 4,
        );
        return false;
      }
    }

    // ?†???? 2 (???‚?§?±??): ?„?§ ?†?¬???„ ???? ?­?‚?„ ???¬?¨?§?±?? ?§?„???†
    return true;
  }

  Map<String, dynamic> _toStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
    }
    return <String, dynamic>{};
  }

  List<_StoreGatewayAccountDraft> _collectStoreGatewayAccountDrafts() {
    final List<_StoreGatewayAccountDraft> result =
        <_StoreGatewayAccountDraft>[];

    for (final int gatewayId in _selectedStoreGatewayIds) {
      final String beneficiary =
          _storeGatewayBeneficiaryControllers[gatewayId]?.text.trim() ?? '';
      final String accountNumber =
          _storeGatewayAccountControllers[gatewayId]?.text.trim() ?? '';

      if (beneficiary.isEmpty || accountNumber.isEmpty) {
        continue;
      }

      result.add(
        _StoreGatewayAccountDraft(
          gatewayId: gatewayId,
          beneficiaryName: beneficiary,
          accountNumber: accountNumber,
        ),
      );
    }

    return result;
  }

  Future<void> _syncStoreGatewayAccounts() async {
    final List<_StoreGatewayAccountDraft> desiredAccounts =
        _collectStoreGatewayAccountDrafts();

    try {
      final Map<String, dynamic> response =
          await Api.get(url: Api.storeGatewayAccountsApi);

      final Set<int> existingAccountIds = <int>{};

      void collect(dynamic source) {
        if (source == null) return;
        if (source is List) {
          for (final dynamic element in source) {
            collect(element);
          }
          return;
        }
        if (source is Map<String, dynamic>) {
          final dynamic idValue = source['id'];
          final dynamic gatewayIdValue = source['store_gateway_id'];
          if (idValue != null && gatewayIdValue != null) {
            final int? parsedId = switch (idValue) {
              int value => value,
              num value => value.toInt(),
              String value => int.tryParse(value.trim()),
              Object value => int.tryParse(value.toString()),
              _ => null,
            };
            if (parsedId != null) {
              existingAccountIds.add(parsedId);
            }
          }
          for (final dynamic value in source.values) {
            collect(value);
          }
          return;
        }
        if (source is Map) {
          collect(Map<String, dynamic>.from(source as Map<dynamic, dynamic>));
        }
      }

      collect(response);

      for (final int accountId in existingAccountIds) {
        try {
          await Api.delete(
            url: Api.storeGatewayAccountApi(accountId),
          );
        } catch (_) {
          // Ignore deletion failures for now.
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print('Failed to fetch existing store gateway accounts: $error');
      }
    }

    if (desiredAccounts.isEmpty) {
      return;
    }

    for (final _StoreGatewayAccountDraft account in desiredAccounts) {
      try {
        await Api.post(
          url: Api.storeGatewayAccountsApi,
          parameter: <String, dynamic>{
            'store_gateway_id': account.gatewayId,
            'beneficiary_name': account.beneficiaryName,
            'account_number': account.accountNumber,
            'is_active': true,
          },
        );
      } catch (error) {
        if (kDebugMode) {
          print('Failed to create store gateway account: $error');
        }
      }
    }
  }

  // ???±???§?„ ?§?„?·?„?¨

  Future<void> _submitForm() async {
    final form = _formKey.currentState;
    if (form == null) return;

    form.save();
    final acctType = widget.selectedAccountType;
    final bool passValidation = (acctType == "2" || acctType == "3")
        ? _validateWithoutPhone() // ?†???¬?§???? ???­?‚?‚?§?? ?§?„?€ Form ???†?????®???… ???­?‚?‚ ?…?®?µ?µ
        : (form.validate() && _validateAdditionalFields());

    if (passValidation) {
      try {
        final Map<String, dynamic> payload = {};

        if (widget.selectedAccountType == "2") {
          // ???‚?§?±??
          payload.addAll({
            "office_name": _officeNameController.text.trim(),
            "office_phone": _officePhoneController.text.trim(),
            "office_whatsapp": _officeWhatsappController.text.trim(),
            "office_location": _officeLocationController.text.trim(),
            "phone_number": widget.phoneNumber,
            "country_code": widget.countryCode,
            "account_type": widget.selectedAccountType,
            "contact_info": {
              "office_name": _officeNameController.text.trim(),
              "office_phone": _officePhoneController.text.trim(),
              "office_whatsapp": _officeWhatsappController.text.trim(),
              "office_location": _officeLocationController.text.trim(),
            },
            "latitude": _officeLatitude?.toString(),
            "longitude": _officeLongitude?.toString(),
          });

          if (_officeLogoImage != null) {
            final base64Image =
                base64Encode(_officeLogoImage!.readAsBytesSync());
            payload["office_logo"] = base64Image;
          }
        } else if (widget.selectedAccountType == "3") {
          // ???¬?§?±??
          final List<_StoreGatewayAccountDraft> gatewayAccounts =
              _collectStoreGatewayAccountDrafts();

          final String businessCategoriesString =
              selectedBusinessCategories.map((e) => e.toString()).join(',');

          final List<Map<String, dynamic>> gatewayDetails =
              gatewayAccounts.map((e) => e.toJson()).toList();

          final String normalizedPaymentMethods =
              gatewayAccounts.isEmpty ? '' : 'store_gateway';

          payload.addAll({
            "business_name": _businessNameController.text.trim(),
            "business_phone": _businessPhoneController.text.trim(),
            "business_whatsapp": _businessWhatsappController.text.trim(),
            "business_location": _businessLocationController.text.trim(),
            "business_categories": businessCategoriesString,
            "payment_methods": normalizedPaymentMethods,
            "payment_account_details": gatewayDetails,
            "phone_number": widget.phoneNumber,
            "country_code": widget.countryCode,
            "account_type": widget.selectedAccountType,
            "contact_info": {
              "business_name": _businessNameController.text.trim(),
              "business_phone": _businessPhoneController.text.trim(),
              "business_whatsapp": _businessWhatsappController.text.trim(),
              "business_location": _businessLocationController.text.trim(),
              "business_categories": businessCategoriesString,
              "payment_methods": normalizedPaymentMethods,
              "payment_account_details": gatewayDetails,
            },
          });

          final String staffUsername = _storeStaffEmailController.text.trim();
          if (staffUsername.isNotEmpty) {
            payload['staff'] = {
              'invited_email': staffUsername.toLowerCase(),
            };
          }

          if (_businessLatitude != null && _businessLongitude != null) {
            payload.addAll({
              "latitude": _businessLatitude.toString(),
              "longitude": _businessLongitude.toString(),
            });
          }

          if (_openingTime != null) {
            payload["opening_time"] =
                "${_openingTime!.hour}:${_openingTime!.minute.toString().padLeft(2, '0')}";
          }
          if (_closingTime != null) {
            payload["closing_time"] =
                "${_closingTime!.hour}:${_closingTime!.minute.toString().padLeft(2, '0')}";
          }

          if (_businessLogoImage != null) {
            final base64Image =
                base64Encode(_businessLogoImage!.readAsBytesSync());
            payload["business_logo"] = base64Image;
          }

          if (_commercialRegisterFile != null) {
            final base64File =
                base64Encode(_commercialRegisterFile!.readAsBytesSync());
            final fileName = _commercialRegisterFile!.path.split('/').last;
            payload["commercial_register_file"] = base64File;
            payload["commercial_register_filename"] = fileName;
          }
        } else {
          // ???±????
          payload.addAll({
            "email": _emailController.text,
            "phone_number": widget.phoneNumber,
            "country_code": widget.countryCode,
            "account_type": widget.selectedAccountType,
          });
        }

        final response = await Api.post(
          url: "complete-registration",
          parameter: payload,
        );

        Map<String, dynamic>? storeData;
        if (response['store'] is Map<String, dynamic>) {
          storeData = Map<String, dynamic>.from(
            response['store'] as Map<String, dynamic>,
          );
        }

        if (response['error'] == false) {
          try {
            Map<String, dynamic> latestUserData = {};
            final dynamic responseData = response['data'];

            if (responseData is Map) {
              latestUserData = Map<String, dynamic>.from(
                  responseData as Map<dynamic, dynamic>);
            }

            if (response['token'] != null) {
              HiveUtils.setJWT(response['token'].toString());
            }

            if (latestUserData.isEmpty &&
                (widget.phoneNumber?.isNotEmpty ?? false)) {
              final Map<String, dynamic> loginPayload = {
                Api.mobile: widget.phoneNumber,
                Api.type: "phone",
                "country_code": widget.countryCode ?? "",
              };

              final firebase.User? currentUser =
                  firebase.FirebaseAuth.instance.currentUser;
              if (currentUser != null) {
                loginPayload[Api.firebaseId] = currentUser.uid;
              }

              loginPayload["platform_type"] =
                  Platform.isAndroid ? "android" : "ios";

              try {
                final loginResponse = await Api.post(
                  url: Api.userLoginApi,
                  parameter: loginPayload,
                );

                if (loginResponse['error'] == false &&
                    loginResponse['data'] is Map) {
                  latestUserData = Map<String, dynamic>.from(
                      loginResponse['data'] as Map<dynamic, dynamic>);

                  if (loginResponse['token'] != null) {
                    HiveUtils.setJWT(loginResponse['token'].toString());
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print(
                      'Failed to refresh user data after registration: ${e.toString()}');
                }
              }
            }

            Map<String, dynamic> persistedUser = {};
            try {
              persistedUser = HiveUtils.getUserDetails().toJson();
            } catch (_) {}

            if (latestUserData.isNotEmpty) {
              persistedUser.addAll(latestUserData);
            }

            if (storeData != null) {
              persistedUser['store'] = storeData;
            }

            final String? selectedTypeString = widget.selectedAccountType;
            if (selectedTypeString != null && selectedTypeString.isNotEmpty) {
              final int? parsedType = int.tryParse(selectedTypeString);
              persistedUser['account_type'] = parsedType ?? selectedTypeString;
            }

            if (latestUserData.containsKey('is_verified')) {
              persistedUser['is_verified'] = latestUserData['is_verified'];
            } else {
              persistedUser['is_verified'] = 1;
            }

            final Map<String, dynamic> additionalInfo =
                _toStringKeyedMap(persistedUser['additional_info']);
            final Map<String, dynamic> contactInfo =
                _toStringKeyedMap(additionalInfo['contact_info']);

            if (widget.selectedAccountType == "2") {
              contactInfo['office_name'] = _officeNameController.text.trim();
              contactInfo['office_phone'] = _officePhoneController.text.trim();
              contactInfo['office_whatsapp'] =
                  _officeWhatsappController.text.trim();
              contactInfo['office_location'] =
                  _officeLocationController.text.trim();
              if (_officeLatitude != null) {
                contactInfo['latitude'] = _officeLatitude;
              }
              if (_officeLongitude != null) {
                contactInfo['longitude'] = _officeLongitude;
              }
              if ((_officeSelectedAddress ?? '').isNotEmpty) {
                contactInfo['formatted_address'] = _officeSelectedAddress;
              }
            } else if (widget.selectedAccountType == "3") {
              contactInfo['business_name'] =
                  _businessNameController.text.trim();
              contactInfo['business_phone'] =
                  _businessPhoneController.text.trim();
              contactInfo['business_whatsapp'] =
                  _businessWhatsappController.text.trim();
              contactInfo['business_location'] =
                  _businessLocationController.text.trim();
              contactInfo['business_categories'] =
                  selectedBusinessCategories.map((e) => e.toString()).toList();

              final List<_StoreGatewayAccountDraft> gatewayAccounts =
                  _collectStoreGatewayAccountDrafts();
              if (gatewayAccounts.isNotEmpty) {
                contactInfo['payment_methods'] = 'store_gateway';
                contactInfo['payment_account_details'] =
                    gatewayAccounts.map((e) => e.toJson()).toList();
              } else {
                contactInfo.remove('payment_methods');
                contactInfo.remove('payment_account_details');
              }

              final String staffUsername =
                  _storeStaffEmailController.text.trim().toLowerCase();
              if (staffUsername.isNotEmpty) {
                contactInfo['store_staff_email'] =
                    '$staffUsername@${Constant.storeStaffEmailDomain}';
              }

              if (_businessLatitude != null) {
                contactInfo['latitude'] = _businessLatitude;
              }
              if (_businessLongitude != null) {
                contactInfo['longitude'] = _businessLongitude;
              }
              if ((_businessSelectedAddress ?? '').isNotEmpty) {
                contactInfo['formatted_address'] = _businessSelectedAddress;
              }
              if (_openingTime != null) {
                contactInfo['opening_time'] =
                    "${_openingTime!.hour}:${_openingTime!.minute.toString().padLeft(2, '0')}";
              }
              if (_closingTime != null) {
                contactInfo['closing_time'] =
                    "${_closingTime!.hour}:${_closingTime!.minute.toString().padLeft(2, '0')}";
              }
            }

            if (contactInfo.isNotEmpty ||
                additionalInfo.containsKey('contact_info')) {
              additionalInfo['contact_info'] = contactInfo;
            }
            persistedUser['additional_info'] = additionalInfo;

            HiveUtils.setUserData(persistedUser);
            HiveUtils.setUserIsAuthenticated(true);

            await NotificationService.resendPendingTokenIfNeeded();

            if (mounted) {
              context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());

              FetchSystemSettingsCubit.refreshPermissionsForCurrentUser(
                context,
                clearCacheBeforeFetch: true,
              );
            }

            if (widget.selectedAccountType == "3") {
              await _syncStoreGatewayAccounts();
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to persist registration data: ${e.toString()}');
            }
          }

          HelperUtils.showSnackBarMessage(
            context,
            "registrationCompletedSuccessfully".translate(context),
            messageDuration: 3,
          );

          if (widget.selectedAccountType == "1") {
            // ???±????: ???­?‚?‚ ?§?„?…???‚??
            if (HiveUtils.getCityName() != null &&
                HiveUtils.getCityName() != "" &&
                HiveUtils.getCityName() != "null") {
              HelperUtils.killPreviousPages(
                  context, Routes.main, {"from": "signup"});
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.locationPermissionScreen, (route) => false);
            }
          } else {
            // ???¬?§?±??/???‚?§?±??
            HelperUtils.killPreviousPages(
                context, Routes.main, {"from": "signup"});
          }
        } else {
          HelperUtils.showSnackBarMessage(
            context,
            response['message'] ?? 'registrationError'.translate(context),
            messageDuration: 3,
          );
        }
      } catch (e, stack) {
        // debug
        // print(stack);
        HelperUtils.showSnackBarMessage(
          context,
          "${"unexpectedError".translate(context)}: ${e.toString()}",
          messageDuration: 3,
        );
      }
    }
  }
}

class _StoreGatewayAccountDraft {
  const _StoreGatewayAccountDraft({
    required this.gatewayId,
    required this.beneficiaryName,
    required this.accountNumber,
  });

  final int gatewayId;
  final String beneficiaryName;
  final String accountNumber;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'store_gateway_id': gatewayId,
      'beneficiary_name': beneficiaryName,
      'account_number': accountNumber,
    };
  }
}
