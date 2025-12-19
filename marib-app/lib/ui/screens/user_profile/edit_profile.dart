import 'dart:io';
import 'package:marib/app/app_scroll_behavior.dart';

import 'package:country_picker/country_picker.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/auth_cubit.dart';
import 'package:marib/data/cubits/slider_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/ui/screens/widgets/custom_text_form_field.dart';
import 'package:marib/ui/screens/widgets/image_cropper.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/model/user_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:marib/utils/helper_utils.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/home_screen/home_screen.dart'
    show notificationPermissionChecker;
import 'dart:async';

part 'edit_profile_ui.dart'; // ← واجهة المستخدم مفصولة هنا

class UserProfileScreen extends StatefulWidget {
  final String from;
  final bool? navigateToHome;
  final bool? popToCurrent;
  final AuthenticationType? type;
  final Map<String, dynamic>? extraData;

  const UserProfileScreen({
    super.key,
    required this.from,
    this.navigateToHome,
    this.popToCurrent,
    required this.type,
    this.extraData,
  });

  @override
  State<UserProfileScreen> createState() => UserProfileScreenState();

  static Route route(RouteSettings routeSettings) {
    Map arguments = routeSettings.arguments as Map;
    return BlurredRouter(
      builder: (_) => UserProfileScreen(
        from: arguments['from'] as String,
        popToCurrent: arguments['popToCurrent'] as bool?,
        type: arguments['type'],
        navigateToHome: arguments['navigateToHome'] as bool?,
        extraData: arguments['extraData'],
      ),
    );
  }
}

class UserProfileScreenState extends State<UserProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // حقول إضافية للحسابات التجارية والعقارية
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessLocationController =
      TextEditingController();
  final TextEditingController businessPhoneController = TextEditingController();
  final TextEditingController businessWhatsappController =
      TextEditingController();
  final TextEditingController officeNameController = TextEditingController();
  final TextEditingController officeLocationController =
      TextEditingController();
  final TextEditingController officePhoneController = TextEditingController();
  final TextEditingController officeWhatsappController =
      TextEditingController();

  // متغيرات إضافية للحسابات التجارية والعقارية المحسنة
  File? businessLogoImage; // شعار الشركة/المكتب
  File? commercialRegisterFile; // ملف السجل التجاري
  String? existingBusinessLogoUrl; // رابط الشعار الحالي
  String? existingCommercialRegisterUrl; // رابط السجل التجاري الحالي

  // أوقات العمل للحسابات التجارية
  TimeOfDay? openingTime;
  TimeOfDay? closingTime;

  dynamic size;
  dynamic city, _state, country;
  double? latitude, longitude;
  String? name, email, address;
  File? fileUserimg;
  bool isNotificationsEnabled = true;
  bool isPersonalDetailShow = true;
  bool? isLoading;
  String? countryCode = "+${Constant.defaultCountryCode}";
  int? userType;

// يبدأ الواجهة على وضع الشيمر حتى يكتمل الجلب الكسول
  bool isUiLazyLoading = true;

