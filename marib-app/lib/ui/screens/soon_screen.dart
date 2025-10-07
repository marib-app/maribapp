import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/hive_utils.dart';

import 'package:marib/ui/screens/subscription/packages_list.dart';

// استيراد صريح لتفادي التعارض
import 'package:marib/utils/payment/bank_transfer_screen.dart' show BankTransferScreen;
import 'package:marib/utils/payment/bank_transfer_args.dart' show BankTransferArgs;
import 'package:marib/utils/payment/manual_payment_service.dart'
    show ManualPaymentSubmissionResult;










import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SoonScreen extends StatelessWidget {
  const SoonScreen({super.key});
  static Route route(RouteSettings s) => MaterialPageRoute(builder: (_) => const SoonScreen());

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      // يزيل الوهج الأزرق نهائيًا
      behavior: const _NoGlowBehavior(),
      child: Scaffold(
        appBar: AppBar(title: const Text('تمرير متزن بلا وهج')),
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is OverscrollNotification) {
              HapticFeedback.lightImpact(); // اهتزاز خفيف فقط
            }
            return false;
          },
          child: ListView.builder(
            physics: const ClampingScrollPhysics(), // تمرير ثابت بلا ارتداد
            itemCount: 40,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemBuilder: (c, i) => Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text('عنصر ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('تجربة تمرير هادئ بلا شدّ ولا وهج'),
              ),
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF6F7FB),
      ),
    );
  }
}

class _NoGlowBehavior extends MaterialScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // لا Glow ولا Stretch
  }
}
