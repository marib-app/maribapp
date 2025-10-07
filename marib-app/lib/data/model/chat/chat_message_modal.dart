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

  ChatMessageModal(
      {this.id,
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
      this.readAt});

  ChatMessageModal.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    senderId = json['sender_id'];
    receiverId = json['receiver_id'];
    itemId = json['item_id'];
    itemOfferId = json['item_offer_id'];

    message = json['message'];
    file = json['file'];
    audio = json['audio'];
    messageType = json['message_type'];

    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    status = json['status'];
    deliveredAt = json['delivered_at'];
    readAt = json['read_at'];
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

    return data;
  }
}
