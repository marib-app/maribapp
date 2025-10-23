//import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/data/model/seller_ratings_model.dart';

class ChatedUser {
  int? id;
  int? sellerId;
  int? buyerId;
  int? itemId;
  int? itemOfferId;
  String? conversationId;
  String? createdAt;
  String? updatedAt;
  double? amount;
  Seller? seller;
  Buyer? buyer;
  Item? item;
  bool? userBlocked;
  List<ChatParticipant>? participants;
  int? unreadMessagesCount;
  ChatLastMessage? lastMessage;


  ChatedUser(
      {this.id,
      this.sellerId,
      this.buyerId,
      this.itemId,
        this.itemOfferId,
        this.conversationId,
      this.createdAt,
      this.updatedAt,
      this.amount,
      this.seller,
      this.buyer,
      this.userBlocked,
        this.item,
        this.participants,
        this.unreadMessagesCount,
        this.lastMessage});


  static bool? parseUserBlocked(dynamic value) {
    return _parseBool(value);
  }


  ChatedUser.fromJson(Map<String, dynamic> json /*, {BuildContext? context}*/) {
    id = _parseInt(json['id']);
    sellerId = _parseInt(json['seller_id']);
    buyerId = _parseInt(json['buyer_id']);
    itemId = _parseInt(json['item_id']);
    itemOfferId = _parseInt(json['item_offer_id']) ?? _parseInt(json['id']);
    conversationId =
        _parseString(json['conversation_id']) ?? id?.toString();

    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    amount = _parseDouble(json['amount']);
    userBlocked = _parseBool(json['user_blocked']);
    unreadMessagesCount =
        _parseInt(json['unread_messages_count']) ?? _parseInt(json['unread']);
    seller = json['seller'] != null ? Seller.fromJson(json['seller']) : null;
    buyer = json['buyer'] != null ? Buyer.fromJson(json['buyer']) : null;
    item = json['item'] != null ? Item.fromJson(json['item']) : null;
    if (json['participants'] is List) {
      participants = (json['participants'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ChatParticipant.fromJson)
          .toList();
    }
    final dynamic lastMessageJson = json['last_message'];
    if (lastMessageJson is Map<String, dynamic>) {
      lastMessage = ChatLastMessage.fromJson(lastMessageJson);
    } else if (lastMessageJson is List && lastMessageJson.isNotEmpty) {
      final first = lastMessageJson.first;
      if (first is Map<String, dynamic>) {
        lastMessage = ChatLastMessage.fromJson(first);
      }
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['id'] = id;
    data['seller_id'] = sellerId;
    data['buyer_id'] = buyerId;
    data['item_id'] = itemId;
    data['item_offer_id'] = itemOfferId;
    data['conversation_id'] = conversationId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['amount'] = amount;
    data['user_blocked'] = userBlocked;
    if (seller != null) {
      data['seller'] = seller!.toJson();
    }
    if (buyer != null) {
      data['buyer'] = this.buyer!.toJson();
    }
    if (item != null) {
      data['item'] = item!.toJson();
    }
    if (participants != null) {
      data['participants'] = participants!.map((e) => e.toJson()).toList();
    }
    if (unreadMessagesCount != null) {
      data['unread_messages_count'] = unreadMessagesCount;
    }
    if (lastMessage != null) {
      data['last_message'] = lastMessage!.toJson();
    }
    return data;
  }
}


int? _parseInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String && value.isNotEmpty) {
    return int.tryParse(value);
  }
  return null;
}


double? _parseDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}

String? _parseString(dynamic value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.toLowerCase() == 'null') {
    return null;
  }
  return trimmed;
}


bool? _parseBool(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') {
      return true;
    }
    if (lower == 'false' || lower == '0') {
      return false;
    }
  }
  return null;
}



class ChatLastMessage {
  final int? id;
  final int? senderId;
  final String? message;
  final String? file;
  final String? audio;
  final String? messageType;
  final String? status;
  final String? deliveredAt;
  final String? readAt;
  final String? createdAt;

  ChatLastMessage({
    this.id,
    this.senderId,
    this.message,
    this.file,
    this.audio,
    this.messageType,
    this.status,
    this.deliveredAt,
    this.readAt,
    this.createdAt,
  });

