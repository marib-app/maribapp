import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:marib/data/chat_core/chat_cache_store.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';
import 'package:marib/data/chat_core/chat_conversation_entity.dart';
import 'package:marib/data/chat_core/chat_repository_v2.dart';
import 'package:marib/data/chat_core/paging_models.dart';
import 'package:marib/data/model/chat/chat_message_modal.dart';
import 'package:marib/data/repositories/chat_repository.dart';
import 'package:marib/utils/helper_utils.dart';

/// Adapter to bridge the legacy ChatRepostiory to the new ChatRepositoryV2
/// contract. This keeps the existing API usage while allowing the new cubits
/// to be integrated gradually.
class ChatRepositoryAdapter implements ChatRepositoryV2 {
  ChatRepositoryAdapter({
    ChatRepostiory? legacyRepo,
    ChatCacheStore? cacheStore,
    this.perPage = 20,
  })  : _legacy = legacyRepo ?? ChatRepostiory(),
        _cache = cacheStore ?? ChatCacheStore(maxPerConversation: 500);

  final ChatRepostiory _legacy;
  final ChatCacheStore _cache;
  final int perPage;
  final Map<String, int> _pageByConversation = <String, int>{};

  final StreamController<ChatMessageEntity> _messageStreamController =
      StreamController<ChatMessageEntity>.broadcast();
  final StreamController<PresenceEvent> _presenceStreamController =
      StreamController<PresenceEvent>.broadcast();

  @override
  Future<ChatPage> loadPage({
    required String conversationId,
    int limit = 20,
    int? beforeMessageId,
    DateTime? beforeTimestamp,
    int? itemOfferId,
  }) async {
    // Legacy API paginates by page number; keep an internal cursor per conversation.
    final bool isInitial = beforeMessageId == null && beforeTimestamp == null;
    if (isInitial) {
      _pageByConversation[conversationId] = 1;
    }
    final int page = _pageByConversation[conversationId] ?? 1;
    final response = await _legacy.getMessagesApi(
      page: page,
      perPage: limit,
      itemOfferId: itemOfferId ?? 0,
      conversationId: conversationId,
    );

    final List<ChatMessageEntity> entities = response.modelList
        .map((m) => _mapModalToEntity(m, forcedConversationId: conversationId))
        .whereType<ChatMessageEntity>()
        .toList();

    final int total = response.total;
    final int currentPage = response.page ?? page;
    final bool hasMore =
        total > (currentPage * limit) || entities.length >= limit;

    // advance page cursor for next call
    _pageByConversation[conversationId] = currentPage + 1;

    return ChatPage(messages: entities, hasMore: hasMore);
  }

  @override
  Future<ChatMessageEntity> sendMessage(ChatMessageDraft draft) async {
    final MultipartFile? file = await _maybeMultipart(draft.filePath, 'file');
    final MultipartFile? audio =
        await _maybeMultipart(draft.audioPath, 'audio');

    final map = await _legacy.sendMessageApi(
      itemOfferId: draft.itemOfferId ?? 0,
      message: draft.text ?? '',
      attachment: file,
      audio: audio,
    );

    final dynamic data = map['data'];
    if (data is Map<String, dynamic>) {
      final ChatMessageModal modal = ChatMessageModal.fromJson(data);
      final entity = _mapModalToEntity(
        modal,
        forcedConversationId: draft.conversationId,
      )?.copyWith(
        localId: draft.localId,
      );
      if (entity != null) {
        _messageStreamController.add(entity);
        return entity;
      }
    }

    // Fallback to a sent copy using draft data.
    final fallback = ChatMessageEntity(
      id: null,
      localId: draft.localId,
      conversationId: draft.conversationId,
      senderId: draft.senderId,
      receiverId: draft.receiverId,
      itemOfferId: draft.itemOfferId,
      itemId: draft.itemId,
      text: draft.text,
      fileUrl: draft.filePath,
      audioUrl: draft.audioPath,
      messageType: draft.messageType,
      createdAt: draft.createdAt,
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    _messageStreamController.add(fallback);
    return fallback;
  }

  @override
  Stream<ChatMessageEntity> messageStream() => _messageStreamController.stream;

  @override
  Stream<PresenceEvent> presenceStream() =>
      _presenceStreamController.stream; // currently not wired; can be fed later

  @override
  Future<List<ChatConversationEntity>> loadConversations() async {
    // Not implemented in legacy API. Return empty for now.
    return <ChatConversationEntity>[];
  }

  ChatMessageEntity? _mapModalToEntity(
    ChatMessageModal modal, {
    String? forcedConversationId,
  }) {
    DateTime? _parse(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final DateTime created = _parse(modal.createdAt) ?? DateTime.now();
    final DateTime? updated = _parse(modal.updatedAt);

    final String conversationId =
        forcedConversationId?.trim().isNotEmpty == true
            ? forcedConversationId!
            : (modal.itemOfferId?.toString() ??
                modal.receiverId?.toString() ??
                modal.id?.toString() ??
                '');

    return ChatMessageEntity(
      id: modal.id,
      localId: modal.localId,
      conversationId: conversationId,
      senderId: modal.senderId ?? 0,
      receiverId: modal.receiverId ?? 0,
      itemOfferId: modal.itemOfferId,
      itemId: modal.itemId,
      text: modal.message,
      fileUrl: HelperUtils.absoluteImage(modal.file ?? ''),
      audioUrl: modal.audio,
      messageType: modal.messageType ?? 'text',
      createdAt: created,
      updatedAt: updated,
      deliveryStatus: _mapStatus(modal),
      isDeleted: false,
    );
  }

  MessageDeliveryStatus _mapStatus(ChatMessageModal modal) {
    final String? status = modal.status?.toLowerCase();
    if (status == 'read') return MessageDeliveryStatus.read;
    if (status == 'delivered') return MessageDeliveryStatus.delivered;
    if (status == 'sent') return MessageDeliveryStatus.sent;
    return MessageDeliveryStatus.sent;
  }

  Future<MultipartFile?> _maybeMultipart(String? path, String field) async {
    if (path == null || path.trim().isEmpty) return null;
    final File file = File(path);
    if (!await file.exists()) return null;
    final String fileName = path.split('/').last;
    return MultipartFile.fromFile(path, filename: fileName);
  }

  void dispose() {
    _messageStreamController.close();
    _presenceStreamController.close();
  }
}
