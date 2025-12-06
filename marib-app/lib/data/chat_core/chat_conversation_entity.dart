import 'package:flutter/foundation.dart';

@immutable
class ChatParticipantEntity {
  const ChatParticipantEntity({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.isBlocked = false,
  });

  final int userId;
  final String name;
  final String? avatarUrl;
  final bool isBlocked;
}

@immutable
class ChatConversationEntity {
  const ChatConversationEntity({
    required this.conversationId,
    required this.participants,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String conversationId;
  final List<ChatParticipantEntity> participants;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ChatConversationEntity copyWith({
    String? conversationId,
    List<ChatParticipantEntity>? participants,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ChatConversationEntity(
      conversationId: conversationId ?? this.conversationId,
      participants: participants ?? this.participants,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
