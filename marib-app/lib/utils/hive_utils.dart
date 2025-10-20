import 'package:marib/app/app_theme.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/utils/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:marib/data/model/user_model.dart';

import 'helper_utils.dart';
import 'package:marib/utils/hive_keys.dart';
import 'dart:math';
import 'dart:async';
import 'package:marib/ui/screens/chat/chat_badge_controller.dart';
import 'dart:convert';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/notification/notification_service.dart';

// أداة مساعدة للتعامل مع التخزين المحلي عبر Hive
// - تُجمّع كل عمليات القراءة/الكتابة على صناديق Hive
// - تُقدّم دوال عالية المستوى لاستخدام موحّد داخل المشروع

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
  //                         مفاتيح/مساعدات عامة
  // ---------------------------------------------------------------------------

  /// قراءة قيمة مفردة (Generic) من صندوق تفاصيل المستخدم
  // مثال: `HiveUtils.getUserDetail<String>(key: 'accountType')`

  static T? getUserDetail<T>({required String key}) {
    return _userDetailsBox.get(key) as T?;
  }

  // كتابة قيمة مفردة في صندوق تفاصيل المستخدم

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

  /// قسم السلة الحالي (لمنع دمج أقسام مختلفة بين الجلسات)
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

  // إرجاع نوع الحساب كما هو مخزّن (من UserModel أو مباشرة من الـBox)
  // قد يعيد: 'real_estate' | 'individual' | 'business' (أو سلسلة فارغة إن لم يُحدّد)

  static String getAccountTypeRaw() {
    return (_userDetailsBox.get('accountType') ?? '').toString();
  }

  // نوع الحساب بصيغة lower-case لتسهيل المقارنة

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

    // في حالة عدم وجود أقسام مسموح بها صراحةً نعتبر الوصول متاحًا ما لم يتم حظره
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
  //                             مصادقة/هوية
  // ---------------------------------------------------------------------------

  /// إرجاع الـJWT (لو غير موجود يرجّع سلسلة فارغة لتجنّب null)
  static String getJWT() {
    return (_userDetailsBox.get(HiveKeys.jwtToken) ?? '').toString();
  }

  /// تعيين JWT
  static void setJWT(String token) async {
    await _userDetailsBox.put(HiveKeys.jwtToken, token);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({HiveKeys.jwtToken: token});
    }
  }

  // هل المستخدم موثّق (Authenticated) وبالإضافة لذلك "مُتحقَّق" (مثلاً OTP/توثيق الحساب)

  static bool isUserAuthenticated() {
    final isAuth =
        Hive.box(HiveKeys.authBox).get(HiveKeys.isAuthenticated) ?? false;
    if (!isAuth) return false;
    if (!isUserVerified()) return false;
    return true;
  }

  /// تحقّق إضافي (مثلاً حقل isVerified داخل UserModel)
  static bool isUserVerified() {
    try {
      final user = getUserDetails();
      return user.isVerified == 1;
    } catch (_) {
      return false;
    }
  }

  /// تحقّق أساسي فقط (بدون شرط isVerified)
  static bool isUserBasicallyAuthenticated() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isAuthenticated) ?? false;
  }

  /// وضع المستخدم كـمُوثّق
  static void setUserIsAuthenticated(bool value) {
    Hive.box(HiveKeys.authBox).put(HiveKeys.isAuthenticated, value);
  }

  /// أول استخدام للتطبيق؟
  static bool isUserFirstTime() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isUserFirstTime) ?? true;
  }

  /// تخطّى المقدّمة/التسجيل؟
  static bool isUserSkip() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isUserSkip) ?? false;
  }

  /// تمييز أن المستخدم لم يعد جديدًا (يُنصح استدعاؤها بعد أول تشغيل)
  static Future<void> setUserIsNotNew() {
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserFirstTime, false);
  }

  /// (للاختبارات فقط) تفعيل حالة "مستخدم جديد"
  @visibleForTesting
  static Future<void> setUserIsNew() {
    Hive.box(HiveKeys.authBox).put(HiveKeys.isAuthenticated, false);
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserFirstTime, true);
  }

  /// جلب معرف المستخدم (قد تكون null إذا لم تُحفظ)
  static String? getUserId() {
    final v = _userDetailsBox.get("id");
    return v == null ? null : v.toString();
  }

  /// حفظ بيانات مستخدم (دفعة واحدة)
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
        await _resetDelegateHistory();
      }
    }
    await ChatBadgeController.handleUserChanged(incomingId);
    if (incomingId != null && incomingId != previousId) {
      NotificationService.clearParticipantsCache();
      _runUserChangeHooks();
    }
  }

  /// إعادة تمهيد/تصفير كل الصناديق الأساسية (تسجيل خروج قوي)
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

  /// تسجيل الخروج + تنظيف + إعادة التوجيه (إن لزم)
  static logoutUser(
    context, {
    required VoidCallback onLogout,
    bool? isRedirect,
  }) async {
    Api.handleAccountChange();
    // 1) تسجيل خروج من Firebase
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // 2) تسجيل خروج من Google
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}

    // 3) تنظيف مخازن المشروع
    await _userDetailsBox.clear();
    _invalidateUserDetailsCache();

    HiveUtils.setUserIsAuthenticated(false);

    // 4) نداء الـcallback (لو فيه إجراءات إضافية)
    onLogout.call();
    NotificationService.disposeListeners();
    NotificationService.clearParticipantsCache();
    _runLogoutHooks();

    // 5) إعادة التوجيه (افتراضيًا: إلى صفحة الدخول)
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
  //                                 اللغة/الثيم
  // ---------------------------------------------------------------------------

  // الثيم الحالي (light/dark) — افتراضي Light
  static AppTheme getCurrentTheme() {
    final current = Hive.box(HiveKeys.themeBox).get(HiveKeys.currentTheme);
    if (current == null) return AppTheme.light;
    if (current == "light") return AppTheme.light;
    if (current == "dark") return AppTheme.dark;
    return AppTheme.light;
  }

  // تعيين الثيم
  static setCurrentTheme(AppTheme theme) {
    final newTheme = theme == AppTheme.light ? "light" : "dark";
    Hive.box(HiveKeys.themeBox).put(HiveKeys.currentTheme, newTheme);
  }

  // تخزين اللغة المختارة
  static Future<bool> storeLanguage(dynamic data) async {
    Hive.box(HiveKeys.languageBox).put(HiveKeys.currentLanguageKey, data);
    return true;
  }

  // جلب اللغة المختارة
  static dynamic getLanguage() {
    return Hive.box(HiveKeys.languageBox).get(HiveKeys.currentLanguageKey);
  }

  // ---------------------------------------------------------------------------
  //                            الموقع/المناطق/نصف القطر
  // ---------------------------------------------------------------------------

  static bool isLocationFilled() {
    final city = _userDetailsBox.get(HiveKeys.city);
    final state = _userDetailsBox.get(HiveKeys.stateKey);
    final country = _userDetailsBox.get(HiveKeys.countryKey);
    return !(city == null && state == null && country == null);
  }

  /// تعيين الموقع (لملف المستخدم)
  /// في وضع الديمو تُحفظ قيم ثابتة، وإلا تُحفظ القيم الممرّرة (قد تكون null)
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

  /// تعيين الموقع الحالي (Current Location) — يُستخدم عادةً لخدمة "بالقرب مني"
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

  /// مسح حقول الموقع (الأساسية)
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

  // تعيين نصف قطر البحث القريب
  static void setNearbyRadius(int radius) async {
    await _userDetailsBox.put(HiveKeys.nearbyRadius, radius);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({HiveKeys.nearbyRadius: radius});
    }
  }

  // جلب نصف قطر البحث القريب
  static dynamic getNearbyRadius() {
    return _userDetailsBox.get(HiveKeys.nearbyRadius);
  }

  // قراءات شائعة (Getters) — تُبقي الاستدعاءات موحّدة
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
  //                         سلوك واجهة: نوافذ/إشعارات صغيرة
  // ---------------------------------------------------------------------------

  // لا تُظهر نافذة "اختيار الموقع" مرة أخرى
  static void dontShowChooseLocationDialoge() {
    _userDetailsBox.put("showChooseLocationDialoge", false);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({"showChooseLocationDialoge": false});
    }
  }

  // هل ينبغي إظهار نافذة اختيار الموقع؟
  // تُعيد true إذا لم تُضبط من قبل (القيمة غير موجودة)
  static bool isShowChooseLocationDialoge() {
    final value = _userDetailsBox.get("showChooseLocationDialoge");
    return value == null;
  }

  // ---------------------------------------------------------------------------
  //                         تفاصيل المستخدم/الدولة/الثيم
  // ---------------------------------------------------------------------------

  static String? getCountryCode() {
    return _userDetailsBox.get("country_code");
  }

  /// وضع علامة أن "الملف لم يكتمل" — قد تُستخدم لفرض إكمال الملف
  static void setProfileNotCompleted() async {
    await _userDetailsBox.put(HiveKeys.isProfileCompleted, false);
    if (_cachedUserDetailsMap != null) {
      _applyCacheUpdates({HiveKeys.isProfileCompleted: false});
    }
  }

  /// جلب نموذج المستخدم كاملًا من الصندوق (UserModel)
  static UserModel getUserDetails() {
    if (_cachedUserDetails != null) {
      return _cachedUserDetails!;
    }
    _hydrateUserDetailsCache();
    return _cachedUserDetails ?? UserModel.fromJson(<String, dynamic>{});
  }

  /// تعيين أنّ المستخدم "تجاوز" شاشة ما (مثل Onboarding)
  static Future<void> setUserSkip() {
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserSkip, true);
  }

  static String getAccountTypeCode() {
    // يتوقع: "1" (فردي) | "2" (عقاري) | "3" (تجاري)
    final v = _userDetailsBox.get('accountType');

    return (v ?? '').toString().trim();
  }
}
