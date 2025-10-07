// payment_coordinator.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/ui/screens/subscription/payment_gatways.dart'; // PaymentGateways + PaymentWebView
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/data/cubits/subscription/get_payment_intent_cubit.dart';

import 'package:marib/utils/payment/gatways/payment_webview.dart';
// أو:

enum PayGateway { stripe, paystack, phonepe }

class PaymentRequest {
  final PayGateway gateway;
  final int? itemId; // للترويج/تمييز إعلان
  final int? packageId; // للباقات
  final int? days; // عدد الأيام (للتمييز)
  final num amount; // الإجمالي
  final Map<String, dynamic> extra;
  PaymentRequest({
    required this.gateway,
    required this.amount,
    this.itemId,
    this.packageId,
    this.days,
    this.extra = const {},
  });
}

/// 1) طلب إنشاء Payment Intent عبر Cubit (بدون إرجاع قيمة؛ الإصغاء يكون عبر BlocListener)
class PaymentCoordinator {
  static Future<void> requestIntent(
      BuildContext context, PaymentRequest r) async {
    final method = switch (r.gateway) {
      PayGateway.stripe => "Stripe",
      PayGateway.paystack => "Paystack",
      PayGateway.phonepe => "PhonePe",
    };
    context.read<GetPaymentIntentCubit>().getPaymentIntent(
          paymentMethod: method,
          // مرّر مرجع مناسب (باقة/إعلان). backend عندك يتعامل معها.
          packageId: r.packageId ?? r.itemId ?? 0,
          // لو داعم: extra: {"purpose": r.itemId!=null?"feature":"package","item_id":r.itemId,"days":r.days,"amount":r.amount}
        );
  }

  /// 2) تنفيذ الدفع بعد نجاح الـ intent (تستدعى من BlocListener)
  static Future<void> pay(
    BuildContext context,
    PaymentRequest r,
    Map<String, dynamic> intent, {
    required Future<void> Function() onServerApply,
    required VoidCallback onSuccessUI,
  }) async {
    switch (r.gateway) {
      case PayGateway.stripe:
        await PaymentGateways.stripe(
          context,
          price: r.amount.toDouble(),
          packageId: (r.packageId ?? r.itemId)!,
          paymentIntent: intent,
        );
        await onServerApply();
        onSuccessUI();
        break;

      case PayGateway.paystack:
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentWebView(
                authorizationUrl: intent["payment_gateway_response"]["data"]
                    ["authorization_url"],
                reference: intent["payment_gateway_response"]["data"]
                    ["reference"],
                onSuccess: (_) async {
                  await onServerApply();
                  onSuccessUI();
                },
                onFailed: (_) =>
                    HelperUtils.showSnackBarMessage(context, 'فشل الدفع'),
                onCancel: () =>
                    HelperUtils.showSnackBarMessage(context, 'تم إلغاء الدفع'),
              ),
            ));
        break;

      case PayGateway.phonepe:
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentWebView(
                authorizationUrl: intent["payment_gateway_response"],
                onSuccess: (_) async {
                  await onServerApply();
                  onSuccessUI();
                },
                onFailed: (_) =>
                    HelperUtils.showSnackBarMessage(context, 'فشل الدفع'),
                onCancel: () =>
                    HelperUtils.showSnackBarMessage(context, 'تم إلغاء الدفع'),
              ),
            ));
        break;
    }
  }
}