  factory ChatLastMessage.fromJson(Map<String, dynamic> json) {
    return ChatLastMessage(
      id: _parseInt(json['id']),
      senderId: _parseInt(json['sender_id']),
      message: json['message']?.toString(),
      file: json['file']?.toString(),
      audio: json['audio']?.toString(),
      messageType: json['message_type']?.toString(),
      status: json['status']?.toString(),
      deliveredAt: json['delivered_at']?.toString(),
      readAt: json['read_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    if (senderId != null) data['sender_id'] = senderId;
    if (message != null) data['message'] = message;
    if (file != null) data['file'] = file;
    if (audio != null) data['audio'] = audio;
    if (messageType != null) data['message_type'] = messageType;
    if (status != null) data['status'] = status;
    if (deliveredAt != null) data['delivered_at'] = deliveredAt;
    if (readAt != null) data['read_at'] = readAt;
    if (createdAt != null) data['created_at'] = createdAt;
    return data;
  }
}




class Seller {
  int? id;
  String? name;
  String? profile;

  Seller({this.id, this.name, this.profile});

  Seller.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    name = json['name'];
    profile = json['profile'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['profile'] = this.profile;
    return data;
  }
}

class Buyer {
  int? id;
  String? name;
  String? profile;

  Buyer({this.id, this.name, this.profile});

  Buyer.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    name = json['name'];
    profile = json['profile'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['profile'] = this.profile;
    return data;
  }
}

class Item {
  int? id;
  String? name;
  String? description;
  double? price;
  String? image;
  String? status;
  int? isPurchased;
  UserRatings? review;
  List<UserRatings>? reviews;
  String? currency;
  String? currencySymbol;


  Item(
      {this.id,
      this.name,
      this.description,
      this.price,
      this.image,
      this.status,
      this.review,
        this.reviews,
        this.isPurchased,
        this.currency,
        this.currencySymbol});

  Item.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    name = json['name'];
    description = json['description'];
    /* if (json['price'] is int) {
      price = (json['price'] as int).toDouble();
    } else if (json['price'] is double) {
      price = json['price'];
    }*/
    price = _parseDouble(json['price']);
    image = json['image'];
    status = json['status'];
    status = json['status'];
    isPurchased = _parseInt(json['is_purchased']);
    currency = _parseString(json['currency']) ??
        _parseString(json['currency_code']) ??
        _parseString(json['currencyCode']) ??
    _parseString(json['currency_label']) ??
        _parseString(json['currencyLabel']);


    currencySymbol = _parseString(json['currency_symbol']) ??
        _parseString(json['currencySymbol']) ??
    _parseString(json['currency_label']) ??
        _parseString(json['currencyLabel']) ??
        currency;



    final reviewJson = json['review'];
    if (reviewJson is List) {
      reviews = reviewJson
          .whereType<Map<String, dynamic>>()
          .map(UserRatings.fromJson)
          .toList();
      review = null;
    } else if (reviewJson is Map<String, dynamic>) {
      review = UserRatings.fromJson(reviewJson);
      reviews = null;
    } else {
      review = null;
      reviews = null;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['description'] = this.description;
    data['price'] = this.price;
    data['image'] = this.image;
    data['status'] = this.status;
    data['is_purchased'] = this.isPurchased;
    if ((currency ?? '').isNotEmpty) {
      data['currency'] = currency;
    }
    if ((currencySymbol ?? '').isNotEmpty) {
      data['currency_symbol'] = currencySymbol;
    }
    if (reviews != null) {
      data['review'] = reviews!.map((e) => e.toJson()).toList();
    } else if (review != null) {
      data['review'] = review!.toJson();
    }

    return data;
  }
}

class BlockedUserModel {
  int? id;
  String? name;
  String? profile;

  BlockedUserModel({this.id, this.name, this.profile});

  BlockedUserModel.fromJson(Map<String, dynamic> json) {
    id = _parseInt(json['id']);
    name = json['name'];
    profile = json['profile'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['profile'] = this.profile;
    return data;
  }
}


class ChatParticipant {
  int? userId;
  String? role;
  String? name;
  String? profile;
  ParticipantStatus? status;
  Map<String, dynamic>? additionalData;

  ChatParticipant({
    this.userId,
    this.role,
    this.name,
    this.profile,
    this.status,
    this.additionalData,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    return ChatParticipant(
      userId: _parseInt(map['user_id'] ?? map['id']),
      role: map['role']?.toString() ?? map['type']?.toString(),
      name: map['name']?.toString() ?? map['user_name']?.toString(),
      profile: map['profile']?.toString() ?? map['user_profile']?.toString(),
      status: map.containsKey('status')
          ? ParticipantStatus.fromJson(map['status'])
          : null,
      additionalData: map,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data =
    additionalData != null ? Map<String, dynamic>.from(additionalData!) : {};

    if (userId != null) {
      data['user_id'] = userId;
    }
    if (role != null) {
      data['role'] = role;
    }
    if (name != null) {
      data['name'] = name;
    }
    if (profile != null) {
      data['profile'] = profile;
    }
    if (status != null) {
      data['status'] = status!.toJson();
    }
    return data;
  }
}

class ParticipantStatus {
  final bool? isOnline;
  final bool? isTyping;
  final bool? isBlocked;
  final String? lastSeen;
  final Map<String, dynamic>? raw;

  const ParticipantStatus({
    this.isOnline,
    this.isTyping,
    this.isBlocked,
    this.lastSeen,
    this.raw,
  });

  factory ParticipantStatus.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return ParticipantStatus(
        isOnline: _parseBool(json['is_online']),
        isTyping: _parseBool(json['is_typing']),
        isBlocked: _parseBool(json['is_blocked']),
        lastSeen: json['last_seen']?.toString(),
        raw: Map<String, dynamic>.from(json),
      );
    }
    if (json != null) {
      return ParticipantStatus(raw: {'value': json});
    }
    return const ParticipantStatus();
  }

  Map<String, dynamic> toJson() {
    if (raw != null) {
      return Map<String, dynamic>.from(raw!);
    }
    final Map<String, dynamic> data = <String, dynamic>{};
    if (isOnline != null) {
      data['is_online'] = isOnline;
    }
    if (isTyping != null) {
      data['is_typing'] = isTyping;
    }
    if (isBlocked != null) {
      data['is_blocked'] = isBlocked;
    }
    if (lastSeen != null) {
      data['last_seen'] = lastSeen;
    }
    return data;
  }
}