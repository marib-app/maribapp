import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/extensions/extensions.dart';

/// Animated search bar used on home screen hero area.
class AnimatedSearchBar extends StatefulWidget {
  const AnimatedSearchBar({super.key});

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar>
    with WidgetsBindingObserver {
  static const List<String> _hintKeys = <String>[
    'homeSearchHint1',
    'homeSearchHint2',
    'homeSearchHint3',
  ];

  int currentHintIndex = 0;
  Timer? _timer;
  bool _isLifecycleResumed = true;
  String? _lastHintsSignature;

  Duration _getDurationForHint(String text) {
    final base = 4.0;
    final extra = (text.length / 10);
    return Duration(seconds: (base + extra).ceil());
  }

  void _startTimer(List<String> hints) {
    if (!_isLifecycleResumed || hints.isEmpty) return;
    _cancelTimer();
    _timer = Timer(_getDurationForHint(hints[currentHintIndex]), () {
      if (!mounted) return;
      setState(() {
        currentHintIndex = (currentHintIndex + 1) % hints.length;
      });
      _startTimer(hints);
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
    // Timer will be (re)started in build with the translated hints.
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
    setState(() {
      _isLifecycleResumed = shouldResume;
      if (!shouldResume) {
        _cancelTimer();
      } else {
        currentHintIndex = 0;
        _cancelTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final TextAlign localeAlign = isRtl ? TextAlign.right : TextAlign.left;
    final Alignment hintAlignment =
        isRtl ? Alignment.centerRight : Alignment.centerLeft;
    final String languageCode =
        Localizations.localeOf(context).languageCode.toLowerCase();
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hintFontSize = screenWidth < 360 ? 14 : 15;

    final List<String> hintTexts = (languageCode.startsWith('ar'))
        ? const [
            'ابحث عن منتجات أو خدمات أو مواقع',
            'جرّب كتابة لابتوب، فيلا، أو مقهى',
            'اعثر على العروض القريبة والمنتجات الرائجة',
          ]
        : _hintKeys.map((key) => key.translate(context)).toList();

    if (hintTexts.isEmpty) {
      hintTexts.add('searchHintLbl'.translate(context));
    }

    final String signature = hintTexts.join('|');
    if (_lastHintsSignature != signature) {
      _lastHintsSignature = signature;
      currentHintIndex = 0;
      _cancelTimer();
    }

    // Restart timer with updated translations.
    if (_timer == null && _isLifecycleResumed) {
      _startTimer(hintTexts);
    }

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
                        alignment: hintAlignment,
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
                      alignment: hintAlignment,
                      key: ValueKey(currentHintIndex % hintTexts.length),
                      child: Text(
                        hintTexts[currentHintIndex % hintTexts.length],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontSize: hintFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: localeAlign,
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
