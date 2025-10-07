class FilterMemory {
  static final Map<String, dynamic> _store = {};

  static T? get<T>(String key) {
    return _store[key] as T?;
  }

  static void set<T>(String key, T? value) {
    _store[key] = value;
  }

  static void clear(String key) {
    _store.remove(key);
  }
}