// لحماية onStartLazyLoad من التشغيل أكثر من مرة
  bool _didLazyKickoff = false;

  // تجهيز الموقع المنسّق (نفس منطقك لكن مختصر للتoggles)
  String? _formattedLocation() {
    if (city != null || _state != null || country != null) {
      return [city, _state, country]
          .where((p) => p != null && p.toString().isNotEmpty)
          .join(', ');
    }
    return null;
  }

  // حفظ فوري عند تبديل سويتش (إشعارات/تفاصيل شخصية)
  Future<bool> _savePrivacyToggle(
      {bool? notifications, bool? personalDetails}) async {
    try {
      // نرسل القيم الحالية + المتغير الذي تغيّر فقط
      final resp = await context.read<AuthCubit>().updateuserdata(
            context,
            name: nameController.text.trim(),
            email: emailController.text.trim(),
            // لا نرفع صورة هنا
            address: addressController.text,
            location: _formattedLocation(),
            mobile: phoneController.text,
            notification: (notifications ?? isNotificationsEnabled) ? "1" : "0",
            countryCode: countryCode,
            personalDetail: (personalDetails ?? isPersonalDetailShow) ? 1 : 0,
            // لا نمرّر additionalData هنا حتى لا نكتب فوق بيانات أخرى
          );

      // مزامنة الحالة المحلية مثل profileupdateprocess
      Future.microtask(() {
        context.read<UserDetailsCubit>().copy(UserModel.fromJson(resp['data']));
      });

      // رسالة نجاح (اختياري)

      //  HelperUtils.showSnackBarMessage(context, resp['message'] ?? "تم الحفظ");

      return true;
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
      return false;
    }
  }

  bool _isNotificationPermissionActive(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return true;
      case PermissionStatus.denied:
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return false;
    }
  }

  Future<PermissionStatus> _requestNotificationPermissionIfNeeded() async {
    try {
      final currentStatus = await Permission.notification.status;
      if (_isNotificationPermissionActive(currentStatus)) {
        return currentStatus;
      }

      await notificationPermissionChecker();

      return await Permission.notification.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  @override
  void initState() {
    super.initState();

    city = HiveUtils.getCityName();
    _state = HiveUtils.getStateName();
    country = HiveUtils.getCountryName();
    latitude = HiveUtils.getLatitude();
    longitude = HiveUtils.getLongitude();

    var userDetails = HiveUtils.getUserDetails();
    userType = userDetails.userType;

    nameController.text = userDetails.name ?? "";
    emailController.text = userDetails.email ?? "";
    addressController.text = userDetails.address ?? "";

    // تحميل البيانات الأساسية حسب نوع الحساب
    if (userType == 2) {
      // حساب عقاري - تحميل البيانات الأساسية أولاً
      officeNameController.text = userDetails.name ?? "";
      officeLocationController.text = userDetails.address ?? "";
      officePhoneController.text = userDetails.mobile ?? "";
      officeWhatsappController.text = userDetails.mobile ?? "";
    } else if (userType == 3) {
      // حساب تجاري - تحميل البيانات الأساسية أولاً
      businessNameController.text = userDetails.name ?? "";
      businessLocationController.text = userDetails.address ?? "";
      businessPhoneController.text = userDetails.mobile ?? "";
      businessWhatsappController.text = userDetails.mobile ?? "";
    }

    // تحميل البيانات الإضافية من additional_info.contact_info
    if (userDetails.additionalInfo != null) {
      Map<String, dynamic> additionalInfo;
      if (userDetails.additionalInfo is Map<String, dynamic>) {
        additionalInfo = userDetails.additionalInfo as Map<String, dynamic>;
      } else if (userDetails.additionalInfo is Map) {
        additionalInfo =
            Map<String, dynamic>.from(userDetails.additionalInfo as Map);
      } else {
        additionalInfo = <String, dynamic>{};
      }

      Map<String, dynamic>? contactInfo;
      if (additionalInfo['contact_info'] is Map<String, dynamic>) {
        contactInfo = additionalInfo['contact_info'] as Map<String, dynamic>;
      } else if (additionalInfo['contact_info'] is Map) {
        contactInfo =
            Map<String, dynamic>.from(additionalInfo['contact_info'] as Map);
      }

      print("Debug - User Type: $userType");
      print("Debug - Additional Info: $additionalInfo");
      print("Debug - Contact Info: $contactInfo");

      if (userType == 2) {
        String officeName = contactInfo?['office_name'] ??
            additionalInfo['office_name'] ??
            userDetails.additionalInfo?['office_name']?.toString() ??
            officeNameController.text;
        String officeLocation = contactInfo?['office_location'] ??
            additionalInfo['office_location'] ??
            userDetails.additionalInfo?['office_location']?.toString() ??
            officeLocationController.text;
        String officePhone = contactInfo?['office_phone'] ??
            additionalInfo['office_phone'] ??
            userDetails.additionalInfo?['office_phone']?.toString() ??
            officePhoneController.text;
        String officeWhatsapp = contactInfo?['office_whatsapp'] ??
            additionalInfo['office_whatsapp'] ??
            userDetails.additionalInfo?['office_whatsapp']?.toString() ??
            officeWhatsappController.text;

        officeNameController.text = officeName;
        officeLocationController.text = officeLocation;
        officePhoneController.text = officePhone;
        officeWhatsappController.text = officeWhatsapp;

        print("Debug - Office Data Loaded:");
        print("  Name: $officeName");
        print("  Location: $officeLocation");
        print("  Phone: $officePhone");
        print("  WhatsApp: $officeWhatsapp");

        existingBusinessLogoUrl = contactInfo?['office_logo'] ??
            additionalInfo['office_logo'] ??
            userDetails.additionalInfo?['office_logo']?.toString();
      } else if (userType == 3) {
        String businessName = contactInfo?['business_name'] ??
            additionalInfo['business_name'] ??
            userDetails.additionalInfo?['business_name']?.toString() ??
            businessNameController.text;
        String businessLocation = contactInfo?['business_location'] ??
            additionalInfo['business_location'] ??
            userDetails.additionalInfo?['business_location']?.toString() ??
            businessLocationController.text;
        String businessPhone = contactInfo?['business_phone'] ??
            additionalInfo['business_phone'] ??
            userDetails.additionalInfo?['business_phone']?.toString() ??
            businessPhoneController.text;
        String businessWhatsapp = contactInfo?['business_whatsapp'] ??
            additionalInfo['business_whatsapp'] ??
            userDetails.additionalInfo?['business_whatsapp']?.toString() ??
            businessWhatsappController.text;

        businessNameController.text = businessName;
        businessLocationController.text = businessLocation;
        businessPhoneController.text = businessPhone;
        businessWhatsappController.text = businessWhatsapp;

        print("Debug - Business Data Loaded:");
        print("  Name: $businessName");
        print("  Location: $businessLocation");
        print("  Phone: $businessPhone");
        print("  WhatsApp: $businessWhatsapp");

        String? openingTimeStr = contactInfo?['opening_time'] ??
            additionalInfo['opening_time'] ??
            userDetails.additionalInfo?['opening_time']?.toString();
        String? closingTimeStr = contactInfo?['closing_time'] ??
            additionalInfo['closing_time'] ??
            userDetails.additionalInfo?['closing_time']?.toString();

        if (openingTimeStr != null && openingTimeStr.isNotEmpty) {
          List<String> openingParts = openingTimeStr.split(':');
          if (openingParts.length == 2) {
            openingTime = TimeOfDay(
              hour: int.tryParse(openingParts[0]) ?? 0,
              minute: int.tryParse(openingParts[1]) ?? 0,
            );
            print("Debug - Opening Time Loaded: $openingTime");
          }
        }

        if (closingTimeStr != null && closingTimeStr.isNotEmpty) {
          List<String> closingParts = closingTimeStr.split(':');
          if (closingParts.length == 2) {
            closingTime = TimeOfDay(
              hour: int.tryParse(closingParts[0]) ?? 0,
              minute: int.tryParse(closingParts[1]) ?? 0,
            );
            print("Debug - Closing Time Loaded: $closingTime");
          }
        }

        existingBusinessLogoUrl = contactInfo?['business_logo'] ??
            additionalInfo['business_logo'] ??
            userDetails.additionalInfo?['business_logo']?.toString();
        existingCommercialRegisterUrl =
            contactInfo?['commercial_register_file'] ??
                additionalInfo['commercial_register_file'] ??
                userDetails.additionalInfo?['commercial_register_file']
                    ?.toString();

        print("Debug - Business Logo URL: $existingBusinessLogoUrl");
        print(
            "Debug - Commercial Register URL: $existingCommercialRegisterUrl");
      }
    } else {
      print("Debug - No additional info found");

      var userDetails = HiveUtils.getUserDetails();
      if (userType == 2) {
        String officeName =
            userDetails.additionalInfo?['office_name']?.toString() ??
                officeNameController.text;
        String officeLocation =
            userDetails.additionalInfo?['office_location']?.toString() ??
                officeLocationController.text;
        String officePhone =
            userDetails.additionalInfo?['office_phone']?.toString() ??
                officePhoneController.text;
        String officeWhatsapp =
            userDetails.additionalInfo?['office_whatsapp']?.toString() ??
                officeWhatsappController.text;

        officeNameController.text = officeName;
        officeLocationController.text = officeLocation;
        officePhoneController.text = officePhone;
        officeWhatsappController.text = officeWhatsapp;

        existingBusinessLogoUrl =
            userDetails.additionalInfo?['office_logo']?.toString();

        print("Debug - Office Data Loaded from Basic Fields:");
        print("  Name: ${officeNameController.text}");
        print("  Location: ${officeLocationController.text}");
        print("  Phone: ${officePhoneController.text}");
        print("  WhatsApp: ${officeWhatsappController.text}");
      } else if (userType == 3) {
        String businessName =
            userDetails.additionalInfo?['business_name']?.toString() ??
                businessNameController.text;
        String businessLocation =
            userDetails.additionalInfo?['business_location']?.toString() ??
                businessLocationController.text;
        String businessPhone =
            userDetails.additionalInfo?['business_phone']?.toString() ??
                businessPhoneController.text;
        String businessWhatsapp =
            userDetails.additionalInfo?['business_whatsapp']?.toString() ??
                businessWhatsappController.text;

        businessNameController.text = businessName;
        businessLocationController.text = businessLocation;
        businessPhoneController.text = businessPhone;
        businessWhatsappController.text = businessWhatsapp;

        existingBusinessLogoUrl =
            userDetails.additionalInfo?['business_logo']?.toString();
        existingCommercialRegisterUrl =
            userDetails.additionalInfo?['commercial_register_file']?.toString();

        String? openingTimeStr =
            userDetails.additionalInfo?['opening_time']?.toString();
        String? closingTimeStr =
            userDetails.additionalInfo?['closing_time']?.toString();

        if (openingTimeStr != null && openingTimeStr.isNotEmpty) {
          List<String> openingParts = openingTimeStr.split(':');
          if (openingParts.length == 2) {
            openingTime = TimeOfDay(
              hour: int.tryParse(openingParts[0]) ?? 0,
              minute: int.tryParse(openingParts[1]) ?? 0,
            );
          }
        }

        if (closingTimeStr != null && closingTimeStr.isNotEmpty) {
          List<String> closingParts = closingTimeStr.split(':');
          if (closingParts.length == 2) {
            closingTime = TimeOfDay(
              hour: int.tryParse(closingParts[0]) ?? 0,
              minute: int.tryParse(closingParts[1]) ?? 0,
            );
          }
        }

        print("Debug - Business Data Loaded from Basic Fields:");
        print("  Name: ${businessNameController.text}");
        print("  Location: ${businessLocationController.text}");
        print("  Phone: ${businessPhoneController.text}");
        print("  WhatsApp: ${businessWhatsappController.text}");
        print("  Opening Time: $openingTime");
        print("  Closing Time: $closingTime");
      }
    }

    if (widget.from == "login") {
      isNotificationsEnabled = true;
    } else {
      isNotificationsEnabled = userDetails.notification == 1 ? true : false;
    }

    if (widget.from == "login") {
      isPersonalDetailShow = true;
    } else {
      isPersonalDetailShow =
          userDetails.isPersonalDetailShow == 1 ? true : false;
    }

    if (HiveUtils.getCountryCode() != null) {
      countryCode = (HiveUtils.getCountryCode() != null
          ? HiveUtils.getCountryCode()!
          : "");
      phoneController.text = userDetails.mobile != null
          ? userDetails.mobile!.replaceFirst("+$countryCode", "")
          : "";
    } else {
      phoneController.text =
          userDetails.mobile != null ? userDetails.mobile! : "";
    }
  }

  @override
  void dispose() {
    super.dispose();
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    businessNameController.dispose();
    businessLocationController.dispose();
    businessPhoneController.dispose();
    businessWhatsappController.dispose();
    officeNameController.dispose();
    officeLocationController.dispose();
    officePhoneController.dispose();
    officeWhatsappController.dispose();
    businessLogoImage = null;
    commercialRegisterFile = null;
  }

  void _onTapVerifyPhoneNumber() {
    //verify phone number before update
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;

    // 👇 واجهة المستخدم مفصولة بالكامل في EditProfileUI (ملف edit_profile_ui.dart)
    return buildUserProfileScreenUI(
      context: context,
      state: this,
      formKey: _formKey,
      isLoading: isLoading,
      isNotificationsEnabled: isNotificationsEnabled,
      isPersonalDetailShow: isPersonalDetailShow,
      countryCode: countryCode,
      userType: userType,

      // Controllers
      phoneController: phoneController,
      nameController: nameController,
      emailController: emailController,
      addressController: addressController,
      businessNameController: businessNameController,
      businessLocationController: businessLocationController,
      businessPhoneController: businessPhoneController,
      businessWhatsappController: businessWhatsappController,
      officeNameController: officeNameController,
      officeLocationController: officeLocationController,
      officePhoneController: officePhoneController,
      officeWhatsappController: officeWhatsappController,

      // Files & images
      fileUserimg: fileUserimg,
      businessLogoImage: businessLogoImage,
      existingBusinessLogoUrl: existingBusinessLogoUrl,
      existingCommercialRegisterUrl: existingCommercialRegisterUrl,
      commercialRegisterFile: commercialRegisterFile,

      // Times
      openingTime: openingTime,
      closingTime: closingTime,

      // Location
      city: city,
      stateName: _state,
      country: country,
      latitude: latitude,
      longitude: longitude,

      // Callbacks (المنطق يبقى هنا)
      onSubmit: () {
        if (widget.from == 'login') {
          validateData();
        } else {
          if (city != null && city != "") {
            HiveUtils.setCurrentLocation(
              city: city,
              state: _state,
              country: country,
              latitude: latitude,
              longitude: longitude,
            );
            unawaited(context.read<SliderCubit>().fetchSlider(context));
          } else {
            HiveUtils.clearLocation();
            unawaited(context.read<SliderCubit>().fetchSlider(context));
          }
          validateData();
        }
      },
      onShowPicker: showPicker,
      onSelectCountryCode: showCountryCode,
      onPickLogoImage: _pickLogoImage,
      onPickCommercialRegister: _pickCommercialRegisterFile,
      onSelectTime: _selectTime,

      // ✅ تحديث فوري + رجوع عند الفشل
      onToggleNotifications: (v) async {
        final old = isNotificationsEnabled;

        setState(() => isNotificationsEnabled = v); // Optimistic UI

        if (v) {
          final status = await _requestNotificationPermissionIfNeeded();

          if (!_isNotificationPermissionActive(status)) {
            if (!mounted) return;
            setState(() => isNotificationsEnabled = old);
            HelperUtils.showSnackBarMessage(
              context,
              "turnOnNotification".translate(context),
            );
            return;
          }
        }

        final ok = await _savePrivacyToggle(notifications: v); // حفظ فعلي

        if (!ok && mounted)
          setState(() => isNotificationsEnabled = old); // تراجع
      },
      onTogglePersonalDetail: (v) async {
        final old = isPersonalDetailShow;
        setState(() => isPersonalDetailShow = v); // Optimistic UI
        final ok = await _savePrivacyToggle(personalDetails: v); // حفظ فعلي
        if (!ok && mounted) setState(() => isPersonalDetailShow = old); // تراجع
      },

      setCountryCode: (value) {
        countryCode = value;
        setState(() {});
      },
      setPhoneReadOnly:
          HiveUtils.getUserDetails().type == AuthenticationType.phone.name
              ? true
              : false,

      // —————— التحميل الكسول + الشيمر ——————
      isLazyLoading: isUiLazyLoading,
      onStartLazyLoad: () async {
        // حماية من التكرار
        if (_didLazyKickoff) return;
        _didLazyKickoff = true;

        try {
          // ✳️ ضع هنا جلبك الكسول فقط (إن لزم)
          // مثال:
          // final user = HiveUtils.getUserDetails();
          // nameController.text = user.name ?? "";
          // emailController.text = user.email ?? "";
          // addressController.text = user.address ?? "";
          // ...الخ
        } catch (e) {
          // يمكن عرض Snackbar/Log هنا
        } finally {
          if (mounted) setState(() => isUiLazyLoading = false);
        }
      },
    );
  }

  Future<void> validateData() async {
    if (_formKey.currentState!.validate()) {
      profileupdateprocess();
    }
  }

  profileupdateprocess() async {
    setState(() {
      isLoading = true;
    });
    try {
      String? formattedLocation;
      if (city != null || _state != null || country != null) {
        formattedLocation = [city, _state, country]
            .where((part) => part != null && part.toString().isNotEmpty)
            .join(', ');
      }

      Map<String, dynamic>? additionalData;
      if (userType == 2) {
        additionalData = {
          'contact_info': {
            'office_name': officeNameController.text.trim(),
            'office_location': officeLocationController.text.trim(),
            'office_phone': officePhoneController.text.trim(),
            'office_whatsapp': officeWhatsappController.text.trim(),
          }
        };

        if (existingBusinessLogoUrl != null && businessLogoImage == null) {
          additionalData!['contact_info']['office_logo'] =
              existingBusinessLogoUrl;
        }
      } else if (userType == 3) {
        additionalData = {
          'contact_info': {
            'business_name': businessNameController.text.trim(),
            'business_location': businessLocationController.text.trim(),
            'business_phone': businessPhoneController.text.trim(),
            'business_whatsapp': businessWhatsappController.text.trim(),
          }
        };

        if (openingTime != null) {
          additionalData!['contact_info']['opening_time'] =
              "${openingTime!.hour}:${openingTime!.minute.toString().padLeft(2, '0')}";
        }

        if (closingTime != null) {
          additionalData!['contact_info']['closing_time'] =
              "${closingTime!.hour}:${closingTime!.minute.toString().padLeft(2, '0')}";
        }

        if (existingBusinessLogoUrl != null && businessLogoImage == null) {
          additionalData!['contact_info']['business_logo'] =
              existingBusinessLogoUrl;
        }

        if (existingCommercialRegisterUrl != null &&
            commercialRegisterFile == null) {
          additionalData!['contact_info']['commercial_register_file'] =
              existingCommercialRegisterUrl;
        }
      }

      var response = await context.read<AuthCubit>().updateuserdata(context,
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          fileUserimg: fileUserimg,
          address: addressController.text,
          location: formattedLocation,
          mobile: phoneController.text,
          notification: isNotificationsEnabled == true ? "1" : "0",
          countryCode: countryCode,
          personalDetail: isPersonalDetailShow == true ? 1 : 0,
          additionalData: additionalData);

      Future.delayed(
        Duration.zero,
        () {
          context
              .read<UserDetailsCubit>()
              .copy(UserModel.fromJson(response['data']));
        },
      );

      Future.delayed(
        Duration.zero,
        () {
          setState(() {
            isLoading = false;
          });
          HelperUtils.showSnackBarMessage(
            context,
            response['message'],
          );
          if (widget.from != "login") {
            Navigator.pop(context);
          }
        },
      );

      if (widget.from == "login" && widget.popToCurrent != true) {
        Future.delayed(
          Duration.zero,
          () {
            if (HiveUtils.getCityName() != null &&
                HiveUtils.getCityName() != "") {
              HelperUtils.killPreviousPages(
                  context, Routes.main, {"from": widget.from});
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                  Routes.main, (route) => false);
            }
          },
        );
      } else if (widget.from == "login" && widget.popToCurrent == true) {
        Future.delayed(Duration.zero, () {
          Navigator.of(context)
            ..pop()
            ..pop();
        });
      }
    } catch (e) {
      Future.delayed(Duration.zero, () {
        setState(() {
          isLoading = false;
        });
        HelperUtils.showSnackBarMessage(context, e.toString());
      });
    }
  }

  void showPicker() {
    showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.transparent),
            borderRadius: BorderRadius.circular(10)),
        builder: (BuildContext bc) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: Text("gallery".translate(context)),
                    onTap: () {
                      _imgFromGallery(ImageSource.gallery);
                      Navigator.of(context).pop();
                    }),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: Text("camera".translate(context)),
                  onTap: () {
                    _imgFromGallery(ImageSource.camera);
                    Navigator.of(context).pop();
                  },
                ),
                if (fileUserimg != null && widget.from == 'login')
                  ListTile(
                    leading: const Icon(Icons.clear_rounded),
                    title: Text("lblremove".translate(context)),
                    onTap: () {
                      fileUserimg = null;

                      Navigator.of(context).pop();
                      setState(() {});
                    },
                  ),
              ],
            ),
          );
        });
  }

  _imgFromGallery(ImageSource imageSource) async {
    final pickedFile = await ImagePicker().pickImage(source: imageSource);

    if (pickedFile != null) {
      CroppedFile? croppedFile;
      croppedFile = await CropImage.crop(
        context: context,
        filePath: pickedFile.path,
      );
      if (croppedFile == null) {
        fileUserimg = null;
      } else {
        fileUserimg = File(croppedFile.path);
      }
    } else {
      fileUserimg = null;
    }
    setState(() {});
  }

  void showCountryCode() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme:
          CountryListThemeData(borderRadius: BorderRadius.circular(11)),
      onSelect: (Country value) {
        countryCode = value.phoneCode;
        setState(() {});
      },
    );
  }

  void _pickLogoImage(bool isOffice) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        businessLogoImage = File(pickedFile.path);
      });
    }
  }

  void _pickCommercialRegisterFile() async {
    // سيتم تطبيق هذه الوظيفة لاحقاً مع file_picker package
    HelperUtils.showSnackBarMessage(
      context,
      "featureWillBeAvailableSoon".translate(context),
    );
  }

  Future<void> _selectTime(bool isOpeningTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpeningTime
          ? (openingTime ?? TimeOfDay.now())
          : (closingTime ?? TimeOfDay.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.color.territoryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpeningTime) {
          openingTime = picked;
        } else {
          closingTime = picked;
        }
      });
    }
  }
}
