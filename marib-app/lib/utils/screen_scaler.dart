import 'package:flutter/material.dart';

/// 📐 كلاس لحساب "النسبة الموحدة" للتصميم المتجاوب عبر كل الأجهزة
/// يعتمد على أقصر ضلع للشاشة ويحول أي رقم إلى قيمة متوازنة بصريًا
class ScreenScaler {
  static late double scale;

  /// 📌 استدعها في بداية التطبيق (مثلاً في main أو Splash) مرة واحدة فقط
  static void init(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    scale = shortestSide / 375; // المرجع: عرض شاشة iPhone 11 = 375
  }

  /// 📏 استخدمها لأي قيمة: عرض، ارتفاع، خط، padding، margin، radius...
  static double s(num value) => value * scale;

  /// حجم الخط بناءً على scale وعامل تكبير الخط في النظام
  static double fontSize(BuildContext context, {required double baseSize}) {
    return s(baseSize) * MediaQuery.of(context).textScaleFactor;
  }

  /// حجم الأيقونة
  static double iconSize(BuildContext context, {required double baseSize}) {
    return s(baseSize);
  }
}
