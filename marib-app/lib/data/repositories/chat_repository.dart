import 'package:dio/dio.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:marib/utils/api.dart';
import 'package:flutter/material.dart';

class ChatRepostiory {
  BuildContext? _setContext;

  String? _normalizeField(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }

  void setContext(BuildContext context) {
    _setContext = context;
  }

  Future<DataOutput<ChatedUser>> fetchBuyerChatList(int page) async {
    /* Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi, queryParameters: {*/ /*"page": page, */ /*"type": "buyer"});*/

    Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi,
        queryParameters: {"type": "buyer", "page": page});

    List<ChatedUser> modelList = (response['data']['data'] as List).map(
      (e) {
        return ChatedUser.fromJson(e);
      },
    ).toList();

    return DataOutput(total: response['data']['total'], modelList: modelList);
  }

  Future<DataOutput<ChatedUser>> fetchSellerChatList(int page) async {
    Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi,
        queryParameters: {"page": page, "type": "seller"});

    List<ChatedUser> modelList = (response['data']["data"] as List).map(
      (e) {
        return ChatedUser.fromJson(e /*, context: _setContext*/);
      },
    ).toList();

    return DataOutput(
        total: response['data']['total'] ?? 0, modelList: modelList);
  }

  Future<DataOutput<ChatMessage>> getMessagesApi(
      {required int page,
      required int itemOfferId,
      required String conversationId}) async {
    Map<String, dynamic> response = await Api.get(
      url: Api.chatMessagesApi,
      queryParameters: {
        "item_offer_id": itemOfferId,
        "conversation_id": conversationId,
        "page": page,
      },
    );

    final Map<String, dynamic> responseData =
        (response['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final List<dynamic> resultList =
        (responseData['data'] as List<dynamic>?) ?? <dynamic>[];

    List<ChatMessage> modelList = resultList.map((result) {
      final Map<String, dynamic> resultMap =
          Map<String, dynamic>.from(result as Map);

      final dynamic senderIdRaw = resultMap['sender_id'];
      final int senderId = senderIdRaw is int
          ? senderIdRaw
          : int.tryParse(senderIdRaw?.toString() ?? '') ?? 0;

      final String message = resultMap['message']?.toString() ?? '';
      final String file = resultMap['file']?.toString() ?? '';
      final String audio = resultMap['audio']?.toString() ?? '';
      final String messageType = resultMap['message_type']?.toString() ?? '';
      final String? status = _normalizeField(resultMap['status']?.toString());
      final String? deliveredAt =
          _normalizeField(resultMap['delivered_at']?.toString());
      final String? readAt = _normalizeField(resultMap['read_at']?.toString());

      final String createdAt = resultMap['created_at']?.toString() ?? '';
      final String updatedAt = resultMap['updated_at']?.toString() ?? createdAt;

      final dynamic itemOfferRaw = resultMap['item_offer_id'];
      final int itemOfferId = itemOfferRaw is int
          ? itemOfferRaw
          : int.tryParse(itemOfferRaw?.toString() ?? '') ?? 0;

      final dynamic idRaw = resultMap['id'];
      final int id =
          idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;

      return ChatMessage(
        key: ValueKey(id),
        id: id,
        message: message,
        senderId: senderId,
        createdAt: createdAt,
        file: file,
        audio: audio,
        itemOfferId: itemOfferId,
        updatedAt: updatedAt,
        messageType: messageType.isEmpty ? null : messageType,
        status: status,
        deliveredAt: deliveredAt,
        readAt: readAt,
      );
    }).toList();

    final dynamic totalRaw = responseData['total'];
    final int total = totalRaw is int
        ? totalRaw
        : int.tryParse(totalRaw?.toString() ?? '') ?? modelList.length;

    return DataOutput(total: total, modelList: modelList);
  }

  Future<Map<String, dynamic>> sendMessageApi(
      {required int itemOfferId,
      required String message,
      MultipartFile? audio,
      MultipartFile? attachment}) async {
    Map<String, dynamic> parameters = {
      "item_offer_id": itemOfferId,
    };

    if (attachment != null) {
      parameters['file'] = attachment;
    }
    if (audio != null) {
      parameters['audio'] = audio;
    }

    if (message != "") {
      parameters['message'] = message;
    }

    // Logger.error(parameters, name: "CHAT PARAMS");
    Map<String, dynamic> map =
        await Api.post(url: Api.sendMessageApi, parameter: parameters);

    return map;
  }

  Future<Map<String, dynamic>> blockUserApi({required int blockUserId}) async {
    Map<String, dynamic> parameters = {
      "blocked_user_id": blockUserId,
    };

    Map<String, dynamic> map =
        await Api.post(url: Api.blockUserApi, parameter: parameters);

    return map;
  }

  Future<Map<String, dynamic>> unBlockUserApi(
      {required int blockUserId}) async {
    Map<String, dynamic> parameters = {
      "blocked_user_id": blockUserId,
    };

    Map<String, dynamic> map =
        await Api.post(url: Api.unBlockUserApi, parameter: parameters);

    return map;
  }

  Future<DataOutput<BlockedUserModel>> blockedUsersListApi() async {
    Map<String, dynamic> response =
        await Api.get(url: Api.blockedUsersListApi, queryParameters: {});

    List<BlockedUserModel> modelList = (response['data'] as List).map(
      (e) {
        return BlockedUserModel.fromJson(e);
      },
    ).toList();

    return DataOutput(modelList: modelList, total: modelList.length);
  }

  Future<ChatedUser?> fetchConversationDetails({
    required String conversationId,
    int? itemOfferId,
  }) async {
    final Map<String, dynamic> queryParameters = <String, dynamic>{};
    if (conversationId.isNotEmpty) {
      queryParameters['conversation_id'] = conversationId;
    }
    if (itemOfferId != null && itemOfferId > 0) {
      queryParameters['item_offer_id'] = itemOfferId;
    }

    if (queryParameters.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi,
        queryParameters: queryParameters,
      );
      final dynamic data = response['data'];
      final dynamic payload = _extractConversationPayload(data);
      if (payload is Map<String, dynamic>) {
        return ChatedUser.fromJson(payload);
      }
      if (payload is List && payload.isNotEmpty) {
        final dynamic first = payload.first;
        if (first is Map<String, dynamic>) {
          return ChatedUser.fromJson(first);
        }
      }
    } catch (_) {}
    return null;
  }

  dynamic _extractConversationPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('conversation')) {
        return data['conversation'];
      }
      if (data.containsKey('data')) {
        return data['data'];
      }
      return data;
    }
    return data;
  }

  Future<void> markMessagesDelivered({
    required String conversationId,
    required Iterable<int> messageIds,
    int? itemOfferId,
  }) async {
    final String trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) {
      return;
    }

    final List<int> sanitizedIds =
        messageIds.where((id) => id > 0).toSet().toList(growable: false);

    if (sanitizedIds.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': trimmedConversationId,
      'message_ids': sanitizedIds,
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.post(
      url: Api.markMessageDeliveredApi,
      parameter: payload,
    );
  }

  Future<void> markMessagesRead({
    required String conversationId,
    required Iterable<int> messageIds,
    int? itemOfferId,
  }) async {
    final String trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) {
      return;
    }

    final List<int> sanitizedIds =
        messageIds.where((id) => id > 0).toSet().toList(growable: false);

    if (sanitizedIds.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': trimmedConversationId,
      'message_ids': sanitizedIds,
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.post(
      url: Api.markMessageReadApi,
      parameter: payload,
    );
  }

  Future<void> updateTypingStatus({
    required String conversationId,
    required bool isTyping,
    int? itemOfferId,
  }) async {
    final String trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'is_typing': isTyping ? 1 : 0,
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.post(
      url: Api.chatConversationTypingApi(trimmedConversationId),
      parameter: payload,
    );
  }

  Future<void> updatePresenceStatus({
    required String conversationId,
    required bool isOnline,
    int? itemOfferId,
  }) async {
    final String trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'status': isOnline ? 'online' : 'offline',
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.post(
      url: Api.chatConversationPresenceApi(trimmedConversationId),
      parameter: payload,
    );
  }
}
