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

class SoonScreen extends StatefulWidget {
  const SoonScreen({super.key});
  static Route route(RouteSettings s) => MaterialPageRoute(builder: (_) => const SoonScreen());
  @override State<SoonScreen> createState() => _SoonScreenState();
}

class _SoonScreenState extends State<SoonScreen> {
  final _scroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scroll.animateTo(600, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic),
        icon: const Icon(Icons.south_rounded), label: const Text('اذهب للنصف'),
      ),
      body: StretchingOverscrollIndicator(
        axisDirection: AxisDirection.down,
        child: CustomScrollView(
          controller: _scroll,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true, stretch: true, expandedHeight: 220,
              title: const Text('🚀 قريباً — تجربة التمرير'),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
                background: Stack(fit: StackFit.expand, children: [
                  Image.network('https://picsum.photos/1000/400?blur=2', fit: BoxFit.cover),
                  Container(color: Colors.black26),
                  Positioned(
                    left: 16, bottom: 16,
                    child: ElevatedButton.icon(
                      onPressed: () {}, icon: const Icon(Icons.info_outline), label: const Text('معلومات'),
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ]),
              ),
            ),

            // عنوان صغير
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: const [
                  Text('قائمة عناصر وهمية', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),

            // قائمة طويلة للتجربة (بدون overflow)
            SliverList.builder(
              itemCount: 30,
              itemBuilder: (c, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Material(
                  color: Colors.white, elevation: 2, borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 128,
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                        child: Image.network('https://picsum.photos/seed/card$i/320/220', width: 140, height: 128, fit: BoxFit.cover),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('عنوان تجريبي ${i + 1}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('وصف تجريبي يوضّح سلوك الالتفاف والتمرير. نص وهمي لملء المساحة.',
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700])),
                            const Spacer(),
                            Row(children: [
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 6),
                              Text('${(4.0 + (i % 5) * 0.1).toStringAsFixed(1)}'),
                              const Spacer(),
                              SizedBox(
                                height: 36,
                                child: FilledButton.tonal(onPressed: () {}, child: const Text('تفاصيل')),
                              ),
                            ]),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),

            // مساحة إعلان + ذيل
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 60),
                child: Column(children: [
                  Container(
                    height: 92, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('مساحة إعلان تجريبية — 300×250')),
                  ),
                  const SizedBox(height: 16),
                  const Text('نهاية المعاينة — اسحب لشدّ الرأس/الذيل', style: TextStyle(color: Colors.black54)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
