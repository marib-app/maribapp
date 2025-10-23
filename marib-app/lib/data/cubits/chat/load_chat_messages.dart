// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:marib/data/repositories/chat_repository.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/chat/chat_message_modal.dart';
import 'package:marib/utils/chat/conversation_id_utils.dart';

class LoadChatMessagesState {}

class LoadChatMessagesInitial extends LoadChatMessagesState {}

class LoadChatMessagesInProgress extends LoadChatMessagesState {}

class LoadChatMessagesSuccess extends LoadChatMessagesState {
  List<ChatMessageModal> messages;
  int currentPage;
  int itemOfferId;
  String conversationId;

  int totalPage;
  bool isLoadingMore;

  LoadChatMessagesSuccess({
    required this.messages,
    required this.currentPage,
    required this.itemOfferId,
    required this.conversationId,
    required this.totalPage,
    required this.isLoadingMore,
  });

  LoadChatMessagesSuccess copyWith({
    List<ChatMessageModal>? messages,
    int? currentPage,
    int? userId,
    int? itemOfferId,
    String? conversationId,
    int? totalPage,
    bool? isLoadingMore,
  }) {
    return LoadChatMessagesSuccess(
      messages: messages ?? this.messages,
      currentPage: currentPage ?? this.currentPage,
      itemOfferId: itemOfferId ?? this.itemOfferId,
      conversationId: conversationId ?? this.conversationId,
      totalPage: totalPage ?? this.totalPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  String toString() {
    return 'LoadChatMessagesSuccess(messages: $messages, currentPage: $currentPage, itemOfferId: $itemOfferId, conversationId: $conversationId,totalPage: $totalPage, isLoadingMore: $isLoadingMore)';
  }
}

class LoadChatMessagesFailed extends LoadChatMessagesState {
  final dynamic error;

  LoadChatMessagesFailed({
    required this.error,
  });
}

class LoadChatMessagesCubit extends Cubit<LoadChatMessagesState> {
  LoadChatMessagesCubit() : super(LoadChatMessagesInitial());
  final ChatRepostiory _chatRepostiory = ChatRepostiory();

  Future<void> load(
      {required int itemOfferId, required String conversationId}) async {
    try {
      emit(LoadChatMessagesInProgress());
      final String normalizedConversationId =
      normalizeConversationId(conversationId);
      final int normalizedItemOfferId = itemOfferId > 0 ? itemOfferId : 0;

      DataOutput<ChatMessageModal> result =
          await _chatRepostiory.getMessagesApi(
        itemOfferId: normalizedItemOfferId,
        conversationId: normalizedConversationId,
        page: 1,
      );

      emit(LoadChatMessagesSuccess(
        messages: result.modelList,
        currentPage: 1,
        itemOfferId: normalizedItemOfferId,
        conversationId: normalizedConversationId,
        isLoadingMore: false,
        totalPage: result.total,
      ));
    } catch (e) {
      emit(LoadChatMessagesFailed(error: e.toString()));
    }
  }

  Future<void> loadMore() async {
    try {
      if (state is LoadChatMessagesSuccess) {
        if ((state as LoadChatMessagesSuccess).isLoadingMore) {
          return;
        }
        emit((state as LoadChatMessagesSuccess).copyWith(isLoadingMore: true));

        DataOutput<ChatMessageModal> result =
            await _chatRepostiory.getMessagesApi(
                page: (state as LoadChatMessagesSuccess).currentPage + 1,
                itemOfferId: (state as LoadChatMessagesSuccess).itemOfferId,
                conversationId:
                    (state as LoadChatMessagesSuccess).conversationId);

        LoadChatMessagesSuccess messagesSuccessState =
            (state as LoadChatMessagesSuccess);

        messagesSuccessState.messages.addAll(result.modelList);

        emit(LoadChatMessagesSuccess(
          messages: messagesSuccessState.messages,
          currentPage: (state as LoadChatMessagesSuccess).currentPage + 1,
          conversationId: (state as LoadChatMessagesSuccess).conversationId,
          itemOfferId: (state as LoadChatMessagesSuccess).itemOfferId,
          isLoadingMore: false,
          totalPage: result.total,
        ));
      }
    } catch (e) {
      emit((state as LoadChatMessagesSuccess).copyWith(isLoadingMore: false));
    }
  }

  bool hasMoreChat() {
    if (state is LoadChatMessagesSuccess) {
      return (state as LoadChatMessagesSuccess).messages.length <
          (state as LoadChatMessagesSuccess).totalPage;
    }
    return false;
  }

  @override
  LoadChatMessagesState? fromJson(Map<String, dynamic> json) {
    // TODO: implement fromJson
    return null;
  }

  @override
  Map<String, dynamic>? toJson(LoadChatMessagesState state) {
    return null;
  }
}
