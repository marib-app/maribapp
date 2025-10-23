import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/screen_scaler.dart';

class CardPlanetData {
  final String title;
  final String subtitle;
  final ImageProvider? image;
  final List<Color> backgroundGradientColors;
  final Color titleColor;
  final Color subtitleColor;
  final String? animationPath;

  CardPlanetData({
    required this.title,
    required this.subtitle,
    this.image,
    required this.backgroundGradientColors,
    required this.titleColor,
    required this.subtitleColor,
    this.animationPath,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  double currentPage = 0.0;
  bool _showHint = false;
  bool _showStartButton = false; // لعرض زر البدء مع أنيميشن
  Timer? _hintTimer;

  final List<CardPlanetData> data = [
    CardPlanetData(
      title: "مرحباً بك في مأرب بين يديك!",
      subtitle: "كل ما تحتاجه في مأرب بتطبيق واحد – تسوق، خدمات، عروض وتوصيل!",
      image: const AssetImage("assets/image/1.png"),
      backgroundGradientColors: [Color(0xFF0F2027), Color(0xFF203A43)],
      titleColor: Colors.white,
      subtitleColor: Colors.white70,
    ),
    CardPlanetData(
      title: "كل شيء في مكان واحد!",
      subtitle: "تسوّق، أعلن، اطلب واستفد من منصة تجمع التجار والمستهلكين.",
      backgroundGradientColors: [Color(0xFF1D4350), Color(0xFFA43931)],
      titleColor: Colors.white,
      subtitleColor: Colors.white,
      animationPath: 'assets/lottie/a_1.json',
    ),
    CardPlanetData(
      title: "كل العقارات بخطوة!",
      subtitle: "وفّر وقتك، كل العروض العقارية في مكان واحد.",
      backgroundGradientColors: [Color(0xFF355C7D), Color(0xFF6C5B7B)],
      titleColor: Colors.yellow,
      subtitleColor: Colors.white,
      animationPath: 'assets/lottie/a_2.json',
    ),
    CardPlanetData(
      title: "خلّي متجرك يلمع",
      subtitle: "اعرض منتجاتك ، بعها بسهولة ، وخلي التوصيل علينا.",
      backgroundGradientColors: [Colors.black87, Colors.grey.shade900],
      titleColor: Colors.amber,
      subtitleColor: Colors.white,
      animationPath: 'assets/lottie/a_3.json',
    ),
    CardPlanetData(
      title: "بع، اشترِي، وأعلن!",
      subtitle: "بدون وسيط، حط إعلانك وخلي الناس تجيك!",
      backgroundGradientColors: [Colors.black87, Colors.grey.shade800],
      titleColor: Colors.lightBlueAccent,
      subtitleColor: Colors.white,
      animationPath: 'assets/lottie/a_4.json',
    ),
    CardPlanetData(
      title: "موثوق رسميًا",
      subtitle: "تطبيق مرخص من وزارة الصناعة والتجارة – مأرب\nرقم القيد: 6561 / السجل: 3154",
      image: const AssetImage("assets/image/6.png"),
      backgroundGradientColors: [Colors.black, Colors.blueGrey.shade900],
      titleColor: Colors.cyanAccent,
      subtitleColor: Colors.white,
    ),
  ];


  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        currentPage = _pageController.page ?? 0.0;

        // إخفاء التلميح فور الوصول إلى الصفحة الأخيرة أو في الصفحة التي تحتوي على "موثوق رسميًا"
        if (currentPage >= data.length - 1 ||
            data[currentPage.floor()].title == "موثوق رسميًا") {
          _showHint = false;
          _showStartButton = true; // إظهار زر البدء مع التأثير
        }
      });
    });

    // عرض التلميح بعد فترة معينة بشرط ألا تكون الصفحة "موثوق رسميًا"
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && currentPage < data.length - 1 &&
          data[currentPage.floor()].title != "موثوق رسميًا") {
        setState(() {
          _showHint = true;
        });
      }
    });
  }

  Color lerpColor(Color a, Color b, double t) =>
      Color.lerp(a, b, t.clamp(0.0, 1.0))!;

  double lerpDouble(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);



  @override
  Widget build(BuildContext context) {
    ScreenScaler.init(context);

    int basePage = currentPage.floor();
    double pageOffset = currentPage - basePage;

    // تدرج الخلفية بين الصفحتين بناء على موقع السحب
    final Color backgroundStart = basePage < data.length - 1
        ? lerpColor(data[basePage].backgroundGradientColors.first,
        data[basePage + 1].backgroundGradientColors.first, pageOffset)
        : data[basePage].backgroundGradientColors.first;

    final Color backgroundEnd = basePage < data.length - 1
        ? lerpColor(data[basePage].backgroundGradientColors.last,
        data[basePage + 1].backgroundGradientColors.last, pageOffset)
        : data[basePage].backgroundGradientColors.last;

    return Scaffold(
      backgroundColor: backgroundEnd,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [backgroundStart, backgroundEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: PageView.builder(
              controller: _pageController,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];

                // حساب شفافية كل صفحة حسب موقع السحب
                double opacity;
                if (index == basePage) {
                  opacity = 1 - pageOffset;
                } else if (index == basePage + 1) {
                  opacity = pageOffset;
                } else {
                  opacity = 0.0;
                }

                // تحريك النص من اليمين لليسار (slide + opacity)
                double textTranslateX;
                if (index == basePage) {
                  textTranslateX = lerpDouble(0, -100, pageOffset);
                } else if (index == basePage + 1) {
                  textTranslateX = lerpDouble(100, 0, pageOffset);
                } else {
                  textTranslateX = 100;
                }

                // تحريك الصورة/الأنيميشن من الأسفل للأعلى
                double imageTranslateY;
                if (index == basePage) {
                  imageTranslateY = lerpDouble(0, -50, pageOffset);
                } else if (index == basePage + 1) {
                  imageTranslateY = lerpDouble(50, 0, pageOffset);
                } else {
                  imageTranslateY = 50;
                }

                return Opacity(
                  opacity: opacity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ScreenScaler.s(24),
                      vertical: ScreenScaler.s(60),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item.animationPath != null)
                          Transform.translate(
                            offset: Offset(0, imageTranslateY),
                            child: SizedBox(
                              height: ScreenScaler.s(300),
                              child: Lottie.asset(
                                item.animationPath!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        else
                          if (item.image != null)
                            Transform.translate(
                              offset: Offset(0, imageTranslateY),
                              child: Image(
                                image: item.image!,
                                height: ScreenScaler.s(300),
                                fit: BoxFit.contain,
                              ),
                            ),
                        SizedBox(height: ScreenScaler.s(40)),
                        Transform.translate(
                          offset: Offset(textTranslateX, 0),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Column(
                              children: [
                                Text(
                                  item.title,
                                  style: GoogleFonts.tajawal(
                                    fontSize: ScreenScaler.s(22),
                                    fontWeight: FontWeight.bold,
                                    color: item.titleColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: ScreenScaler.s(12)),
                                Text(
                                  item.subtitle,
                                  style: GoogleFonts.tajawal(
                                    fontSize: ScreenScaler.s(16),
                                    height: 1.6,
                                    color: item.subtitleColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // مؤشرات التقدم (Dots)
          Positioned(
            bottom: ScreenScaler.s(20),
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(data.length, (i) {
                double selectedness = 1.0 -
                    (currentPage - i).abs().clamp(0.0, 1.0);
                double width = lerpDouble(8, 18, selectedness)!;
                Color color = Color.lerp(
                    Colors.white38, Colors.white, selectedness)!;

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: ScreenScaler.s(4)),
                  width: ScreenScaler.s(width),
                  height: ScreenScaler.s(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(ScreenScaler.s(8)),
                  ),
                );
              }),
            ),
          ),

          // التلميح (Swipe hint)
          if (_showHint && currentPage < data.length - 1)
            Positioned(
              bottom: ScreenScaler.s(60),
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_right,
                      color: Colors.white70,
                      size: ScreenScaler.iconSize(context, baseSize: 24),
                    ),
                    SizedBox(height: ScreenScaler.s(6)),
                    Text(
                      "اسحب لليمين للمتابعة",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: ScreenScaler.fontSize(context, baseSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // زر البدء في الصفحة الأخيرة (ظهور مع تأثير)
          if (_showStartButton && currentPage >= data.length - 1 - 0.01)
            Positioned(
              left: ScreenScaler.s(20),
              bottom: ScreenScaler.s(60),
              child: ElevatedButton(
                onPressed: () {
                  HiveUtils.setUserIsNotNew();
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(Routes.login, (_) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenScaler.s(24),
                    vertical: ScreenScaler.s(12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ScreenScaler.s(30)),
                  ),
                  elevation: 8,
                ),
                child: Text(
                  "ابدأ الآن",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: ScreenScaler.s(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}