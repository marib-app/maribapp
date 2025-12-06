import 'package:equatable/equatable.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';

enum ChatMessagesStatus { initial, loading, success, failure }

class ChatMessagesState extends Equatable {
  const ChatMessagesState({
    this.status = ChatMessagesStatus.initial,
    this.conversationId,
    this.messages = const <ChatMessageEntity>[],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
  });

  final ChatMessagesStatus status;
  final String? conversationId;
  final List<ChatMessageEntity> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;

  ChatMessagesState copyWith({
    ChatMessagesStatus? status,
    String? conversationId,
    List<ChatMessageEntity>? messages,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
  }) {
    return ChatMessagesState(
      status: status ?? this.status,
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        conversationId,
        messages,
        hasMore,
        isLoadingMore,
        error,
      ];
}
