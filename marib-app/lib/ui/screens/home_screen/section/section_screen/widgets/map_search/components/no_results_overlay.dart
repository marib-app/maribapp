import 'package:flutter/material.dart';

class NoResultsOverlay extends StatelessWidget {
  const NoResultsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(.98),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(.25),
          ),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 32),
            SizedBox(height: 8),
            Text('لا توجد إعلانات ضمن الإعدادات الحالية'),
          ],
        ),
      ),
    );
  }
}