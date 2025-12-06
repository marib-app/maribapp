import 'dart:async';

import 'package:marib/data/chat_core/chat_message_entity.dart';
import 'package:marib/data/chat_core/chat_conversation_entity.dart';
import 'package:marib/data/chat_core/paging_models.dart';

/// Abstraction for the new chat stack. Concrete implementations can wrap
/// existing REST/socket APIs while exposing a clean, testable surface.
abstract class ChatRepositoryV2 {
  /// Load a page of messages. `beforeMessageId` or `beforeTimestamp` can be
  /// used as an anchor for pagination (e.g., when pulling older messages).
  Future<ChatPage> loadPage({
    required String conversationId,
    int limit = 20,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
  });

  /// Send a new message. Returns the confirmed message (with server id) or
  /// throws on failure.
  Future<ChatMessageEntity> sendMessage(ChatMessageDraft draft);

  /// Stream of live incoming/updated messages (e.g., via sockets/notifications).
  Stream<ChatMessageEntity> messageStream();

  /// Stream of presence updates for participants.
  Stream<PresenceEvent> presenceStream();

  /// Optionally prefetch conversation metadata (counts/last message).
  Future<List<ChatConversationEntity>> loadConversations();
}

@override
String toString() => 'ChatRepositoryV2';
