// نسخة محسّنة من AddClassified لتجربة مستخدم مرنة واحترافية

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/classified_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marquee/marquee.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';



class AddClassified extends StatelessWidget {
  final ClassifiedModel classified;

  const AddClassified({super.key, required this.classified});

  static Route route(RouteSettings settings) {
    final arguments = settings.arguments as Map;
    return BlurredRouter(
      builder: (_) => AddClassified(classified: arguments['model']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = (classified.image ?? '').isNotEmpty;
    final bool isMain = classified.isMain == true;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: classified.title,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16).copyWith(bottom: 100),
              physics: const BouncingScrollPhysics(),
              children: [
                if (isMain)
                  SizedBox(
                    height: ScreenScaler.s(2.6), // ✅ ارتفاع مرن للماركي
                    width: ScreenScaler.s(100),
                    child: Marquee(
                      text: (classified.title ?? '').firstUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.color.textColorDark,
                        fontSize: context.font.large,
                      ),
                      scrollAxis: Axis.horizontal,
                      blankSpace: 40.0,
                      velocity: 30.0,
                      pauseAfterRound: const Duration(seconds: 1),
                      startPadding: 16.0,
                      accelerationDuration: const Duration(milliseconds: 500),
                      accelerationCurve: Curves.linear,
                      decelerationDuration: const Duration(milliseconds: 400),
                      decelerationCurve: Curves.easeOut,
                    ),
                  ),
                const SizedBox(height: 15),

                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ScreenScaler.s(1.5)), // ✅ زوايا ناعمة
                    child: Container(
                      width: ScreenScaler.s(100),
                      height: ScreenScaler.s(25), // ✅ مرن حسب الشاشة
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CachedNetworkImage(
                        imageUrl: classified.image!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ShimmerBox(
                          width: ScreenScaler.s(100),
                          height: ScreenScaler.s(25),
                          borderRadius:
                          BorderRadius.circular(ScreenScaler.s(1.5)),
                        ),
                        errorWidget: (_, __, ___) => ShimmerBox(
                          width: ScreenScaler.s(100),
                          height: ScreenScaler.s(25),
                          borderRadius:
                          BorderRadius.circular(ScreenScaler.s(1.5)),
                          animate: false,
                          baseColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                Text(classified.createdAt.toString().formatDate())
                    .size(context.font.smaller)
                    .color(context.color.textColorDark.withOpacity(0.5)),

                const SizedBox(height: 14),
                Text((classified.title ?? '').firstUpperCase())
                    .size(context.font.large)
                    .color(context.color.textColorDark)
                    .bold(),

                const SizedBox(height: 18),
                // ✅ لعرض وصف الإعلان باستخدام HTML
                FutureBuilder(
                  future: Future.delayed(const Duration(milliseconds: 250)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(height: 60);
                    }
                    return HtmlWidget(
                      classified.description ?? '',
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: context.color.textDefaultColor,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ✅ زر الاستمرار إذا كان الإعلان من النوع الرئيسي
          if (isMain)
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom + 16,
                left: 20,
                right: 20,
              ),
              child: UiUtils.buildButton(
                context,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    Routes.addItemDetails,
                    arguments: {
                      'breadCrumbItems': null,
                      'isEdit': false,
                    },
                  );
                },
                buttonTitle: "continue".translate(context),
                radius: 10,
                disabledColor: const Color.fromARGB(255, 104, 102, 106),
              ),
            ),
        ],
      ),
    );
  }
}







/*
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/classified_model.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class AddClassified extends StatelessWidget {
  final ClassifiedModel classified;

  const AddClassified({super.key, required this.classified});

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map;
    return BlurredRouter(
      builder: (context) {
        return AddClassified(
          classified: arguments['model'],
        );
      },
    );
  }

  String stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    String strippedString = htmlString.replaceAll(exp, '');
    return strippedString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar:
          UiUtils.buildAppBar(context, showBackButton: true, title: classified.title),
      body: Stack(
        children: [
          // المحتوى القابل للتمرير
          Padding(
            padding: const EdgeInsets.only(bottom: 80), // نترك مساحة للزر
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon removed as requested

                    if (classified.isMain == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Center(
                          child: Text((classified.title ?? "").firstUpperCase())
                            .size(context.font.large)
                            .color(context.color.textColorDark)
                            .bold(),
                        ),
                      ),

                    // Display service image only if it's not a main service or if the main service has an image
                    if (classified.isMain != true || (classified.isMain == true && classified.image != null && classified.image!.isNotEmpty))
                      ClipRRect(
                        clipBehavior: Clip.antiAlias,
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: context.screenWidth,
                          height: 170.rh(context),
                          child: UiUtils.getImage(
                            classified.image!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    SizedBox(height: 15.rh(context)),
                    Text(classified.createdAt.toString().formatDate())
                        .size(context.font.smaller)
                        .color(context.color.textColorDark.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text((classified.title ?? "").firstUpperCase())
                        .size(context.font.large)
                        .color(context.color.textColorDark),
                    const SizedBox(height: 14),
                    HtmlWidget(classified.description ?? ""),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          // Only show continue button for main services
          if (classified.isMain == true)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: UiUtils.buildButton(
                context,
                onPressed: () {
                  // Navigate to add item screen
                  Navigator.pushNamed(
                    context,
                    Routes.addItemDetails,
                    arguments: {
                      'breadCrumbItems': null,
                      'isEdit': false,
                    },
                  );
                },
                buttonTitle: "continue".translate(context),
                radius: 10,
                disabledColor: const Color.fromARGB(255, 104, 102, 106),
              ),
            ),
        ],
      ),
    );
  }
}


 */