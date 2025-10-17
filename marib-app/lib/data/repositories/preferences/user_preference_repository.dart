import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marib/data/model/user_preferences.dart';
import 'package:marib/utils/api.dart';

class UserPreferenceRepository {
  static const String _storageKey = 'user_preferences_v1';
  static const String _pendingSyncKey = 'user_preferences_pending_sync';
  static const String _filterKey = 'user_preferences_watchlist_filter';

  Future<UserPreferences> loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const UserPreferences();
    }

    try {
      final Map<String, dynamic> map =
      Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>);
      return UserPreferences.fromJson(map);
    } catch (error) {
      debugPrint('Failed to parse cached preferences: $error');
      return const UserPreferences();
    }
  }

  Future<void> saveLocalPreferences(
      UserPreferences preferences, {
        required bool markPendingSync,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(preferences.toJson()));
    if (markPendingSync) {
      await prefs.setBool(_pendingSyncKey, true);
    } else {
      await prefs.remove(_pendingSyncKey);
    }
  }

  Future<void> clearPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSyncKey);
  }

  Future<bool> hasPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingSyncKey) ?? false;
  }

  Future<void> setPendingSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_pendingSyncKey, true);
    } else {
      await prefs.remove(_pendingSyncKey);
    }
  }

  Future<bool> loadWatchlistFilter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_filterKey) ?? false;
  }

  Future<void> saveWatchlistFilter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_filterKey, value);
  }

  Future<UserPreferences?> fetchRemotePreferences() async {
    try {
      final Map<String, dynamic> result = await Api.get(
        url: Api.userPreferencesApi,
      );

      final dynamic data = result['data'];
      if (result['error'] == false && data is Map<String, dynamic>) {
        final remote = UserPreferences.fromJson(data);
        await saveLocalPreferences(remote, markPendingSync: false);
        return remote;
      }
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return null;
      }
      debugPrint('Failed to fetch preferences: ${error.errorMessage}');
    } catch (error) {
      debugPrint('Failed to fetch preferences: $error');
    }
    return null;
  }

  Future<UserPreferences?> updateRemotePreferences(
      UserPreferences preferences,
      ) async {
    try {
      final Map<String, dynamic> result = await Api.requestJson(
        url: Api.userPreferencesApi,
        method: 'PUT',
        data: <String, dynamic>{
          'favorite_governorate_code': preferences.favoriteGovernorateCode,
          'currency_watchlist': preferences.currencyWatchlist.toList(),
          'metal_watchlist': preferences.metalWatchlist.toList(),
          'notification_frequency': preferences.notificationFrequency,
        },
      );

      final dynamic data = result['data'];
      if (result['error'] == false && data is Map<String, dynamic>) {
        final remote = UserPreferences.fromJson(data);
        await saveLocalPreferences(remote, markPendingSync: false);
        await clearPendingSync();
        return remote;
      }
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return null;
      }
      debugPrint('Failed to update preferences: ${error.errorMessage}');
    } catch (error) {
      debugPrint('Failed to update preferences: $error');
    }

    await setPendingSync(true);
    return null;
  }
}