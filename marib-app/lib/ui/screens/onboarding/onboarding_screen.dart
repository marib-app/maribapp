import 'dart:async';
import 'package:concentric_transition/page_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';

import 'models/card_planet_data.dart';
import 'widgets/card_planet.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  late final PageController _pageController;
  late final ValueNotifier<double> _pageNotifier;

  bool _showHint = false;
  Timer? _hintTimer;
  final Map<String, LottieComposition> _preloadedCompositions = {};
  late final AnimationController _hintAnimationController;
  late final Animation<double> _hintFadeAnimation;
  late final Animation<Offset> _hintSlideAnimation;

  final data = [
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
      backgroundAnimationPath: 'assets/lottie/bg-2.json',
    ),
    CardPlanetData(
      title: "كل العقارات بخطوة!",
      subtitle: "وفّر وقتك، كل العروض العقارية في مكان واحد.",
      backgroundGradientColors: [Color(0xFF355C7D), Color(0xFF6C5B7B)],
      titleColor: Colors.yellow,
      subtitleColor: Colors.white,
      animationPath: 'assets/lottie/a_2.json',
      backgroundAnimationPath: 'assets/lottie/bg-1.json',
    ),
    CardPlanetData(
      title: "خلّي متجرك يلمع",
      subtitle: "اعرض منتجاتك ، بعها بسهولة ، وخلي التوصيل علينا.",
      backgroundGradientColors: [Colors.black87, Colors.grey.shade900],
      titleColor: Colors.amber,
      subtitleColor: Colors.white,
      animationPath: 'assets/lottie/a_3.json',
      backgroundAnimationPath: 'assets/lottie/bg-2.json',
    ),
    CardPlanetData(
      title: "بع، اشترِي، وأعلن!",
      subtitle: "بدون وسيط، حط إعلانك وخلي الناس تجيك!",
      backgroundGradientColors: [Colors.black87, Colors.grey.shade800],
      titleColor: Colors.lightBlueAccent,
      subtitleColor: Colors.white,
      animationPath: 'assets/lottie/a_4.json',
      backgroundAnimationPath: 'assets/lottie/bg-1.json',
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

    _pageController = PageController();
    _pageNotifier =
        ValueNotifier<double>(_pageController.initialPage.toDouble());
    _pageController.addListener(_handlePageChanged);

    _hintAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    final animationCurve = CurvedAnimation(
      parent: _hintAnimationController,
      curve: Curves.easeInOut,
    );
    _hintFadeAnimation =
        Tween<double>(begin: 0.6, end: 1).animate(animationCurve);
    _hintSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.05))
            .animate(animationCurve);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_preloadAssets());
    });
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showHint = true);
      _syncHintAnimation();
    });
  }

  void _handlePageChanged() {
    final page = _pageController.hasClients
        ? _pageController.page ?? _pageController.initialPage.toDouble()
        : _pageController.initialPage.toDouble();
    if (_pageNotifier.value != page) {
      _pageNotifier.value = page;
    }
  }

  void _syncHintAnimation() {
    final shouldAnimate = _showHint && currentIndex.value != data.length - 1;
    if (shouldAnimate) {
      if (!_hintAnimationController.isAnimating) {
        _hintAnimationController.repeat(reverse: true);
      }
    } else {
      if (_hintAnimationController.isAnimating ||
          _hintAnimationController.value != 0.0) {
        _hintAnimationController.stop();
        _hintAnimationController.reset();
      }
    }
  }

  Future<void> _preloadAssets() async {
    final Map<String, LottieComposition> loaded = {};

    for (final card in data) {
      if (!mounted) return;

      final image = card.image;
      if (image != null) {
        await precacheImage(image, context);
      }

      await _loadComposition(card.animationPath, loaded);
      await _loadComposition(card.backgroundAnimationPath, loaded);
    }

    if (!mounted || loaded.isEmpty) return;
    setState(() {
      _preloadedCompositions.addAll(loaded);
    });
  }

  Future<void> _loadComposition(
    String? path,
    Map<String, LottieComposition> target,
  ) async {
    if (path == null ||
        _preloadedCompositions.containsKey(path) ||
        target.containsKey(path)) {
      return;
    }

    try {
      final composition = await AssetLottie(
        path,
        bundle: rootBundle,
      ).load();
      target[path] = composition;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to preload Lottie asset $path: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  @override
  void dispose() {
    _hintAnimationController.dispose();
    _hintTimer?.cancel();
    _pageController.removeListener(_handlePageChanged);
    _pageController.dispose();
    _pageNotifier.dispose();
    currentIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<int>(
        valueListenable: currentIndex,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (_) {},
          // تمكين التفاعل بالسحب على كامل الشاشة
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                reverse: true,
                itemCount: data.length,
                onPageChanged: (index) {
                  currentIndex.value = index;
                  _syncHintAnimation();
                  if (index == data.length - 1 && _showHint) {
                    setState(() => _showHint = false);
                  }
                },
                itemBuilder: (context, index) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _pageNotifier,
                    builder: (context, page, _) {
                      final effectivePage = page
                          .clamp(0.0, (data.length - 1).toDouble())
                          .toDouble();
                      final progress = index - effectivePage;
                      final isActive = progress.abs() < 0.5;
                      return CardPlanet(
                        data: data[index],
                        progress: progress,
                        isActive: isActive,
                        compositions: _preloadedCompositions,
                      );
                    },
                  );
                },
              ),
              ValueListenableBuilder<int>(
                valueListenable: currentIndex,
                builder: (context, index, _) {
                  return Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(data.length, (i) {
                          final selected = i == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: selected ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : Colors.white38,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<int>(
                valueListenable: currentIndex,
                builder: (context, index, _) {
                  final shouldShowHint = _showHint && index != data.length - 1;
                  if (!shouldShowHint) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: FadeTransition(
                        opacity: _hintFadeAnimation,
                        child: SlideTransition(
                          position: _hintSlideAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.swipe_right, color: Colors.white70),
                              SizedBox(height: 6),
                              Text(
                                "اسحب لليمين للمتابعة",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 20,
                bottom: 60,
                child: ValueListenableBuilder<int>(
                  valueListenable: currentIndex,
                  builder: (context, index, _) {
                    return index == data.length - 1
                        ? ElevatedButton(
                            onPressed: () {
                              HiveUtils.setUserIsNotNew();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  Routes.login, (_) => false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 8,
                            ),
                            child: const Text(
                              "ابدأ الآن",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                        : const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
        builder: (context, _, child) {
          return ValueListenableBuilder<double>(
            valueListenable: _pageNotifier,
            builder: (context, page, _) {
              final clampedPage =
                  page.clamp(0.0, (data.length - 1).toDouble()).toDouble();
              final lowerIndex = clampedPage.floor();
              final upperIndex = math.min(data.length - 1, clampedPage.ceil());
              final t = (clampedPage - lowerIndex).clamp(0.0, 1.0);

              List<Color> gradientFor(int cardIndex) =>
                  data[cardIndex].backgroundGradientColors;

              List<Color> lerpGradient(
                List<Color> from,
                List<Color> to,
                double progress,
              ) {
                final maxLength = math.max(from.length, to.length);
                return List<Color>.generate(maxLength, (i) {
                  final fromColor = from[i % from.length];
                  final toColor = to[i % to.length];
                  return Color.lerp(fromColor, toColor, progress) ?? fromColor;
                });
              }

              final blendedColors = lowerIndex == upperIndex
                  ? gradientFor(lowerIndex)
                  : lerpGradient(
                      gradientFor(lowerIndex),
                      gradientFor(upperIndex),
                      t,
                    );

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: blendedColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}
