class ChatMessageModal {
  int? id;
  int? senderId;
  int? receiverId;
  int? itemId;
  int? itemOfferId;
  String? message;
  String? file;
  String? audio;
  String? messageType;

  String? createdAt;
  String? updatedAt;
  String? status;
  String? deliveredAt;
  String? readAt;
  String? localId;
  bool isSentNow;

  ChatMessageModal({
    this.id,
    this.senderId,
    this.receiverId,
    this.itemId,
    this.itemOfferId,
    this.message,
    this.file,
    this.audio,
    this.messageType,
    this.createdAt,
    this.updatedAt,
    this.status,
    this.deliveredAt,
    this.readAt,
    this.localId,
    bool? isSentNow,
  }) : isSentNow = isSentNow ?? false;

  ChatMessageModal.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        senderId = json['sender_id'],
        receiverId = json['receiver_id'],
        itemId = json['item_id'],
        itemOfferId = json['item_offer_id'],
        message = json['message'],
        file = json['file'],
        audio = json['audio'],
        messageType = json['message_type'],
        createdAt = json['created_at'],
        updatedAt = json['updated_at'],
        status = json['status'],
        deliveredAt = json['delivered_at'],
        readAt = json['read_at'],
        localId = json['local_id'],
        isSentNow = json['is_sent_now'] == true;

  ChatMessageModal copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    int? itemId,
    int? itemOfferId,
    String? message,
    String? file,
    String? audio,
    String? messageType,
    String? createdAt,
    String? updatedAt,
    String? status,
    String? deliveredAt,
    String? readAt,
    String? localId,
    bool? isSentNow,
  }) {
    return ChatMessageModal(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      itemId: itemId ?? this.itemId,
      itemOfferId: itemOfferId ?? this.itemOfferId,
      message: message ?? this.message,
      file: file ?? this.file,
      audio: audio ?? this.audio,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      localId: localId ?? this.localId,
      isSentNow: isSentNow ?? this.isSentNow,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['sender_id'] = senderId;
    data['receiver_id'] = receiverId;
    data['item_id'] = itemId;
    data['item_offer_id'] = itemOfferId;

    data['message'] = message;
    data['file'] = file;
    data['audio'] = audio;
    data['message_type'] = messageType;

    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['status'] = status;
    data['delivered_at'] = deliveredAt;
    data['read_at'] = readAt;
    data['local_id'] = localId;
    data['is_sent_now'] = isSentNow;
    return data;
  }
}
