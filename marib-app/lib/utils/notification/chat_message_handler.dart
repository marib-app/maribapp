import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/chat/chat_message_modal.dart';

class ChatMessageHandler {
  static final List<ChatMessageModal> _remoteMessages = <ChatMessageModal>[];
  static final List<ChatMessageModal> _localMessages = <ChatMessageModal>[];
  static final StreamController<List<ChatMessageModal>> _chatMessageStream =
      StreamController<List<ChatMessageModal>>.broadcast();

  static final ValueNotifier<ParticipantStatus?> participantStatusNotifier =
      ValueNotifier<ParticipantStatus?>(null);

  static List<ChatMessageModal> get currentMessages {
    // Merge local (pending) and remote (confirmed) then sort newest -> oldest
    // by createdAt (fallback updatedAt, then id). This prevents visual jumps
    // when a pending message is replaced by its confirmed copy.
    final List<ChatMessageModal> merged = <ChatMessageModal>[
      ..._localMessages,
      ..._remoteMessages,
    ];

    DateTime? _parseTs(ChatMessageModal m) {
      DateTime? tryParse(String? value) {
        if (value == null || value.isEmpty) return null;
        return DateTime.tryParse(value);
      }

      return tryParse(m.createdAt) ?? tryParse(m.updatedAt);
    }

    merged.sort((a, b) {
      final DateTime? ta = _parseTs(a);
      final DateTime? tb = _parseTs(b);
      if (ta != null && tb != null) {
        // newer first
        final int cmp = tb.compareTo(ta);
        if (cmp != 0) return cmp;
      } else if (ta != null || tb != null) {
        return (tb ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(ta ?? DateTime.fromMillisecondsSinceEpoch(0));
      }

      final int idA = a.id ?? -1;
      final int idB = b.id ?? -1;
      if (idA != idB) {
        return idB.compareTo(idA);
      }

      // Keep existing order as final fallback
      return 0;
    });

    return List<ChatMessageModal>.unmodifiable(merged);
  }

  static void add(ChatMessageModal chat) {
    // If this is a remote/confirmed message (has server id), insert/update
    // it into remote messages and remove any matching local pending copies.
    if (chat.id != null && chat.id! > 0 && chat.isSentNow == false) {
      final int existingIndex =
          _remoteMessages.indexWhere((element) => element.id == chat.id);
      if (existingIndex != -1) {
        _remoteMessages[existingIndex] = chat;
      } else {
        _remoteMessages.insert(0, chat);
      }

      // Remove local pending copies that match this remote message (by id or signature)
      final String sigSender = (chat.senderId ?? 0).toString();
      final String sigReceiver = (chat.receiverId ?? 0).toString();
      final String sigMessage = (chat.message ?? '').trim();
      final String sigFile = (chat.file ?? '').trim();
      final String sigAudio = (chat.audio ?? '').trim();
      final String sigCreated = (chat.createdAt ?? '').trim();
      final String signature =
          '${sigSender}#${sigReceiver}#${sigMessage}#${sigFile}#${sigAudio}#${sigCreated}';

      _localMessages.removeWhere((element) {
        // Only remove pending local messages
        if (element.isSentNow != true) return false;

        // If local has now-matching id, remove
        if (element.id != null && element.id == chat.id) return true;

        final String ls = (element.senderId ?? 0).toString();
        final String lr = (element.receiverId ?? 0).toString();
        final String lm = (element.message ?? '').trim();
        final String lf = (element.file ?? '').trim();
        final String la = (element.audio ?? '').trim();
        final String lc = (element.createdAt ?? '').trim();
        final String localSignature =
            '${ls}#${lr}#${lm}#${lf}#${la}#${lc}';
        return localSignature == signature;
      });

    } else {
      // Local/pending message being added. Avoid inserting if a matching
      // remote message already exists (prevents adding duplicate local copy
      // when the server already provided the message).
      final String? identifier = chat.localId;

      final String sigSender = (chat.senderId ?? 0).toString();
      final String sigReceiver = (chat.receiverId ?? 0).toString();
      final String sigMessage = (chat.message ?? '').trim();
      final String sigFile = (chat.file ?? '').trim();
      final String sigAudio = (chat.audio ?? '').trim();
      final String sigCreated = (chat.createdAt ?? '').trim();
      final String signature =
          '${sigSender}#${sigReceiver}#${sigMessage}#${sigFile}#${sigAudio}#${sigCreated}';

      // If a remote message with same signature exists, skip adding the local copy
      final bool hasRemoteMatch = _remoteMessages.any((m) {
        final String rs = (m.senderId ?? 0).toString();
        final String rr = (m.receiverId ?? 0).toString();
        final String rm = (m.message ?? '').trim();
        final String rf = (m.file ?? '').trim();
        final String ra = (m.audio ?? '').trim();
        final String rc = (m.createdAt ?? '').trim();
        final String rSignature =
            '${rs}#${rr}#${rm}#${rf}#${ra}#${rc}';
        return rSignature == signature;
      });

      if (hasRemoteMatch) {
        // Nothing to do; server message already present
      } else {
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
    _localMessages.clear();

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
    // Remove local messages that were already delivered (exist remotely).
    final Set<int> remoteIds = _remoteMessages
        .where((element) => (element.id ?? 0) > 0)
        .map((element) => element.id!)
        .toSet();

    // Build a set of remote message signatures to match local pending messages
    // in case the server doesn't return a local_id or the local message wasn't
    // updated with the remote id. Signature includes sender/receiver/message/file/audio/createdAt
    final Set<String> remoteSignatures = _remoteMessages.map((m) {
      final String sigSender = (m.senderId ?? 0).toString();
      final String sigReceiver = (m.receiverId ?? 0).toString();
      final String sigMessage = (m.message ?? '').trim();
      final String sigFile = (m.file ?? '').trim();
      final String sigAudio = (m.audio ?? '').trim();
      final String sigCreated = (m.createdAt ?? '').trim();
      return '${sigSender}#${sigReceiver}#${sigMessage}#${sigFile}#${sigAudio}#${sigCreated}';
    }).toSet();

    if (remoteIds.isEmpty && remoteSignatures.isEmpty) {
      return;
    }

    _localMessages.removeWhere((element) {
      // If local already has assigned id and it's present remotely, remove it
      final int? messageId = element.id;
      if (messageId != null && remoteIds.contains(messageId)) {
        return true;
      }

      // Otherwise, try to match by signature for pending local messages
      // (isSentNow true) to avoid accidentally removing drafts.
      if (element.isSentNow != true) {
        return false;
      }
      final String sigSender = (element.senderId ?? 0).toString();
      final String sigReceiver = (element.receiverId ?? 0).toString();
      final String sigMessage = (element.message ?? '').trim();
      final String sigFile = (element.file ?? '').trim();
      final String sigAudio = (element.audio ?? '').trim();
      final String sigCreated = (element.createdAt ?? '').trim();
      final String signature =
          '${sigSender}#${sigReceiver}#${sigMessage}#${sigFile}#${sigAudio}#${sigCreated}';
      return remoteSignatures.contains(signature);
    });
  }

  static void _emit() {
    if (_chatMessageStream.isClosed) {
      return;
    }

    _chatMessageStream.sink.add(currentMessages);
  }
}
