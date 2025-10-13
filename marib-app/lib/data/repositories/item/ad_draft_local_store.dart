import 'dart:convert';

import 'package:marib/data/model/ad_draft_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdDraftLocalStore {
  Future<void> savePending(String key, Map<String, dynamic> payload) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(payload);
    await prefs.setString(_pendingKey(key), jsonEncode(normalized));
    await saveSnapshot(key, AdDraftModel.fromPending(normalized));
  }

  Future<Map<String, dynamic>?> readPending(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_pendingKey(key));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded as Map);
      }
    } catch (_) {
      await prefs.remove(_pendingKey(key));
    }
    return null;
  }

  Future<void> clearPending(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey(key));
  }

  Future<void> saveSnapshot(String key, AdDraftModel draft) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey(key), jsonEncode(draft.toJson()));
  }

  Future<AdDraftModel?> readSnapshot(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_snapshotKey(key));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AdDraftModel.fromJson(decoded);
      }
      if (decoded is Map) {
        return AdDraftModel.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
    } catch (_) {
      await prefs.remove(_snapshotKey(key));
    }
    return null;
  }

  Future<void> migrate({required String from, required String to}) async {
    if (from == to) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? pending = prefs.getString(_pendingKey(from));
    final String? snapshot = prefs.getString(_snapshotKey(from));
    if (pending != null) {
      await prefs.setString(_pendingKey(to), pending);
    }
    if (snapshot != null) {
      await prefs.setString(_snapshotKey(to), snapshot);
    }
    await prefs.remove(_pendingKey(from));
    await prefs.remove(_snapshotKey(from));
  }

  String _pendingKey(String key) => 'ad_draft_pending_$key';

  String _snapshotKey(String key) => 'ad_draft_snapshot_$key';
}