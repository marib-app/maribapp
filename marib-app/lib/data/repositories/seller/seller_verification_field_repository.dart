import 'dart:convert';

import 'package:marib/data/model/custom_field/custom_field_model.dart';
import 'package:marib/data/model/verification_metadata.dart';
import 'package:marib/data/model/verification_request_model.dart';
import 'package:marib/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SellerVerificationFieldRepository {
  static const String _cacheKey = 'verification_metadata_cache_v1';
  static const String _cacheTimestampKey = '${_cacheKey}_ts';
  static const Duration _cacheTtl = Duration(minutes: 5);

  Future<VerificationMetadata> getVerificationMetadata({
    String? accountType,
    bool forceRefresh = false,
  }) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      if (!forceRefresh) {
        final cached = _readCache(prefs);
        if (cached != null) {
          return cached;
        }
      }

      final Map<String, dynamic> response = await Api.get(
        url: Api.getVerificationMetadataApi,
        queryParameters:
            accountType != null ? <String, dynamic>{'account_type': accountType} : null,
      );

      final VerificationMetadata metadata =
          VerificationMetadata.fromMap(response['data'] as Map<String, dynamic>?);

      await _writeCache(metadata, prefs);

      return metadata;
    } catch (e) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final VerificationMetadata? cached = _readCache(prefs, ignoreTtl: true);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<VerificationFieldModel>> getSellerVerificationFields({
    String? accountType,
    bool forceRefresh = false,
  }) async {
    final VerificationMetadata metadata = await getVerificationMetadata(
      accountType: accountType,
      forceRefresh: forceRefresh,
    );

    return metadata.fieldsFor(accountType);
  }

  Future<Map> sendVerificationField(
      {required Map<String, dynamic> data}) async {
    try {
      Map response =
          await Api.post(url: Api.sendVerificationRequestApi, parameter: data);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<VerificationRequestModel> getVerificationRequest() async {
    try {
      Map<String, dynamic> parameters = {};

      Map<String, dynamic> response = await Api.get(
          url: Api.getVerificationRequestApi, queryParameters: parameters);

      VerificationRequestModel model =
          VerificationRequestModel.fromJson(response['data']);

      return model;
    } catch (e) {
      throw "$e";
    }
  }

  VerificationMetadata? _readCache(SharedPreferences prefs,
      {bool ignoreTtl = false}) {
    final String? raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;

    final String? timestampRaw = prefs.getString(_cacheTimestampKey);
    final DateTime? cachedAt =
        timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;

    if (!ignoreTtl && !_isFresh(cachedAt)) {
      return null;
    }

    try {
      final Map<String, dynamic> decoded =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return VerificationMetadata.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
      VerificationMetadata metadata, SharedPreferences prefs) async {
    await prefs.setString(_cacheKey, jsonEncode(metadata.toJson()));
    await prefs.setString(
        _cacheTimestampKey, DateTime.now().toIso8601String());
  }

  bool _isFresh(DateTime? cachedAt) {
    if (cachedAt == null) return false;
    return DateTime.now().difference(cachedAt) <= _cacheTtl;
  }
}
