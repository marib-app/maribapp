import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/utils/ui_utils.dart';

import 'widgets/manual_payment_tile.dart';

class ManualPaymentDetailsScreen extends StatelessWidget {
  const ManualPaymentDetailsScreen({
    super.key,
    required this.manualPayment,
    required this.dateFormat,
    required this.pollInterval,
  });

  final ManualPayment manualPayment;
  final DateFormat dateFormat;
  final Duration pollInterval;

  static Future<void> push(
    BuildContext context, {
    required ManualPayment manualPayment,
    required DateFormat dateFormat,
    required Duration pollInterval,
  }) {
    return Navigator.of(context).push(
      BlurredRouter(
        builder: (_) => ManualPaymentDetailsScreen(
          manualPayment: manualPayment,
          dateFormat: dateFormat,
          pollInterval: pollInterval,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: colors.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: colors.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: 'تفاصيل المعاملة',
          bottomHeight: 12,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: ManualPaymentTile(
              manualPayment: manualPayment,
              dateFormat: dateFormat,
              pollInterval: pollInterval,
            ),
          ),
        ),
      ),
    );
  }
}
