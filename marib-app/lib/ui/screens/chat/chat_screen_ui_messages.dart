part of 'chat_screen.dart';

extension _ChatScreenUiMessages on _ChatScreenState {
List<_ChatListEntry> _buildRenderableMessages(
      List<ChatMessageModal> messages, BuildContext context) {
    final List<_ChatListEntry> items = <_ChatListEntry>[];
    String? previousDate;
    for (int index = messages.length - 1; index >= 0; index--) {
      final ChatMessageModal message = messages[index];
      final String? label = _formatDateLabel(message.createdAt, context);
      if (label != null && label != previousDate) {
        items.insert(0, _ChatListEntry.date(label));
        previousDate = label;
      }
      items.insert(0, _ChatListEntry.message(message));
    }
    return items;
  }

String? _formatDateLabel(String? createdAt, BuildContext context) {
    if (createdAt == null || createdAt.isEmpty) {
      return null;
    }
    try {
      final DateTime parsed = DateTime.parse(createdAt).toLocal();
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime yesterday = today.subtract(const Duration(days: 1));

      if (!parsed.isBefore(today)) {
        return "today".translate(context);
      }
      if (!parsed.isBefore(yesterday)) {
        return "yesterday".translate(context);
      }
      return parsed.toString().formatDate();
    } catch (_) {
      return createdAt;
    }
  }

Widget _buildMessageDateChip(BuildContext context, String formattedDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: context.color.territoryColor.withOpacity(0.3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text(formattedDate),
          ),
        ),
      ),
    );
  }

Widget _buildChatMessageWidget(ChatMessageModal modal) {
    final String? localKey = modal.localId;
    final Key messageKey;
    if ((modal.id ?? 0) > 0) {
      messageKey = ValueKey(modal.id);
    } else if (localKey != null && localKey.isNotEmpty) {
      messageKey = ValueKey(localKey);
    } else {
      messageKey = ValueKey(modal.hashCode);
    }

    final ChatMessage chatWidget = ChatMessage(
      key: messageKey,
      id: modal.id,
      senderId: modal.senderId ?? 0,
      itemOfferId: modal.itemOfferId ?? widget.itemOfferId,
      message: modal.message ?? '',
      file: modal.file ?? '',
      audio: modal.audio ?? '',
      createdAt: modal.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: modal.updatedAt ?? modal.createdAt ?? '',
      messageType: modal.messageType,
      isSentNow: modal.isSentNow,
      status: modal.status,
      deliveredAt: modal.deliveredAt,
      readAt: modal.readAt,
    );

    if (modal.isSentNow) {
      return BlocProvider(
        key:
            ValueKey('provider_${localKey ?? modal.id ?? chatWidget.hashCode}'),
        create: (_) => SendMessageCubit(),
        child: chatWidget,
      );
    }

    return chatWidget;
  }
}

class _ChatListEntry {
  final ChatMessageModal? message;
  final String? dateLabel;

  bool get isDateSeparator => dateLabel != null;

  const _ChatListEntry._({this.message, this.dateLabel});

  factory _ChatListEntry.message(ChatMessageModal message) =>
      _ChatListEntry._(message: message);

  factory _ChatListEntry.date(String label) =>
      _ChatListEntry._(dateLabel: label);
}
