import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';

/// Lightweight in-memory cache for the new chat stack. Can be swapped with
/// Hive/SQLite later while keeping the same interface.
class ChatCacheStore {
  /// How many recent messages to keep per conversation.
  ChatCacheStore({this.maxPerConversation = 200});

  final int maxPerConversation;
  final Map<String, List<ChatMessageEntity>> _messages = <String, List<ChatMessageEntity>>{};

  /// Get a snapshot (new list) of cached messages for a conversation,
  /// sorted by createdAt descending.
  List<ChatMessageEntity> getMessages(String conversationId) {
    final list = _messages[conversationId];
    if (list == null) return <ChatMessageEntity>[];
    return List<ChatMessageEntity>.unmodifiable(list);
  }

  /// Merge a page of messages (remote) into cache, removing duplicates.
  void mergePage(String conversationId, Iterable<ChatMessageEntity> page) {
    final List<ChatMessageEntity> existing = List<ChatMessageEntity>.from(
      _messages[conversationId] ?? <ChatMessageEntity>[],
    );

    for (final ChatMessageEntity incoming in page) {
      final int byId = existing.indexWhere((m) => m.id != null && m.id == incoming.id);
      final int byLocalId = incoming.localId != null
          ? existing.indexWhere((m) => m.localId == incoming.localId)
          : -1;

      if (byId != -1) {
        existing[byId] = _preferLatest(existing[byId], incoming);
      } else if (byLocalId != -1) {
        existing[byLocalId] = _preferLatest(existing[byLocalId], incoming);
      } else {
        existing.add(incoming);
      }
    }

    _messages[conversationId] = _sortedTrimmed(existing);
  }

  /// Insert a local/pending message immediately.
  void addLocal(String conversationId, ChatMessageEntity message) {
    final List<ChatMessageEntity> existing = List<ChatMessageEntity>.from(
      _messages[conversationId] ?? <ChatMessageEntity>[],
    );
    existing.add(message);
    _messages[conversationId] = _sortedTrimmed(existing);
  }

  /// Replace a pending message with its confirmed copy.
  void replaceLocalWithRemote(String conversationId, ChatMessageEntity remote) {
    final List<ChatMessageEntity> existing = List<ChatMessageEntity>.from(
      _messages[conversationId] ?? <ChatMessageEntity>[],
    );
    final int byLocalId = remote.localId != null
        ? existing.indexWhere((m) => m.localId == remote.localId)
        : -1;

    if (byLocalId != -1) {
      existing[byLocalId] = _preferLatest(existing[byLocalId], remote);
    } else {
      existing.add(remote);
    }
    _messages[conversationId] = _sortedTrimmed(existing);
  }

  ChatMessageEntity _preferLatest(
    ChatMessageEntity a,
    ChatMessageEntity b,
  ) {
    final DateTime? ta = a.updatedAt ?? a.createdAt;
    final DateTime? tb = b.updatedAt ?? b.createdAt;
    if (tb != null && ta != null && tb.isAfter(ta)) {
      return b;
    }
    // If remote has server id, prefer it.
    if (b.id != null && a.id == null) {
      return b;
    }
    return b.id == null && a.id != null ? a : b;
  }

  List<ChatMessageEntity> _sortedTrimmed(List<ChatMessageEntity> list) {
    list.sort((a, b) {
      final DateTime ta = a.createdAt;
      final DateTime tb = b.createdAt;
      final int cmp = tb.compareTo(ta);
      if (cmp != 0) return cmp;
      final int ida = a.id ?? -1;
      final int idb = b.id ?? -1;
      return idb.compareTo(ida);
    });

    if (list.length > maxPerConversation) {
      return list.sublist(0, maxPerConversation);
    }
    return list;
  }

  /// Quick helper to locate the newest message timestamp in cache.
  DateTime? latestTimestamp(String conversationId) {
    final list = _messages[conversationId];
    if (list == null || list.isEmpty) return null;
    return list.first.createdAt;
  }

  /// Remove all cached data (e.g., on logout).
  void clear() {
    _messages.clear();
  }
}
