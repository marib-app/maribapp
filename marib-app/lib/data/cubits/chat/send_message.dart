// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:dio/dio.dart';
import 'package:marib/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/repositories/chat_repository.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:marib/data/cubits/chat/chat_message_tracker.dart';

class SendMessageState {}

class SendMessageInitial extends SendMessageState {}

class SendMessageInProgress extends SendMessageState {}

class SendMessageSuccess extends SendMessageState {
  final int messageId;

  SendMessageSuccess({
    required this.messageId,
  });
}

class SendMessageFailed extends SendMessageState {
  final dynamic error;

  SendMessageFailed(
    this.error,
  );
}

class SendMessageCubit extends Cubit<SendMessageState> {
  SendMessageCubit() : super(SendMessageInitial());
  final ChatRepostiory _chatRepostiory = ChatRepostiory();

  void send(
      {required int itemOfferId,
      required String message,
      dynamic audio,
      dynamic attachment}) async {
    try {
      emit(SendMessageInProgress());
      MultipartFile? audioFile;
      MultipartFile? attachmentFile;

      if (audio != "") {
        String? audioFileType = path.extension(audio).substring(1);

        audioFile = await MultipartFile.fromFile(
          audio,
          contentType: MediaType('audio', 'mpeg'),
          filename: 'audio.mp3',
        );
      }
      if (attachment != "") {
        attachmentFile = await MultipartFile.fromFile(attachment!);
      }

      ///If use is not uploading any text so we will upload [File].
      var message0 = message;

      var result = await _chatRepostiory.sendMessageApi(
          message: message0,
          itemOfferId: itemOfferId,
          attachment: attachmentFile,
          audio: audioFile);

      emit(SendMessageSuccess(messageId: result['data']['id']));

      final tracker = ChatMessageTracker.instance;
      Logger.debug(
          'ChatMessageTracker size: ${tracker.length}/${tracker.maxEntries}');
      assert(() {
        final withinLimit = tracker.length <= tracker.maxEntries;
        if (!withinLimit) {
          Logger.error(
              'ChatMessageTracker size ${tracker.length} exceeds limit ${tracker.maxEntries}');
        }
        return withinLimit;
      }());

    } catch (e) {
      Logger.error(e.toString());
      emit(SendMessageFailed(e.toString()));
    }
  }

//This will check if given file like audio recording or attachment is local or it is coming from remote server
  bool isRemoteFile(dynamic file) {
    if (file is String) {
      return true;
    } else {
      return false;
    }
  }
}
