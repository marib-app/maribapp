import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/chat_core/chat_message_entity.dart';
import 'package:marib/data/chat_core/chat_repository_adapter.dart';
import 'package:marib/data/chat_core/cubit/chat_messages_cubit.dart';
import 'package:marib/data/chat_core/cubit/chat_messages_state.dart';

/// Minimal V2 chat screen wired to the new ChatRepositoryV2 stack.
/// This is isolated from the legacy screens so it can be iterated safely.
class ChatScreenV2 extends StatefulWidget {
  const ChatScreenV2({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.senderId,
    this.itemOfferId,
    this.itemId,
    this.title,
  });

  final String conversationId;
  final int receiverId;
  final int senderId;
  final int? itemOfferId;
  final int? itemId;
  final String? title;

  @override
  State<ChatScreenV2> createState() => _ChatScreenV2State();
}

class _ChatScreenV2State extends State<ChatScreenV2> {
  late final ChatRepositoryAdapter _repository;
  late final ChatMessagesCubit _messagesCubit;
  late final ScrollController _scrollController;
  final TextEditingController _textController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepositoryAdapter();
    _messagesCubit = ChatMessagesCubit(repository: _repository, pageLimit: 20);
    _scrollController = ScrollController()..addListener(_onScroll);
    _messagesCubit.loadInitial(widget.conversationId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 12) {
      _messagesCubit.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _messagesCubit.close();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final String text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final draft = ChatMessageDraft(
      localId: 'local_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
      conversationId: widget.conversationId,
      senderId: widget.senderId,
      receiverId: widget.receiverId,
      itemOfferId: widget.itemOfferId,
      itemId: widget.itemId,
      text: text,
      filePath: null,
      audioPath: null,
      messageType: 'text',
      createdAt: DateTime.now(),
    );
    _textController.clear();
    await _messagesCubit.sendMessage(draft);
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _messagesCubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'المحادثة'),
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatMessagesCubit, ChatMessagesState>(
                builder: (context, state) {
                  if (state.status == ChatMessagesStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == ChatMessagesStatus.failure) {
                    return Center(
                      child: Text(state.error ?? 'تعذر تحميل الرسائل'),
                    );
                  }
                  final messages = state.messages;
                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        itemCount: messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return state.isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          final msg = messages[index];
                          final bool isMe = msg.senderId == widget.senderId;
                          return _MessageBubble(message: msg, isMe: isMe);
                        },
                      ),
                      if (state.isLoadingMore && messages.isEmpty)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _isSending ? null : _sendText,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final ChatMessageEntity message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color bubbleColor =
        isMe ? colors.primary.withOpacity(0.12) : colors.surfaceVariant;
    final Color textColor =
        isMe ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    final String statusLabel = _statusText(message.deliveryStatus);

    return Align(
      alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if ((message.text ?? '').isNotEmpty)
              Text(
                message.text ?? '',
                style: TextStyle(color: textColor),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _statusText(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.pending:
        return '...';
      case MessageDeliveryStatus.sent:
        return 'مرسلة';
      case MessageDeliveryStatus.delivered:
        return 'وُصلت';
      case MessageDeliveryStatus.read:
        return 'مقروءة';
      case MessageDeliveryStatus.failed:
        return 'فشل';
    }
  }
}
