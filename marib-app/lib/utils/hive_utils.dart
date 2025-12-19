import 'package:marib/app/app_theme.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:marib/data/model/user_model.dart';
import 'package:marib/data/model/verification_request_model.dart';

import 'helper_utils.dart';
import 'package:marib/utils/hive_keys.dart';
import 'dart:math';
import 'dart:async';
import 'package:marib/ui/screens/chat/chat_badge_controller.dart';
import 'dart:convert';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/notification/notification_service.dart';

// ط£ط¯ط§ط© ظ…ط³ط§ط¹ط¯ط© ظ„ظ„طھط¹ط§ظ…ظ„ ظ…ط¹ ط§ظ„طھط®ط²ظٹظ† ط§ظ„ظ…ط­ظ„ظٹ ط¹ط¨ط± Hive
// - طھظڈط¬ظ…ظ‘ط¹ ظƒظ„ ط¹ظ…ظ„ظٹط§طھ ط§ظ„ظ‚ط±ط§ط،ط©/ط§ظ„ظƒطھط§ط¨ط© ط¹ظ„ظ‰ طµظ†ط§ط¯ظٹظ‚ Hive
// - طھظڈظ‚ط¯ظ‘ظ… ط¯ظˆط§ظ„ ط¹ط§ظ„ظٹط© ط§ظ„ظ…ط³طھظˆظ‰ ظ„ط§ط³طھط®ط¯ط§ظ… ظ…ظˆط­ظ‘ط¯ ط¯ط§ط®ظ„ ط§ظ„ظ…ط´ط±ظˆط¹

class HiveUtils {
  HiveUtils._();

  static UserModel? _cachedUserDetails;
  static Map<String, dynamic>? _cachedUserDetailsMap;
  static String? _cachedSliderSessionId;
  static final Random _sliderSessionRandom = Random();
  static final List<VoidCallback> _logoutHooks = <VoidCallback>[];
  static final List<VoidCallback> _userChangeHooks = <VoidCallback>[];

  static Box<dynamic> get _userDetailsBox => Hive.box(HiveKeys.userDetailsBox);
  static const Map<String, int> _delegateSectionRootIds = <String, int>{
    'shein': Constant.sheinRootCategoryId,
    'computer': Constant.computerRootCategoryId,
    'store': Constant.storeRootCategoryId,
  };

  static void _hydrateUserDetailsCache() {
    final box = _userDetailsBox;
    final map = <String, dynamic>{};
    _cachedSliderSessionId = null;

    for (final dynamic key in box.keys) {
      final cacheKey = key is String ? key : key.toString();
      map[cacheKey] = box.get(key);
      if (cacheKey == HiveKeys.sliderSessionId) {
        _cachedSliderSessionId = _normalizeSliderSessionIdValue(map[cacheKey]);
      }
    }
    _cachedUserDetailsMap = map;
    _cachedUserDetails = UserModel.fromJson(Map<String, dynamic>.from(map));
  }

  static void _rebuildCachedUserDetails() {
    if (_cachedUserDetailsMap == null) return;
    final map = _cachedUserDetailsMap;
    _cachedUserDetails =
        UserModel.fromJson(Map<String, dynamic>.from(_cachedUserDetailsMap!));
  }

  static void _applyCacheUpdates(Map<dynamic, dynamic> updates) {
    final cachedMap = _cachedUserDetailsMap;
    if (cachedMap == null) return;
    updates.forEach((dynamic key, dynamic value) {
      final cacheKey = key is String ? key : key.toString();
      if (cachedMap != null) {
        if (value is Map) {
          cachedMap[cacheKey] = Map<String, dynamic>.from(value);
        } else {
          cachedMap[cacheKey] = value;
        }
      }
      if (cacheKey == HiveKeys.sliderSessionId) {
        _cachedSliderSessionId = _normalizeSliderSessionIdValue(value);
      }
    });
    if (cachedMap != null) {
      _rebuildCachedUserDetails();
    }
  }

  static void _removeFromCache(Iterable<dynamic> keys) {
    if (_cachedUserDetailsMap == null) return;
    for (final dynamic key in keys) {
      final cacheKey = key is String ? key : key.toString();
      _cachedUserDetailsMap!.remove(cacheKey);
      if (cacheKey == HiveKeys.sliderSessionId) {
        _cachedSliderSessionId = null;
      }
    }
    _rebuildCachedUserDetails();
  }

  static void _invalidateUserDetailsCache() {
    _cachedUserDetails = null;
    _cachedUserDetailsMap = null;
    _cachedSliderSessionId = null;
  }

  static void registerLogoutHook(VoidCallback hook) {
    if (_logoutHooks.contains(hook)) {
      return;
    }
    _logoutHooks.add(hook);
  }

  static void unregisterLogoutHook(VoidCallback hook) {
    _logoutHooks.remove(hook);
  }

