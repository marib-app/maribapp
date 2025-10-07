import 'package:flutter/foundation.dart';

/// مفاتيح التحكم في تشغيل/إيقاف الميزات داخل التطبيق
class FeatureFlags {
  const FeatureFlags._();

  static bool? _deliveryPricingOverride;

  /// هل ميزة تسعير/توصيل مفعّلة؟
  static bool get deliveryPricingEnabled {
    // أولوية ١: القيمة التي تحدد يدوياً في وقت التشغيل
    if (_deliveryPricingOverride != null) {
      return _deliveryPricingOverride!;
    }

    // أولوية ٢: وضع debug يقرأ من متغير dart-define
    if (kDebugMode) {
      return const bool.fromEnvironment(
        'delivery_pricing_enabled_debug',
        defaultValue: true, // افتراضي مفعّل بالـ debug
      );
    }

    // أولوية ٣: الوضع العادي (release/profile)
    return const bool.fromEnvironment(
      'delivery_pricing_enabled',
      defaultValue: true, // افتراضي مفتوح بالإنتاج
    );
  }

  /// تغيير القيمة يدوياً وقت التشغيل (مثلاً لتعطيل مؤقت)
  static void setDeliveryPricingEnabledOverride(bool? enabled) {
    _deliveryPricingOverride = enabled;
  }
}
