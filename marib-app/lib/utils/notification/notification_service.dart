// ignore_for_file: file_names

import 'dart:async';
import 'dart:developer';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/chat/chat_message_modal.dart';
import 'package:marib/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/awsomeNotification.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:marib/ui/screens/chat/chat_screen.dart';
import 'package:marib/ui/screens/chat/chat_badge_controller.dart';

import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:marib/data/cubits/chat/get_seller_chat_users_cubit.dart';
import 'dart:io';

import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_transactions_cubit.dart';

import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/cubits/chat/load_chat_messages.dart';
import 'package:marib/data/cubits/chat/send_message.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/utils/api.dart';
import 'dart:io';
import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_transfers_cubit.dart';
import 'package:marib/data/cubits/wallet/wallet_withdrawals_cubit.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/notification/chat_message_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';

enum UserPresenceEventType { userTyping, userPresenceUpdated }

class ChatMessageStatusUpdate {
  final int messageId;
  final String? status;
  final String? deliveredAt;
  final String? readAt;

  const ChatMessageStatusUpdate({
    required this.messageId,
    this.status,
    this.deliveredAt,
    this.readAt,
  });
}



class UserPresenceEvent {
  final UserPresenceEventType type;
  final ParticipantStatus status;

  const UserPresenceEvent({
    required this.type,
    required this.status,
  });
}

String currentlyChatingWith = "";
String currentlyChatItemId = "";

class NotificationService {
  static const String _pendingFcmTokenKey = '_pending_fcm_token';

  static FirebaseMessaging messagingInstance = FirebaseMessaging.instance;

  static LocalAwsomeNotification localNotification = LocalAwsomeNotification();

  static final ValueNotifier<ParticipantStatus?> participantStatusNotifier =
      ChatMessageHandler.participantStatusNotifier;

  static final ValueNotifier<UserPresenceEvent?> userPresenceEventNotifier =
  ValueNotifier<UserPresenceEvent?>(null);


  static final StreamController<ParticipantStatus?>
  _participantStatusController =
  StreamController<ParticipantStatus?>.broadcast();

  static final StreamController<UserPresenceEvent>
  _userPresenceEventController =
  StreamController<UserPresenceEvent>.broadcast();


  static final StreamController<ChatMessageStatusUpdate>
  _messageStatusController =
  StreamController<ChatMessageStatusUpdate>.broadcast();


  static Stream<ParticipantStatus?> get participantStatusStream =>
      _participantStatusController.stream;

  static Stream<ChatMessageStatusUpdate> get messageStatusStream =>
      _messageStatusController.stream;


  static Stream<UserPresenceEvent> get userPresenceEvents =>
      _userPresenceEventController.stream;


  static final Map<String, List<ChatParticipant>>
  _conversationParticipantsCache =
  <String, List<ChatParticipant>>{};


  static late StreamSubscription<RemoteMessage> foregroundStream;
  static late StreamSubscription<RemoteMessage> onMessageOpen;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static final StreamController<String> _walletNotificationController =
  StreamController<String>.broadcast();

  static Stream<String> get walletNotifications =>
      _walletNotificationController.stream;


  static requestPermission() async {}

/*  static int? getPrice(dynamic price) {
    if (price == null || price.toString().trim().isEmpty) {
      return null;
    }
    if (price is double) {
      return price.toInt();
    }
    if (price is String) {
      return int.parse(price);
    }
    return price;
  }*/

  static double? getPrice(dynamic price) {
    if (price == null || price
        .toString()
        .isEmpty) {
      return null;
    }
    if (price is String) {
      return double.tryParse(price);
    }
    if (price is int) {
      return price.toDouble();
    }
    if (price is double) {
      return price;
    }
    return null; // In case of unexpected types
  }


  static int? _tryParseInt(dynamic value) {
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

  static String? _normalizeNotificationValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.toString().trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }

