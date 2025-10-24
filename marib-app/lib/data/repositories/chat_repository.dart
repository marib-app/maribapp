import 'package:dio/dio.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:marib/utils/api.dart';
import 'package:flutter/material.dart';
import 'package:marib/data/model/chat/chat_message_modal.dart';
import 'package:marib/utils/chat/conversation_id_utils.dart';

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

    final Map<String, dynamic> response = await Api.get(
      url: Api.getChatListApi,
      queryParameters: {"type": "buyer", "page": page},
    );

    final _ParsedPaginatedMap parsed = _parsePaginatedMap(response['data']);

    final List<ChatedUser> modelList =
        parsed.items.map(ChatedUser.fromJson).toList();

    return DataOutput(
      total: parsed.total,
      modelList: modelList,
      page: parsed.page,
    );
  }

  Future<DataOutput<ChatedUser>> fetchSellerChatList(int page) async {
    final Map<String, dynamic> response = await Api.get(
      url: Api.getChatListApi,
      queryParameters: {"page": page, "type": "seller"},
    );

    final _ParsedPaginatedMap parsed = _parsePaginatedMap(response['data']);

    final List<ChatedUser> modelList =
        parsed.items.map(ChatedUser.fromJson).toList();

    return DataOutput(
      total: parsed.total,
      modelList: modelList,
      page: parsed.page,
    );
  }

  Future<DataOutput<ChatMessageModal>> getMessagesApi(
      {required int page,
      required int itemOfferId,
      required String conversationId}) async {
    final String normalizedConversationId =
        normalizeConversationId(conversationId);

    final Map<String, dynamic> queryParameters = <String, dynamic>{
      'page': page,
      if (itemOfferId > 0) 'item_offer_id': itemOfferId,
      if (normalizedConversationId.isNotEmpty)
        'conversation_id': normalizedConversationId,
    };
    Map<String, dynamic> response = await Api.get(
      url: Api.chatMessagesApi,
      queryParameters: queryParameters,
    );

    final _ParsedPaginatedMap parsed = _parsePaginatedMap(response['data']);

    final List<ChatMessageModal> modelList =
        parsed.items.map((Map<String, dynamic> item) {
      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(item);

      final dynamic senderIdRaw = resultMap['sender_id'];
      final int senderId = senderIdRaw is int
          ? senderIdRaw
          : int.tryParse(senderIdRaw?.toString() ?? '') ?? 0;

      final dynamic receiverIdRaw = resultMap['receiver_id'];
      final int? receiverId = receiverIdRaw == null
          ? null
          : (receiverIdRaw is int
              ? receiverIdRaw
              : int.tryParse(receiverIdRaw.toString()));

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

      final dynamic itemIdRaw = resultMap['item_id'];
      final int? itemId = itemIdRaw == null
          ? null
          : (itemIdRaw is int ? itemIdRaw : int.tryParse(itemIdRaw.toString()));

      final dynamic itemOfferRaw = resultMap['item_offer_id'];
      final int itemOfferId = itemOfferRaw is int
          ? itemOfferRaw
          : int.tryParse(itemOfferRaw?.toString() ?? '') ?? 0;

      final dynamic idRaw = resultMap['id'];
      final int id =
          idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0;

      return ChatMessageModal(
        id: id,
        senderId: senderId,
        receiverId: receiverId,
        message: message,
        file: file,
        audio: audio,
        createdAt: createdAt,
        itemId: itemId,
        itemOfferId: itemOfferId,
        updatedAt: updatedAt,
        messageType: messageType.isEmpty ? null : messageType,
        status: status,
        deliveredAt: deliveredAt,
        readAt: readAt,
      );
    }).toList();

    final int total = parsed.total;
    final int? currentPage = parsed.page ??
        _parseInt(
          response['data'] is Map<String, dynamic>
              ? (response['data'] as Map<String, dynamic>)['current_page']
              : null,
        );

    return DataOutput(
      total: total,
      modelList: modelList,
      page: currentPage ?? page,
    );
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
    final String normalizedConversationId =
        normalizeConversationId(conversationId);
    if (normalizedConversationId.isNotEmpty) {
      queryParameters['conversation_id'] = normalizedConversationId;
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
    final String normalizedConversationId =
        normalizeConversationId(conversationId);
    if (normalizedConversationId.isEmpty) {
      return;
    }

    final List<int> sanitizedIds =
        messageIds.where((id) => id > 0).toSet().toList(growable: false);

    if (sanitizedIds.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': normalizedConversationId,
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
    final String normalizedConversationId =
        normalizeConversationId(conversationId);
    if (normalizedConversationId.isEmpty) {
      return;
    }

    final List<int> sanitizedIds =
        messageIds.where((id) => id > 0).toSet().toList(growable: false);

    if (sanitizedIds.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': normalizedConversationId,
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
    final String normalizedConversationId =
        normalizeConversationId(conversationId);
    if (normalizedConversationId.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'is_typing': isTyping ? 1 : 0,
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.post(
      url: Api.chatConversationTypingApi(normalizedConversationId),
      parameter: payload,
    );
  }

  Future<void> updatePresenceStatus({
    required String conversationId,
    required bool isOnline,
    int? itemOfferId,
  }) async {
    final String normalizedConversationId =
        normalizeConversationId(conversationId);
    if (normalizedConversationId.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'status': isOnline ? 'online' : 'offline',
      if (itemOfferId != null && itemOfferId > 0) 'item_offer_id': itemOfferId,
    };

    await Api.post(
      url: Api.chatConversationPresenceApi(normalizedConversationId),
      parameter: payload,
    );
  }

  _ParsedPaginatedMap _parsePaginatedMap(dynamic payload) {
    if (payload == null) {
      return const _ParsedPaginatedMap(
        items: <Map<String, dynamic>>[],
        total: 0,
      );
    }

    List<Map<String, dynamic>> items = const <Map<String, dynamic>>[];
    int total = 0;
    int? page;

    if (payload is List) {
      items = payload.whereType<Map<String, dynamic>>().toList();
      total = items.length;
    } else if (payload is Map<String, dynamic>) {
      final dynamic candidateItems = payload['items'] ??
          payload['data'] ??
          payload['records'] ??
          payload['results'];
      items = (candidateItems is List ? candidateItems : const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();

      final Map<String, dynamic>? meta = payload['meta'] is Map<String, dynamic>
          ? payload['meta'] as Map<String, dynamic>
          : null;
      final Map<String, dynamic>? pagination =
          payload['pagination'] is Map<String, dynamic>
              ? payload['pagination'] as Map<String, dynamic>
              : null;

      total = _parseInt(payload['total']) ??
          _parseInt(meta?['total']) ??
          _parseInt(pagination?['total']) ??
          items.length;

      page = _parseInt(payload['page']) ??
          _parseInt(meta?['current_page']) ??
          _parseInt(pagination?['current_page']) ??
          _parseInt(payload['current_page']);
    } else {
      return const _ParsedPaginatedMap(
        items: <Map<String, dynamic>>[],
        total: 0,
      );
    }

    return _ParsedPaginatedMap(
      items: items,
      total: total,
      page: page,
    );
  }

  int? _parseInt(dynamic source) {
    if (source == null) {
      return null;
    }

    if (source is int) {
      return source;
    }

    if (source is String) {
      return int.tryParse(source);
    }

    return null;
  }
}

class _ParsedPaginatedMap {
  final List<Map<String, dynamic>> items;
  final int total;
  final int? page;

  const _ParsedPaginatedMap({
    required this.items,
    required this.total,
    this.page,
  });
}
