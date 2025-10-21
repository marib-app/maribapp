import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// أدوات مساعدة موحّدة لضبط شريط الحالة في واجهات تسجيل الدخول.
///
/// - تحافظ على لون محايد مستمد من الثيم.
/// - تختار سطوع الأيقونات تلقائيًا استنادًا إلى قيمة [computeLuminance].
/// - توفّر ودجت جاهزًا لحجز مساحة شريط الحالة بنفس اللون.
class LoginStatusBar {
  const LoginStatusBar._();

  /// اللون الافتراضي المستخدم لشريط الحالة.
  static Color resolveBaseColor(BuildContext context, {Color? override}) {
    final theme = Theme.of(context);
    return override ?? theme.colorScheme.surface;
  }

  /// يعيد [SystemUiOverlayStyle] مطابق للّون المحدد مع اختيار سطوع الأيقونات تلقائيًا.
  static SystemUiOverlayStyle overlayFor(
      BuildContext context, {
        Color? baseColor,
      }) {
    final color = resolveBaseColor(context, override: baseColor);
    final useDarkIcons = color.computeLuminance() > 0.5;

    return (useDarkIcons ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
        .copyWith(
      statusBarColor: color,
      statusBarIconBrightness:
      useDarkIcons ? Brightness.dark : Brightness.light,
      statusBarBrightness: useDarkIcons ? Brightness.light : Brightness.dark,
    );
  }

  /// ودجت بسيط يشغل ارتفاع شريط الحالة ويملأه بنفس اللون المحايد.
  static Widget topSpacer(
      BuildContext context, {
        Color? baseColor,
      }) {
    final height = MediaQuery.of(context).padding.top;
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      height: height,
      color: resolveBaseColor(context, override: baseColor),
    );
  }
}