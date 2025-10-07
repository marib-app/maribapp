// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:marib/settings.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/payment/gatways/stripe_service.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:marib/utils/ui_utils.dart';

import 'package:marib/utils/helper_utils.dart';

class PaymentGateways {
  //static PaystackPlugin payStackPlugin = PaystackPlugin();
  static const bool _legacyGatewaysEnabled = false;

  static void _showDisabledMessage(BuildContext context) {
    HelperUtils.showSnackBarMessage(
      context,
      UiUtils.getTranslatedLabel(context, "legacyPaymentDisabled"),
      type: MessageType.warning,
    );
  }

  static String generateReference(String email) {
    late String platform;
    if (Platform.isIOS) {
      platform = 'I';
    } else if (Platform.isAndroid) {
      platform = 'A';
    }
    String reference =
        '${platform}_${email.split("@").first}_${DateTime.now().millisecondsSinceEpoch}';
    return reference;
  }

  static Future<void> stripe(BuildContext context,
      {required double price,
      required int packageId,
      required dynamic paymentIntent}) async {
    if (!_legacyGatewaysEnabled) {
      _showDisabledMessage(context);
      return;
    }

    String paymentIntentId = paymentIntent["id"].toString();
    String clientSecret =
        paymentIntent['payment_gateway_response']["client_secret"].toString();

    await StripeService.payWithPaymentSheet(
      context: context,
      merchantDisplayName: Constant.appName,
      amount: paymentIntent["amount"].toString(),
      currency: AppSettings.stripeCurrency,
      clientSecret: clientSecret,
      paymentIntentId: paymentIntentId,
    );
  }

  static void razorpay(
      {required BuildContext context,
      required price,
      required orderId,
      required packageId}) {
    if (!_legacyGatewaysEnabled) {
      _showDisabledMessage(context);
      return;
    }

    final Razorpay razorpay = Razorpay();

    var options = {
      'key': AppSettings.razorpayKey,
      'amount': price! * 100,
      'name': HiveUtils.getUserDetails().name ?? "",
      'description': '',
      'order_id': orderId,
      'prefill': {
        'contact': HiveUtils.getUserDetails().mobile ?? "",
        'email': HiveUtils.getUserDetails().email ?? ""
      },
      "notes": {"package_id": packageId, "user_id": HiveUtils.getUserId()},
    };

    if (AppSettings.razorpayKey != "") {
      razorpay.open(options);
      razorpay.on(
        Razorpay.EVENT_PAYMENT_SUCCESS,
        (
          PaymentSuccessResponse response,
        ) async {
          await _purchase(context);
        },
      );
      razorpay.on(
        Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
          HelperUtils.showSnackBarMessage(
              context, UiUtils.getTranslatedLabel(context, "purchaseFailed"));
        },
      );
      razorpay.on(
        Razorpay.EVENT_EXTERNAL_WALLET,
        (e) {},
      );
    } else {
      HelperUtils.showSnackBarMessage(
          context, UiUtils.getTranslatedLabel(context, "setAPIkey"));
    }
  }

  static Future<void> _purchase(BuildContext context) async {
    try {
      Future.delayed(
        Duration.zero,
        () {
          HelperUtils.showSnackBarMessage(
              context, UiUtils.getTranslatedLabel(context, "success"),
              type: MessageType.success, messageDuration: 5);

          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );
    } catch (e) {
      HelperUtils.showSnackBarMessage(
          context, UiUtils.getTranslatedLabel(context, "purchaseFailed"),
          type: MessageType.error);
    }
  }
}
