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

class CardPlanetData {
  final String title;
  final String subtitle;
  final ImageProvider? image;
  final List<Color> backgroundGradientColors;
  final Color titleColor;
  final Color subtitleColor;
  final String? backgroundAnimationPath;
  final String? animationPath;

  CardPlanetData({
    required this.title,
    required this.subtitle,
    this.image,
    required this.backgroundGradientColors,
    required this.titleColor,
    required this.subtitleColor,
    this.backgroundAnimationPath,
    this.animationPath,
  });
}

class CardPlanet extends StatelessWidget {
  final CardPlanetData data;
  final Map<String, LottieComposition> compositions;
  final bool isActive;

  const CardPlanet({
    required this.data,
    required this.isActive,
    required this.compositions,
    super.key,
  });

  LottieComposition? _compositionFor(String? path) {
    if (path == null) return null;
    return compositions[path];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: data.backgroundGradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (data.backgroundAnimationPath != null)
          Opacity(
            opacity: 0.2,
            child: () {
              final cached = _compositionFor(data.backgroundAnimationPath);
              if (cached != null) {
                return Lottie(
                  composition: cached,
                  fit: BoxFit.cover,
                  animate: isActive,
                  repeat: isActive,
                );
              }
              return Lottie.asset(
                data.backgroundAnimationPath!,
                fit: BoxFit.cover,
                animate: isActive,
                repeat: isActive,
              );
            }(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              if (data.animationPath != null)
                Flexible(
                  flex: 20,
                  child: () {
                    final cached = _compositionFor(data.animationPath);
                    if (cached != null) {
                      return Lottie(
                        composition: cached,
                        height: MediaQuery.of(context).size.height * 0.45,
                        fit: BoxFit.contain,
                        animate: isActive,
                        repeat: isActive,
                      );
                    }
                    return Lottie.asset(
                      data.animationPath!,
                      height: MediaQuery.of(context).size.height * 0.45,
                      fit: BoxFit.contain,
                      // قم بإيقاف التشغيل الافتراضي إذا تريد تحكم خاص
                      animate: isActive,
                      repeat: isActive,
                    );
                  }(),
                ),
              if (data.image != null)
                Flexible(flex: 20, child: Image(image: data.image!)),
              const Spacer(flex: 2),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    Text(
                      data.title,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: data.titleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.subtitle,
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        height: 1.6,
                        color: data.subtitleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 5),
            ],
          ),
        )
      ],
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  bool _showHint = false;
  Timer? _hintTimer;
  final Map<String, LottieComposition> _preloadedCompositions = {};

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_preloadAssets());
    });
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showHint = true);
    });
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
    _hintTimer?.cancel();
    currentIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: data[currentIndex.value].backgroundGradientColors.last,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (_) {}, // تمكين التفاعل بالسحب على كامل الشاشة
        child: Stack(
          children: [
            ConcentricPageView(
              reverse: true,
              onChange: (i) => currentIndex.value = i,
              itemCount: data.length,
              colors: data.map((e) => e.backgroundGradientColors.last).toList(),
              itemBuilder: (index) => ValueListenableBuilder<int>(
                valueListenable: currentIndex,
                builder: (context, activeIndex, _) {
                  return CardPlanet(
                    data: data[index],
                    isActive: index == activeIndex,
                    compositions: _preloadedCompositions,
                  );
                },
              ),
              onFinish: () {
                HiveUtils.setUserIsNotNew();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(Routes.login, (_) => false);
              },
            ),
            ValueListenableBuilder<int>(
              valueListenable: currentIndex,
              builder: (context, index, _) {
                return Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(data.length, (i) {
                      final reversedIndex = data.length - 1 - i;
                      final selected = reversedIndex == index;
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
                );
              },
            ),
            ValueListenableBuilder<int>(
              valueListenable: currentIndex,
              builder: (context, index, _) {
                if (!_showHint || index == data.length - 1) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.swipe_right, color: Colors.white70),
                        SizedBox(height: 6),
                        Text(
                          "اسحب لليمين للمتابعة",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
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
                          child: const Text("ابدأ الآن",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      : const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
