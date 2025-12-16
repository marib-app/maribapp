import 'package:cached_network_image/cached_network_image.dart';
import 'package:marib/data/cubits/chat/delete_message_cubit.dart';
import 'package:marib/data/cubits/chat/load_chat_messages.dart';
import 'package:marib/ui/screens/chat_v2/chat_screen_v2.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';

import 'package:marib/utils/helper_utils.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';

part 'chatTile_ui.dart';





class ChatTile extends StatelessWidget {
  final String profilePicture;
  final String userName;
  final String itemPicture;
  final String itemName;
  final String itemId;
  final int unreadCount;
  final ChatLastMessage? lastMessage;
  final String id;
  final String date;
  final int itemOfferId;
  final String conversationId;

  final double itemPrice;
  final double? itemAmount;
  final String? status;
  final String? buyerId;
  final int isPurchased;
  final bool alreadyReview;
  final List<ChatParticipant>? participants;
  final String? itemCurrency;
  final String? itemCurrencySymbol;

  static final Map<String, ParticipantStatus?> _lastKnownPresence = {};

  static ParticipantStatus? getLastPresence(String userId) {
    return _lastKnownPresence[userId];
  }

  static void setLastPresence(String userId, ParticipantStatus? status) {
    if (userId.isEmpty) return;
    _lastKnownPresence[userId] = status;
  }


  const ChatTile({
    super.key,
    required this.profilePicture,
    required this.userName,
    required this.itemPicture,
    required this.itemName,
    required this.unreadCount,
    this.lastMessage,

    required this.id,
    required this.date,
    required this.itemId,
    required this.itemOfferId,
    required this.conversationId,

    required this.itemPrice,
    this.status,
    this.itemAmount,
    this.buyerId,
    required this.isPurchased,
    required this.alreadyReview,
    this.participants,
    this.itemCurrency,
    this.itemCurrencySymbol,
  });

  @override
  Widget build(BuildContext context) => buildChatTile(context);

}
