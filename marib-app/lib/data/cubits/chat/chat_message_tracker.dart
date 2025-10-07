import 'dart:collection';

class ChatMessageTracker {
  ChatMessageTracker._({this.maxEntries = _defaultMaxEntries});

  static const int _defaultMaxEntries = 200;

  static final ChatMessageTracker instance = ChatMessageTracker._();

  final int maxEntries;
  final LinkedHashSet<Object?> _recentKeys = LinkedHashSet<Object?>();

  bool contains(Object? key) {
    if (key == null) {
      return false;
    }
    return _recentKeys.contains(key);
  }

  void track(Object? key) {
    if (key == null) {
      return;
    }

    if (_recentKeys.contains(key)) {
      _recentKeys.remove(key);
      _recentKeys.add(key);
      return;
    }

    _recentKeys.add(key);
    if (_recentKeys.length > maxEntries) {
      final iterator = _recentKeys.iterator;
      if (iterator.moveNext()) {
        _recentKeys.remove(iterator.current);
      }
    }
  }

  void remove(Object? key) {
    if (key == null) {
      return;
    }
    _recentKeys.remove(key);
  }

  int get length => _recentKeys.length;
}