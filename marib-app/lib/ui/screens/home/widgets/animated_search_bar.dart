import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/app/routes.dart';

/// بسيط ومتناسق مع واجهة الهوم، يحافظ على التلميحات المتبدلة والانتقال لشاشة البحث.
class AnimatedSearchBar extends StatefulWidget {
  const AnimatedSearchBar({super.key});

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
    with WidgetsBindingObserver {
  final List<String> hints = const [
    "ابحث عن منتج، خدمة أو إعلان",
    "جرّب كلمات مثل: كمبيوتر، عقار، صيانة",
    "اكتب اسم المتجر أو البائع للوصول السريع",
  ];

  int currentHintIndex = 0;
  Timer? _timer;
  bool _isLifecycleResumed = true;

  Duration _getDurationForHint(String text) {
    final base = 4.0;
    final extra = (text.length / 10);
    return Duration(seconds: (base + extra).ceil());
  }

  void _startTimer() {
    if (!_isLifecycleResumed || hints.isEmpty) return;
    _cancelTimer();
    _timer = Timer(_getDurationForHint(hints[currentHintIndex]), () {
      if (!mounted) return;
      setState(() {
        currentHintIndex = (currentHintIndex + 1) % hints.length;
      });
      _startTimer();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? lifecycleState =
        WidgetsBinding.instance.lifecycleState;
    _isLifecycleResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (_isLifecycleResumed) _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool shouldResume = state == AppLifecycleState.resumed;
    if (shouldResume == _isLifecycleResumed) return;
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hintFontSize = screenWidth < 360 ? 14 : 15;

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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          height: 54,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white12 : Colors.black12),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 22,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 650),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.28),
                        end: Offset.zero,
                      ).animate(curved);
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      key: ValueKey(currentHintIndex),
                      child: Text(
                        hints[currentHintIndex],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontSize: hintFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
