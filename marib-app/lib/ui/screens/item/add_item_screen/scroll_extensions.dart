// lib/utils/extensions/scroll_extensions.dart
import 'package:flutter/widgets.dart';

extension ScrollControllerExtension on ScrollController {
  bool isEndReached({double offset = 200.0}) {
    if (!hasClients) return false;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    return maxScroll - currentScroll <= offset;
  }
}
