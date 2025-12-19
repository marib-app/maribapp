import 'package:flutter/material.dart';

/// شاشة إذن الموقع – تم تعطيلها بالكامل.
class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // تعطيل عرض شاشة إذن الموقع نهائياً
    return const SizedBox.shrink();
  }
}
