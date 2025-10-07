// شاشة محسنة لطلب صلاحيات الموقع مع نصوص وتجربة مستخدم احترافية
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/api.dart';



class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();

  static Route route(RouteSettings routeSettings) => MaterialPageRoute(builder: (_) => const LocationPermissionScreen());
}



class _LocationPermissionScreenState extends State<LocationPermissionScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _openedAppSettings = false;
  bool _isLoading = false;
  late AnimationController _fadeController;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeController.forward();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _saveLocationToAPI(double lat, double lng, Placemark p) async {
    // ✅ إذا المستخدم غير مسجّل، ما نرسل شيء
    if (!HiveUtils.isUserAuthenticated()) return;

    final user = HiveUtils.getUserDetails();

    // ✅ فقط للمستخدمين من نوع معين (مثلاً: 1 = مستخدم عادي)
    if (user.userType != 1) return;

    // ✅ إرسال الموقع إلى السيرفر
    await Api.post(
      url: "save-user-location",
      parameter: {
        "latitude": lat.toString(),
        "longitude": lng.toString(),
        "area": p.subLocality ?? '',
        "city": p.locality ?? '',
        "state": p.administrativeArea ?? '',
        "country": p.country ?? '',
      },
    );
  }

  Future<void> _setDefaultLocationAndNavigate() async {
    try {
      // ✅ نستخدم الإحداثيات الافتراضية من الثوابت
      final lat = double.parse(Constant.defaultLatitude);
      final lng = double.parse(Constant.defaultLongitude);

      // ✅ نحصل على اسم المنطقة بناءً على الإحداثيات
      final placemarks = await placemarkFromCoordinates(lat, lng);
      final p = placemarks.first;

      // ✅ إذا كان التطبيق في الوضع التجريبي، لا نحفظ الموقع
      if (Constant.isDemoModeOn) {
        UiUtils.setDefaultLocationValue(
          isCurrent: false,
          isHomeUpdate: false,
          context: context,
        );
      } else {
        // ✅ نحفظ الموقع في التخزين المحلي
        HiveUtils.setLocation(
          area: p.subLocality,
          city: p.locality ?? '',
          state: p.administrativeArea ?? '',
          country: p.country ?? '',
          latitude: lat,
          longitude: lng,
        );

        // ✅ نرسل الموقع للسيرفر
        await _saveLocationToAPI(lat, lng, p);
      }

      // ✅ ننتقل للصفحة الرئيسية بعد حفظ الموقع
      HelperUtils.killPreviousPages(context, Routes.main, {"from": "login"});
    } catch (_) {
      _showSnack("فشل في استخدام الموقع الافتراضي");
    } finally {
      setState(() => _isLoading = false);
    }
  }



  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    // ✅ التأكد أن خدمة الموقع مفعلة بالجهاز (GPS)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack("الرجاء تفعيل خدمة الموقع");
      setState(() => _isLoading = false);
      return;
    }

    // ✅ التحقق من حالة الصلاحيات
    LocationPermission permission = await Geolocator.checkPermission();

    // ❌ إذا مرفوضة بشكل دائم، نوجّه المستخدم للإعدادات
    if (permission == LocationPermission.deniedForever) {
      _showSnack("يرجى تفعيل صلاحيات الموقع من الإعدادات");
      await openAppSettings();
      _openedAppSettings = true;
      setState(() => _isLoading = false);
      return;
    }

    // ✅ إذا مرفوضة بشكل مؤقت، نطلبها
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        await _setDefaultLocationAndNavigate();
        return;
      }

      // ✅ ننتظر شوي بعد الموافقة قبل المحاولة
      await Future.delayed(const Duration(seconds: 2));
    }

    try {
      // ✅ المحاولة الأولى للحصول على الموقع
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // ❌ إذا رجعت الإحداثيات صفر، نعيد المحاولة مرة ثانية
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        await Future.delayed(const Duration(seconds: 2));
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      }

      // ✅ تحويل الإحداثيات إلى بيانات مكانية (مدينة، منطقة...)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks[0];

        if (Constant.isDemoModeOn) {
          UiUtils.setDefaultLocationValue(
            isCurrent: false,
            isHomeUpdate: false,
            context: context,
          );
        } else {
          HiveUtils.setLocation(
            area: p.subLocality,
            city: p.locality ?? '',
            state: p.administrativeArea ?? '',
            country: p.country ?? '',
            latitude: position.latitude,
            longitude: position.longitude,
          );
          await _saveLocationToAPI(position.latitude, position.longitude, p);
        }

        // ✅ التنقل إلى الصفحة الرئيسية بعد حفظ الموقع
        HelperUtils.killPreviousPages(context, Routes.main, {"from": "login"});
      }
    } catch (e) {
      // ❌ في حال فشل التحديد لأي سبب
      _showSnack("تعذّر الحصول على موقعك الحالي");
    }

    setState(() => _isLoading = false);
  }


  void _showSnack(String message) {
    UiUtils.showSoftSnackBar(
      context,
      message: message,
      iconPath: 'assets/image/showSoftSnackBar.png',
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.black.withOpacity(0.4),
      backgroundOpacity: 0.9,
      textColor: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
            child: Column(
              children: [
                const Spacer(),

                /// 🔹 أنميشن الموقع
                Lottie.asset('assets/lottie/location.json', width: 200, height: 200),

                const SizedBox(height: 30),

                /// 🔹 العنوان
                Text("لتجربة افضل حدد موقعك  📍")
                    .size(context.font.larger + 2)
                    .bold()
                    .centerAlign(),

                const SizedBox(height: 20),
                /// 🔹 بطاقة موحدة للشرح + الخصوصية
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.color.background.withOpacity(0.01),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: context.color.textDefaultColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /// 📝 الشرح
                      Text(
                        "كل ما حولك ... بين يديك ",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.font.larger,
                          color: context.color.textDefaultColor.withOpacity(0.85),
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// 🔒 الخصوصية
                      Text(
                        "🔒 خصوصيتك محفوظة، موقعك الجغرافي يُستخدم لتحسين تجربتك داخل التطبيق فقط.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.font.small,
                          color: context.color.textDefaultColor.withOpacity(0.7),
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                /// 🔘 زر تحديد موقعي
                _buildActionButton(
                  title: "🔎 تحديد موقعي الآن",
                  onPressed: _isLoading ? () {} : _getCurrentLocation,
                ),

                const SizedBox(height: 14),

                /// 🔘 زر التجاوز
                _buildActionButton(
                  title: "الاستمرار بدون تحديد الموقع",
                  onPressed: _isLoading
                      ? () {}
                      : () {
                    UiUtils.setDefaultLocationValue(
                      isCurrent: false,
                      isHomeUpdate: false,
                      context: context,
                    );
                    HelperUtils.killPreviousPages(
                      context,
                      Routes.main,
                      {"from": "login"},
                    );
                  },
                  outline: true,
                ),

                const SizedBox(height: 36),

                /// 🔄 تحميل
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _isLoading
                      ? Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text("جارٍ تحديد موقعك...")
                          .size(context.font.normal)
                          .color(context.color.textDefaultColor),
                    ],
                  )
                      : const SizedBox.shrink(),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }





  Widget _buildActionButton({
    required String title,
    required VoidCallback onPressed,
    bool outline = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        splashColor: context.color.territoryColor.withOpacity(0.3), // تأثير الموجة عند الضغط
        highlightColor: context.color.territoryColor.withOpacity(0.1), // تأثير الإضاءة عند الضغط
        child: UiUtils.buildButton(
          context,
          buttonTitle: title,
          onPressed: onPressed,
          buttonColor: outline ? context.color.backgroundColor : context.color.territoryColor,
          textColor: outline ? context.color.territoryColor : context.color.secondaryColor,
          border: outline
              ? BorderSide(color: context.color.territoryColor.withOpacity(0.5))
              : BorderSide.none,
          height: 46,
          radius: 10,
          showElevation: !outline,
        ),
      ),
    );
  }

}

