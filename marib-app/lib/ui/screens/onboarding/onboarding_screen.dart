import 'dart:async';
import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'widgets/onboarding_dots.dart';
import 'widgets/onboarding_hint.dart';
import 'widgets/onboarding_page.dart';
import 'widgets/onboarding_start_button.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  static const _trustedTitle = "موثوق رسميًا";


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
    _pageController.addListener(_handleScroll);
    _restartHintTimer(0);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handleScroll);
    _pageController.dispose();
    _cancelHintTimer();
    super.dispose();
  }

  void _handleScroll() {
    final double page = _pageController.page ?? currentPage;
    setState(() {
      currentPage = page;
    });
  }

  void _handlePageSettled(int pageIndex) {
    final bool isLastPage = pageIndex >= data.length - 1;
    final bool isTrustedPage = data[pageIndex].title == _trustedTitle;
    final bool shouldShowStart = isLastPage || isTrustedPage;

    if (shouldShowStart) {
      _cancelHintTimer();

      setState(() {
        _showHint = false;
        _showStartButton = true;
      });
    } else {
      setState(() {
        _showStartButton = false;
      });
      _restartHintTimer(pageIndex);
    }
  }

  void _restartHintTimer(int pageIndex) {
    _cancelHintTimer();

    if (_showHint) {
      setState(() {
        _showHint = false;
      });
    }

    if (pageIndex >= data.length - 1 || data[pageIndex].title == _trustedTitle) {
      return;
    }

    // عرض التلميح بعد فترة معينة بشرط ألا تكون الصفحة "موثوق رسميًا"
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      final int currentIndex =
      currentPage.round().clamp(0, data.length - 1);
      if (currentIndex == pageIndex &&
          currentIndex < data.length - 1 &&
          data[currentIndex].title != _trustedTitle) {
        setState(() {
          _showHint = true;
        });
      }
    });
  }



  void _cancelHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = null;
  }




  Color lerpColor(Color a, Color b, double t) =>
      Color.lerp(a, b, t.clamp(0.0, 1.0))!;

  double lerpDouble(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);



  @override
  Widget build(BuildContext context) {
    ScreenScaler.init(context);

    final int basePage = currentPage.floor().clamp(0, data.length - 1);
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
              onPageChanged: _handlePageSettled,
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

                return OnboardingPage(
                  data: item,
                  opacity: opacity,
                  textTranslateX: textTranslateX,
                  imageTranslateY: imageTranslateY,
                );
              },
            ),
          ),

          // مؤشرات التقدم (Dots)
          Positioned(
            bottom: ScreenScaler.s(20),
            left: 0,
            right: 0,
            child: OnboardingDots(
              itemCount: data.length,
              currentPage: currentPage,
            ),
          ),

          // التلميح (Swipe hint)
          if (_showHint && currentPage < data.length - 1)
            Positioned(
              bottom: ScreenScaler.s(60),
              left: 0,
              right: 0,
              child: const OnboardingHint(),

            ),

          // زر البدء في الصفحة الأخيرة (ظهور مع تأثير)
          if (_showStartButton && currentPage >= data.length - 1 - 0.01)
            Positioned(
              left: ScreenScaler.s(20),
              bottom: ScreenScaler.s(60),
              child: OnboardingStartButton(
                onPressed: () {
                  HiveUtils.setUserIsNotNew();
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(Routes.login, (_) => false);
                },

              ),
            ),
        ],
      ),
    );
  }
}