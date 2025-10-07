// ======= Smart Hint (single-file) ===========================================

import 'dart:async';
import 'package:flutter/material.dart';



enum SmartHintKind {
  initial,         // أول مرة
  moveMap,         // أثناء التحريك
  zoomIn,          // قرّب الخريطة
  reverseLoading,  // جارِ تحديد العنوان
  reverseNoResult, // لم يُعثر على عنوان
  myLocationTip,   // جرّب زر موقعي
  confirmed,       // تم التحديد
}

class SmartHintState {
  final SmartHintKind kind;
  final String text;
  final IconData icon;
  const SmartHintState(this.kind, this.text, this.icon);
}

class SmartHintController {
  final ValueNotifier<SmartHintState?> notifier = ValueNotifier(null);
  Timer? _autoHide;
  DateTime _lastMoveAt = DateTime.now();

  void dispose() {
    _autoHide?.cancel();
    notifier.dispose();
  }

  void _show(SmartHintState s, {Duration? forDuration}) {
    _autoHide?.cancel();
    notifier.value = s;
    if (forDuration != null) {
      _autoHide = Timer(forDuration, () => hide());
    }
  }

  void hide() {
    _autoHide?.cancel();
    notifier.value = null;
  }

  // أحداث تستخدمها من شاشة الخريطة:
  void onScreenOpened() {
    _show(
      const SmartHintState(
        SmartHintKind.initial,
        '📍 اترك الدبوس على موقع الإعلان',
        Icons.info_outline,
      ),
      forDuration: const Duration(seconds: 5),
    );
  }

  void onMoveStart() {
    _lastMoveAt = DateTime.now();
    _show(const SmartHintState(
      SmartHintKind.moveMap,
      'حرّك الخريطة ليكون الدبوس في منتصف الموقع المطلوب',
      Icons.pan_tool_alt_outlined,
    ));
  }

  void onMove({required double zoom}) {
    _lastMoveAt = DateTime.now();
    if (zoom < 14) {
      _show(const SmartHintState(
        SmartHintKind.zoomIn,
        'قرّب الخريطة للحصول على عنوان أدق',
        Icons.zoom_in_map,
      ));
    }
  }

  void onIdle() {
    final since = DateTime.now().difference(_lastMoveAt);
    if (since > const Duration(seconds: 5)) {
      _show(
        const SmartHintState(
          SmartHintKind.myLocationTip,
          'تقدر تستخدم زر 📍 موقعي للرجوع بسرعة',
          Icons.my_location,
        ),
        forDuration: const Duration(seconds: 4),
      );
    }
  }

  void onReverseStart() {
    _show(const SmartHintState(
      SmartHintKind.reverseLoading,
      'جارِ تحديد العنوان…',
      Icons.sync,
    ));
  }

  void onReverseDone({required bool success}) {
    if (success) {
      _show(
        const SmartHintState(
          SmartHintKind.confirmed,
          'تم تحديد العنوان 🎯',
          Icons.check_circle,
        ),
        forDuration: const Duration(seconds: 3),
      );
    } else {
      _show(
        const SmartHintState(
          SmartHintKind.reverseNoResult,
          'تعذّر العثور على عنوان دقيق هنا — قرّب أكثر أو حرّك قليلاً',
          Icons.error_outline,
        ),
        forDuration: const Duration(seconds: 4),
      );
    }
  }
}

class SmartHintOverlay extends StatelessWidget {
  final SmartHintController controller;
  final double offsetBelowPin; // مسافة أسفل الدبوس
  const SmartHintOverlay({
    super.key,
    required this.controller,
    this.offsetBelowPin = 56,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: Alignment.center,
        child: Transform.translate(
          offset: Offset(0, offsetBelowPin),
          child: ValueListenableBuilder<SmartHintState?>(
            valueListenable: controller.notifier,
            builder: (_, state, __) {
              if (state == null) return const SizedBox.shrink();
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Container(
                  key: ValueKey(state.kind),
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.surface.withOpacity(.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.outline.withOpacity(.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(state.icon, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          state.text,
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
// ============================================================================
// نهاية المقطع الجاهز
