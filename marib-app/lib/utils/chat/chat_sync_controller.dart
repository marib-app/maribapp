import 'dart:async';
import 'dart:collection';

import 'package:marib/data/repositories/chat_repository.dart';
import 'package:marib/utils/logger.dart';

class ChatSyncController {
  ChatSyncController({
    required String conversationId,
    int? itemOfferId,
  })  : _conversationId = conversationId.trim(),
        _itemOfferId =
            itemOfferId != null && itemOfferId > 0 ? itemOfferId : null;

  final ChatRepostiory _repository = ChatRepostiory();
  final LinkedHashSet<int> _delivered = LinkedHashSet<int>();
  final LinkedHashSet<int> _read = LinkedHashSet<int>();

  Timer? _typingDebounce;
  Timer? _typingResetTimer;
  bool _lastTypingSent = false;
  bool _disposed = false;
  String _lastPresenceStatus = '';

  String _conversationId;
  int? _itemOfferId;

  static const Duration _typingDebounceDuration = Duration(milliseconds: 150);
  static const Duration _typingIdleTimeout = Duration(seconds: 6);

  bool get _hasConversation => _conversationId.trim().isNotEmpty;

  void updateIdentifiers({String? conversationId, int? itemOfferId}) {
    if (_disposed) {
      return;
    }

    if (conversationId != null) {
      final String trimmed = conversationId.trim();
      if (trimmed.isNotEmpty && trimmed != _conversationId) {
        _conversationId = trimmed;
        _delivered.clear();
        _read.clear();
        _lastPresenceStatus = '';
        _lastTypingSent = false;
      }
    }

    if (itemOfferId != null) {
      _itemOfferId = itemOfferId > 0 ? itemOfferId : null;
    }
  }

  Future<void> markDelivered(Iterable<int> messageIds) async {
    if (_disposed || !_hasConversation) {
      return;
    }

    final List<int> pending = messageIds
        .where((id) => id > 0 && !_delivered.contains(id))
        .toSet()
        .toList(growable: false);

    if (pending.isEmpty) {
      return;
    }

    try {
      await _repository.markMessagesDelivered(
        conversationId: _conversationId,
        messageIds: pending,
        itemOfferId: _itemOfferId,
      );
      _delivered.addAll(pending);
    } catch (error, stackTrace) {
      Logger.error(
          'Failed to mark messages delivered for $_conversationId: $error');
      Logger.debug(stackTrace, name: 'ChatSyncController');
    }
  }

  Future<void> markRead(Iterable<int> messageIds) async {
    if (_disposed || !_hasConversation) {
      return;
    }

    final List<int> pending = messageIds
        .where((id) => id > 0 && !_read.contains(id))
        .toSet()
        .toList(growable: false);

    if (pending.isEmpty) {
      return;
    }

    try {
      await _repository.markMessagesRead(
        conversationId: _conversationId,
        messageIds: pending,
        itemOfferId: _itemOfferId,
      );
      _read.addAll(pending);
      _delivered.addAll(pending);
    } catch (error, stackTrace) {
      Logger.error('Failed to mark messages read for $_conversationId: $error');
      Logger.debug(stackTrace, name: 'ChatSyncController');
    }
  }

  void onTypingChanged(bool isTyping) {
    if (_disposed || !_hasConversation) {
      return;
    }

    _typingDebounce?.cancel();

    if (!isTyping) {
      _typingResetTimer?.cancel();
      _sendTyping(false);
      return;
    }

    _typingDebounce = Timer(_typingDebounceDuration, () {
      _sendTyping(true);
      _typingResetTimer?.cancel();
      _typingResetTimer = Timer(_typingIdleTimeout, () {
        _sendTyping(false);
      });
    });
  }

  void _sendTyping(bool isTyping) {
    if (_disposed || !_hasConversation) {
      return;
    }

    if (_lastTypingSent == isTyping) {
      return;
    }

    _lastTypingSent = isTyping;

    unawaited(_repository
        .updateTypingStatus(
      conversationId: _conversationId,
      isTyping: isTyping,
      itemOfferId: _itemOfferId,
    )
        .catchError((error, stackTrace) {
      Logger.error(
          'Failed to update typing status for $_conversationId: $error');
      Logger.debug(stackTrace, name: 'ChatSyncController');
    }));
  }

  Future<void> setPresenceOnline() async {
    await _updatePresence(isOnline: true);
  }

  Future<void> setPresenceOffline() async {
    await _updatePresence(isOnline: false);
  }

  Future<void> _updatePresence({required bool isOnline}) async {
    if (_disposed || !_hasConversation) {
      return;
    }

    final String statusLabel = isOnline ? 'online' : 'offline';
    if (_lastPresenceStatus == statusLabel) {
      return;
    }

    _lastPresenceStatus = statusLabel;

    try {
      await _repository.updatePresenceStatus(
        conversationId: _conversationId,
        isOnline: isOnline,
        itemOfferId: _itemOfferId,
      );
    } catch (error, stackTrace) {
      Logger.error('Failed to update presence for $_conversationId: $error');
      Logger.debug(stackTrace, name: 'ChatSyncController');
      if (isOnline) {
        _lastPresenceStatus = '';
      }
    }
  }

  void dispose() {
    _disposed = true;
    _typingDebounce?.cancel();
    _typingResetTimer?.cancel();
  }
}
