import 'dart:async';
import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/screen_scaler.dart';
import 'widgets/onboarding_dots.dart';
import 'widgets/onboarding_hint.dart';
import 'widgets/onboarding_page.dart';
import 'widgets/onboarding_start_button.dart';
import 'models/onboarding_page_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _trustedTitle = "موثوق رسميًا";

  final PageController _pageController = PageController();
  final ValueNotifier<bool> _showHintNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showStartButtonNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<int> _currentPageIndexNotifier = ValueNotifier<int>(0);
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
      subtitle:
          "تطبيق مرخص من وزارة الصناعة والتجارة – مأرب\nرقم القيد: 6561 / السجل: 3154",
      image: const AssetImage("assets/image/6.png"),
      backgroundGradientColors: [Colors.black, Colors.blueGrey.shade900],
      titleColor: Colors.cyanAccent,
      subtitleColor: Colors.white,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _restartHintTimer(0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cancelHintTimer();
    _showHintNotifier.dispose();
    _showStartButtonNotifier.dispose();
    _currentPageIndexNotifier.dispose();
    super.dispose();
  }

  void _setHintVisible(bool visible) {
    if (_showHintNotifier.value != visible) {
      _showHintNotifier.value = visible;
    }
  }

  void _setStartButtonVisible(bool visible) {
    if (_showStartButtonNotifier.value != visible) {
      _showStartButtonNotifier.value = visible;
    }
  }

  void _setCurrentPageIndex(int index) {
    if (_currentPageIndexNotifier.value != index) {
      _currentPageIndexNotifier.value = index;
    }
  }

  void _handlePageSettled(int pageIndex) {
    _setCurrentPageIndex(pageIndex);

    final bool isLastPage = pageIndex >= data.length - 1;
    final bool isTrustedPage = data[pageIndex].title == _trustedTitle;
    final bool shouldShowStart = isLastPage || isTrustedPage;

    if (shouldShowStart) {
      _cancelHintTimer();
      _setHintVisible(false);
      _setStartButtonVisible(true);
    } else {
      _setStartButtonVisible(false);

      _restartHintTimer(pageIndex);
    }
  }

  void _restartHintTimer(int pageIndex) {
    _cancelHintTimer();

    _setHintVisible(false);

    if (pageIndex >= data.length - 1 ||
        data[pageIndex].title == _trustedTitle) {
      return;
    }

    // عرض التلميح بعد فترة معينة بشرط ألا تكون الصفحة "موثوق رسميًا"
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      final int currentIndex = _currentPageIndexNotifier.value;
      final double controllerPage = _pageController.hasClients
          ? _pageController.page ?? _pageController.initialPage.toDouble()
          : _pageController.initialPage.toDouble();
      final int roundedControllerPage =
          controllerPage.round().clamp(0, data.length - 1);
      if (currentIndex == pageIndex &&
          currentIndex < data.length - 1 &&
          data[currentIndex].title != _trustedTitle &&
          roundedControllerPage == pageIndex) {
        _setHintVisible(true);
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
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        final double currentPage = _pageController.hasClients
            ? _pageController.page ?? _pageController.initialPage.toDouble()
            : _pageController.initialPage.toDouble();
        final int basePage = currentPage.floor().clamp(0, data.length - 1);
        final double pageOffset = currentPage - basePage;

        // تدرج الخلفية بين الصفحتين بناء على موقع السحب
        final Color backgroundStart = basePage < data.length - 1
            ? lerpColor(
                data[basePage].backgroundGradientColors.first,
                data[basePage + 1].backgroundGradientColors.first,
                pageOffset,
              )
            : data[basePage].backgroundGradientColors.first;

        final Color backgroundEnd = basePage < data.length - 1
            ? lerpColor(
                data[basePage].backgroundGradientColors.last,
                data[basePage + 1].backgroundGradientColors.last,
                pageOffset,
              )
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
                child: child,
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
              ValueListenableBuilder<bool>(
                valueListenable: _showHintNotifier,
                builder: (context, showHint, _) {
                  if (!showHint) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    bottom: ScreenScaler.s(60),
                    left: 0,
                    right: 0,
                    child: const OnboardingHint(),
                  );
                },
              ),

              // زر البدء في الصفحة الأخيرة (ظهور مع تأثير)
              ValueListenableBuilder<bool>(
                valueListenable: _showStartButtonNotifier,
                builder: (context, showStart, _) {
                  if (!showStart) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: ScreenScaler.s(20),
                    bottom: ScreenScaler.s(60),
                    child: OnboardingStartButton(
                      onPressed: () {
                        HiveUtils.setUserIsNotNew();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.login,
                          (_) => false,
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PageView.builder(
          controller: _pageController,
          itemCount: data.length,
          onPageChanged: _handlePageSettled,
          itemBuilder: (context, index) {
            return _AnimatedOnboardingPage(
              controller: _pageController,
              index: index,
              pageCount: data.length,
              data: data[index],
              lerpDouble: lerpDouble,
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedOnboardingPage extends StatefulWidget {
  const _AnimatedOnboardingPage({
    required this.controller,
    required this.index,
    required this.pageCount,
    required this.data,
    required this.lerpDouble,
  });

  final PageController controller;
  final int index;
  final int pageCount;
  final CardPlanetData data;
  final double Function(double a, double b, double t) lerpDouble;

  @override
  State<_AnimatedOnboardingPage> createState() =>
      _AnimatedOnboardingPageState();
}

class _AnimatedOnboardingPageState extends State<_AnimatedOnboardingPage> {
  late final ValueNotifier<bool> _isHeroActive;
  late OnboardingPageContent _staticContent;
  late CardPlanetData _currentData;

  OnboardingPageContent _createStaticContent(CardPlanetData data) {
    return OnboardingPageContent(
      data: data,
      heroActiveListenable: _isHeroActive,
    );
  }


  @override
  void initState() {
    super.initState();
    _isHeroActive = ValueNotifier<bool>(false);
    _currentData = widget.data;
    _staticContent = _createStaticContent(_currentData);
  }

  @override
  void didUpdateWidget(covariant _AnimatedOnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      final CardPlanetData newData = widget.data;
      if (!identical(_currentData, newData)) {
        _currentData = newData;
        setState(() {
          _staticContent = _createStaticContent(_currentData);
        });
      }
    }
  }

  @override
  void dispose() {
    _isHeroActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {

        final double currentPage = widget.controller.hasClients
            ? widget.controller.page ?? widget.controller.initialPage.toDouble()
            : widget.controller.initialPage.toDouble();
        final int basePage = currentPage.floor().clamp(0, widget.pageCount - 1);
        final double pageOffset = currentPage - basePage;

        final bool isHeroActive = widget.index == basePage ||
            (basePage + 1 < widget.pageCount && widget.index == basePage + 1);
        if (_isHeroActive.value != isHeroActive) {
          _isHeroActive.value = isHeroActive;
        }

        double opacity;
        if (widget.index == basePage) {
          opacity = 1 - pageOffset;
        } else if (widget.index == basePage + 1) {
          opacity = pageOffset;
        } else {
          opacity = 0.0;
        }

        double textTranslateX;
        if (widget.index == basePage) {
          textTranslateX = widget.lerpDouble(0, -100, pageOffset);
        } else if (widget.index == basePage + 1) {
          textTranslateX = widget.lerpDouble(100, 0, pageOffset);
        } else {
          textTranslateX = 100;
        }

        double imageTranslateY;
        if (widget.index == basePage) {
          imageTranslateY = widget.lerpDouble(0, -50, pageOffset);
        } else if (widget.index == basePage + 1) {
          imageTranslateY = widget.lerpDouble(50, 0, pageOffset);
        } else {
          imageTranslateY = 50;
        }

        final OnboardingPageContent content = _staticContent;
        final Widget? hero = content.hero;
        final Widget textContent = content.textContent;
        final double spacing = ScreenScaler.s(40);

        final List<Widget> columnChildren = <Widget>[
          if (hero != null)
            Transform.translate(
              offset: Offset(0, imageTranslateY),
              child: hero,
            ),
          SizedBox(height: spacing),
          Transform.translate(
            offset: Offset(textTranslateX, 0),
            child: textContent,
          ),
        ];

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ScreenScaler.s(24),
              vertical: ScreenScaler.s(60),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: columnChildren,
            ),
          ),
        );
      },
    );
  }
}
