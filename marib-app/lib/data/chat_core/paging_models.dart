import 'package:flutter/foundation.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';

/// Paged response wrapper for chat messages.
@immutable
class ChatPage {
  const ChatPage({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ChatMessageEntity> messages;
  final bool hasMore;
  final String? nextCursor;
}

/// Presence event used by the new presence channel.
@immutable
class PresenceEvent {
  const PresenceEvent({
    required this.userId,
    required this.isOnline,
    this.isTyping = false,
    this.lastSeen,
    this.conversationId,
  });

  final int userId;
  final bool isOnline;
  final bool isTyping;
  final DateTime? lastSeen;
  final String? conversationId;
}
