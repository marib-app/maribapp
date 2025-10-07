import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageWithNavigationWidget extends StatefulWidget {
  final String assetPath;
  final VoidCallback? onTap;

  const ImageWithNavigationWidget({
    super.key,
    required this.assetPath,
    this.onTap,
  });

  @override
  State<ImageWithNavigationWidget> createState() =>
      _ImageWithNavigationWidgetState();
}

class _ImageWithNavigationWidgetState extends State<ImageWithNavigationWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 395,
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            // ظل ناعم يتبدّل عند الضغط
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_pressed ? 0.06 : 0.12),
                blurRadius: _pressed ? 10 : 16,
                spreadRadius: 0,
                offset: Offset(0, _pressed ? 4 : 8),
              ),
            ],
          ),
          // Material + InkWell عشان Ripple مقصوص بشكل صحيح
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                  color: Colors.black.withOpacity(0.10)), // إطار خفيف
            ),
            child: InkWell(
              onTap: widget.onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      widget.onTap!.call();
                    },
              splashColor: Colors.white.withOpacity(0.08),
              highlightColor: Colors.white.withOpacity(0.02),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // الصورة
                  Ink.image(
                    image: AssetImage(widget.assetPath),
                    fit: BoxFit.cover,
                  ),
                  // تدرّج خفيف من الأسفل (مفيد لو أضفت نص لاحقًا)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0x80000000), Color(0x00000000)],
                        stops: [0.0, 0.6],
                      ),
                    ),
                  ),
                  // مثال نص اختياري (احذفه إن ما تحتاجه)
                  // Align(
                  //   alignment: Alignment.bottomLeft,
                  //   child: Padding(
                  //     padding: const EdgeInsets.all(12),
                  //     child: Text('عنوان القسم',
                  //       style: const TextStyle(
                  //         color: Colors.white, fontWeight: FontWeight.w700),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
