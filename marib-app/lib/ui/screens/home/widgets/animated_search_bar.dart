import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:marib/app/routes.dart';

class AnimatedSearchBar extends StatefulWidget {
  const AnimatedSearchBar({super.key});

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final List<String> hints = [
    "ابحث عن منتج يهمك 🔍",
    "وش تحتاج اليوم؟ 🛒",
    "استكشف العروض الجديدة 🎁",
    "جرب تكتب 'كوب قهوة' ☕",
  ];

  int currentHintIndex = 0;
  Timer? _timer;
  bool _isLifecycleResumed = true;

  Duration _getDurationForHint(String text) {
    final base = 4.0; // مدة أساسية بالثواني
    final extra = (text.length / 10); // زيادة حسب طول النص
    return Duration(seconds: (base + extra).ceil());
  }

  void _startTimer() {
    if (!_isLifecycleResumed || hints.isEmpty) {
      return;
    }
    _cancelTimer();
    _timer = Timer(_getDurationForHint(hints[currentHintIndex]), () {
      if (!mounted) {
        return;
      }
      setState(() {
        currentHintIndex = (currentHintIndex + 1) % hints.length;
      });
      _startTimer(); // نعيد التايمر
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? lifecycleState =
        WidgetsBinding.instance.lifecycleState;
    _isLifecycleResumed = lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
    if (_isLifecycleResumed) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    super.dispose();
  }
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool shouldResume = state == AppLifecycleState.resumed;
    if (shouldResume == _isLifecycleResumed) {
      return;
    }
    _isLifecycleResumed = shouldResume;
    if (shouldResume) {
      _startTimer();
    } else {
      _cancelTimer();
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(
            context,
            Routes.searchScreenRoute,
            arguments: {"autoFocus": true},
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          height: 50,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.search, size: 22, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800), // ← أبطأ وأكثر سلاسة
                  switchInCurve: Curves.easeOutQuad,
                  switchOutCurve: Curves.easeInQuad,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.2, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ));

                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slide,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    hints[currentHintIndex],
                    key: ValueKey(currentHintIndex),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
