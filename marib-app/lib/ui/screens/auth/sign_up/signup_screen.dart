// FILE: lib/ui/screens/auth/sign_up/signup_screen.dart
// Refactored: المنطق هنا فقط + استدعاء واجهات من signup_sections.dart و account_type_selector.dart
import 'package:flutter/foundation.dart';

import 'dart:io';
import 'dart:convert';
import 'package:flutter_svg/svg.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/cloudState/cloud_state.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:marib/data/cubits/system/user_details.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/utils/api.dart';
import 'package:country_picker/country_picker.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:file_picker/file_picker.dart';

// الواجهات المفصولة
import 'package:marib/ui/screens/auth/sign_up/widgets/account_type_selector.dart';
import 'package:marib/ui/screens/auth/sign_up/widgets/signup_shared_widgets.dart';
import 'package:marib/ui/screens/auth/sign_up/widgets/real_estate_section.dart';
import 'package:marib/ui/screens/auth/sign_up/widgets/business_section.dart';
import 'dart:async'; // للـ Timer

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

  static BlurredRouter route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;

    return BlurredRouter(
      builder: (context) {
        return SignupScreen(
          selectedAccountType: args?['selectedAccountType'],
          phoneNumber: args?['phoneNumber'],
          countryCode: args?['countryCode'],
          fromSocialLogin: args?['fromSocialLogin'] ?? false,
        );
      },
    );
  }

  @override
  CloudState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends CloudState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final TextEditingController _emailController = TextEditingController();

  // حقول العقاري (نوع 2)
  final TextEditingController _officeNameController = TextEditingController();
  final TextEditingController _officePhoneController = TextEditingController();
  final TextEditingController _officeWhatsappController =
      TextEditingController();
  final TextEditingController _officeLocationController =
      TextEditingController();

  // حقول التجاري (نوع 3)
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessPhoneController =
      TextEditingController();
  final TextEditingController _businessWhatsappController =
      TextEditingController();
  final TextEditingController _businessLocationController =
      TextEditingController();
  final TextEditingController _commercialRegisterController =
      TextEditingController();

  // قوائم للحساب التجاري
  List<int> selectedBusinessCategories = [];
  List<String> selectedPaymentMethods = [];
  final Map<String, TextEditingController> paymentAccountControllers = {};

  // صور/ملفات
  File? _officeLogoImage;
  File? _businessLogoImage;
  File? _commercialRegisterFile;
  final ImagePicker _picker = ImagePicker();

  // الموقع
  double? _latitude, _longitude;
  String? _selectedAddress;
  bool _isLocationLoading = false;

  // الموقع لكل نوع
  double? _officeLatitude, _officeLongitude;
  String? _officeSelectedAddress;
  double? _businessLatitude, _businessLongitude;
  String? _businessSelectedAddress;

  // أوقات العمل (تجاري)
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

  // أوقات العمل (افتراضي: جميع الأيام غير متاحة)
  Map<String, dynamic> _workingHours = {
    "sat": {"enabled": false, "from": null, "to": null},
    "sun": {"enabled": false, "from": null, "to": null},
    "mon": {"enabled": false, "from": null, "to": null},
    "tue": {"enabled": false, "from": null, "to": null},
    "wed": {"enabled": false, "from": null, "to": null},
    "thu": {"enabled": false, "from": null, "to": null},
    "fri": {"enabled": false, "from": null, "to": null},
  };

  // وسائل الدفع
  final Map<String, String> paymentMethods = const {
    "bank_sharq": "bankSharqYemeni",
    "easy_cash": "easyCashPoint",
    "bank_tadamon": "bankTadamonIslamic",
    "mahfazti_tadamon": "mahfaztiTadamon",
    "bank_karimi": "bankKarimi",
    "al_shabaka": "alShabakaInternalTransfers",
  };

  String? countryCode;
  String? flagEmoji = "🇾🇪";

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
      });
    }
  }

  // اختيار صورة
  Future<void> _pickImage(String type) async {
    try {
      // ابدأ "رفع" واجهةً
      if (type == 'office_logo') {
        setState(() {
          _officeLogoUploading = true;
          _officeLogoProgress = null; // أو قيمة 0..1 إذا عندك تقدم حقيقي
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

      // محاكاة رفع سريع لإظهار اللودر (احذف التأخير لو عندك رفع حقيقي)
      await Future.delayed(const Duration(milliseconds: 400));

      // أنهِ الرفع + فعّل تلميح النجاح 3 ثواني
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
      // أنهِ الرفع في حال الخطأ
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

  // اختيار ملف السجل التجاري

// لو بتستخدم kIsWeb:

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
      // 1) فتح منتقي الملفات (ما نفعّل اللودر هنا لأن نافذة النظام تغطي الواجهة)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExt,
        withData: true, // مهم للويب
      );

      if (result == null) return; // المستخدم ألغى

      final picked = result.files.single;
      final ext = (picked.extension ?? '').toLowerCase();

      // تحقق الامتداد
      if (!_allowedExt.contains(ext)) {
        HelperUtils.showSnackBarMessage(
          context,
          "fileTypeNotAllowed".translate(context),
          messageDuration: 3,
        );
        return;
      }

      // تحقق الحجم
      final size = picked.size;
      if (size > _maxFileSizeBytes) {
        HelperUtils.showSnackBarMessage(
          context,
          "fileTooLarge".translate(context), // "الحجم يتجاوز 10MB"
          messageDuration: 3,
        );
        return;
      }

      // 2) احفظ الملف المختار
      if (kIsWeb) {
        if (picked.bytes == null) {
          HelperUtils.showSnackBarMessage(
            context,
            "fileReadError".translate(context),
            messageDuration: 3,
          );
          return;
        }
        // حفظ/رفع مباشرة بالـ bytes عندك إن احتجت:
        // _webFileBytes = picked.bytes!;
        // _webFileName  = picked.name;
        setState(() {
          _commercialRegisterFile =
              null; // لا نملك File على الويب، احتفظ بالاسم فقط إن شئت
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

      // 3) فعّل اللودر أثناء "الرفع الفعلي"
      setState(() => isUploading = true);
      try {
        // TODO: ارفع الملف للسيرفر هنا
        // await api.uploadCommercialRegister(_commercialRegisterFile or picked.bytes);
        await Future.delayed(const Duration(seconds: 1)); // محاكاة رفع
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
      // _webFileBytes = null; _webFileName = null; // للويب إن وجِد
    });
  }

  // اختيار الوقت
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

  // الموقع الحالي
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
          // عقاري
          _officeLatitude = position.latitude;
          _officeLongitude = position.longitude;
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            _officeSelectedAddress =
                "${placemark.street}, ${placemark.locality}, ${placemark.country}";
            _officeLocationController.text = _officeSelectedAddress ?? "";
          }
        } else if (widget.selectedAccountType == "3") {
          // تجاري
          _businessLatitude = position.latitude;
          _businessLongitude = position.longitude;
          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            _businessSelectedAddress =
                "${placemark.street}, ${placemark.locality}, ${placemark.country}";
            _businessLocationController.text = _businessSelectedAddress ?? "";
          }
        } else {
          // فردي
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

  // زر الموقع
  VoidCallback _getLocationCallback() {
    return _isLocationLoading ? () {} : _getCurrentLocation;
  }

  // منتقي الدولة
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

  @override
  void dispose() {
    _emailController.dispose();
    _officeNameController.dispose();
    _officePhoneController.dispose();
    _officeWhatsappController.dispose();
    _officeLocationController.dispose();
    _businessNameController.dispose();
    _businessWhatsappController.dispose();
    _businessLocationController.dispose();
    _commercialRegisterController.dispose();
    paymentAccountControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      // الخلفية العامة
      backgroundColor: context.color.backgroundColor,

      // الجسم: خلفية متدرجة + محتوى داخل SafeArea (top: true) حتى لا نرسم تحت شريط الحالة
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
          // <-- هنا الأهم
          top: true, // احجز مساحة شريط الحالة بالأعلى (يبقى ثابت ومرئي)
          bottom:
              false, // خليه يرسم حتى آخر الشاشة (نضبط الـ inset بالسفل عند الكيبورد يدويًا)
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              // ===== الهيدر: شعار + عبارة ترحيبية =====
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

              // ===== المحتوى (جسم النموذج) =====
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
                            AccountTypeSelector(
                              value: currentSelectedAccountType,
                              onChanged: (v) => setState(
                                  () => currentSelectedAccountType = v),
                              onContinue: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SignupScreen(
                                      selectedAccountType:
                                          currentSelectedAccountType,
                                      phoneNumber: widget.phoneNumber,
                                      countryCode: widget.countryCode,
                                      fromSocialLogin: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],

                          // العقاري
                          if (widget.selectedAccountType == "2") ...[
                            RealEstateSection(
                              logo: _officeLogoImage,
                              onPickLogo: () => _pickImage('office_logo'),
                              officeName: _officeNameController,
                              officePhone: _officePhoneController,
                              officeWhatsapp: _officeWhatsappController,
                              officeLocation: _officeLocationController,
                              prefixText:
                                  "${flagEmoji ?? "🇾🇪"} ${countryCode ?? "+967"}",
                              onPickCountry: _showCountryPicker,
                              isLocationLoading: _isLocationLoading,
                              onGetLocation: _getLocationCallback(),

                              // ⬇️ مهم لعرض اللودر/التلميح
                              isLogoUploading: _officeLogoUploading,
                              logoUploadProgress: _officeLogoProgress,
                              showLogoPreviewHint: _officeLogoPreviewHint,
                            )
                          ],

                          // التجاري
                          if (widget.selectedAccountType == "3") ...[
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
                                      "${flagEmoji ?? "🇾🇪"} ${countryCode ?? "+967"}",
                                  onPickCountry: _showCountryPicker,
                                  isLocationLoading: _isLocationLoading,
                                  onGetLocation: _getLocationCallback(),
                                  categories: cats,
                                  selectedCategoryIds:
                                      selectedBusinessCategories,
                                  onToggleCategory: (id) {
                                    setState(() {
                                      if (selectedBusinessCategories
                                          .contains(id)) {
                                        selectedBusinessCategories.remove(id);
                                      } else {
                                        selectedBusinessCategories.add(id);
                                      }
                                    });
                                  },
                                  openingTime: _openingTime,
                                  closingTime: _closingTime,
                                  onPickOpening: () =>
                                      _selectTime(context, true),
                                  onPickClosing: () =>
                                      _selectTime(context, false),
                                  paymentMethods: paymentMethods,
                                  selectedPaymentMethods:
                                      selectedPaymentMethods,
                                  paymentControllers: paymentAccountControllers,
                                  onTogglePayment: (key, isSelected) {
                                    setState(() {
                                      if (isSelected) {
                                        if (!selectedPaymentMethods
                                            .contains(key)) {
                                          selectedPaymentMethods.add(key);
                                          paymentAccountControllers[key] =
                                              TextEditingController();
                                        }
                                      } else {
                                        selectedPaymentMethods.remove(key);
                                        paymentAccountControllers[key]
                                            ?.dispose();
                                        paymentAccountControllers.remove(key);
                                      }
                                    });
                                  },
                                  getAccountHint: _getAccountHint,

                                  // ⬇️ مهم: أوقات الدوام (الجديد)
                                  workingHours: _workingHours,
                                  onChangedWorkingHours: (updated) {
                                    setState(() {
                                      _workingHours =
                                          updated; // خزّنها أو أرسلها للكيوبيت/الباك-إند
                                    });
                                  },

                                  // اختياري: عرض/تحميل الشعار
                                  isLogoUploading: _businessLogoUploading,
                                  logoUploadProgress: _businessLogoProgress,
                                  showLogoPreviewHint: _businessLogoPreviewHint,
                                );
                              },
                            ),
                          ],

                          // الأفراد
                          if (widget.selectedAccountType == "1" ||
                              widget.selectedAccountType == "individual") ...[
                            EmailOnlySection(emailController: _emailController),
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

  String _getAccountHint(String paymentKey) {
    switch (paymentKey) {
      case "bank_sharq":
        return "bankSharqAccountNumber".translate(context);
      case "easy_cash":
        return "easyCashAccountNumber".translate(context);
      case "bank_tadamon":
        return "bankTadamonAccountNumber".translate(context);
      case "mahfazti_tadamon":
        return "mahfaztiTadamonNumber".translate(context);
      case "bank_karimi":
        return "bankKarimiAccountNumber".translate(context);
      case "al_shabaka":
        return "alShabakaAccountName".translate(context);
      default:
        return "accountNumberOrName".translate(context);
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
    // نوع 3 (تجاري): نتحقق من الاسم/الموقع/الأقسام فقط — بدون هاتف/واتساب
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
    }

    // نوع 2 (عقاري): لا نجعل أي حقل إجباري الآن
    return true;
  }

  Map<String, dynamic> _toStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _collectSelectedPaymentAccounts() {
    final Map<String, dynamic> result = {};
    for (final entry in paymentAccountControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        result[entry.key] = text;
      }
    }
    return result;
  }

  // إرسال الطلب

  Future<void> _submitForm() async {
    final form = _formKey.currentState;
    if (form == null) return;

    form.save();
    final acctType = widget.selectedAccountType;
    final bool passValidation = (acctType == "2" || acctType == "3")
        ? _validateWithoutPhone() // نتجاوز تحققات الـ Form ونستخدم تحقق مخصص
        : (form.validate() && _validateAdditionalFields());

    if (passValidation) {
      try {
        final Map<String, dynamic> payload = {};

        if (widget.selectedAccountType == "2") {
          // عقاري
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
          // تجاري
          final Map<String, String> accountDetails = {};
          for (final paymentMethod in selectedPaymentMethods) {
            final value = paymentAccountControllers[paymentMethod]?.text;
            if (value != null && value.isNotEmpty) {
              accountDetails[paymentMethod] = value;
            }
          }

          final businessCategoriesString =
              selectedBusinessCategories.map((e) => e.toString()).join(',');

          payload.addAll({
            "business_name": _businessNameController.text.trim(),
            "business_phone": _businessPhoneController.text.trim(),
            "business_whatsapp": _businessWhatsappController.text.trim(),
            "business_location": _businessLocationController.text.trim(),
            "business_categories": businessCategoriesString,
            "payment_methods": selectedPaymentMethods.join(','),
            "payment_account_details": accountDetails,
            "phone_number": widget.phoneNumber,
            "country_code": widget.countryCode,
            "account_type": widget.selectedAccountType,
            "contact_info": {
              "business_name": _businessNameController.text.trim(),
              "business_phone": _businessPhoneController.text.trim(),
              "business_whatsapp": _businessWhatsappController.text.trim(),
              "business_location": _businessLocationController.text.trim(),
              "business_categories": businessCategoriesString,
              "payment_methods": selectedPaymentMethods.join(','),
              "payment_account_details": accountDetails,
            },
          });

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
          // فردي
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

        if (response['error'] == false) {
          try {
            Map<String, dynamic> latestUserData = {};
            final dynamic responseData = response['data'];

            if (responseData is Map) {
              latestUserData = Map<String, dynamic>.from(responseData);
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
              contactInfo['payment_methods'] =
                  List<String>.from(selectedPaymentMethods);

              final Map<String, dynamic> accountDetails =
                  _collectSelectedPaymentAccounts();
              if (accountDetails.isNotEmpty) {
                contactInfo['payment_account_details'] = accountDetails;
              } else {
                contactInfo.remove('payment_account_details');
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

            if (mounted) {
              context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());
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
            // فردي: تحقق الموقع
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
            // تجاري/عقاري
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
      } catch (e) {
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

/*

  // إرسال الطلب
  Future<void> _submitForm() async {
    final form = _formKey.currentState;
    if (form == null) return;

    form.save();
    if (form.validate() && _validateAdditionalFields()) {
      try {
        final Map<String, dynamic> payload = {};

        if (widget.selectedAccountType == "2") {
          // عقاري
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
          // تجاري
          final Map<String, String> accountDetails = {};
          for (final paymentMethod in selectedPaymentMethods) {
            final value = paymentAccountControllers[paymentMethod]?.text;
            if (value != null && value.isNotEmpty) {
              accountDetails[paymentMethod] = value;
            }
          }

          final businessCategoriesString =
          selectedBusinessCategories.map((e) => e.toString()).join(',');

          payload.addAll({
            "business_name": _businessNameController.text.trim(),
            "business_phone": _businessPhoneController.text.trim(),
            "business_whatsapp": _businessWhatsappController.text.trim(),
            "business_location": _businessLocationController.text.trim(),
            "business_categories": businessCategoriesString,
            "payment_methods": selectedPaymentMethods.join(','),
            "payment_account_details": accountDetails,
            "phone_number": widget.phoneNumber,
            "country_code": widget.countryCode,
            "account_type": widget.selectedAccountType,
            "contact_info": {
              "business_name": _businessNameController.text.trim(),
              "business_phone": _businessPhoneController.text.trim(),
              "business_whatsapp":
              _businessWhatsappController.text.trim(),
              "business_location":
              _businessLocationController.text.trim(),
              "business_categories": businessCategoriesString,
              "payment_methods": selectedPaymentMethods.join(','),
              "payment_account_details": accountDetails,
            },
          });

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
            final fileName =
                _commercialRegisterFile!.path.split('/').last;
            payload["commercial_register_file"] = base64File;
            payload["commercial_register_filename"] = fileName;
          }
        } else {
          // فردي
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

        if (response['error'] == false) {
          HelperUtils.showSnackBarMessage(
            context,
            "registrationCompletedSuccessfully".translate(context),
            messageDuration: 3,
          );

          if (widget.selectedAccountType == "1") {
            // فردي: تحقق الموقع
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
            // تجاري/عقاري
            HelperUtils.killPreviousPages(
                context, Routes.main, {"from": "signup"});
          }
        } else {
          HelperUtils.showSnackBarMessage(
            context,
            response['message'] ??
                'registrationError'.translate(context),
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

  */
}
