import 'package:flutter/material.dart';
import 'package:marib/utils/screen_scaler.dart';

class OnboardingHint extends StatelessWidget {
  const OnboardingHint({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swipe_right,
            color: Colors.white70,
            size: ScreenScaler.iconSize(context, baseSize: 24),
          ),
          SizedBox(height: ScreenScaler.s(6)),
          Text(
            'اسحب لليمين للمتابعة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: ScreenScaler.fontSize(context, baseSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}