  static void _runLogoutHooks() {
    if (_logoutHooks.isEmpty) {
      return;
    }
    final List<VoidCallback> hooksSnapshot =
        List<VoidCallback>.from(_logoutHooks, growable: false);
    for (final VoidCallback hook in hooksSnapshot) {
      try {
        hook();
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            'HiveUtils.logout hook error: $error\n$stackTrace',
          );
        }
      }
    }
  }

  static void registerUserChangeHook(VoidCallback hook) {
    if (_userChangeHooks.contains(hook)) {
      return;
    }
    _userChangeHooks.add(hook);
  }

  static void unregisterUserChangeHook(VoidCallback hook) {
    _userChangeHooks.remove(hook);
  }

  static void _runUserChangeHooks() {
    if (_userChangeHooks.isEmpty) {
      return;
    }
    final List<VoidCallback> hooksSnapshot =
        List<VoidCallback>.from(_userChangeHooks, growable: false);
    for (final VoidCallback hook in hooksSnapshot) {
      try {
        hook();
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            'HiveUtils.userChange hook error: $error\n$stackTrace',
          );
        }
      }
    }
  }

  static String? _normalizeSliderSessionIdValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final String trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // ---------------------------------------------------------------------------
  //                         ظ…ظپط§طھظٹط­/ظ…ط³ط§ط¹ط¯ط§طھ ط¹ط§ظ…ط©
  // ---------------------------------------------------------------------------

  /// ظ‚ط±ط§ط،ط© ظ‚ظٹظ…ط© ظ…ظپط±ط¯ط© (Generic) ظ…ظ† طµظ†ط¯ظˆظ‚ طھظپط§طµظٹظ„ ط§ظ„ظ…ط³طھط®ط¯ظ…
  // ظ…ط«ط§ظ„: `HiveUtils.getUserDetail<String>(key: 'accountType')`

  static T? getUserDetail<T>({required String key}) {
    return _userDetailsBox.get(key) as T?;
  }

  // ظƒطھط§ط¨ط© ظ‚ظٹظ…ط© ظ…ظپط±ط¯ط© ظپظٹ طµظ†ط¯ظˆظ‚ طھظپط§طµظٹظ„ ط§ظ„ظ…ط³طھط®ط¯ظ…

  static Future<void> setUserDetail({
    required String key,
    required dynamic value,
  }) async {
    await _userDetailsBox.put(key, value);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({key: value});
    }
  }

  static String? getSliderSessionId() {
    final String? cached = _cachedSliderSessionId;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final dynamic stored = _userDetailsBox.get(HiveKeys.sliderSessionId);
    final String? normalized = _normalizeSliderSessionIdValue(stored);
    if (normalized != null) {
      _cachedSliderSessionId = normalized;
    }
    return normalized;
  }

  static Future<String> ensureSliderSessionId() async {
    final String? existing = getSliderSessionId();
    if (existing != null) {
      return existing;
    }
    final String newId = _generateSliderSessionId();
    await _userDetailsBox.put(HiveKeys.sliderSessionId, newId);
    _cachedSliderSessionId = newId;
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({HiveKeys.sliderSessionId: newId});
    }
    return newId;
  }

  static Future<void> clearSliderSessionId() async {
    await _userDetailsBox.delete(HiveKeys.sliderSessionId);
    _cachedSliderSessionId = null;
    if (_cachedUserDetailsMap != null) {
      _removeFromCache([HiveKeys.sliderSessionId]);
    }
  }

  static String _generateSliderSessionId() {
    final String timestamp =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final StringBuffer buffer = StringBuffer('sldr_')
      ..write(timestamp)
      ..write('_');
    for (int i = 0; i < 12; i++) {
      buffer.write(_sliderSessionRandom.nextInt(36).toRadixString(36));
    }
    return buffer.toString();
  }

  /// ظ‚ط³ظ… ط§ظ„ط³ظ„ط© ط§ظ„ط­ط§ظ„ظٹ (ظ„ظ…ظ†ط¹ ط¯ظ…ط¬ ط£ظ‚ط³ط§ظ… ظ…ط®طھظ„ظپط© ط¨ظٹظ† ط§ظ„ط¬ظ„ط³ط§طھ)
  static Future<void> setCartSection(String? section) async {
    final box = _userDetailsBox;
    if (section == null || section.isEmpty) {
      await box.delete(HiveKeys.cartSection);
      _removeFromCache([HiveKeys.cartSection]);
    } else {
      await box.put(HiveKeys.cartSection, section);
      if (_cachedUserDetailsMap != null) {
        _applyCacheUpdates({HiveKeys.cartSection: section});
      }
    }
  }

  static String? getCartSection() {
    final value = _userDetailsBox.get(HiveKeys.cartSection);
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  // ط¥ط±ط¬ط§ط¹ ظ†ظˆط¹ ط§ظ„ط­ط³ط§ط¨ ظƒظ…ط§ ظ‡ظˆ ظ…ط®ط²ظ‘ظ† (ظ…ظ† UserModel ط£ظˆ ظ…ط¨ط§ط´ط±ط© ظ…ظ† ط§ظ„ظ€Box)
  // ظ‚ط¯ ظٹط¹ظٹط¯: 'real_estate' | 'individual' | 'business' (ط£ظˆ ط³ظ„ط³ظ„ط© ظپط§ط±ط؛ط© ط¥ظ† ظ„ظ… ظٹظڈط­ط¯ظ‘ط¯)

  static String getAccountTypeRaw() {
    return (_userDetailsBox.get('accountType') ?? '').toString();
  }

  // ظ†ظˆط¹ ط§ظ„ط­ط³ط§ط¨ ط¨طµظٹط؛ط© lower-case ظ„طھط³ظ‡ظٹظ„ ط§ظ„ظ…ظ‚ط§ط±ظ†ط©

  static String getAccountTypeLower() => getAccountTypeRaw().toLowerCase();

  static Future<void> cacheDelegateSections({
    required Iterable<String> permitted,
    Iterable<String> blocked = const <String>[],
  }) async {
    final Set<String> permittedSet = {
      for (final section in permitted)
        if (_normalizeDelegateSection(section) != null)
          _normalizeDelegateSection(section)!,
    };

    final Set<String> blockedSet = {
      for (final section in blocked)
        if (_normalizeDelegateSection(section) != null)
          _normalizeDelegateSection(section)!,
    }..removeWhere(permittedSet.contains);

    final List<String> permittedList = permittedSet.toList(growable: false);
    final List<String> blockedList = blockedSet.toList(growable: false);

    await _userDetailsBox.put(
        HiveKeys.permittedDelegateSections, permittedList);
    await _userDetailsBox.put(HiveKeys.blockedDelegateSections, blockedList);

    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({
        HiveKeys.permittedDelegateSections: permittedList,
        HiveKeys.blockedDelegateSections: blockedList,
      });
    }
  }

  static Future<void> clearDelegateSectionsCache() async {
    await _userDetailsBox.delete(HiveKeys.permittedDelegateSections);
    await _userDetailsBox.delete(HiveKeys.blockedDelegateSections);
    _cachedUserDetailsMap?.remove(HiveKeys.permittedDelegateSections);
    _cachedUserDetailsMap?.remove(HiveKeys.blockedDelegateSections);
  }

  static Set<String> getPermittedDelegateSections() {
    final dynamic cached =
        _cachedUserDetailsMap?[HiveKeys.permittedDelegateSections];
    if (cached != null) {
      return _normalizeDelegateSectionList(cached);
    }
    return _normalizeDelegateSectionList(
      _userDetailsBox.get(HiveKeys.permittedDelegateSections),
    );
  }

  static Set<String> getBlockedDelegateSections() {
    final dynamic cached =
        _cachedUserDetailsMap?[HiveKeys.blockedDelegateSections];
    if (cached != null) {
      return _normalizeDelegateSectionList(cached);
    }
    return _normalizeDelegateSectionList(
      _userDetailsBox.get(HiveKeys.blockedDelegateSections),
    );
  }

  static bool hasDelegateAccess(String section) {
    final String? normalized = _normalizeDelegateSection(section);
    if (normalized == null) {
      return false;
    }
    final Set<String> permitted = getPermittedDelegateSections();

    final Set<String> blocked = getBlockedDelegateSections();
    final bool hasDelegateAssignments = permitted.isNotEmpty;

    if (hasDelegateAssignments && blocked.contains(normalized)) {
      return false;
    }

    if (permitted.contains(normalized)) {
      return true;
    }

    // ظپظٹ ط­ط§ظ„ط© ط¹ط¯ظ… ظˆط¬ظˆط¯ ط£ظ‚ط³ط§ظ… ظ…ط³ظ…ظˆط­ ط¨ظ‡ط§ طµط±ط§ط­ط©ظ‹ ظ†ط¹طھط¨ط± ط§ظ„ظˆطµظˆظ„ ظ…طھط§ط­ظ‹ط§ ظ…ط§ ظ„ظ… ظٹطھظ… ط­ط¸ط±ظ‡
    if (!hasDelegateAssignments) {
      return true;
    }

    return false;
  }

  static bool isDelegateSectionBlocked(String section) {
    final String? normalized = _normalizeDelegateSection(section);
    if (normalized == null) {
      return false;
    }
    return getBlockedDelegateSections().contains(normalized);
  }

  static int? getDelegateRootCategoryId({int? userId, String? section}) {
    final int? resolvedUserId = userId ?? _tryReadCurrentUserId();
    if (resolvedUserId == null) {
      _persistDelegateHistory(null);
      return null;
    }
    final Set<String> permittedSections = getPermittedDelegateSections();
    if (permittedSections.isEmpty) {
      _persistDelegateHistory(null);
      return null;
    }

    int? rootId;
    if (section != null) {
      final String? normalized = _normalizeDelegateSection(section);
      if (normalized != null && permittedSections.contains(normalized)) {
        rootId = _delegateSectionRootIds[normalized];
      }
    } else {
      for (final MapEntry<String, int> entry
          in _delegateSectionRootIds.entries) {
        if (permittedSections.contains(entry.key)) {
          rootId = entry.value;
          break;
        }
      }
    }

    _persistDelegateHistory(rootId);
    return rootId;
  }

  static bool wasDelegateBefore() {
    if (getPermittedDelegateSections().isNotEmpty) {
      return true;
    }

    return _userDetailsBox.get(HiveKeys.delegateHistoryFlag) == true;
  }

  static bool isDelegateUser({int? userId}) =>
      getDelegateRootCategoryId(userId: userId) != null;

  static void _persistDelegateHistory(int? rootCategoryId) {
    if (rootCategoryId != null) {
      _userDetailsBox.put(HiveKeys.lastDelegateCategoryId, rootCategoryId);
      if (_userDetailsBox.get(HiveKeys.delegateHistoryFlag) != true) {
        _userDetailsBox.put(HiveKeys.delegateHistoryFlag, true);
      }
      return;
    }

    _userDetailsBox.delete(HiveKeys.lastDelegateCategoryId);
  }

  static Future<void> _resetDelegateHistory() async {
    await _userDetailsBox.delete(HiveKeys.delegateHistoryFlag);
    await _userDetailsBox.delete(HiveKeys.lastDelegateCategoryId);
    _cachedUserDetailsMap?.remove(HiveKeys.delegateHistoryFlag);
    _cachedUserDetailsMap?.remove(HiveKeys.lastDelegateCategoryId);

    await clearDelegateSectionsCache();
  }

  static String? _normalizeDelegateSection(dynamic value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static Set<String> _normalizeDelegateSectionList(dynamic raw) {
    final Set<String> resolved = <String>{};

    void consume(dynamic candidate) {
      final String? normalized = _normalizeDelegateSection(candidate);
      if (normalized != null) {
        resolved.add(normalized);
      }
    }

    if (raw == null) {
      return resolved;
    }

    if (raw is Iterable) {
      for (final element in raw) {
        consume(element);
      }
      return resolved;
    }

    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return resolved;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        decoded = null;
      }

      if (decoded is Iterable) {
        return _normalizeDelegateSectionList(decoded);
      }

      for (final String segment in trimmed.split(RegExp(r'[\s,]+'))) {
        consume(segment);
      }
      return resolved;
    }

    if (raw is Map) {
      for (final dynamic value in raw.values) {
        consume(value);
      }
      return resolved;
    }

    consume(raw);
    return resolved;
  }

  static int? _tryReadCurrentUserId() {
    try {
      return getUserDetails().id;
    } catch (_) {
      final dynamic storedId = _userDetailsBox.get('id');
      if (storedId == null) {
        return null;
      }
      return int.tryParse(storedId.toString());
    }
  }

  // ---------------------------------------------------------------------------
  //                             ظ…طµط§ط¯ظ‚ط©/ظ‡ظˆظٹط©
  // ---------------------------------------------------------------------------

  /// ط¥ط±ط¬ط§ط¹ ط§ظ„ظ€JWT (ظ„ظˆ ط؛ظٹط± ظ…ظˆط¬ظˆط¯ ظٹط±ط¬ظ‘ط¹ ط³ظ„ط³ظ„ط© ظپط§ط±ط؛ط© ظ„طھط¬ظ†ظ‘ط¨ null)
  static String getJWT() {
    return (_userDetailsBox.get(HiveKeys.jwtToken) ?? '').toString();
  }

  /// طھط¹ظٹظٹظ† JWT
  static void setJWT(String token) async {
    await _userDetailsBox.put(HiveKeys.jwtToken, token);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({HiveKeys.jwtToken: token});
    }
  }

  // ظ‡ظ„ ط§ظ„ظ…ط³طھط®ط¯ظ… ظ…ظˆط«ظ‘ظ‚ (Authenticated) ظˆط¨ط§ظ„ط¥ط¶ط§ظپط© ظ„ط°ظ„ظƒ "ظ…ظڈطھط­ظ‚ظ‘ظژظ‚" (ظ…ط«ظ„ط§ظ‹ OTP/طھظˆط«ظٹظ‚ ط§ظ„ط­ط³ط§ط¨)

  static bool isUserAuthenticated() {
    final bool isAuth =
        Hive.box(HiveKeys.authBox).get(HiveKeys.isAuthenticated) ?? false;
    if (!isAuth) {
      return false;
    }
    try {
      final UserModel user = getUserDetails();
      return user.id != null;
    } catch (_) {
      return false;
    }
  }

  /// طھط­ظ‚ظ‘ظ‚ ط¥ط¶ط§ظپظٹ (ظ…ط«ظ„ط§ظ‹ ط­ظ‚ظ„ isVerified ط¯ط§ط®ظ„ UserModel)
  static bool isUserVerified() {
    try {
      final user = getUserDetails();
      return user.isVerified == 1;
    } catch (_) {
      return false;
    }
  }

  /// طھط­ظ‚ظ‘ظ‚ ط£ط³ط§ط³ظٹ ظپظ‚ط· (ط¨ط¯ظˆظ† ط´ط±ط· isVerified)
  static bool isUserBasicallyAuthenticated() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isAuthenticated) ?? false;
  }

  /// ظˆط¶ط¹ ط§ظ„ظ…ط³طھط®ط¯ظ… ظƒظ€ظ…ظڈظˆط«ظ‘ظ‚
  static void setUserIsAuthenticated(bool value) {
    Hive.box(HiveKeys.authBox).put(HiveKeys.isAuthenticated, value);
  }

  /// ط£ظˆظ„ ط§ط³طھط®ط¯ط§ظ… ظ„ظ„طھط·ط¨ظٹظ‚طں
  static bool isUserFirstTime() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isUserFirstTime) ?? true;
  }

  /// طھط®ط·ظ‘ظ‰ ط§ظ„ظ…ظ‚ط¯ظ‘ظ…ط©/ط§ظ„طھط³ط¬ظٹظ„طں
  static bool isUserSkip() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isUserSkip) ?? false;
  }

  static bool hasCorePermissionsSnapshot() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.corePermissionsGranted) ??
        false;
  }

  static Future<void> setCorePermissionsSnapshot(bool value) async {
    await Hive.box(HiveKeys.authBox)
        .put(HiveKeys.corePermissionsGranted, value);
  }

  /// طھظ…ظٹظٹط² ط£ظ† ط§ظ„ظ…ط³طھط®ط¯ظ… ظ„ظ… ظٹط¹ط¯ ط¬ط¯ظٹط¯ظ‹ط§ (ظٹظڈظ†طµط­ ط§ط³طھط¯ط¹ط§ط¤ظ‡ط§ ط¨ط¹ط¯ ط£ظˆظ„ طھط´ط؛ظٹظ„)
  static Future<void> setUserIsNotNew() {
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserFirstTime, false);
  }

  /// (ظ„ظ„ط§ط®طھط¨ط§ط±ط§طھ ظپظ‚ط·) طھظپط¹ظٹظ„ ط­ط§ظ„ط© "ظ…ط³طھط®ط¯ظ… ط¬ط¯ظٹط¯"
  @visibleForTesting
  static Future<void> setUserIsNew() {
    Hive.box(HiveKeys.authBox).put(HiveKeys.isAuthenticated, false);
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserFirstTime, true);
  }

  /// ط¬ظ„ط¨ ظ…ط¹ط±ظپ ط§ظ„ظ…ط³طھط®ط¯ظ… (ظ‚ط¯ طھظƒظˆظ† null ط¥ط°ط§ ظ„ظ… طھظڈط­ظپط¸)
  static String? getUserId() {
    final v = _userDetailsBox.get("id");
    return v == null ? null : v.toString();
  }

  /// ط­ظپط¸ ط¨ظٹط§ظ†ط§طھ ظ…ط³طھط®ط¯ظ… (ط¯ظپط¹ط© ظˆط§ط­ط¯ط©)
  static void setUserData(Map data) async {
    final String? previousId = _userDetailsBox.get('id')?.toString();
    final String? incomingId = data['id']?.toString();
    await _userDetailsBox.putAll(data);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates(data);
    }
    if (incomingId != null) {
      final bool isFirstTime = previousId == null;
      final bool isDifferentUser =
          previousId != null && previousId != incomingId;
      if (isFirstTime || isDifferentUser) {
        Api.handleAccountChange();
        await _resetDelegateHistory();
      }
    }
    await ChatBadgeController.handleUserChanged(incomingId);
    if (incomingId != null && incomingId != previousId) {
      NotificationService.clearParticipantsCache();
      _runUserChangeHooks();
    }
  }

  /// ط¥ط¹ط§ط¯ط© طھظ…ظ‡ظٹط¯/طھطµظپظٹط± ظƒظ„ ط§ظ„طµظ†ط§ط¯ظٹظ‚ ط§ظ„ط£ط³ط§ط³ظٹط© (طھط³ط¬ظٹظ„ ط®ط±ظˆط¬ ظ‚ظˆظٹ)
  static void clear() async {
    Api.handleAccountChange();
    await _userDetailsBox.clear();
    _invalidateUserDetailsCache();

    await Hive.box(HiveKeys.historyBox).clear();
    HiveUtils.setUserIsAuthenticated(false);
    await ChatBadgeController.handleUserChanged(null);
    NotificationService.disposeListeners();
    NotificationService.clearParticipantsCache();
    _runLogoutHooks();
  }

  /// طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬ + طھظ†ط¸ظٹظپ + ط¥ط¹ط§ط¯ط© ط§ظ„طھظˆط¬ظٹظ‡ (ط¥ظ† ظ„ط²ظ…)
  static logoutUser(
    context, {
    required VoidCallback onLogout,
    bool? isRedirect,
  }) async {
    Api.handleAccountChange();
    // 1) طھط³ط¬ظٹظ„ ط®ط±ظˆط¬ ظ…ظ† Firebase
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // 2) طھط³ط¬ظٹظ„ ط®ط±ظˆط¬ ظ…ظ† Google
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}

    // 3) طھظ†ط¸ظٹظپ ظ…ط®ط§ط²ظ† ط§ظ„ظ…ط´ط±ظˆط¹
    await _userDetailsBox.clear();
    _invalidateUserDetailsCache();

    HiveUtils.setUserIsAuthenticated(false);

    // 4) ظ†ط¯ط§ط، ط§ظ„ظ€callback (ظ„ظˆ ظپظٹظ‡ ط¥ط¬ط±ط§ط،ط§طھ ط¥ط¶ط§ظپظٹط©)
    onLogout.call();
    NotificationService.disposeListeners();
    NotificationService.clearParticipantsCache();
    _runLogoutHooks();

    // 5) ط¥ط¹ط§ط¯ط© ط§ظ„طھظˆط¬ظٹظ‡ (ط§ظپطھط±ط§ط¶ظٹظ‹ط§: ط¥ظ„ظ‰ طµظپط­ط© ط§ظ„ط¯ط®ظˆظ„)
    Future.delayed(
      Duration.zero,
      () {
        if (isRedirect ?? true) {
          HelperUtils.killPreviousPages(context, Routes.login, {});
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  //                                 ط§ظ„ظ„ط؛ط©/ط§ظ„ط«ظٹظ…
  // ---------------------------------------------------------------------------

  // ط§ظ„ط«ظٹظ… ط§ظ„ط­ط§ظ„ظٹ (light/dark) â€” ط§ظپطھط±ط§ط¶ظٹ Light
  static AppTheme getCurrentTheme() {
    final current = Hive.box(HiveKeys.themeBox).get(HiveKeys.currentTheme);
    if (current == null) return AppTheme.light;
    if (current == "light") return AppTheme.light;
    if (current == "dark") return AppTheme.dark;
    return AppTheme.light;
  }

  // طھط¹ظٹظٹظ† ط§ظ„ط«ظٹظ…
  static setCurrentTheme(AppTheme theme) {
    final newTheme = theme == AppTheme.light ? "light" : "dark";
    Hive.box(HiveKeys.themeBox).put(HiveKeys.currentTheme, newTheme);
  }

  // طھط®ط²ظٹظ† ط§ظ„ظ„ط؛ط© ط§ظ„ظ…ط®طھط§ط±ط©
  static Future<bool> storeLanguage(dynamic data) async {
    Hive.box(HiveKeys.languageBox).put(HiveKeys.currentLanguageKey, data);
    return true;
  }

  // ط¬ظ„ط¨ ط§ظ„ظ„ط؛ط© ط§ظ„ظ…ط®طھط§ط±ط©
  static dynamic getLanguage() {
    return Hive.box(HiveKeys.languageBox).get(HiveKeys.currentLanguageKey);
  }

  // ---------------------------------------------------------------------------
  //                            ط§ظ„ظ…ظˆظ‚ط¹/ط§ظ„ظ…ظ†ط§ط·ظ‚/ظ†طµظپ ط§ظ„ظ‚ط·ط±
  // ---------------------------------------------------------------------------

  static bool isLocationFilled() {
    final city = _userDetailsBox.get(HiveKeys.city);
    final state = _userDetailsBox.get(HiveKeys.stateKey);
    final country = _userDetailsBox.get(HiveKeys.countryKey);
    return !(city == null && state == null && country == null);
  }

  /// طھط¹ظٹظٹظ† ط§ظ„ظ…ظˆظ‚ط¹ (ظ„ظ…ظ„ظپ ط§ظ„ظ…ط³طھط®ط¯ظ…)
  /// ظپظٹ ظˆط¶ط¹ ط§ظ„ط¯ظٹظ…ظˆ طھظڈط­ظپط¸ ظ‚ظٹظ… ط«ط§ط¨طھط©طŒ ظˆط¥ظ„ط§ طھظڈط­ظپط¸ ط§ظ„ظ‚ظٹظ… ط§ظ„ظ…ظ…ط±ظ‘ط±ط© (ظ‚ط¯ طھظƒظˆظ† null)
  static void setLocation({
    String? city,
    String? state,
    String? country,
    String? area,
    int? areaId,
    double? latitude,
    double? longitude,
  }) async {
    if (Constant.isDemoModeOn) {
      final updates = {
        HiveKeys.city: "Bhuj",
        HiveKeys.stateKey: "Gujarat",
        HiveKeys.countryKey: "India",
        HiveKeys.areaId: null,
        HiveKeys.area: null,
        HiveKeys.latitudeKey: 23.2533,
        HiveKeys.longitudeKey: 69.6693
      };
      await _userDetailsBox.putAll(updates);
      if (_cachedUserDetailsMap != null) {
        _applyCacheUpdates(updates);
      }
    } else {
      final updates = {
        HiveKeys.city: city,
        HiveKeys.stateKey: state,
        HiveKeys.countryKey: country,
        HiveKeys.areaId: areaId,
        HiveKeys.area: area,
        HiveKeys.latitudeKey: latitude,
        HiveKeys.longitudeKey: longitude
      };
      await _userDetailsBox.putAll(updates);
      if (_cachedUserDetailsMap != null) {
        _applyCacheUpdates(updates);
      }
    }
  }

  /// طھط¹ظٹظٹظ† ط§ظ„ظ…ظˆظ‚ط¹ ط§ظ„ط­ط§ظ„ظٹ (Current Location) â€” ظٹظڈط³طھط®ط¯ظ… ط¹ط§ط¯ط©ظ‹ ظ„ط®ط¯ظ…ط© "ط¨ط§ظ„ظ‚ط±ط¨ ظ…ظ†ظٹ"
  static void setCurrentLocation({
    required String city,
    required String state,
    required String country,
    dynamic latitude,
    dynamic longitude,
    String? area,
  }) async {
    if (Constant.isDemoModeOn) {
      final updates = {
        HiveKeys.currentLocationCity: "Bhuj",
        HiveKeys.currentLocationState: "Gujarat",
        HiveKeys.currentLocationCountry: "India",
        HiveKeys.currentLocationArea: null,
        HiveKeys.currentLocationLatitude: 23.2533,
        HiveKeys.currentLocationLongitude: 69.6693
      };
      await _userDetailsBox.putAll(updates);
      if (_cachedUserDetailsMap != null) {
        _applyCacheUpdates(updates);
      }
    } else {
      final updates = {
        HiveKeys.currentLocationCity: city,
        HiveKeys.currentLocationState: state,
        HiveKeys.currentLocationCountry: country,
        HiveKeys.currentLocationLatitude: latitude,
        HiveKeys.currentLocationLongitude: longitude,
        HiveKeys.currentLocationArea: area
      };
      await _userDetailsBox.putAll(updates);
      if (_cachedUserDetailsMap != null) {
        _applyCacheUpdates(updates);
      }
    }
  }

  /// ظ…ط³ط­ ط­ظ‚ظˆظ„ ط§ظ„ظ…ظˆظ‚ط¹ (ط§ظ„ط£ط³ط§ط³ظٹط©)
  static void clearLocation() async {
    final updates = {
      HiveKeys.city: null,
      HiveKeys.stateKey: null,
      HiveKeys.countryKey: null,
    };
    await _userDetailsBox.putAll(updates);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates(updates);
    }
  }

  // طھط¹ظٹظٹظ† ظ†طµظپ ظ‚ط·ط± ط§ظ„ط¨ط­ط« ط§ظ„ظ‚ط±ظٹط¨
  static void setNearbyRadius(int radius) async {
    await _userDetailsBox.put(HiveKeys.nearbyRadius, radius);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({HiveKeys.nearbyRadius: radius});
    }
  }

  // ط¬ظ„ط¨ ظ†طµظپ ظ‚ط·ط± ط§ظ„ط¨ط­ط« ط§ظ„ظ‚ط±ظٹط¨
  static dynamic getNearbyRadius() {
    return _userDetailsBox.get(HiveKeys.nearbyRadius);
  }

  // ظ‚ط±ط§ط،ط§طھ ط´ط§ط¦ط¹ط© (Getters) â€” طھظڈط¨ظ‚ظٹ ط§ظ„ط§ط³طھط¯ط¹ط§ط،ط§طھ ظ…ظˆط­ظ‘ط¯ط©
  static dynamic getCityName() => _userDetailsBox.get(HiveKeys.city);

  static dynamic getAreaName() => _userDetailsBox.get(HiveKeys.area);

  static dynamic getAreaId() => _userDetailsBox.get(HiveKeys.areaId);

  static dynamic getStateName() => _userDetailsBox.get(HiveKeys.stateKey);

  static dynamic getCountryName() => _userDetailsBox.get(HiveKeys.countryKey);

  static dynamic getCurrentCityName() =>
      _userDetailsBox.get(HiveKeys.currentLocationCity);

  static dynamic getCurrentAreaName() =>
      _userDetailsBox.get(HiveKeys.currentLocationArea);

  static dynamic getCurrentStateName() =>
      _userDetailsBox.get(HiveKeys.currentLocationState);

  static dynamic getCurrentCountryName() =>
      _userDetailsBox.get(HiveKeys.currentLocationCountry);

  static dynamic getCurrentLatitude() =>
      _userDetailsBox.get(HiveKeys.currentLocationLatitude);

  static dynamic getCurrentLongitude() =>
      _userDetailsBox.get(HiveKeys.currentLocationLongitude);

  static dynamic getLatitude() => _userDetailsBox.get(HiveKeys.latitudeKey);

  static dynamic getLongitude() => _userDetailsBox.get(HiveKeys.longitudeKey);

  // ---------------------------------------------------------------------------
  //                         ط³ظ„ظˆظƒ ظˆط§ط¬ظ‡ط©: ظ†ظˆط§ظپط°/ط¥ط´ط¹ط§ط±ط§طھ طµط؛ظٹط±ط©
  // ---------------------------------------------------------------------------

  // ظ„ط§ طھظڈط¸ظ‡ط± ظ†ط§ظپط°ط© "ط§ط®طھظٹط§ط± ط§ظ„ظ…ظˆظ‚ط¹" ظ…ط±ط© ط£ط®ط±ظ‰
  static void dontShowChooseLocationDialoge() {
    _userDetailsBox.put("showChooseLocationDialoge", false);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({"showChooseLocationDialoge": false});
    }
  }

  // ظ‡ظ„ ظٹظ†ط¨ط؛ظٹ ط¥ط¸ظ‡ط§ط± ظ†ط§ظپط°ط© ط§ط®طھظٹط§ط± ط§ظ„ظ…ظˆظ‚ط¹طں
  // طھظڈط¹ظٹط¯ true ط¥ط°ط§ ظ„ظ… طھظڈط¶ط¨ط· ظ…ظ† ظ‚ط¨ظ„ (ط§ظ„ظ‚ظٹظ…ط© ط؛ظٹط± ظ…ظˆط¬ظˆط¯ط©)
  static bool isShowChooseLocationDialoge() {
    final value = _userDetailsBox.get("showChooseLocationDialoge");
    return value == null;
  }

  // ---------------------------------------------------------------------------
  //                         طھظپط§طµظٹظ„ ط§ظ„ظ…ط³طھط®ط¯ظ…/ط§ظ„ط¯ظˆظ„ط©/ط§ظ„ط«ظٹظ…
  // ---------------------------------------------------------------------------

  static String? getCountryCode() {
    return _userDetailsBox.get("country_code");
  }

  /// ظˆط¶ط¹ ط¹ظ„ط§ظ…ط© ط£ظ† "ط§ظ„ظ…ظ„ظپ ظ„ظ… ظٹظƒطھظ…ظ„" â€” ظ‚ط¯ طھظڈط³طھط®ط¯ظ… ظ„ظپط±ط¶ ط¥ظƒظ…ط§ظ„ ط§ظ„ظ…ظ„ظپ
  static void setProfileNotCompleted() async {
    await _userDetailsBox.put(HiveKeys.isProfileCompleted, false);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({HiveKeys.isProfileCompleted: false});
    }
  }

  /// ط¬ظ„ط¨ ظ†ظ…ظˆط°ط¬ ط§ظ„ظ…ط³طھط®ط¯ظ… ظƒط§ظ…ظ„ظ‹ط§ ظ…ظ† ط§ظ„طµظ†ط¯ظˆظ‚ (UserModel)
  static UserModel getUserDetails() {
    if (_cachedUserDetails != null) {
      return _cachedUserDetails!;
    }
    _hydrateUserDetailsCache();
    return _cachedUserDetails ?? UserModel.fromJson(<String, dynamic>{});
  }

  static VerificationRequestModel? getCachedVerificationRequest() {
    final dynamic raw = _userDetailsBox.get(HiveKeys.lastVerificationRequest);
    if (raw is Map<String, dynamic>) {
      return VerificationRequestModel.fromJson(raw);
    }
    if (raw is Map) {
      return VerificationRequestModel.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)));
    }
    return null;
  }

  static Future<void> cacheVerificationRequest(
      VerificationRequestModel model) async {
    await _userDetailsBox.put(HiveKeys.lastVerificationRequest, model.toJson());
  }

  static Future<void> clearCachedVerificationRequest() async {
    await _userDetailsBox.delete(HiveKeys.lastVerificationRequest);
  }

  /// طھط¹ظٹظٹظ† ط£ظ†ظ‘ ط§ظ„ظ…ط³طھط®ط¯ظ… "طھط¬ط§ظˆط²" ط´ط§ط´ط© ظ…ط§ (ظ…ط«ظ„ Onboarding)
  static Future<void> setUserSkip() {
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserSkip, true);
  }
  // ---------------------------------------------------------------------------
  //                        Merchant Onboarding Helpers
  // ---------------------------------------------------------------------------

  static bool isMerchantOnboardingInProgress() {
    return _userDetailsBox.get(HiveKeys.merchantOnboardingInProgress) == true;
  }

  static Future<void> beginMerchantOnboardingSession({
    int initialStep = 0,
    Map<String, dynamic>? draft,
  }) async {
    await _userDetailsBox.put(HiveKeys.merchantOnboardingInProgress, true);
    await setMerchantOnboardingStep(initialStep);
    if (draft != null && draft.isNotEmpty) {
      await saveMerchantOnboardingDraft(draft);
    }
  }

  static Future<void> setMerchantOnboardingStep(int step) {
    final int safeStep = step.clamp(0, 5);
    return _userDetailsBox.put(HiveKeys.merchantOnboardingStep, safeStep);
  }

  static int getMerchantOnboardingStep() {
    final dynamic raw = _userDetailsBox.get(HiveKeys.merchantOnboardingStep);
    if (raw is int) return raw.clamp(0, 5);
    if (raw is num) return raw.toInt().clamp(0, 5);
    return 0;
  }

  static Map<String, dynamic>? getMerchantOnboardingDraft() {
    final dynamic raw = _userDetailsBox.get(HiveKeys.merchantOnboardingDraft);
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map(
        (dynamic key, dynamic value) => MapEntry(
          key.toString(),
          value,
        ),
      );
    }
    return null;
  }

  static Future<void> saveMerchantOnboardingDraft(
      Map<String, dynamic> draft) async {
    final Map<String, dynamic> sanitized = Map<String, dynamic>.from(draft)
      ..removeWhere(
        (key, value) =>
            value == null ||
            (value is String && value.trim().isEmpty) ||
            key == 'password',
      );
    await _userDetailsBox.put(HiveKeys.merchantOnboardingDraft, sanitized);
  }

  static Future<void> clearMerchantOnboardingProgress() async {
    await _userDetailsBox.delete(HiveKeys.merchantOnboardingInProgress);
    await _userDetailsBox.delete(HiveKeys.merchantOnboardingStep);
    await _userDetailsBox.delete(HiveKeys.merchantOnboardingDraft);
  }

  static Map<String, dynamic>? getMerchantStoreRaw() {
    final dynamic raw = _userDetailsBox.get('store');
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map(
        (dynamic key, dynamic value) => MapEntry(
          key.toString(),
          value,
        ),
      );
    }
    return null;
  }

  static Future<void> setMerchantStoreRaw(
      Map<String, dynamic>? store) async {
    if (store == null) {
      await _userDetailsBox.delete('store');
      _removeFromCache(<dynamic>['store']);
      return;
    }
    final Map<String, dynamic> sanitized = Map<String, dynamic>.from(store);
    await _userDetailsBox.put('store', sanitized);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates(<dynamic, dynamic>{'store': sanitized});
    }
  }

  static String? getMerchantStoreStatus() {
    final Map<String, dynamic>? store = getMerchantStoreRaw();
    final dynamic rawStatus = store?['status'];
    if (rawStatus == null) {
      return null;
    }
    final String status = rawStatus.toString().trim();
    return status.isEmpty ? null : status;
  }
  static String getAccountTypeCode() {
    // ظٹطھظˆظ‚ط¹: "1" (ظپط±ط¯ظٹ) | "2" (ط¹ظ‚ط§ط±ظٹ) | "3" (طھط¬ط§ط±ظٹ)
    final v = _userDetailsBox.get('accountType');

    return (v ?? '').toString().trim();
  }
}

