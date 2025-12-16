import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/chat_core/chat_cache_store.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';
import 'package:marib/data/chat_core/chat_repository_v2.dart';
import 'package:marib/data/chat_core/cubit/chat_messages_state.dart';

/// Cubit that manages message pagination, sending, and live updates for a
/// single conversation. It relies on ChatRepositoryV2 and ChatCacheStore
/// (in-memory; can be swapped with persistent cache later).
class ChatMessagesCubit extends Cubit<ChatMessagesState> {
  ChatMessagesCubit({
    required ChatRepositoryV2 repository,
    ChatCacheStore? cacheStore,
    this.pageLimit = 20,
    this.itemOfferId,
  })  : _repository = repository,
        _cache = cacheStore ?? ChatCacheStore(),
        super(const ChatMessagesState());

  final ChatRepositoryV2 _repository;
  final ChatCacheStore _cache;
  final int pageLimit;
  final int? itemOfferId;

  StreamSubscription<ChatMessageEntity>? _messageSub;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  String? get _conversationId => state.conversationId;

  /// Load the first page for a conversation (resets previous state).
  Future<void> loadInitial(String conversationId) async {
    if (_loading) return;
    _loading = true;
    _hasMore = true;
    _loadingMore = false;
    _currentPage = 1;
    await _messageSub?.cancel();
    emit(const ChatMessagesState(status: ChatMessagesStatus.loading));

    try {
      final page = await _repository.loadPage(
        conversationId: conversationId,
        limit: pageLimit,
        itemOfferId: itemOfferId,
      );
      _cache.mergePage(conversationId, page.messages);
      _hasMore = page.hasMore;
      _subscribeToStream(conversationId);
      emit(
        state.copyWith(
          status: ChatMessagesStatus.success,
          conversationId: conversationId,
          messages: _cache.getMessages(conversationId),
          hasMore: _hasMore,
          isLoadingMore: false,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ChatMessagesStatus.failure,
          conversationId: conversationId,
          error: e.toString(),
        ),
      );
    } finally {
      _loading = false;
    }
  }

  /// Load older messages (pagination) keeping scroll anchor stable by
  /// appending to cache and emitting a unified sorted list.
  Future<void> loadMore() async {
    final String? cid = _conversationId;
    if (cid == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final messages = _cache.getMessages(cid);
      final ChatMessageEntity? oldest =
          messages.isNotEmpty ? messages.last : null;
      final page = await _repository.loadPage(
        conversationId: cid,
        limit: pageLimit,
        itemOfferId: itemOfferId,
        beforeMessageId: oldest?.id,
        beforeTimestamp: oldest?.createdAt,
      );
      _cache.mergePage(cid, page.messages);
      _hasMore = page.hasMore;
      emit(
        state.copyWith(
          status: ChatMessagesStatus.success,
          messages: _cache.getMessages(cid),
          hasMore: _hasMore,
          isLoadingMore: false,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ChatMessagesStatus.failure,
          isLoadingMore: false,
          error: e.toString(),
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }

  /// Add a local draft immediately to the list, then attempt to send and
  /// replace with the confirmed server copy.
  Future<void> sendMessage(ChatMessageDraft draft) async {
    final String? cid = _conversationId;
    if (cid == null || cid != draft.conversationId) {
      return;
    }

    final ChatMessageEntity local = ChatMessageEntity(
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
      deliveryStatus: MessageDeliveryStatus.pending,
    );

    _cache.addLocal(cid, local);
    emit(
      state.copyWith(
        messages: _cache.getMessages(cid),
        status: ChatMessagesStatus.success,
      ),
    );

    try {
      final ChatMessageEntity remote = await _repository.sendMessage(draft);
      _cache.replaceLocalWithRemote(cid, remote.copyWith(
        deliveryStatus: MessageDeliveryStatus.sent,
      ));
      emit(
        state.copyWith(
          messages: _cache.getMessages(cid),
          status: ChatMessagesStatus.success,
        ),
      );
    } catch (_) {
      // mark pending as failed
      final failed = local.copyWith(deliveryStatus: MessageDeliveryStatus.failed);
      _cache.replaceLocalWithRemote(cid, failed);
      emit(
        state.copyWith(
          messages: _cache.getMessages(cid),
          status: ChatMessagesStatus.success,
        ),
      );
    }
  }

  void _subscribeToStream(String conversationId) {
    _messageSub?.cancel();
    _messageSub = _repository.messageStream().listen((event) {
      if (event.conversationId != conversationId) return;
      _cache.mergePage(conversationId, <ChatMessageEntity>[event]);
      emit(
        state.copyWith(
          messages: _cache.getMessages(conversationId),
          status: ChatMessagesStatus.success,
        ),
      );
    });
  }

  @override
  Future<void> close() async {
    await _messageSub?.cancel();
    return super.close();
  }
}
