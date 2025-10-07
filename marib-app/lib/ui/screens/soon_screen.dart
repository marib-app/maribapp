import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';

import 'package:marib/ui/screens/subscription/packages_list.dart';

// استيراد صريح لتفادي التعارض
import 'package:marib/utils/payment/bank_transfer_screen.dart'
    show BankTransferScreen;
import 'package:marib/utils/payment/bank_transfer_args.dart'
    show BankTransferArgs;
import 'package:marib/utils/payment/manual_payment_service.dart'
    show ManualPaymentSubmissionResult;

class SoonScreen extends StatefulWidget {
  const SoonScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const SoonScreen());
  }

  @override
  State<SoonScreen> createState() => SoonScreenState();
}

class SoonScreenState extends State<SoonScreen> with TickerProviderStateMixin {
  Future<void> _openBankTransferForPackage({
    required int packageId,
    required double amount,
    String currency = 'YER',
    required String packageType, // 'item_listing' | 'advertisement' | 'user'
    int? itemId,
  }) async {
    final token = HiveUtils.getJWT();
    if (token.isEmpty) {
      // UiUtils.showSnackBarMessage(context, "سجّل الدخول أولاً");
      return;
    }

    final result = await Navigator.of(context).push(
      BankTransferScreen.route(
        RouteSettings(
          name: '/bank-transfer',
          arguments: BankTransferArgs(
            token: token,
            packageId: packageId,
            amount: amount,
            currency: currency,
            packageType: packageType,
            purpose: 'package',
            itemId: itemId,
          ),
        ),
      ),
    );

    if (!mounted) return;
    final success = result is ManualPaymentSubmissionResult
        ? result.success
        : result == true;
    if (success) {
      // UiUtils.showSnackBarMessage(context, "تم رفع الإيصال وبانتظار المراجعة");
      // UiUtils.showSnackBarMessage(context, "تم رفع الإيصال وبانتظار المراجعة");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.primaryColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "soon".translate(context),
          bottomHeight: 20,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/svg/soon.svg', width: 200, height: 200),
              const SizedBox(height: 20),
              Text(
                "Coming Soon",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.color.territoryColor,
                ),
              ),
              const SizedBox(height: 40),

              // شاشة الباقات (كما هي)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.territoryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final res = await Navigator.of(context).push(
                    SubscriptionPackageListScreen.route(
                      const RouteSettings(
                        name: '/subscription-packages',
                        arguments: {'source': 'soon_screen_test'},
                      ),
                    ),
                  );
                  if (res == true) {
                    // UiUtils.showSnackBarMessage(context, "✅ Package Activated!");
                  }
                },
                child: const Text("جرّب شاشة الباقات",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 14),

              // اختبار التحويل البنكي مباشرةً
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      context.color.territoryColor.withOpacity(0.85),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  const pkgId = 1;
                  const amount = 5000.0;
                  const currency = 'YER';
                  const packageType = 'item_listing';
                  await _openBankTransferForPackage(
                    packageId: pkgId,
                    amount: amount,
                    currency: currency,
                    packageType: packageType,
                    itemId: null,
                  );
                },
                child: const Text("ادفع الآن (تحويل بنكي)",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
