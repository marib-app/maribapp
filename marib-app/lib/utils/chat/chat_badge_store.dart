import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistence helper that stores chat badge counters per user.
///
/// Keeping it separate from the UI layer allows other services (such as
/// Hive utilities) to reset the counters without depending on Flutter
/// widgets. Values are saved per-user so logging out won't leak the old
/// counts into a new session.
class ChatBadgeStore {
  ChatBadgeStore._();

  static const String _buyerKeyPrefix = 'chat_unread:buyer:';
  static const String _sellerKeyPrefix = 'chat_unread:seller:';

  /// Loads the stored unread counters for the provided [userId]. If the user
  /// has never stored counters before this simply returns zeros.
  static Future<({int buyer, int seller})> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return (
    buyer: prefs.getInt('$_buyerKeyPrefix$userId') ?? 0,
    seller: prefs.getInt('$_sellerKeyPrefix$userId') ?? 0,
    );
  }

  /// Saves the counters for the given [userId]. Values are clamped to avoid
  /// storing negative numbers that might slip in from buggy API responses.
  static Future<void> save(
      String userId, {
        required int buyer,
        required int seller,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_buyerKeyPrefix$userId', buyer.clamp(0, 9999));
    await prefs.setInt('$_sellerKeyPrefix$userId', seller.clamp(0, 9999));
  }

  /// Removes any stored counters for the supplied [userId].
  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_buyerKeyPrefix$userId');
    await prefs.remove('$_sellerKeyPrefix$userId');
  }
}
