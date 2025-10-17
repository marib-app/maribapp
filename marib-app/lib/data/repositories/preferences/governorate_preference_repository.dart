import 'package:shared_preferences/shared_preferences.dart';

class GovernoratePreferenceRepository {
  static const String _storageKey = 'preferred_governorate_code';

  Future<String?> loadPreferredGovernorate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey);
  }

  Future<void> savePreferredGovernorate(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, code);
  }

  Future<void> clearPreferredGovernorate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}