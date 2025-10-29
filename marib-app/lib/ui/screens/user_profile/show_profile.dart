import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// التنقل + المسارات
import 'package:marib/app/routes.dart';

// Cubits / بيانات
import 'package:marib/data/cubits/auth/auth_cubit.dart';
import 'package:marib/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:marib/data/cubits/profile/profile_stats_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/model/user_model.dart';

// أدوات واجهة
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/image_cropper.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';

// التقاط الصور
import 'package:image_picker/image_picker.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart' as auth;

// واجهة العرض المكوّنة في ملف منفصل
import 'show_profile_ui.dart';

// Utilities
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/app/app_scroll_behavior.dart';

// شاشة عرض الملف الشخصي + الوصول لأزرار:
// - مشاركة الملف الشخصي
// - تعديل الملف الشخصي (مع تمرير allowProfileRoute للسماح بالمسار)
class ShowUserProfileScreen extends StatefulWidget {
  final String from;
  final bool? navigateToHome;
  final bool? popToCurrent;
  final auth.AuthenticationType? type;
  final Map<String, dynamic>? extraData;

  const ShowUserProfileScreen({
    super.key,
    required this.from,
    this.navigateToHome,
    this.popToCurrent,
    required this.type,
    this.extraData,
  });

  /// الراوت الثابت لإنشاء الصفحة بموفّرات Cubit اللازمة.
  /// ملاحظة: يتم إنشاء Cubits جديدة لكل فتح للشاشة (سلوك مقصود هنا).
  static Route route(RouteSettings routeSettings) {
    final arguments = routeSettings.arguments as Map;

    return BlurredRouter(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ProfileStatsCubit()),
          BlocProvider(create: (_) => FetchMyItemsCubit()),
          BlocProvider(create: (_) => UserDetailsCubit()),
        ],
        child: ShowUserProfileScreen(
          from: arguments['from'] as String,
          popToCurrent: arguments['popToCurrent'] as bool?,
          type: arguments['type'],
          navigateToHome: arguments['navigateToHome'] as bool?,
          extraData: arguments['extraData'],
        ),
      ),
    );
  }

  @override
  State<ShowUserProfileScreen> createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<ShowUserProfileScreen>
    with SingleTickerProviderStateMixin {
  // ========= Controllers / State =========
  // ملاحظة: _formKey و validateData موجودين للحفاظ على التوافق — إن لم تحتاجهما يمكنك إزالتهما لاحقاً.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // حقول بيانات أساسية
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // مواقع محفوظة (لترويسات/معلومات)
  String? city, country;
  double? latitude, longitude;

  // صورة المستخدم المحلية إن تم اختيارها
  File? fileUserimg;

  // إعدادات الخصوصية والإشعارات
  bool isNotificationsEnabled = true;
  bool isPersonalDetailShow = true;

  // حالة حفظ/تحديث (تُظهر لودينغ إن لزم)
  bool? isLoading;

  // تبويبات الإعلانات (ثابتة)
  final List<Map<String, String>> adTabs = const [
    {"title": "allAds", "status": ""},
    {"title": "live", "status": "approved"},
    {"title": "underReview", "status": "review"},
    {"title": "expired", "status": "expired"},
    {"title": "rejected", "status": "rejected"},
    {"title": "soldOut", "status": "sold out"},
  ];

  late final TabController _tabController;

  // Getters لتسهيل تمريرها للـ UI
  TabController get tabController => _tabController;

  List<Map<String, String>> get tabs => adTabs;

  @override
  void initState() {
    super.initState();

    // تحكم التبويبات (يجب التخلص منه في dispose)
    _tabController = TabController(length: adTabs.length, vsync: this);

    // تحميل تبويب البداية (الكل)
    final status = adTabs[0]["status"] ?? "";
    context.read<FetchMyItemsCubit>().fetchMyItems(getItemsWithStatus: status);

    // قراءة مواقع محفوظة
    city = HiveUtils.getCityName();
    country = HiveUtils.getCountryName();
    latitude = HiveUtils.getLatitude();
    longitude = HiveUtils.getLongitude();

    // جلب إحصائيات عند توفر جلسة مستخدم
    if (HiveUtils.isUserAuthenticated()) {
      context.read<ProfileStatsCubit>().fetchProfileStats();
    }

    // تعبئة الحقول من بيانات المستخدم المخزنة
    final user = HiveUtils.getUserDetails();
    nameController.text = user.name ?? "";
    emailController.text = user.email ?? "";
    addressController.text = user.address ?? "";

    if (widget.from == "login") {
      // أثناء تسجيل الدخول: افتراضيات آمنة
      isNotificationsEnabled = true;
      isPersonalDetailShow = true;
    } else {
      // خارج تسجيل الدخول: خُذ الإعدادات الفعلية للمستخدم
      isNotificationsEnabled = user.notification == 1;
      isPersonalDetailShow = user.isPersonalDetailShow == 1;
    }

    // تنسيق رقم الهاتف حسب كود الدولة
    final cc = HiveUtils.getCountryCode();
    if (cc != null) {
      phoneController.text =
          user.mobile != null ? user.mobile!.replaceFirst("+$cc", "") : "";
    } else {
      phoneController.text = user.mobile ?? "";
    }

    // (اختياري) تهيئة أداة القص مرة واحدة لو كانت التهيئة ثقيلة:
    // CropImage.init(context);
  }

  @override
  void dispose() {
    // مهم: التخلص من الموارد لتفادي تسريب الذاكرة
    _tabController.dispose();
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // إغلاق لوحة المفاتيح عند النقر خارج الحقول
      onTap: () => FocusScope.of(context).unfocus(),
      child: safeAreaCondition(
        child: Scaffold(
          backgroundColor: context.color.primaryColor,
          appBar: widget.from == "login"
              ? null
              : UiUtils.buildAppBar(
                  // عنوان الشريط
                  title: "profileTab".translate(context),
                  context,
                  showBackButton: true,
                  actions: const [],
                ),

          /// ملاحظة:
          /// - استخدمنا ScrollConfiguration+Bouncing لمنح سحب لطيف.
          /// - تم إبقاء الواجهة الفعلية في ProfileScreenUI (ملف منفصل) لتبسيط الصيانة.
          body: ScrollConfiguration(
            behavior: RemoveGlow(),
            child: SingleChildScrollView(
              physics: AppScrollBehavior.defaultPhysics,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ProfileScreenUI(
                // التبويبات + الحالات
                tabController: _tabController,
                adTabs: adTabs,

                // زر "تعديل الملف الشخصي":
                // نمرّر allowProfileRoute=true حتى لا يعترضه الحارس الموجود في الراوتر.
                onEditProfilePressed: () {
                  HelperUtils.goToNextPage(
                    Routes.completeProfile,
                    context,
                    false,
                    args: {
                      "from": "profile",
                      "allowProfileRoute": true, // ← ضروري للسماح بالانتقال
                    },
                  );
                },

                // زر "مشاركة الملف" (جاهز للتنفيذ لاحقًا)
                onShareProfilePressed: () {
                  // TODO: منطق المشاركة (Share API / Dynamic Links ...)
                },

                // زر تغيير صورة الحساب (يفتح BottomSheet)
                onAvatarEditPressed: showPicker,

                // باني صورة الحساب
                buildProfileImage: getProfileImage,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// تطبيق SafeArea فقط لو أتت الشاشة من مسار "login" (حسب منطقك الحالي)
  Widget safeAreaCondition({required Widget child}) {
    if (widget.from == "login") return SafeArea(child: child);
    return child;
  }

  /// صورة الحساب:
  /// - إن وُجدت صورة محلية مختارة: عرضها مع تقليل الدقة (cacheWidth/Height) لتقليل RAM.
  /// - إن وُجد رابط صورة: الاعتماد على UiUtils.getImage (يفضّل أن يكون CachedNetworkImage).
  /// - وإلا: عرض SVG افتراضي.
  Widget getProfileImage() {
    if (fileUserimg != null) {
      // ⚠️ ضبط cacheWidth/Height لخفض الاستهلاك (اضبط الأبعاد حسب تصميم Avatar لديك)
      return Image.file(
        fileUserimg!,
        fit: BoxFit.cover,
        cacheWidth: 256,
        cacheHeight: 256,
      );
      // بديل:
      // return Image(
      //   image: ResizeImage(FileImage(fileUserimg!), width: 256, height: 256),
      //   fit: BoxFit.cover,
      // );
    }

    final profile = HiveUtils.getUserDetails().profile ?? "";
    if (profile.isNotEmpty) {
      return UiUtils.getImage(profile, fit: BoxFit.cover);
    }

    return UiUtils.getSvg(
      AppIcons.defaultPersonLogo,
      color: context.color.territoryColor,
      fit: BoxFit.none,
    );
  }

  /// التحقق من صحة نموذج (موجود للتوافق إن استدعته الواجهة)
  Future<void> validateData() async {
    if (_formKey.currentState?.validate() == true) {
      await profileupdateprocess();
    }
  }

  Future<bool> profileupdateprocess() async {
    setState(() => isLoading = true);
    try {
      final resp = await context.read<AuthCubit>().updateuserdata(
            context,
            name: nameController.text.trim(),
            email: emailController.text.trim(),
            fileUserimg: fileUserimg,
            address: addressController.text,
            mobile: phoneController.text,
            notification: isNotificationsEnabled ? "1" : "0",
            countryCode: HiveUtils.getCountryCode(),
            personalDetail: isPersonalDetailShow ? 1 : 0,
          );

      // النجاح حسب هيكلة الـ API عندك:
      final bool ok = (resp['status'] == 1) || (resp['success'] == true);

      // حدّث بيانات المستخدم محليًا لو نجح
      if (ok) {
        Future.microtask(() {
          context
              .read<UserDetailsCubit>()
              .copy(UserModel.fromJson(resp['data']));
        });
      }

      setState(() => isLoading = false);

      // ⚠️ مهم: لا تعرض أي رسالة هنا. فقط أعد النتيجة.
      return ok;
    } catch (e) {
      setState(() => isLoading = false);
      // هنا ممكن تعرض رسالة خطأ فقط لو تحب (أو ترجع false وتترك الرسالة للطبقة المستدعية)
      HelperUtils.showSnackBarMessage(context, e.toString());
      return false;
    }
  }

  /// BottomSheet لاختيار مصدر الصورة (كاميرا/ألبوم) + إزالة الصورة المؤقتة أثناء login
  void showPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      builder: (bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text("gallery".translate(context)),
                onTap: () {
                  _imgFromGallery(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
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
                    setState(() {}); // تحديث الواجهة لإزالة المعاينة
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// التقاط/اختيار صورة + قصّها ثم الاحتفاظ بها محليًا قبل الرفع
  Future<void> _imgFromGallery(ImageSource imageSource) async {
    final pickedFile = await ImagePicker().pickImage(source: imageSource);

    if (pickedFile != null) {
      final croppedFile = await CropImage.crop(
        context: context,
        filePath: pickedFile.path,
      );

      fileUserimg = croppedFile == null ? null : File(croppedFile.path);
    } else {
      fileUserimg = null;
    }

    setState(() {}); // لإعادة بناء الصورة المعروضة
  }
}
