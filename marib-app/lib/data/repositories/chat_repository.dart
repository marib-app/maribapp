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
    if (trimmed == null || trimmed.isEmpty ||
        trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }



  Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  List<dynamic>? _extractItemList(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    final dynamic items = data['items'];
    if (items is List) {
      return items;
    }

    final dynamic legacyItems = data['data'];
    if (legacyItems is List) {
      return legacyItems;
    }

    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  int? _extractTotalFromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    const List<String> candidateKeys = <String>[
      'total',
      'total_items',
      'total_count',
      'count',
    ];

    for (final String key in candidateKeys) {
      final int? parsed = _asInt(data[key]);
      if (parsed != null) {
        return parsed;
      }
    }

    final Map<String, dynamic>? nestedPagination =
    _asStringKeyedMap(data['pagination']);
    if (nestedPagination != null && !identical(nestedPagination, data)) {
      final int? nested = _extractTotalFromMap(nestedPagination);
      if (nested != null) {
        return nested;
      }
    }

    return null;
  }

  int _extractTotalWithFallback(
      Map<String, dynamic>? data, Map<String, dynamic>? root, int fallback) {
    final int? dataTotal = _extractTotalFromMap(data);
    if (dataTotal != null) {
      return dataTotal;
    }

    final int? rootTotal = _extractTotalFromMap(root);
    if (rootTotal != null) {
      return rootTotal;
    }

    return fallback;
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

    final Map<String, dynamic> responseMap =
        _asStringKeyedMap(response) ?? <String, dynamic>{};
    final Map<String, dynamic> dataMap =
        _asStringKeyedMap(responseMap['data']) ?? <String, dynamic>{};

    final List<dynamic> rawItems =
        _extractItemList(dataMap) ?? <dynamic>[];




    final List<ChatedUser> modelList = rawItems
        .map(_asStringKeyedMap)
        .whereType<Map<String, dynamic>>()
        .map(ChatedUser.fromJson)
        .toList();

    final int total =
    _extractTotalWithFallback(dataMap, responseMap, modelList.length);

    return DataOutput(total: total, modelList: modelList);

  }

  Future<DataOutput<ChatedUser>> fetchSellerChatList(int page) async {
    Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi,
        queryParameters: {"page": page, "type": "seller"});

    final Map<String, dynamic> responseMap =
        _asStringKeyedMap(response) ?? <String, dynamic>{};
    final Map<String, dynamic> dataMap =
        _asStringKeyedMap(responseMap['data']) ?? <String, dynamic>{};

    final List<dynamic> rawItems =
        _extractItemList(dataMap) ?? <dynamic>[];

    final List<ChatedUser> modelList = rawItems
        .map(_asStringKeyedMap)
        .whereType<Map<String, dynamic>>()
        .map(ChatedUser.fromJson)
        .toList();

    final int total =
    _extractTotalWithFallback(dataMap, responseMap, modelList.length);

    return DataOutput(total: total, modelList: modelList);
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


    final Map<String, dynamic> responseMap =
        _asStringKeyedMap(response) ?? <String, dynamic>{};

    final Map<String, dynamic> responseData =
        _asStringKeyedMap(responseMap['data']) ?? <String, dynamic>{};

    final List<dynamic> resultList =
        _extractItemList(responseData) ?? <dynamic>[];

    final List<ChatMessage> modelList = <ChatMessage>[];

    for (final dynamic result in resultList) {
      final Map<String, dynamic>? resultMap = _asStringKeyedMap(result);
      if (resultMap == null || resultMap.isEmpty) {
        continue;
      }

      final dynamic senderIdRaw = resultMap['sender_id'];
      final int senderId = senderIdRaw is int
          ? senderIdRaw
          : int.tryParse(senderIdRaw?.toString() ?? '') ?? 0;

      final String message = resultMap['message']?.toString() ?? '';
      final String file = resultMap['file']?.toString() ?? '';
      final String audio = resultMap['audio']?.toString() ?? '';
      final String messageType = resultMap['message_type']?.toString() ?? '';
      final String? status =
      _normalizeField(resultMap['status']?.toString());
      final String? deliveredAt =
      _normalizeField(resultMap['delivered_at']?.toString());
      final String? readAt =
      _normalizeField(resultMap['read_at']?.toString());


      final String createdAt = resultMap['created_at']?.toString() ?? '';
      final String updatedAt = resultMap['updated_at']?.toString() ?? createdAt;

      final dynamic itemOfferRaw = resultMap['item_offer_id'];
      final int itemOfferId = itemOfferRaw is int
          ? itemOfferRaw
          : int.tryParse(itemOfferRaw?.toString() ?? '') ?? 0;

      final dynamic idRaw = resultMap['id'];
      final int id = idRaw is int
          ? idRaw
          : int.tryParse(idRaw?.toString() ?? '') ?? 0;

      modelList.add(ChatMessage(
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
      ));
    }

    final int total = _extractTotalWithFallback(
      responseData,
      responseMap,
      modelList.length,
    );

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

    final List<int> sanitizedIds = messageIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);

    if (sanitizedIds.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': trimmedConversationId,
      'message_ids': sanitizedIds,
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.postJson(
      url: Api.markMessageDeliveredApi,
      data: payload,
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

    final List<int> sanitizedIds = messageIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);

    if (sanitizedIds.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': trimmedConversationId,
      'message_ids': sanitizedIds,
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.postJson(
      url: Api.markMessageReadApi,
      data: payload,
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
