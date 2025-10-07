import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/utils/extensions/extensions.dart'; // للوصول إلى context.color & context.font
import 'package:marib/ui/theme/theme.dart';

class NoInternet extends StatefulWidget {
  final VoidCallback? onRetry;

  const NoInternet({super.key, this.onRetry});

  @override
  State<NoInternet> createState() => _NoInternetState();
}

enum _NetUiState { idle, loading, success }

class _NoInternetState extends State<NoInternet> with TickerProviderStateMixin {
  _NetUiState _state = _NetUiState.idle;
  String? _statusMsg;

  late final AnimationController _successPulse =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
    ..value = 0.0;

  @override
  void dispose() {
    _successPulse.dispose();
    super.dispose();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final socket = await Socket.connect('1.1.1.1', 53, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onRetryPressed() async {
    if (_state == _NetUiState.loading) return;
    setState(() {
      _state = _NetUiState.loading;
      _statusMsg = null;
    });

    final ok = await _checkConnectivity();
    if (!mounted) return;

    if (ok) {
      HapticFeedback.lightImpact();
      setState(() {
        _state = _NetUiState.success;
      });
      _successPulse
        ..value = 0.0
        ..forward();

      await Future.delayed(const Duration(milliseconds: 600));
      widget.onRetry?.call();
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _state = _NetUiState.idle;
        _statusMsg = "لا يزال الاتصال غير متاح. جرّب مرة أخرى.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.color.territoryColor;
    final bg = context.color.backgroundColor;
    final onBg = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minSide = constraints.biggest.shortestSide.clamp(280.0, 900.0);
            final circle = (minSide * 0.55).clamp(160.0, 360.0);
            final iconSize = (circle * 0.22).clamp(36.0, 64.0);
            final ring1 = circle;
            final ring2 = circle * 0.72;
            final ring3 = circle * 0.50;

            return Column(
              children: [
                const Spacer(flex: 2),

                // الرسم الرئيسي
                SizedBox(
                  width: circle,
                  height: circle,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring(ring1, brand.withOpacity(0.14)),
                      _ring(ring2, brand.withOpacity(0.16)),
                      _ring(ring3, brand.withOpacity(0.18)),

                      Container(
                        width: circle * 0.4,
                        height: circle * 0.4,
                        decoration: BoxDecoration(
                          color: brand.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: brand.withOpacity(0.25)),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: () {
                            if (_state == _NetUiState.loading) {
                              return SizedBox(
                                key: const ValueKey('loader'),
                                width: iconSize,
                                height: iconSize,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: brand,
                                ),
                              );
                            }
                            if (_state == _NetUiState.success) {
                              return ScaleTransition(
                                key: const ValueKey('success'),
                                scale: Tween(begin: 0.7, end: 1.0).animate(
                                  CurvedAnimation(parent: _successPulse, curve: Curves.easeOutBack),
                                ),
                                child: Icon(Icons.check_circle_rounded, size: iconSize, color: brand),
                              );
                            }
                            return Icon(Icons.wifi_off_rounded,
                                key: const ValueKey('icon'), size: iconSize, color: brand);
                          }(),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: (minSide * 0.04).clamp(12.0, 24.0)),

                // العنوان
                Text(
                  _state == _NetUiState.success ? "تم الاتصال بالإنترنت" : "لا يوجد اتصال بالإنترنت",
                  textAlign: TextAlign.center,
                ).size(context.font.extraLarge).color(onBg).bold(weight: FontWeight.w700),

                const SizedBox(height: 8),

                // الوصف
                Text(
                  _state == _NetUiState.success ? "جاري المتابعة..." : "تحقق من الشبكة ثم جرّب مرة أخرى.",
                  textAlign: TextAlign.center,
                ).size(context.font.normal).color(onBg.withOpacity(0.75)),

                const SizedBox(height: 20),

                // زر إعادة المحاولة
                ElevatedButton(
                  onPressed: _state == _NetUiState.loading ? null : _onRetryPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _state == _NetUiState.loading ? "يفحص الاتصال..." : "إعادة المحاولة",
                  ).size(context.font.normal).bold(),
                ),

                // رسالة الخطأ تظهر أسفل الزر عند الفشل
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: (_statusMsg == null)
                      ? const SizedBox.shrink()
                      : Padding(
                    key: ValueKey(_statusMsg),
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _statusMsg!,
                      textAlign: TextAlign.center,
                    ).size(context.font.small).color(onBg.withOpacity(0.85)),
                  ),
                ),

                const Spacer(),

                // الملاحظة أسفل الشاشة دائمًا
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: onBg.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "جرّب تفعيل/إيقاف وضع الطيران أو التحقق من بيانات الهاتف أو الواي فاي.",
                          textAlign: TextAlign.center,
                        ).size(context.font.small).color(onBg.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _ring(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