  static String? _pickFirstString(
      Map<String, dynamic> source, List<String> candidateKeys) {
    for (final key in candidateKeys) {
      if (!source.containsKey(key)) {
        continue;
      }
      final String? normalized = _normalizeNotificationValue(source[key]);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  static String? extractCurrency(Map<String, dynamic> source) {
    const List<String> keys = <String>[
      'currency',
      'currency_code',
      'currencyCode',
      'currency_label',
      'currencyLabel',
      'currency_text',
      'currencyText',
    ];
    return _pickFirstString(source, keys);
  }

  static String? extractCurrencySymbol(Map<String, dynamic> source) {
    const List<String> symbolKeys = <String>[
      'currency_symbol',
      'currencySymbol',
      'currency_sign',
      'currencySign',
      'currency_label',
      'currencyLabel',
    ];
    return _pickFirstString(source, symbolKeys) ?? extractCurrency(source);
  }


  /* void updateFCM() async {
    await FirebaseMessaging.instance.getToken();
    // await Api.post(
    //     // url: Api.updateFCMId,
    //     parameter: {Api.fcmId: token},
    //     useAuthToken: true);
  }*/

  static Future<void> handleNotification(RemoteMessage? message,
      [BuildContext? context]) async {
    final String rawNotificationType =
        _normalizeNotificationValue(message?.data['notification_type']) ??
            _normalizeNotificationValue(message?.data['type']) ??
            '';

    final String rawEventType =
        _normalizeNotificationValue(message?.data['event']) ?? '';
    final String rawActionType =
        _normalizeNotificationValue(message?.data['action']) ?? '';

    final String normalizedNotificationType =
    rawNotificationType.toLowerCase();
    final String normalizedEventType = rawEventType.toLowerCase();
    final String normalizedActionType = rawActionType.toLowerCase();
    const Set<String> presenceEvents = {'UserTyping', 'UserPresenceUpdated'};
    const Set<String> messageStatusEvents = {
      'MessageDelivered',
      'MessageRead',
      'message_delivered',
      'message_read',
      'messagedelivered',
      'messageread',
    };


    final Set<String> normalizedPresenceEvents =
    presenceEvents.map((event) => event.toLowerCase()).toSet();
    final Set<String> normalizedMessageStatusEvents =
    messageStatusEvents.map((event) => event.toLowerCase()).toSet();

    final bool isPresenceEvent =
        normalizedPresenceEvents.contains(normalizedNotificationType) ||
            normalizedPresenceEvents.contains(normalizedEventType) ||
            normalizedPresenceEvents.contains(normalizedActionType);
    final bool isMessageStatusEvent =
        normalizedMessageStatusEvents.contains(normalizedNotificationType) ||
            normalizedMessageStatusEvents.contains(normalizedEventType) ||
            normalizedMessageStatusEvents.contains(normalizedActionType);


    print("@notificaiton data is ${message?.data}****$rawNotificationType");


    if (isPresenceEvent) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        message?.data ?? const <String, dynamic>{},
      );
      _handlePresenceNotification(data);
      return;
    }

    if (isMessageStatusEvent) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        message?.data ?? const <String, dynamic>{},
      );
      _handleMessageStatusNotification(data);
      return;
    }

    if (normalizedNotificationType == 'wallet') {
      final ctx = context ?? Constant.navigatorKey.currentContext;
      final summaryCubit = ctx != null
          ? _maybeReadCubit<WalletSummaryCubit>(ctx)
          : null;
      final transactionsCubit = ctx != null
          ? _maybeReadCubit<WalletTransactionsCubit>(ctx)
          : null;

      final withdrawalsCubit = ctx != null
          ? _maybeReadCubit<WalletWithdrawalsCubit>(ctx)
          : null;
      final manualPaymentsCubit = ctx != null
          ? _maybeReadCubit<ManualPaymentRequestsCubit>(ctx)
          : null;
      final transfersCubit = ctx != null
          ? _maybeReadCubit<WalletTransfersCubit>(ctx)
          : null;


      final idempotencyKey = message?.data['idempotency_key']?.toString();
      final deeplink = message?.data['deeplink']?.toString();

      final List<Future<void>> futures = [];
      if (summaryCubit != null) {
        futures.add(summaryCubit.refresh());
      }

      Future<void>? transactionsFuture;


      if (transactionsCubit != null) {
        transactionsFuture = transactionsCubit.refresh();
        futures.add(transactionsFuture);
      }

      if (withdrawalsCubit != null) {
        futures.add(withdrawalsCubit.refresh(includeOptions: false));
      }

      if (manualPaymentsCubit != null) {
        futures.add(manualPaymentsCubit.refresh());
      }

      transfersCubit?.refresh();

      if (futures.isNotEmpty) {
        try {
          await Future.wait(futures);
        } catch (_) {}
      }

      if (transactionsFuture != null && idempotencyKey != null) {
        try {
          transactionsCubit?.markTransactionNotified(
            idempotencyKey,
            deeplink: deeplink,
          );
        } catch (_) {}
      }

      _walletNotificationController.add(idempotencyKey ?? '');

      if (message != null) {
        localNotification.createNotification(
          isLocked: false,
          notificationData: message,
        );
      }
      return;
    }


    if (normalizedNotificationType == "chat") {
      var username = message?.data['user_name'];
      var itemImage = message?.data['item_image'];
      var itemName = message?.data['item_name'];
      var userProfile = message?.data['user_profile'];
      var senderId = message?.data['user_id'];
      var itemId = message?.data['item_id'];
      var date = message?.data['created_at'];
      var itemOfferId = message?.data['item_offer_id'];
      var itemPrice = message?.data['item_price'];
      var itemOfferPrice = message?.data['item_offer_amount'];
      var userType = message?.data['user_type'];
      var conversationId = message?.data['conversation_id'];

      final int? senderIdInt = _tryParseInt(senderId);
      final int? itemIdInt = _tryParseInt(itemId);
      final int? itemOfferIdInt = _tryParseInt(itemOfferId);
      final String conversationIdStr = conversationId?.toString() ?? '';

      if (userType == "Buyer") {
        (context as BuildContext)
            .read<GetSellerChatListCubit>()
            .addNewChat(ChatedUser(
          itemId: itemIdInt,
          itemOfferId: itemOfferIdInt,
          conversationId: conversationIdStr.isEmpty
              ? null
              : conversationIdStr,

          amount: getPrice(itemOfferPrice),
          createdAt: date,
          userBlocked: false,
          id: itemOfferIdInt,
          /* sellerId: senderId,*/
          updatedAt: date,
          item: Item(
              id: itemIdInt,
              price: getPrice((itemPrice)),
              name: itemName,
              image: itemImage),
          /*seller: Seller(name: username, profile: userProfile),*/
          buyerId: senderIdInt,
          buyer: Buyer(
              name: username,
              profile: userProfile,
              id: senderIdInt),
        ));
      } else {
        final int? currentUserId = _tryParseInt(HiveUtils.getUserId());

        (context as BuildContext)
            .read<GetBuyerChatListCubit>()
            .addNewChat(ChatedUser(
          itemId: itemIdInt,
          userBlocked: false,
          amount: getPrice(itemOfferPrice),
          createdAt: date,
          id: itemOfferIdInt,
          itemOfferId: itemOfferIdInt,
          conversationId: conversationIdStr.isEmpty
              ? null
              : conversationIdStr,
          sellerId: currentUserId,
          buyerId: senderIdInt,
          updatedAt: date,
          item: Item(
              id: itemIdInt,
              price: getPrice((itemPrice)),
              name: itemName,
              image: itemImage),
          buyer: Buyer(
              name: username,
              profile: userProfile,
              id: senderIdInt),
        ));
      }

      ///Checking if this is user we are chatiing with

      final String itemOfferIdStr = itemOfferIdInt?.toString() ?? '';
      final Map<String, dynamic> chatData =
      Map<String, dynamic>.from(message?.data ?? const {});

      if (!chatData.containsKey('message_type') &&
          chatData.containsKey('msg_type')) {
        chatData['message_type'] = chatData['msg_type'];
      }

      _cacheParticipantsFromData(chatData);
      final String? chatMessageType =
          _normalizeNotificationValue(message?.data['chat_message_type']) ??
              _normalizeNotificationValue(message?.data['msg_type']) ??
              _normalizeNotificationValue(message?.data['message_type']) ??
              _normalizeNotificationValue(message?.data['message_type_temp']);
      final bool isConversationMatch = conversationIdStr.isNotEmpty
          ? (conversationIdStr == currentlyChatingWith &&
          itemOfferIdStr == currentlyChatItemId)
          : (senderId?.toString() == currentlyChatingWith &&
          itemId?.toString() == currentlyChatItemId);

      if (isConversationMatch) {
        final ParticipantStatus? participantStatus =
        _parseParticipantStatusFromData(chatData);
        if (participantStatus != null) {
          _notifyParticipantStatus(participantStatus);
        }

        final int? messageId = _tryParseInt(message?.data['id']);
        final int? messageItemId = _tryParseInt(message?.data['item_id']);
        final int? senderIdParsed = _tryParseInt(message?.data['sender_id']);
        final int? receiverIdParsed = _tryParseInt(HiveUtils.getUserId());

        final String? status =
        _normalizeNotificationValue(message?.data['status']);
        final String? deliveredAt =
        _normalizeNotificationValue(message?.data['delivered_at']);
        final String? readAt =
        _normalizeNotificationValue(message?.data['read_at']);



        ChatMessageModal chatMessageModel = ChatMessageModal(
            id: messageId,

            updatedAt: message?.data['updated_at'],
            createdAt: message?.data['created_at'],
            itemId: messageItemId,
            itemOfferId: itemOfferIdInt,

            audio: message?.data['audio'],
            file: message?.data['file'],
            message: message?.data['message'],
            status: status,
            deliveredAt: deliveredAt,
            readAt: readAt,
            messageType: chatMessageType,

            receiverId: receiverIdParsed,
            senderId: senderIdParsed);

        ChatMessageHandler.add(BlocProvider(
          create: (context) => SendMessageCubit(),
          child: ChatMessage(
            key: ValueKey(DateTime.now().toString().toString()),
            message: chatMessageModel.message,
            senderId: chatMessageModel.senderId!,
            createdAt: chatMessageModel.createdAt!,
            isSentNow: false,
            updatedAt: chatMessageModel.updatedAt!,
            audio: chatMessageModel.audio,
            file: chatMessageModel.file,
            itemOfferId: chatMessageModel.itemOfferId ?? itemOfferIdInt ?? 0,
            status: chatMessageModel.status,
            deliveredAt: chatMessageModel.deliveredAt,
            readAt: chatMessageModel.readAt,
            messageType: chatMessageModel.messageType,

          ),
        ));

        totalMessageCount++;
      } else {
        localNotification.createNotification(
          isLocked: false,
          notificationData: message!,
        );

        final BuildContext? ctx = context as BuildContext?;
        final String fallbackConversationId = conversationIdStr.isNotEmpty
            ? conversationIdStr
            : itemOfferIdStr;
        if (ctx != null) {
          try {
            ctx.read<GetBuyerChatListCubit>()
                .incrementUnread(fallbackConversationId);
          } catch (_) {}
          try {
            ctx.read<GetSellerChatListCubit>()
                .incrementUnread(fallbackConversationId);
          } catch (_) {}
        } else {
          ChatBadgeController.incrementTempUnread();
        }
      }
    } else {
      localNotification.createNotification(
        isLocked: false,
        notificationData: message!,
      );
    }
  }

  static void handleRealtimePresenceEvent(Map<String, dynamic> data) {
    _handlePresenceNotification(Map<String, dynamic>.from(data));
  }

  static void handleRealtimeMessageStatusEvent(Map<String, dynamic> data) {
    _handleMessageStatusNotification(Map<String, dynamic>.from(data));
  }

  static Future<void> init(BuildContext context) async {
    requestPermission();
    await _ensureInitialTokenSynced();
    await registerListeners(context);
    _registerTokenRefreshListener();
  }

  @pragma('vm:entry-point')
  static Future<void> onBackgroundMessageHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    await handleNotification(message);
  }

  static forgroundNotificationHandler(BuildContext context) async {
    foregroundStream =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print("foreground notification***${message.toString()}");
          handleNotification(message, context);
        });
  }

  static terminatedStateNotificationHandler(BuildContext context) {
    FirebaseMessaging.instance.getInitialMessage().then(
          (RemoteMessage? message) {
        if (message == null) {
          return;
        }
        if (message.notification == null) {
          handleNotification(message, context);
        }
      },
    );
  }

  static void onTapNotificationHandler(context) {
    onMessageOpen = FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage message) async {
      print("message.data on tap***${message.data.toString()}");
      if (message.data['type'] == "chat") {
        var username = message.data['user_name'];
        var itemTitleImage = message.data['item_title_image'];
        var itemTitle = message.data['item_title'];
        var userProfile = message.data['user_profile'];
        var senderId = message.data['sender_id'];
        var itemId = message.data['item_id'];
        var date = message.data['created_at'];
        var itemOfferId = message.data['item_offer_id'];
        var conversationId = message.data['conversation_id'];

        var itemPrice = message.data['item_price'];
        var itemOfferPrice = message.data['item_offer_amount'] ?? null;
        final int itemOfferIdParsed =
            _tryParseInt(itemOfferId) ?? 0;
        Future.delayed(
          Duration.zero,
              () {
            Navigator.push(Constant.navigatorKey.currentContext!,
                MaterialPageRoute(
                  builder: (context) {
                    return MultiBlocProvider(
                      providers: [
                        BlocProvider(
                          create: (context) => SendMessageCubit(),
                        ),
                        BlocProvider(
                          create: (context) => LoadChatMessagesCubit(),
                        ),
                      ],
                      child: Builder(builder: (context) {
                        final Map<String, dynamic> normalizedData =
                        Map<String, dynamic>.from(message.data);
                        final List<ChatParticipant>? participants =
                            NotificationService.getCachedParticipants(
                              (conversationId ?? '').toString(),
                              itemOfferId: itemOfferIdParsed,
                            ) ??
                                NotificationService
                                    .buildParticipantsFromNotification(
                                  data: normalizedData,

                                );
                        if (participants != null && participants.isNotEmpty) {
                          NotificationService.cacheParticipants(
                            participants: participants,
                            conversationId: (conversationId ?? '').toString(),
                            itemOfferId:
                            itemOfferIdParsed > 0 ? itemOfferIdParsed : null,
                            senderId: senderId?.toString(),
                            itemId: itemId?.toString(),
                          );
                        }

                        final String? currency =
                        NotificationService.extractCurrency(normalizedData);
                        final String? currencySymbol =
                        NotificationService.extractCurrencySymbol(
                            normalizedData);

                        return ChatScreen(
                          profilePicture: userProfile ?? "",
                          userName: username ?? "",
                          itemImage: itemTitleImage ?? "",
                          itemTitle: itemTitle ?? "",
                          userId: senderId ?? "",
                          itemId: itemId ?? "",
                          date: date ?? "",
                          itemOfferId: itemOfferIdParsed,
                          conversationId: (conversationId ?? '').toString(),
                          itemPrice: getPrice(itemPrice)!,
                          itemOfferPrice: getPrice(itemOfferPrice),
                          buyerId: HiveUtils.getUserId(),
                          alreadyReview: false,
                          isPurchased: 0,
                          participants: participants,
                          currency: currency,
                          currencySymbol: currencySymbol,

                        );
                      }),
                    );
                  },
                ));
          },
        );
      } else if (message.data['type'] == "offer") {
        if (HiveUtils.isUserAuthenticated()) {
          var username = message.data['user_name'];
          var itemTitleImage = message.data['item_title_image'];
          var itemTitle = message.data['item_title'];
          var userProfile = message.data['user_profile'];
          var senderId = message.data['sender_id'];
          var itemId = message.data['item_id'];
          var date = message.data['created_at'];
          var itemOfferId = message.data['item_offer_id'];
          var conversationId = message.data['conversation_id'];

          var itemPrice = message.data['item_price'];
          var itemOfferPrice = message.data['item_offer_amount'] ?? null;
          final int itemOfferIdParsed =
              _tryParseInt(itemOfferId) ?? 0;


          /* var username = message.data['user_name'];
          var itemTitleImage = message.data['image'];
          var itemTitle = message.data['name'];
          var userProfile = message.data['user_profile'];
          var senderId = message.data['user_id'];
          var itemId = message.data['id'];
          var date = message.data['created_at'];
          var itemOfferId = message.data['item_offer_id'];
          var itemPrice = message.data['price'];
          var itemOfferPrice = message.data['item_offer_amount'] ?? null;*/
          Future.delayed(
            Duration.zero,
                () {
              Navigator.push(Constant.navigatorKey.currentContext!,
                  MaterialPageRoute(
                    builder: (context) {
                      return MultiBlocProvider(
                        providers: [
                          BlocProvider(
                            create: (context) => SendMessageCubit(),
                          ),
                          BlocProvider(
                            create: (context) => LoadChatMessagesCubit(),
                          ),
                        ],
                        child: Builder(builder: (context) {

                          final Map<String, dynamic> normalizedData =
                          Map<String, dynamic>.from(message.data);


                          final List<ChatParticipant>? participants =
                              NotificationService.getCachedParticipants(
                                (conversationId ?? '').toString(),
                                itemOfferId: itemOfferIdParsed,
                              ) ??
                                  NotificationService
                                      .buildParticipantsFromNotification(
                                    data: normalizedData,

                                  );
                          if (participants != null && participants.isNotEmpty) {
                            NotificationService.cacheParticipants(
                              participants: participants,
                              conversationId: (conversationId ?? '').toString(),
                              itemOfferId:
                              itemOfferIdParsed > 0 ? itemOfferIdParsed : null,
                              senderId: senderId?.toString(),
                              itemId: itemId?.toString(),

                            );
                          }

                          final String? currency =
                          NotificationService.extractCurrency(
                              normalizedData);
                          final String? currencySymbol =
                          NotificationService.extractCurrencySymbol(
                              normalizedData);

                          return ChatScreen(
                            profilePicture: userProfile ?? "",
                            userName: username ?? "",
                            itemImage: itemTitleImage ?? "",
                            itemTitle: itemTitle ?? "",
                            userId: senderId ?? "",
                            itemId: itemId ?? "",
                            date: date ?? "",
                            itemOfferId: itemOfferIdParsed,
                            conversationId: (conversationId ?? '').toString(),
                            itemPrice: getPrice(itemPrice)!,
                            itemOfferPrice: getPrice(itemOfferPrice),
                            buyerId: HiveUtils.getUserId(),
                            alreadyReview: false,
                            isPurchased: 0,
                            currency: currency,
                            currencySymbol: currencySymbol,
                          );
                        }),
                      );
                    },
                  ));
            },
          );
          /*Future.delayed(Duration.zero, () {
            HelperUtils.goToNextPage(
              Routes.main,
              Constant.navigatorKey.currentContext!,
              false,
            );
            MainActivity.globalKey.currentState?.onItemTapped(1);
          });*/
        } else {
          Future.delayed(Duration.zero, () {
            HelperUtils.goToNextPage(Routes.notificationPage,
                Constant.navigatorKey.currentContext!, false);
          });
        }
      } else if (message.data['type'] == "item-update") {
        Future.delayed(Duration.zero, () {
          HelperUtils.goToNextPage(
            Routes.main,
            Constant.navigatorKey.currentContext!,
            false,
          );
          MainActivity.globalKey.currentState?.onItemTapped(2);
        });
      } else if (message.data["item_id"] != null &&
          message.data["item_id"] != '') {
        String id = message.data["item_id"] ?? "";
        DataOutput<ItemModel> item =
        await ItemRepository().fetchItemFromItemId(int.parse(id));
        Future.delayed(Duration.zero, () {
          Navigator.pushNamed(
              Constant.navigatorKey.currentContext!, Routes.adDetailsScreen,
              arguments: {
                'model': item.modelList[0],
              });
          /* HelperUtils.goToNextPage(Routes.adDetailsScreen,
              Constant.navigatorKey.currentContext!, false,
              args: {
                'model': item.modelList[0],
              });*/
        });
      } else if (message.data['type'] == "payment") {
        if (HiveUtils.isUserAuthenticated()) {
          Future.delayed(Duration.zero, () {
            Navigator.pushNamed(Constant.navigatorKey.currentContext!,
                Routes.subscriptionPackageListRoute);
          });
        } else {
          Future.delayed(Duration.zero, () {
            HelperUtils.goToNextPage(Routes.notificationPage,
                Constant.navigatorKey.currentContext!, false);
          });
        }
      } else {
        Future.delayed(Duration.zero, () {
          HelperUtils.goToNextPage(Routes.notificationPage,
              Constant.navigatorKey.currentContext!, false);
        });
      }
    }
