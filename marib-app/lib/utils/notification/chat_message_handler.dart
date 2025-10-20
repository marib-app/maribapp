import 'dart:async';

import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/chat/chat_message_modal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';

class ChatMessageHandler {
  static final List<ChatMessageModal> _remoteMessages = <ChatMessageModal>[];
  static final List<ChatMessageModal> _localMessages = <ChatMessageModal>[];
  static final StreamController<List<ChatMessageModal>> _chatMessageStream =
      StreamController<List<ChatMessageModal>>.broadcast();

  static final ValueNotifier<ParticipantStatus?> participantStatusNotifier =
      ValueNotifier<ParticipantStatus?>(null);

  static List<ChatMessageModal> get currentMessages =>
      List<ChatMessageModal>.unmodifiable(<ChatMessageModal>[
        ..._localMessages,
        ..._remoteMessages,
      ]);

  static void add(ChatMessageModal chat) {
    if (chat.id != null && chat.id! > 0 && chat.isSentNow == false) {
      final int existingIndex =
          _remoteMessages.indexWhere((element) => element.id == chat.id);
      if (existingIndex != -1) {
        _remoteMessages[existingIndex] = chat;
      } else {
        _remoteMessages.insert(0, chat);
      }
    } else {
      final String? identifier = chat.localId;
      if (identifier != null) {
        final int existingIndex = _localMessages
            .indexWhere((element) => element.localId == identifier);
        if (existingIndex != -1) {
          _localMessages[existingIndex] = chat;
        } else {
          _localMessages.insert(0, chat);
        }
      } else {
        _localMessages.insert(0, chat);
      }
    }

    _emit();
  }

  static void loadMessages(List<ChatMessageModal> chats) {
    _remoteMessages
      ..clear()
      ..addAll(chats);
    _removeDeliveredLocalDuplicates();
    _emit();
  }

  static void flushMessages() {
    _remoteMessages.clear();

    _emit();
  }

  static void updateParticipantStatus(ParticipantStatus? status) {
    participantStatusNotifier.value = status;
  }

  static void clearParticipantStatus() {
    participantStatusNotifier.value = null;
  }

  static Stream<List<ChatMessageModal>> getChatStream() {
    return _chatMessageStream.stream;
  }

  static void updateMessageStatus({
    required int messageId,
    String? status,
    String? deliveredAt,
    String? readAt,
  }) {
    bool updated = false;

    void updateIn(List<ChatMessageModal> list) {
      final int index = list.indexWhere((element) => element.id == messageId);
      if (index == -1) {
        return;
      }
      final ChatMessageModal current = list[index];
      list[index] = current.copyWith(
        status: status ?? current.status,
        deliveredAt: deliveredAt ?? current.deliveredAt,
        readAt: readAt ?? current.readAt,
      );
      updated = true;
    }

    updateIn(_remoteMessages);
    updateIn(_localMessages);

    if (updated) {
      _emit();
    }
  }

  static void attachListener(void Function(List<ChatMessageModal>)? onData) {
    _chatMessageStream.stream.listen(onData);
  }

  static void removeMessage(int id) {
    final int initialRemoteLength = _remoteMessages.length;
    _remoteMessages.removeWhere((element) => element.id == id);
    final int initialLocalLength = _localMessages.length;
    _localMessages.removeWhere((element) => element.id == id);

    if (initialRemoteLength != _remoteMessages.length ||
        initialLocalLength != _localMessages.length) {
      _emit();
    }
  }

  static void updateMessageId(String identifier, int id) {
    final int index =
        _localMessages.indexWhere((element) => element.localId == identifier);
    if (index == -1) {
      return;
    }
    final ChatMessageModal updated =
        _localMessages.removeAt(index).copyWith(id: id, isSentNow: false);

    final int remoteIndex =
        _remoteMessages.indexWhere((element) => element.id == id);

    if (remoteIndex != -1) {
      _remoteMessages[remoteIndex] = updated;
    } else {
      _remoteMessages.insert(0, updated);
    }
    _emit();
  }

  static void _removeDeliveredLocalDuplicates() {
    if (_localMessages.isEmpty) {
      return;
    }
    final Set<int> remoteIds = _remoteMessages
        .where((element) => (element.id ?? 0) > 0)
        .map((element) => element.id!)
        .toSet();
    if (remoteIds.isEmpty) {
      return;
    }
    _localMessages.removeWhere((element) {
      final int? messageId = element.id;
      if (messageId == null) {
        return false;
      }
      return remoteIds.contains(messageId);
    });
  }

  static void _emit() {
    if (_chatMessageStream.isClosed) {
      return;
    }

    _chatMessageStream.sink.add(currentMessages);
  }
}
