import 'package:flutter/foundation.dart';

/// Simple controller to keep chat unread badges in sync across the app.
///
/// The chat lists are maintained separately for buyer and seller roles, and
/// each cubit reports its unread count so that the main navigation badge can
/// be updated without the lists needing to know about each other.
class ChatBadgeController {
  ChatBadgeController._();

  static final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  static int _buyerUnread = 0;
  static int _sellerUnread = 0;

  static void updateBuyerUnread(int count) {
    _buyerUnread = count.clamp(0, 9999);
    _notify();
  }

  static void updateSellerUnread(int count) {
    _sellerUnread = count.clamp(0, 9999);
    _notify();
  }

  static void incrementTempUnread() {
    totalUnread.value = (_buyerUnread + _sellerUnread + 1).clamp(0, 9999);
  }

  static void _notify() {
    totalUnread.value = (_buyerUnread + _sellerUnread).clamp(0, 9999);
  }
}