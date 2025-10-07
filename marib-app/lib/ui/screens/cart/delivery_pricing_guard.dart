import 'package:marib/config/feature_flags.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:flutter/widgets.dart';

/// حاجز مركزي لإيقاف/تجاوز أي منطق متعلق بتسعير/توصيل
class DeliveryPricingGuard {
  DeliveryPricingGuard._();

  static bool get enabled => FeatureFlags.deliveryPricingEnabled;

  /// إن كانت الميزة متوقفة يرجّع null ويعتبر التسعير غير مطلوب
  static Future<T?> tryCall<T>(Future<T> Function() call) async {
    if (!enabled) return null;
    return await call();
  }

  /// لتبسيط رسائل الخطأ: إن كانت متوقفة لا تعرض أي رسالة تسعير
  static String? normalizeError(Object e) {
    if (!enabled) return null;
    final s = e.toString().toLowerCase();
    if (s.contains('delivery') || s.contains('pricing') || s.contains('404')) {
      return 'حدثت مشكلة في تسعير/التوصيل. حاول لاحقًا.';
    }
    return null;
  }

  /// Converts an arbitrary error into a human friendly message.
  ///
  /// If delivery pricing is disabled or the error isn't related to pricing,
  /// the method falls back to extracting meaningful messages from known
  /// exception shapes returned by the cart APIs.
  static String readableErrorMessage(
    BuildContext context,
    Object error, {
    String? fallback,
  }) {
    final String? normalizedPricingError = normalizeError(error);
    if (normalizedPricingError != null &&
        normalizedPricingError.trim().isNotEmpty) {
      return normalizedPricingError;
    }

    final String fallbackMessage =
        (fallback ?? 'حدث خطأ غير متوقع'.translate(context)).trim();

    String? extracted = _extractErrorMessage(error);
    if (extracted != null && extracted.trim().isNotEmpty) {
      final String readable =
          HelperUtils.readableErrorMessage(context, extracted);
      final String trimmed = readable.trim();
      if (trimmed.isNotEmpty && !_looksLikeDartObject(trimmed)) {
        return trimmed;
      }
    }

    final String stringified = error.toString().trim();
    if (stringified.isNotEmpty && !_looksLikeDartObject(stringified)) {
      final String readable =
          HelperUtils.readableErrorMessage(context, stringified);
      final String trimmed = readable.trim();
      if (trimmed.isNotEmpty && !_looksLikeDartObject(trimmed)) {
        return trimmed;
      }
    }

    return fallbackMessage.isNotEmpty ? fallbackMessage : 'حدث خطأ غير متوقع';
  }

  static bool _looksLikeDartObject(String value) {
    final String lower = value.toLowerCase();
    return lower.startsWith('instance of') || lower == 'null';
  }

  static String? _extractErrorMessage(Object? error, [int depth = 0]) {
    if (error == null) {
      return null;
    }
    if (depth > 6) {
      return null;
    }

    if (error is String) {
      final String trimmed = error.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (error is ApiException) {
      return _extractErrorMessage(error.errorMessage, depth + 1);
    }

    if (error is Iterable) {
      for (final Object? entry in error) {
        final String? candidate = _extractErrorMessage(entry, depth + 1);
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate;
        }
      }
      return null;
    }

    if (error is Map) {
      const List<String> preferredKeys = <String>[
        'message',
        'error',
        'detail',
        'title',
        'description'
      ];
      for (final String key in preferredKeys) {
        if (!error.containsKey(key)) {
          continue;
        }
        final Object? value = error[key];
        final String? candidate = _extractErrorMessage(value, depth + 1);
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate;
        }
      }

      for (final Object? value in error.values) {
        final String? candidate = _extractErrorMessage(value, depth + 1);
        if (candidate != null && candidate.trim().isNotEmpty) {
          return candidate;
        }
      }
      return null;
    }

    return null;
  }
}
