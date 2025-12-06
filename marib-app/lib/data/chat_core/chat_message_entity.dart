import 'package:flutter/foundation.dart';

/// Delivery states for a message, covering both local and server-confirmed
/// transitions.
enum MessageDeliveryStatus { pending, sent, delivered, read, failed }

/// Lightweight message entity to be used by the new chat stack.
@immutable
class ChatMessageEntity {
  const ChatMessageEntity({
    this.id,
    this.localId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.itemOfferId,
    this.itemId,
    this.text,
    this.fileUrl,
    this.audioUrl,
    required this.messageType,
    required this.createdAt,
    this.updatedAt,
    this.deliveryStatus = MessageDeliveryStatus.pending,
    this.isDeleted = false,
  });

  /// Server id (null for local-only/pending).
  final int? id;

  /// Local identifier to map pending messages to their confirmed counterpart.
  final String? localId;

  /// Normalized conversation identifier.
  final String conversationId;

  final int senderId;
  final int receiverId;
  final int? itemOfferId;
  final int? itemId;

  /// Plain text body.
  final String? text;

  /// Remote or local path for file/image attachments.
  final String? fileUrl;

  /// Remote or local path for audio attachments.
  final String? audioUrl;

  /// Raw message type (e.g., text/image/file/audio/system).
  final String messageType;

  /// Creation timestamp (server or local).
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  final MessageDeliveryStatus deliveryStatus;

  /// Soft-delete flag for handling redacted/removed messages.
  final bool isDeleted;

  bool get isPending => deliveryStatus == MessageDeliveryStatus.pending;

  ChatMessageEntity copyWith({
    int? id,
    String? localId,
    String? conversationId,
    int? senderId,
    int? receiverId,
    int? itemOfferId,
    int? itemId,
    String? text,
    String? fileUrl,
    String? audioUrl,
    String? messageType,
    DateTime? createdAt,
    DateTime? updatedAt,
    MessageDeliveryStatus? deliveryStatus,
    bool? isDeleted,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      itemOfferId: itemOfferId ?? this.itemOfferId,
      itemId: itemId ?? this.itemId,
      text: text ?? this.text,
      fileUrl: fileUrl ?? this.fileUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Draft used for sending a new message.
@immutable
class ChatMessageDraft {
  const ChatMessageDraft({
    required this.localId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.itemOfferId,
    this.itemId,
    this.text,
    this.filePath,
    this.audioPath,
    required this.messageType,
    required this.createdAt,
  });

  final String localId;
  final String conversationId;
  final int senderId;
  final int receiverId;
  final int? itemOfferId;
  final int? itemId;
  final String? text;
  final String? filePath;
  final String? audioPath;
  final String messageType;
  final DateTime createdAt;
}
