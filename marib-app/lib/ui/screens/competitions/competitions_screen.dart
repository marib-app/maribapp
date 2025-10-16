
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart'; // Import for BlurredDialogBox
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/repositories/competition_repository.dart';
import 'package:marib/data/model/challenge_model.dart'; // Added for Challenge model
import 'package:shimmer/shimmer.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart'; // Import CustomShimmer
import 'package:marib/utils/responsiveSize.dart'; // Direct import for rh/rw extensions
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'context_extensions.dart';
import 'package:flutter/material.dart' hide Colors;
import 'user_referral_points.dart';
import 'package:flutter/material.dart';
import 'competition_share_info.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';









class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});



  @override
  State<CompetitionScreen> createState() => CompetitionScreenState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (context) =>
        CompetitionCubit(CompetitionRepository())..fetchCompetitionData(),
        child: const CompetitionScreen(),
      ),
    );
  }
}






class CompetitionScreenState extends State<CompetitionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  List<Challenge> challengesList = [];
  late UserReferralPoints pointsData;



  bool _showHint = false;
  bool showWarning = false;
  bool _isLoadingButton = true; // حالة التحميل المؤقتة




  @override
  void initState() {
    super.initState();

    // كود تحميل الزر
    _isLoadingButton = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLoadingButton = false;
        });
      }
    });

    _tabController = TabController(length: 2, vsync: this);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reverse();


      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Color progressColor(double ratio) {
    if (ratio >= 1.0) return Colors.green;
    if (ratio >= 0.5) return Colors.orange;
    return Colors.red;
  }





  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: Theme.of(context).primaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.isDarkMode ? Colors.black : Colors.white,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "المسابقات".translate(context),
        ),
        body: Column(
          children: [
            SizedBox(height: 10),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Text(
                    'activities'.translate(context),
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ),
                Tab(
                  child: Text(
                    'payment'.translate(context),
                    style: TextStyle(color: context.color.textDefaultColor),
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  /// تبويب "الأنشطة"
                  BlocBuilder<CompetitionCubit, CompetitionState>(
                    builder: (context, state) {
                      if (state is CompetitionLoading) {
                        return _buildGridShimmer(context);
                      } else if (state is CompetitionSuccess) {
                        pointsData = state.referralPoints;
                        challengesList = state.challenges;

                        final int maxReferrals = state.challenges.isNotEmpty
                            ? state.challenges.map((c) => c.requiredReferrals).reduce((a, b) => a > b ? a : b)
                            : 0;

                        final Challenge? highestChallenge = state.challenges.isNotEmpty
                            ? state.challenges.reduce((a, b) =>
                        a.requiredReferrals > b.requiredReferrals ? a : b)
                            : null;

                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                buildPointsCard(context, state.referralPoints, maxReferrals, state.challenges),
                                const SizedBox(height: 20),
                                _buildChallengesSection(context, challengesList, pointsData.currentPoints),
                                const SizedBox(height: 20),
                                //_buildInviteSection(),
                              ],
                            ),
                          ),
                        );
                      } else if (state is CompetitionFailure) {
                        return SomethingWentWrong();
                      }
                      return Center(child: Text('Initializing...'));
                    },
                  ),

                  /// تبويب "الدفع"
                  SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "paymentDetails".translate(context),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          _buildPaymentMethods(context),
                          SizedBox(height: 20),
                          Text(
                            "transactionHistory".translate(context),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          _buildTransactionHistory(),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),





        // ✅ الزر الثابت أسفل الشاشة
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _isLoadingButton
                ? Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
                : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, CompetitionShareInfoScreen.route());
                },
                icon: const Icon(Icons.emoji_events, color: Colors.white, size: 18),
                label: const Text(
                  "شارك واربح",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.forthColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }







  Challenge? getNearestChallenge(List<Challenge> challenges, int currentPoints) {
    if (challenges.isEmpty) {
      return null;
    }

    final sortedChallenges = List<Challenge>.from(challenges)
      ..sort((a, b) => a.requiredPoints.compareTo(b.requiredPoints));

    final nearestChallenge = sortedChallenges.firstWhere(
          (c) => c.requiredPoints > currentPoints,
      orElse: () => sortedChallenges.last,
    );

    return nearestChallenge;
  }


  Widget buildPointsCard(
      BuildContext context,
      UserReferralPoints pointsData,
      int maxReferrals,
      List<Challenge> challenges,
      ) {
    // 🧮 النقاط الحالية
    final int currentPoints = pointsData.currentPoints;

    // 🗃️ ترتيب التحديات حسب النقاط المطلوبة
    final sortedChallenges = [...challenges]..sort((a, b) => a.requiredPoints.compareTo(b.requiredPoints));

    // 🥇 أعلى تحدي
    final highest = sortedChallenges.isNotEmpty
        ? sortedChallenges.reduce((a, b) => a.requiredPoints > b.requiredPoints ? a : b)
        : null;

    // 🎯 أقرب تحدي لم يصله المستخدم بعد
    final nearest = sortedChallenges.cast<Challenge?>().firstWhere(
          (c) => c!.requiredPoints > currentPoints,
      orElse: () => null,
    );

    // 📌 عدد النقاط المتبقية للوصول للتحدي الأقرب
    final int remaining = nearest != null
        ? (nearest.requiredPoints - currentPoints).clamp(0, nearest.requiredPoints)
        : 0;

    // ⏳ نسبة التقدم إلى أعلى تحدي
    final double progress = highest != null && highest.requiredPoints > 0
        ? (currentPoints / highest.requiredPoints).clamp(0.0, 1.0)
        : 0.0;

    // ✅ هل يستطيع جمع الجائزة الآن؟
    final bool canCollect = nearest != null && currentPoints >= nearest.requiredPoints;

    return Container(
      padding: const EdgeInsets.all(16), // 🧱 حواف داخلية للبطاقة
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900] // 🎨 لون البطاقة في الوضع الليلي
            : Colors.amber.shade100, // 🎨 لون البطاقة في الوضع الفاتح
        borderRadius: BorderRadius.circular(12), // 🔲 حواف دائرية للبطاقة
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)), // 🟤 ظل خفيف
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🧱 الجهة اليسرى (النصوص والأزرار)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔢 عرض النقاط الحالية
                Text(
                  "$currentPoints/${highest?.requiredPoints ?? maxReferrals} نقطة",
                  style: TextStyle(
                    fontSize: 18, // 🔠 حجم الخط الرئيسي
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 8),

                // 📊 شريط التقدم
                LinearProgressIndicator(
                  value: progress, // ⚖️ النسبة الحالية
                  backgroundColor: Colors.grey.shade300, // 🎨 لون الخلفية
                  valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0 ? Colors.green : Colors.orange), // 🎨 لون التقدم
                  minHeight: 8, // 📏 ارتفاع الشريط
                ),
                const SizedBox(height: 10),

                // 💬 التلميح عن التحدي الأقرب
                Text(
                  nearest != null
                      ? "باقي لك $remaining نقطة للحصول على جائزة   '${nearest.title}' 🎁"
                      : "🎉 مبروك! وصلت لكل التحديات.",
                  style: TextStyle(
                    fontSize: 14, // 🔠 حجم الخط
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),

                // 🔘 الزر + تنبيه بجانبه أو تحته باستخدام Wrap
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 8, // 📏 المسافة الأفقية بين الزر والتنبيه
                      runSpacing: 6, // 📏 المسافة الرأسية إذا التف للسطر الثاني
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // ▶️ زر جمع النقاط
                        ElevatedButton(
                          onPressed: canCollect
                              ? () {
                            // ✅ تنفيذ الجمع هنا
                          }
                              : () {
                            HapticFeedback.vibrate(); // 📳 اهتزاز خفيف
                            setState(() => showWarning = true); // 🔔 إظهار التنبيه
                            Future.delayed(const Duration(seconds: 3), () {
                              if (context.mounted) setState(() => showWarning = false);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canCollect ? Colors.orange : Colors.grey, // 🎨 لون الزر
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 📐 حجم الزر
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20), // 🟦 حواف الزر
                            ),
                          ),
                          child: Text(
                            canCollect ? "اجمع نقاطك الآن" : "اجمع نقاط التحدي", // 🏷️ نص الزر
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),

                        // 💬 التنبيه (يظهر أو يختفي بشكل سلس + يلتف إذا ما فيه مساحة)
                        AnimatedOpacity(
                          opacity: showWarning ? 1.0 : 0.0, // 👀 ظهور واختفاء
                          duration: const Duration(milliseconds: 300), // ⏱️ مدة الأنميشن
                          child: Text(
                            "باقي $remaining نقطة لتفعيل الزر",
                            style: TextStyle(
                              fontSize: 12, // 🔠 حجم نص التنبيه
                              color: Colors.red.shade700, // 🎨 لون التنبيه
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 🖼️ صورة المكافأة
          Image.asset(
            'assets/image/rewards.png', // 🖼️ مسار الصورة (عدّل إذا لزم)
            width: 110,
            height: 100,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }



















  void _showChallengeDetailsDialog(BuildContext context, Challenge challenge) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (ctx, a1, a2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: BlurredDialogBox(
            title: "🎯 ${challenge.title}",
            showCancleButton: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ وصف التحدي مع Scroll داخلي وروابط مفعّلة
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 4),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.description, color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Linkify(
                            text: challenge.description,
                            style: const TextStyle(fontSize: 14),
                            onOpen: (link) async {
                              if (await canLaunchUrl(Uri.parse(link.url))) {
                                await launchUrl(Uri.parse(link.url),
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Divider(thickness: 1, color: Colors.grey.shade300),
                const SizedBox(height: 12),

                // ✅ الإحالات المطلوبة
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      "الإحالات المطلوبة: ${challenge.requiredReferrals}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ✅ النقاط لكل إحالة
                Row(
                  children: [
                    const Icon(Icons.star_rate_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      "النقاط لكل إحالة: ${challenge.pointsPerReferral}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ✅ الحالة
                Row(
                  children: [
                    Icon(
                      challenge.isActive ? Icons.check_circle : Icons.cancel,
                      color: challenge.isActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      challenge.isActive ? "الحالة: 🔥 نشط" : "الحالة: 🚫 غير نشط",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }









  Widget _buildChallengesSection(
      BuildContext context,
      List<Challenge> challenges,
      int currentPoints,
      ) {
    // تقسيم القائمة إلى صفوف كل صف فيه عنصرين
    final rows = <Widget>[];

    for (var i = 0; i < challenges.length; i += 2) {
      final row = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildChallengeCard(context, challenges[i], currentPoints)),
          const SizedBox(width: 10),
          if (i + 1 < challenges.length)
            Expanded(child: _buildChallengeCard(context, challenges[i + 1], currentPoints))
          else
            const Expanded(child: SizedBox()), // لتعبئة الفراغ في حال كان عدد البطاقات فردي
        ],
      );
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: row,
      ));
    }

    return Column(children: rows);
  }


  Widget _buildChallengeCard(BuildContext context, Challenge challenge, int currentPoints) {
    final bool isActive = challenge.isActive;
    final bool isEligible = currentPoints >= challenge.requiredPoints;

    final Color badgeColor = isActive ? Colors.orange.shade100 : Colors.grey.shade300;
    final Color badgeTextColor = isActive ? Colors.deepOrange : Colors.grey.shade700;
    final Color backgroundColor = isEligible
        ? Colors.lightGreen.shade50
        : isActive
        ? Colors.amber.shade50
        : Colors.grey.shade100;

    return InkWell(
      onTap: () => _showChallengeDetailsDialog(context, challenge),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🎊", // شكل جذاب للجائزة
              style: TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              challenge.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${challenge.requiredPoints} نقطة مطلوبة",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive ? "🔥 نشط" : "🚫 غير نشط",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeTextColor,
                ),
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (currentPoints / challenge.requiredPoints).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(
                      isEligible ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }




  // Shimmer placeholder for Points Section
  Widget _buildPointsSectionShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white, // Shimmer needs a non-transparent background
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 100, height: 16, color: Colors.white),
                SizedBox(height: 8),
                Container(width: 150, height: 8, color: Colors.white),
                SizedBox(height: 10),
                Container(
                    width: 120,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20))),
              ],
            ),
            Container(
                width: 100,
                height: 100,
                color: Colors.white), // Placeholder for image
          ],
        ),
      ),
    );
  }

  // Shimmer placeholder for Challenges Section


  Widget _buildChallengesSectionShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
        ),
        itemCount: 4, // Display a few shimmer items
        itemBuilder: (context, index) {
          return Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                  SizedBox(height: 10),
                  Container(width: 80, height: 14, color: Colors.white),
                  SizedBox(height: 5),
                  Container(width: 60, height: 12, color: Colors.white),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridShimmer(BuildContext context) {
    return GridView.builder(
      itemCount: 6, // Reduced count for better appearance
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      physics:
      const NeverScrollableScrollPhysics(), // Disable scrolling if inside a ScrollView
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Number of items per row
        crossAxisSpacing: 8, // Increased horizontal spacing
        mainAxisSpacing: 8, // Increased vertical spacing
        childAspectRatio:
        0.7, // Controls the width-to-height ratio of each item
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              width: 1.5,
              color: context.color.borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Challenge image shimmer
              CustomShimmer(
                width: double.infinity,
                height: (100 as num).rh(context),
                borderRadius: 16,
              ),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Challenge title shimmer
                    CustomShimmer(
                      width: (120 as num).rw(context),
                      height: (15 as num).rh(context),
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),

                    // Points row with icon and text
                    Row(
                      children: [
                        // Points icon shimmer (circle)
                        CustomShimmer(
                          width: (20 as num).rw(context),
                          height: (20 as num).rh(context),
                          borderRadius: 10, // Make it circular
                        ),
                        const SizedBox(width: 4),
                        // Points text shimmer
                        CustomShimmer(
                          width: (60 as num).rw(context),
                          height: (12 as num).rh(context),
                          borderRadius: 4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Challenge description/status shimmer
                    CustomShimmer(
                      width: (100 as num).rw(context),
                      height: (12 as num).rh(context),
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),

                    // Progress indicator shimmer
                    CustomShimmer(
                      width: double.infinity,
                      height: (8 as num).rh(context),
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }





  Widget _buildInviteSection() {
    return BlocBuilder<CompetitionCubit, CompetitionState>(
      builder: (context, state) {
        String referralCode = "LOADING...";
        String inviteMessage = "loading".translate(context);

        if (state is CompetitionSuccess) {
          referralCode = state.referralPoints.referralCode;
          inviteMessage = state.referralPoints.qrCodeData;
        }

        return Container(
          padding: EdgeInsets.all(16.0),
          width: 370,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                "inviteFriendsEarnPoints".translate(context),
                style: TextStyle(
                  color: context.color.blackColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 15),

              // عرض كود الإحالة
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.color.forthColor, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "yourReferralCode".translate(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          referralCode,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.color.forthColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("messageCopied".translate(context)),
                            backgroundColor: context.color.forthColor,
                          ),
                        );
                      },
                      icon: Icon(Icons.copy, color: context.color.forthColor),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 15),

              // QR Code
              Container(
                height: 120,
                width: 120,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: context.color.forthColor.withOpacity(0.3)),
                ),
                child: state is CompetitionSuccess
                    ? QrImageView(
                  data: inviteMessage,
                  version: QrVersions.auto,
                  size: 104.0,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                )
                    : Center(
                  child:
                  Icon(Icons.qr_code, size: 40, color: Colors.grey),
                ),
              ),

              SizedBox(height: 15),

              // أزرار المشاركة
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.forthColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (state is CompetitionSuccess) {
                          _shareInviteMessage(inviteMessage, context);
                        }
                      },

                      icon: Icon(Icons.share, color: Colors.white, size: 18),
                      label: Text(
                        "share".translate(context),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  // SizedBox(width: 10),
                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     style: OutlinedButton.styleFrom(
                  //       side: BorderSide(color: context.color.forthColor),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //       padding: EdgeInsets.symmetric(vertical: 12),
                  //     ),
                  //     onPressed: () {
                  //       _showInviteMessageDialog(
                  //           context, inviteMessage, referralCode);
                  //     },
                  //     // icon: Icon(Icons.preview,
                  //     //     color: context.color.forthColor, size: 18),
                  //     // label: Text(
                  //     //   "عرض الرسالة",
                  //     //   style: TextStyle(
                  //     //       color: context.color.forthColor, fontSize: 14),
                  //     // ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }



  void _shareInviteMessage(String message, BuildContext context) {
    // نسخ الرسالة إلى الحافظة كبديل للمشاركة
    Clipboard.setData(ClipboardData(text: message));
    // إظهار رسالة تأكيد
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("messageCopiedToClipboard".translate(context)),
        backgroundColor: context.color.forthColor,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showInviteMessageDialog(
      BuildContext context, String message, String referralCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BlurredDialogBox(
          title: "inviteMessage".translate(context),
          showCancleButton: false,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.color.forthColor,
                        ),
                        onPressed: () {
                          _shareInviteMessage(message, context);
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.share, color: Colors.white),
                        label: Text("share".translate(context),
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.color.forthColor),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("messageCopied".translate(context)),
                              backgroundColor: context.color.forthColor,
                            ),
                          );
                        },
                        icon: Icon(Icons.copy, color: context.color.forthColor),
                        label: Text("copy".translate(context),
                            style: TextStyle(color: context.color.forthColor)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _buildPaymentMethods(BuildContext context) {
  return Column(
    children: [
      ListTile(
        leading: Icon(Icons.credit_card, color: Colors.orange),
        title: Text("addCreditCard".translate(context)),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {},
      ),
      ListTile(
        leading: Icon(Icons.account_balance_wallet, color: Colors.orange),
        title: Text("payViaWallet".translate(context)),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          // فتح صفحة المحفظة
        },
      ),
    ],
  );
}

/// مثال على عرض سجل المعاملات
Widget _buildTransactionHistory() {
  return Column(
    children: [
      // ListTile(
      //   leading: Icon(Icons.history, color: Colors.orange),
      //   title: Text("معاملة رقم 12345"),
      //   subtitle: Text("تمت بتاريخ 2024-04-01"),
      //   trailing: Text("- 150.00 SAR", style: TextStyle(color: Colors.red)),
      // ),
      // ListTile(
      //   leading: Icon(Icons.history, color: Colors.orange),
      //   title: Text("معاملة رقم 67890"),
      //   subtitle: Text("تمت بتاريخ 2024-03-28"),
      //   trailing: Text("+ 300.00 SAR", style: TextStyle(color: Colors.green)),
      // ),
    ],
  );
}

/// Shimmer للدفع
Widget _buildPaymentShimmer(BuildContext context) {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 120, height: 20, color: Colors.white),
          SizedBox(height: 16),
          for (int i = 0; i < 3; i++)
            Card(
              child: ListTile(
                leading: Container(width: 40, height: 40, color: Colors.white),
                title: Container(width: 150, height: 16, color: Colors.white),
                trailing: Container(width: 20, height: 20, color: Colors.white),
              ),
            ),
          SizedBox(height: 20),
          Container(width: 100, height: 20, color: Colors.white),
          SizedBox(height: 16),
          for (int i = 0; i < 5; i++)
            Card(
              child: ListTile(
                leading: Container(width: 40, height: 40, color: Colors.white),
                title: Container(width: 120, height: 16, color: Colors.white),
                subtitle:
                Container(width: 180, height: 12, color: Colors.white),
                trailing: Container(width: 60, height: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    ),
  );
}

// دوال مساعدة لتنسيق البيانات
Color _getTransactionStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'success':
    case 'succeeded':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'failed':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

IconData _getTransactionStatusIcon(String? status) {
  switch (status?.toLowerCase()) {
    case 'success':
    case 'succeeded':
      return Icons.check;
    case 'pending':
      return Icons.schedule;
    case 'failed':
      return Icons.close;
    default:
      return Icons.help;
  }
}

String _getStatusText(String? status, BuildContext context) {
  switch (status?.toLowerCase()) {
    case 'success':
    case 'succeeded':
      return 'completed'.translate(context);
    case 'pending':
      return 'pending'.translate(context);
    case 'failed':
      return 'failed'.translate(context);
    default:
      return 'unknown'.translate(context);
  }
}

String _formatDate(String? dateString, BuildContext context) {
  if (dateString == null) return 'notSpecified'.translate(context);
  try {
    final date = DateTime.parse(dateString);
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  } catch (e) {
    return dateString;
  }
}

// حوارات إضافة طرق الدفع
void _showAddPaymentMethodDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BlurredDialogBox(
        title: "addPaymentMethod".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "cardNumber".translate(context),
                hintText: "1234 5678 9012 3456",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "MM/YY",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "CVV",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.forthColor,
              ),
              onPressed: () {
                // حفظ بيانات البطاقة
                context.read<CompetitionCubit>().savePaymentInfo(
                  paymentMethods: ['credit_card'],
                  paymentAccountDetails: {
                    'type': 'credit_card',
                    'card_number': 'masked_number',
                  },
                );
                Navigator.pop(context);
              },
              child: Text("save".translate(context),
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}

void _showWalletPaymentDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BlurredDialogBox(
        title: "payViaWallet".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "electronicWalletNumber".translate(context),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.forthColor,
              ),
              onPressed: () {
                context.read<CompetitionCubit>().savePaymentInfo(
                  paymentMethods: ['wallet'],
                  paymentAccountDetails: {
                    'type': 'wallet',
                    'wallet_number': 'wallet_id',
                  },
                );
                Navigator.pop(context);
              },
              child: Text("save".translate(context),
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}

void _showPhonePaymentDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BlurredDialogBox(
        title: "payViaPhone".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "phoneNumber".translate(context),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.forthColor,
              ),
              onPressed: () {
                context.read<CompetitionCubit>().savePaymentInfo(
                  paymentMethods: ['phone'],
                  paymentAccountDetails: {
                    'type': 'phone',
                    'phone_number': 'phone_id',
                  },
                );
                Navigator.pop(context);
              },
              child: Text("save".translate(context),
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}

void _showAllTransactionsDialog(
    BuildContext context, List<dynamic> paymentTransactions) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BlurredDialogBox(
        title: "allTransactions".translate(context),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: paymentTransactions.length,
            itemBuilder: (context, index) {
              final transaction = paymentTransactions[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTransactionStatusColor(
                        transaction['payment_status']),
                    child: Icon(
                      _getTransactionStatusIcon(transaction['payment_status']),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    "${"transaction".translate(context)} #${transaction['id']}",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${transaction['payment_gateway'] ?? 'notSpecified'.translate(context)} - ${_formatDate(transaction['created_at'], context)}",
                    style: TextStyle(fontSize: 10),
                  ),
                  trailing: Text(
                    "${transaction['amount']} ${"rial".translate(context)}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: transaction['payment_status'] == 'success'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

// --- Appended Cubit, State, and Model Definitions ---

// 1. Models
class UserReferralPoints {
  final int totalPoints;
  final String nextRewardMessage;
  final String inviteFriendMessage;
  final String qrCodeData;
  final int currentPoints;
  final int maxPoints;
  final String referralCode;
  final int referredUsersCount;

  const UserReferralPoints({
    required this.totalPoints,
    required this.nextRewardMessage,
    required this.inviteFriendMessage,
    required this.qrCodeData,
    required this.currentPoints,
    required this.maxPoints,
    required this.referralCode,
    required this.referredUsersCount,
  });

  factory UserReferralPoints.dummy({int? maxPointsFromApi}) {
    return UserReferralPoints(
      totalPoints: 5000,
      nextRewardMessage: "Collect additional points to get a reward!",
      inviteFriendMessage:
      "Invite your friends and earn points for each friend who joins.",
      qrCodeData: "sample_qr_code_data_string",
      currentPoints: 1350,
      maxPoints: maxPointsFromApi ?? 1500, // استخدام القيمة من الـ API
      referralCode: "SAMPLE123",
      referredUsersCount: 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserReferralPoints &&
              runtimeType == other.runtimeType &&
              totalPoints == other.totalPoints &&
              nextRewardMessage == other.nextRewardMessage &&
              inviteFriendMessage == other.inviteFriendMessage &&
              qrCodeData == other.qrCodeData &&
              currentPoints == other.currentPoints &&
              maxPoints == other.maxPoints &&
              referralCode == other.referralCode &&
              referredUsersCount == other.referredUsersCount;

  @override
  int get hashCode =>
      totalPoints.hashCode ^
      nextRewardMessage.hashCode ^
      inviteFriendMessage.hashCode ^
      qrCodeData.hashCode ^
      currentPoints.hashCode ^
      maxPoints.hashCode ^
      referralCode.hashCode ^
      referredUsersCount.hashCode;
}

// 2. States
abstract class CompetitionState {
  const CompetitionState();
}

class CompetitionInitial extends CompetitionState {}

class CompetitionLoading extends CompetitionState {}

class CompetitionSuccess extends CompetitionState {
  final UserReferralPoints referralPoints;
  final List<Challenge> challenges;
  final List<dynamic> paymentTransactions;
  final Challenge? nextChallenge;

  const CompetitionSuccess(
      this.referralPoints,
      this.challenges,
      this.paymentTransactions, {
        this.nextChallenge,
      });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CompetitionSuccess) return false;
    if (referralPoints != other.referralPoints) return false;
    if (challenges.length != other.challenges.length) return false;
    for (int i = 0; i < challenges.length; i++) {
      if (challenges[i] != other.challenges[i]) return false;
    }
    if (nextChallenge != other.nextChallenge) return false;
    return true;
  }

  @override
  int get hashCode {
    int result = referralPoints.hashCode;
    for (final challenge in challenges) {
      result = 31 * result + challenge.hashCode;
    }
    result = 31 * result + (nextChallenge?.hashCode ?? 0);
    return result;
  }
}


class CompetitionFailure extends CompetitionState {
  final String message;

  const CompetitionFailure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CompetitionFailure &&
              runtimeType == other.runtimeType &&
              message == other.message;

  @override
  int get hashCode => message.hashCode;
}

// 3. Cubit
class CompetitionCubit extends Cubit<CompetitionState> {
  final CompetitionRepository _competitionRepository;

  CompetitionCubit(this._competitionRepository) : super(CompetitionInitial());

  Future<void> fetchCompetitionData() async {
    emit(CompetitionLoading());
    try {
      // الحصول على بيانات التحديات مع maxPoints
      final challengesResponse = await _competitionRepository.getChallenges();
      final challenges = challengesResponse['challenges'] as List<Challenge>;
      final maxPointsFromApi = challengesResponse['max_points'] as int;

      // جلب بيانات النقاط الحقيقية للمستخدم (مع fallback للبيانات الوهمية)
      Map<String, dynamic> userPointsData = {};
      try {
        userPointsData = await _competitionRepository.getUserReferralPoints();
      } catch (e) {
        print("Warning: Could not load user referral points: $e");
        // استخدام بيانات افتراضية
        userPointsData = {
          'total_points': 0,
          'referral_code': 'DEFAULT123',
          'referred_users_count': 0,
        };
      }

      // جلب تاريخ المعاملات المالية (اختياري)
      List<dynamic> paymentTransactions = [];
      try {
        paymentTransactions =
        await _competitionRepository.getPaymentTransactions();
      } catch (e) {
        // إذا فشل جلب المعاملات، نستمر بدون تعطيل المسابقات
        print("Warning: Could not load payment transactions: $e");
        paymentTransactions = [];
      }

      // إنشاء بيانات النقاط مع القيم الحقيقية
      final pointsData = UserReferralPoints(
        totalPoints: userPointsData['total_points'] ?? 0,
        currentPoints: userPointsData['total_points'] ?? 0,
        maxPoints: maxPointsFromApi,
        referralCode: userPointsData['referral_code'] ?? 'DEFAULT123',
        referredUsersCount: userPointsData['referred_users_count'] ?? 0,
        nextRewardMessage: "Collect additional points to get a reward!",
        inviteFriendMessage:
        "Invite your friends and earn points for each friend who joins.",
        qrCodeData: _generateInviteMessage(
            userPointsData['referral_code'] ?? 'DEFAULT123'),
      );

      emit(CompetitionSuccess(pointsData, challenges, paymentTransactions));
    } catch (e) {
      emit(CompetitionFailure(
          "Failed to load competition data: ${e.toString()}"));
    }
  }

  Future<void> savePaymentInfo({
    required List<String> paymentMethods,
    required Map<String, dynamic> paymentAccountDetails,
    String? businessName,
    String? businessWhatsapp,
    String? businessLocation,
    List<String>? businessCategories,
    String? commercialRegister,
    String? email,
  }) async {
    try {
      await _competitionRepository.savePaymentInfo(
        accountType: '2', // حساب تجاري
        businessName: businessName,
        businessWhatsapp: businessWhatsapp,
        businessLocation: businessLocation,
        businessCategories: businessCategories,
        commercialRegister: commercialRegister,
        paymentMethods: paymentMethods,
        paymentAccountDetails: paymentAccountDetails,
        email: email,
      );

      // إعادة تحميل البيانات بعد الحفظ
      await fetchCompetitionData();
    } catch (e) {
      emit(CompetitionFailure("Failed to save payment info: ${e.toString()}"));
    }
  }

  Future<void> refreshPaymentTransactions() async {
    try {
      final paymentTransactions =
      await _competitionRepository.getPaymentTransactions();

      if (state is CompetitionSuccess) {
        final currentState = state as CompetitionSuccess;
        emit(CompetitionSuccess(currentState.referralPoints,
            currentState.challenges, paymentTransactions));
      }
    } catch (e) {
      // يمكن إظهار رسالة خطأ للمستخدم هنا
      print("Failed to refresh payment transactions: $e");
    }
  }

  String _generateInviteMessage(String referralCode) {
    return """🎉 Join the "Marib in Your Hands" app and benefit from the best buying and selling offers! 

🏆 Use my referral code: $referralCode

✨ App Features:
• Thousands of local products and services
• Competitive prices and exclusive offers
• Safe and secure buying and selling
• Regular competitions with valuable prizes

🎁 Get reward points upon registration!
💰 Win prizes from monthly competitions

Download the app now and start your business journey with us!

#مارب_بين_يديك #تسوق_آمن #مسابقات_وجوائز""";
  }
}

// دوال مساعدة للحوارات
void _showAddCreditCardDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BlurredDialogBox(
        title: "addCreditCard".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "cardNumber".translate(context),
                hintText: "1234 5678 9012 3456",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.forthColor,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("cardDataSaved".translate(context))),
                );
              },
              child: Text("save".translate(context),
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}

void _showWalletDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BlurredDialogBox(
        title: "payViaWallet".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "walletNumber".translate(context),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.forthColor,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("walletDataSaved".translate(context))),
                );
              },
              child: Text("save".translate(context),
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}

void _showPhoneDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return BlurredDialogBox(
        title: "payViaPhone".translate(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "phoneNumber".translate(context),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.forthColor,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("phoneNumberSaved".translate(context))),
                );
              },
              child: Text("save".translate(context),
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}