// if (message.data["screen"] == "profile") {
//   Navigator.pushNamed(context, profileRoute);
// }

    );
  }

  static Future<void> registerListeners(context) async {
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    await forgroundNotificationHandler(context);
    await terminatedStateNotificationHandler(context);
    onTapNotificationHandler(context);
  }

  static void disposeListeners() {
    onMessageOpen.cancel();
    foregroundStream.cancel();
    _tokenRefreshSubscription?.cancel();
  }


  static void _registerTokenRefreshListener() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
          await _handleTokenRefresh(token);
        });
  }



  static Future<void> _ensureInitialTokenSynced() async {
    try {
      final String? currentToken =
      (await FirebaseMessaging.instance.getToken())?.trim();
      if (currentToken == null || currentToken.isEmpty) {
        return;
      }

      final String? storedToken =
      HiveUtils.getUserDetail<String>(key: Api.fcmId)?.trim();

      if (storedToken == currentToken) {
        await HiveUtils.setUserDetail(key: Api.fcmId, value: currentToken);
        await HiveUtils.setUserDetail(
            key: _pendingFcmTokenKey, value: currentToken);

        if (HiveUtils.isUserBasicallyAuthenticated()) {
          await _updateTokenOnServer(currentToken);
        }

        return;
      }

      await _handleTokenRefresh(currentToken);
    } catch (e) {
      debugPrint('Failed to sync initial FCM token: $e');
    }
  }


  static Future<void> _handleTokenRefresh(String? token) async {
    final String refreshedToken = (token ?? '').trim();
    if (refreshedToken.isEmpty) {
      return;
    }

    await HiveUtils.setUserDetail(key: Api.fcmId, value: refreshedToken);
    await HiveUtils.setUserDetail(
        key: _pendingFcmTokenKey, value: refreshedToken);
    await _updateTokenOnServer(refreshedToken);
  }

  static String? _normalizeTokenValue(String? token) {
    final String normalized = (token ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static Future<void> _updateTokenOnServer(String token) async {
    final String? normalizedToken = _normalizeTokenValue(token);
    if (normalizedToken == null) {
      return;
    }

    if (!HiveUtils.isUserBasicallyAuthenticated()) {
      await HiveUtils.setUserDetail(
          key: _pendingFcmTokenKey, value: normalizedToken);

      log(
        'Skipping FCM token upload because user is not basically authenticated',
        name: 'NotificationService',
      );

      return;
    }
    try {
      await Api.post(
        url: Api.updateProfileApi,
        parameter: {
          Api.fcmId: normalizedToken,

          Api.platformType: Platform.isAndroid ? "android" : "ios",
        },
      );
      await HiveUtils.setUserDetail(key: Api.fcmId, value: normalizedToken);
      await HiveUtils.setUserDetail(key: _pendingFcmTokenKey, value: null);
      log(
        'Successfully synced FCM token with the server',
        name: 'NotificationService',
      );

    } catch (e, stackTrace) {
      await HiveUtils.setUserDetail(
          key: _pendingFcmTokenKey, value: normalizedToken);
      log(
        'Failed to update FCM token on the server: $e',
        name: 'NotificationService',
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> resendPendingTokenIfNeeded() async {
    if (!HiveUtils.isUserBasicallyAuthenticated()) {
      log(
        'Resend of pending FCM token skipped: user not basically authenticated',
        name: 'NotificationService',
      );

      return;
    }

    final String? pendingToken =
    _normalizeTokenValue(HiveUtils.getUserDetail<String>(key: _pendingFcmTokenKey));
    final String? fallbackToken =
    _normalizeTokenValue(HiveUtils.getUserDetail<String>(key: Api.fcmId));

    final String? tokenToResend = pendingToken ?? fallbackToken;

    if (tokenToResend == null || tokenToResend.isEmpty) {
      return;
    }

    await HiveUtils.setUserDetail(key: Api.fcmId, value: tokenToResend);
    await HiveUtils.setUserDetail(
        key: _pendingFcmTokenKey, value: tokenToResend);
    await _updateTokenOnServer(tokenToResend);
  }



  static T? _maybeReadCubit<T extends StateStreamableSource<Object?>>(
      BuildContext context) {
    try {
      return BlocProvider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }


  static ParticipantStatus? _parseParticipantStatusFromData(
      Map<String, dynamic> data) {
    dynamic statusData = data['status'];
    statusData ??= data['presence'];
    if (statusData is String) {
      statusData = _tryDecodeJson(statusData);
    }
    if (statusData == null && data.containsKey('payload')) {
      statusData = _tryDecodeJson(data['payload']);
    }
    if (statusData == null) {
      final Map<String, dynamic> candidate = <String, dynamic>{};
      for (final entry in ['is_online', 'isOnline']) {
        if (data.containsKey(entry)) {
          candidate['is_online'] = data[entry];
          break;
        }
      }
      for (final entry in ['is_typing', 'isTyping']) {
        if (data.containsKey(entry)) {
          candidate['is_typing'] = data[entry];
          break;
        }
      }
      for (final entry in ['is_blocked', 'isBlocked']) {
        if (data.containsKey(entry)) {
          candidate['is_blocked'] = data[entry];
          break;
        }
      }
      for (final entry in ['last_seen', 'lastSeen']) {
        if (data.containsKey(entry)) {
          candidate['last_seen'] = data[entry];
          break;
        }
      }
      if (candidate.isNotEmpty) {
        statusData = candidate;
      }
    }

    if (statusData == null) {
      return null;
    }
    return ParticipantStatus.fromJson(statusData);
  }

  static dynamic _tryDecodeJson(dynamic value) {
    if (value is! String) {
      return value;
    }
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }


  static bool _isMessageForCurrentChat(Map<String, dynamic> data) {
    final String conversationId =
        data['conversation_id']?.toString() ??
            data['conversationId']?.toString() ??
            '';
    final String itemOfferId = data['item_offer_id']?.toString() ??
        data['itemOfferId']?.toString() ??
        '';
    if (conversationId.isNotEmpty) {
      if (conversationId != currentlyChatingWith) {
        return false;
      }
      if (itemOfferId.isNotEmpty && currentlyChatItemId.isNotEmpty) {
        return itemOfferId == currentlyChatItemId;
      }
      return true;
    }

    final String senderId = data['user_id']?.toString() ??
        data['sender_id']?.toString() ??
        data['from_user_id']?.toString() ??
        '';
    final String itemId = data['item_id']?.toString() ??
        data['itemId']?.toString() ??
        '';
    if (senderId.isEmpty && itemId.isEmpty) {
      return false;
    }
    final bool senderMatches = senderId.isEmpty
        ? true
        : senderId == currentlyChatingWith;
    final bool itemMatches = itemId.isEmpty
        ? true
        : itemId == currentlyChatItemId;
    return senderMatches && itemMatches;
  }


  static void _handlePresenceNotification(Map<String, dynamic> data) {
    _cacheParticipantsFromData(data);
    if (!_isMessageForCurrentChat(data)) {
      return;
    }
    final ParticipantStatus? participantStatus =
    _parseParticipantStatusFromData(Map<String, dynamic>.from(data));
    if (participantStatus != null) {
      _notifyParticipantStatus(participantStatus);
      _emitUserPresenceEvent(
        participantStatus: participantStatus,
        data: data,
      );
    }
  }


  static void _handleMessageStatusNotification(Map<String, dynamic> data) {
    if (!_isMessageForCurrentChat(data)) {
      return;
    }

    final List<int> messageIds = _extractMessageIds(data);
    if (messageIds.isEmpty) {
      return;
    }

    final String? status = _normalizeNotificationValue(data['status']);
    final String? deliveredAt =
    _normalizeNotificationValue(data['delivered_at'] ?? data['deliveredAt']);
    final String? readAt =
    _normalizeNotificationValue(data['read_at'] ?? data['readAt']);

    for (final int messageId in messageIds) {
      ChatMessageHandler.updateMessageStatus(
        messageId: messageId,
        status: status,
        deliveredAt: deliveredAt,
        readAt: readAt,
      );

      if (_messageStatusController.isClosed) {
        continue;
      }
      _messageStatusController.add(ChatMessageStatusUpdate(
        messageId: messageId,
        status: status,
        deliveredAt: deliveredAt,
        readAt: readAt,
      ));
    }
  }



  static void _notifyParticipantStatus(ParticipantStatus? participantStatus) {
    participantStatusNotifier.value = participantStatus;
    if (!_participantStatusController.isClosed) {
      _participantStatusController.add(participantStatus);
    }
    ChatMessageHandler.updateParticipantStatus(participantStatus);
  }

  static List<int> _extractMessageIds(Map<String, dynamic> data) {
    final Set<int> ids = <int>{};

    void addValue(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is int) {
        ids.add(value);
        return;
      }
      if (value is num) {
        ids.add(value.toInt());
        return;
      }
      if (value is String) {
        if (value.isEmpty) {
          return;
        }
        final List<String> parts = value
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
        for (final String part in parts) {
          final int? parsed = int.tryParse(part);
          if (parsed != null) {
            ids.add(parsed);
          }
        }
        return;
      }
      if (value is Iterable) {
        for (final dynamic element in value) {
          addValue(element);
        }
        return;
      }
      if (value is Map<String, dynamic>) {
        addValue(value['id']);
        addValue(value['message_id']);
        addValue(value['messageId']);
      }
    }

    addValue(data['message_id']);
    addValue(data['messageId']);
    addValue(data['id']);
    addValue(data['message_ids']);
    addValue(data['messageIds']);
    addValue(data['messages']);

    return ids.toList(growable: false);
  }


  static void _emitUserPresenceEvent({
    required ParticipantStatus participantStatus,
    required Map<String, dynamic> data,
  }) {
    if (_userPresenceEventController.isClosed) {

      userPresenceEventNotifier.value = UserPresenceEvent(
        type: _resolvePresenceEventType(data, participantStatus),
        status: participantStatus,
      );

      return;
    }
    final UserPresenceEvent event = UserPresenceEvent(
      type: _resolvePresenceEventType(data, participantStatus),
      status: participantStatus,
    );

    _userPresenceEventController.add(event);
    userPresenceEventNotifier.value = event;

  }

  static UserPresenceEventType _resolvePresenceEventType(
      Map<String, dynamic> data,
      ParticipantStatus participantStatus,
      ) {
    final String rawEvent = (data['event'] ?? data['action'] ?? data['type'] ?? '')
        .toString()
        .trim();
    if (rawEvent == 'UserTyping') {
      return UserPresenceEventType.userTyping;
    }
    if (rawEvent == 'UserPresenceUpdated') {
      return UserPresenceEventType.userPresenceUpdated;
    }

    if (participantStatus.isTyping == true) {
      return UserPresenceEventType.userTyping;
    }

    final dynamic statusData = data['status'] ?? data['presence'];
    if (statusData is Map<String, dynamic>) {
      final dynamic typing = statusData['is_typing'] ?? statusData['isTyping'];
      if (typing != null && _parseBoolFlexible(typing) == true) {
        return UserPresenceEventType.userTyping;
      }
    }

    final dynamic directTyping = data['is_typing'] ?? data['isTyping'];
    if (directTyping != null && _parseBoolFlexible(directTyping) == true) {
      return UserPresenceEventType.userTyping;
    }

    return UserPresenceEventType.userPresenceUpdated;
  }

  static bool _parseBoolFlexible(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') {
        return true;
      }
      if (lower == 'false' || lower == '0') {
        return false;
      }
    }
    return false;
  }


  static void clearParticipantStatus() {
    participantStatusNotifier.value = null;
    if (!_participantStatusController.isClosed) {
      _participantStatusController.add(null);
    }

    userPresenceEventNotifier.value = null;
    ChatMessageHandler.clearParticipantStatus();
  }

  static void _cacheParticipantsFromData(Map<String, dynamic> data) {
    final List<ChatParticipant>? participants =
    buildParticipantsFromNotification(data: data);
    if (participants == null || participants.isEmpty) {
      return;
    }
    final String conversationId =
        data['conversation_id']?.toString() ??
            data['conversationId']?.toString() ??
            '';
    final int? itemOfferId =
    _tryParseInt(data['item_offer_id'] ?? data['itemOfferId']);


    final String key = _buildConversationCacheKey(
      conversationId: conversationId,
      itemOfferId: itemOfferId,
      senderId: data['sender_id']?.toString() ??
          data['user_id']?.toString() ??
          data['from_user_id']?.toString(),
      itemId: data['item_id']?.toString() ?? data['itemId']?.toString(),


    );
    if (key.isEmpty) {
      return;
    }
    _conversationParticipantsCache[key] = participants;
  }

  static void cacheParticipants({
    required List<ChatParticipant> participants,
    required String conversationId,
    int? itemOfferId,
    String? senderId,
    String? itemId,
  }) {
    if (participants.isEmpty) {
      return;
    }
    final String key = _buildConversationCacheKey(
      conversationId: conversationId,
      itemOfferId: itemOfferId,
      senderId: senderId,
      itemId: itemId,
    );
    if (key.isEmpty) {
      return;
    }
    _conversationParticipantsCache[key] = participants
        .map((participant) => ChatParticipant.fromJson(participant.toJson()))
        .toList();
  }


  static List<ChatParticipant>? getCachedParticipants(String conversationId,
      {int? itemOfferId, String? senderId, String? itemId}) {
    final String key = _buildConversationCacheKey(
      conversationId: conversationId,
      itemOfferId: itemOfferId,
      senderId: senderId,
      itemId: itemId,
    );
    if (key.isEmpty) {
      return null;
    }
    final List<ChatParticipant>? cached = _conversationParticipantsCache[key];
    if (cached == null) {
      return null;
    }
    return cached
        .map((participant) => ChatParticipant.fromJson(participant.toJson()))
        .toList();
  }

  static List<ChatParticipant>? buildParticipantsFromNotification(
      {required Map<String, dynamic> data}) {
    final int? otherUserId = _tryParseInt(
      data['user_id'] ?? data['sender_id'] ?? data['from_user_id'],
    ) ??
        _tryParseInt(data['buyer_id'] ?? data['seller_id']);

    final String? otherName = data['user_name']?.toString() ??
        data['name']?.toString() ??
        data['buyer_name']?.toString() ??
        data['seller_name']?.toString();
    final String? otherProfile = data['user_profile']?.toString() ??
        data['profile']?.toString() ??
        data['buyer_profile']?.toString() ??
        data['seller_profile']?.toString();
    final ParticipantStatus? participantStatus =
    _parseParticipantStatusFromData(Map<String, dynamic>.from(data));

    final List<ChatParticipant> participants = <ChatParticipant>[];
    if (otherUserId != null) {
      participants.add(ChatParticipant(
        userId: otherUserId,
        name: otherName,
        profile: otherProfile,
        status: participantStatus,
        role: data['user_type']?.toString(),
        additionalData: Map<String, dynamic>.from(data),
      ));
    }

    final int? currentUserId = _tryParseInt(HiveUtils.getUserId());
    if (currentUserId != null) {
      String? currentUserName;
      try {
        currentUserName = HiveUtils
            .getUserDetails()
            .name;
      } catch (_) {}
      participants.add(ChatParticipant(
        userId: currentUserId,
        role: 'self',
        name: currentUserName,
      ));
    }

    if (participants.isEmpty) {
      return null;
    }
    return participants;
  }

  static String _buildConversationCacheKey({
    required String conversationId,
    int? itemOfferId,
    String? senderId,
    String? itemId,
  }) {
    final String trimmedConversation = conversationId.trim();
    if (trimmedConversation.isNotEmpty) {
      if (itemOfferId != null && itemOfferId > 0) {
        return 'c:$trimmedConversation#i:$itemOfferId';
      }
      return 'c:$trimmedConversation';
    }

    final String? resolvedSenderId = senderId?.toString();
    final String? resolvedItemId = itemId?.toString();
    if ((resolvedSenderId == null || resolvedSenderId.isEmpty) &&
        (resolvedItemId == null || resolvedItemId.isEmpty)) {
      return '';
    }
    return 's:${resolvedSenderId ?? ''}#item:${resolvedItemId ?? ''}';
  }

}
