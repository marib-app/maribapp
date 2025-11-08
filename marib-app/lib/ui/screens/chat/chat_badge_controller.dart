import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:marib/utils/chat/chat_badge_store.dart';

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
  static String? _userId;
  static bool _badgeSupportKnown = false;
  static bool _isBadgeSupported = false;

  /// Loads the cached unread counters for the supplied [userId]. Passing `null`
  /// resets the controller to zero which is used on logout.
  static Future<void> init({String? userId}) async {
    final String? trimmed = userId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _userId = null;
      _buyerUnread = 0;
      _sellerUnread = 0;
      _notify();
      return;
    }

    _userId = trimmed;
    final stored = await ChatBadgeStore.load(trimmed);
    _buyerUnread = stored.buyer.clamp(0, 9999);
    _sellerUnread = stored.seller.clamp(0, 9999);
    _notify();
  }

  /// Helper used by authentication flows when the active user changes.
  static Future<void> handleUserChanged(String? userId) => init(userId: userId);


  static void updateBuyerUnread(int count) {
    _buyerUnread = count.clamp(0, 9999);
    _persist();
    _notify();
  }

  static void updateSellerUnread(int count) {
    _sellerUnread = count.clamp(0, 9999);
    _persist();
    _notify();
  }

  static void incrementTempUnread() {
    final int tempTotal = (_buyerUnread + _sellerUnread + 1).clamp(0, 9999);
    totalUnread.value = tempTotal;
    _updateAppBadge(tempTotal);
  }

  static void _notify() {
    final int total = (_buyerUnread + _sellerUnread).clamp(0, 9999);
    totalUnread.value = total;
    _updateAppBadge(total);
  }
  static void _persist() {
    final String? userId = _userId;
    if (userId == null || userId.isEmpty) {
      return;
    }
    unawaited(ChatBadgeStore.save(
      userId,
      buyer: _buyerUnread,
      seller: _sellerUnread,
    ));
  }

  static void _updateAppBadge(int count) {
    unawaited(_setBadgeCount(count));
  }

  static Future<void> _setBadgeCount(int count) async {
    try {
      if (!_badgeSupportKnown) {
        _isBadgeSupported = await FlutterAppBadger.isAppBadgeSupported();
        _badgeSupportKnown = true;
      }
      if (!_isBadgeSupported) {
        return;
      }
      if (count <= 0) {
        await FlutterAppBadger.removeBadge();
      } else {
        await FlutterAppBadger.updateBadgeCount(count);
      }
    } catch (_) {
      _isBadgeSupported = false;
    }
  }
}
