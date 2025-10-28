import 'package:flutter/material.dart';
import 'package:marib/utils/screen_scaler.dart';

class OnboardingStartButton extends StatelessWidget {
  const OnboardingStartButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: ScreenScaler.s(24),
          vertical: ScreenScaler.s(12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScreenScaler.s(30)),
        ),
        elevation: 8,
      ),
      child: Text(
        'ابدأ الآن',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: ScreenScaler.s(16),
        ),
      ),
    );
  }
}