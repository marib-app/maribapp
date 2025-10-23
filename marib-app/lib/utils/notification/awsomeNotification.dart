// ignore_for_file: file_names

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/ui/screens/chat/chat_screen.dart';

import 'package:marib/data/cubits/chat/delete_message_cubit.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/data/cubits/chat/load_chat_messages.dart';
import 'package:marib/data/cubits/chat/send_message.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'package:marib/utils/helper_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';

class LocalAwsomeNotification {
  AwesomeNotifications notification = AwesomeNotifications();

  void init(BuildContext context) {
    requestPermission();

    notification.initialize(
        null,
        [
          NotificationChannel(
              channelKey: Constant.notificationChannel,
              channelName: 'Basic notifications',
              channelDescription: 'Notification channel',
              importance: NotificationImportance.Max,
              ledColor: Colors.grey),
          NotificationChannel(
              channelKey: "Chat Notification",
              channelName: 'Chat Notifications',
              channelDescription: 'Chat Notifications',
              importance: NotificationImportance.Max,
              ledColor: Colors.grey)
        ],
        channelGroups: [],
        debug: true);
    listenTap(context);
  }

  void listenTap(BuildContext context) {
    AwesomeNotifications().setListeners(
      onNotificationCreatedMethod:
          NotificationController.onNotificationCreatedMethod,
      onDismissActionReceivedMethod:
          NotificationController.onDismissActionReceivedMethod,
      onNotificationDisplayedMethod:
          NotificationController.onNotificationDisplayedMethod,
      onActionReceivedMethod: NotificationController.onActionReceivedMethod,
    );
  }

  createNotification({
    required RemoteMessage notificationData,
    required bool isLocked,
  }) async {
    try {
      final Map<String, dynamic> payload = notificationData.data;
      final bool isChat = payload["type"] == "chat";
      final String? rawImage = payload["image"]?.toString();
      final bool hasImage =
          rawImage != null && rawImage.trim().isNotEmpty && rawImage != "null";
      final String? title =
          (payload["title"]?.toString().trim().isNotEmpty ?? false)
              ? payload["title"].toString()
              : notificationData.notification?.title;
      final String? body =
          (payload["body"]?.toString().trim().isNotEmpty ?? false)
              ? payload["body"].toString()
              : notificationData.notification?.body;
      final String resolvedTitle = title ?? '';
      final String resolvedBody = body ?? '';

      if (isChat) {
        int chatId = int.parse(notificationData.data['sender_id']) +
            int.parse(notificationData.data['item_id']);

        if (Platform.isAndroid) {
          await notification.createNotification(
            content: NotificationContent(
              id: isChat ? chatId : Random().nextInt(5000),
              title: resolvedTitle,
              // icon: AppIcons.aboutUs,
              hideLargeIconOnExpand: true,
              summary: "${notificationData.data['user_name']}",
              locked: isLocked,
              payload: Map.from(payload),
              autoDismissible: true,

              body: resolvedBody,
              wakeUpScreen: true,

              notificationLayout: NotificationLayout.MessagingGroup,
              groupKey: notificationData.data["id"],
              channelKey: "Chat Notification",
            ),
          );
        }
      } else {
        if (hasImage) {
          final String imageUrl = rawImage!.trim();

          if (Platform.isAndroid) {
            await notification.createNotification(
              content: NotificationContent(
                id: Random().nextInt(5000),
                title: resolvedTitle,
                bigPicture: imageUrl,
                hideLargeIconOnExpand: true,
                summary: null,
                locked: isLocked,
                payload: Map.from(payload),
                autoDismissible: true,
                body: resolvedBody,
                wakeUpScreen: true,
                notificationLayout: NotificationLayout.BigPicture,
                groupKey: payload["item_id"],
                channelKey: Constant.notificationChannel,
              ),
            );
          }
        } else {
          if (Platform.isAndroid) {
            await notification.createNotification(
              content: NotificationContent(
                id: Random().nextInt(5000),
                title: resolvedTitle,
                hideLargeIconOnExpand: true,
                summary: null,
                locked: isLocked,
                payload: Map.from(payload),
                autoDismissible: true,
                body: resolvedBody,
                wakeUpScreen: true,
                notificationLayout: NotificationLayout.Default,
                groupKey: payload["item_id"],
                channelKey: Constant.notificationChannel,
              ),
            );
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> requestPermission() async {
    final notificationSettings =
        await FirebaseMessaging.instance.getNotificationSettings();

    if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.notDetermined) {
      final newSettings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (newSettings.authorizationStatus == AuthorizationStatus.authorized ||
          newSettings.authorizationStatus == AuthorizationStatus.provisional) {
        // Permission granted, handle notification setup here.
      } else if (newSettings.authorizationStatus ==
          AuthorizationStatus.denied) {
        // Permission denied, do nothing.
        return;
      }
    } else if (notificationSettings.authorizationStatus ==
        AuthorizationStatus.denied) {
      // Permission was already denied, do nothing.
      return;
    }

    // If the permission is already granted, you can proceed with setting up notifications here.
  }
}

class NotificationController {
  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {}

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {}

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {}

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    Map<String, String?>? payload = receivedAction.payload;

    print('payload receive click***${payload.toString()}');
    if (payload?['type'] == "chat") {
      var username = payload?['user_name'];
      var itemImage = payload?['item_image'];
      var itemName = payload?['item_name'];
      var userProfile = payload?['user_profile'];
      var senderId = payload?['user_id'];
      var itemId = payload?['item_id'];
      var date = payload?['created_at'];
      final String? itemOfferIdRaw = payload?['item_offer_id'];
      var conversationId = payload?['conversation_id'];

      var itemPrice = payload?['item_price'];
      var itemOfferPrice = payload?['item_offer_amount'];
      final int itemOfferIdParsed =
          int.tryParse(itemOfferIdRaw?.toString() ?? '') ?? 0;
      Future.delayed(
        Duration.zero,
        () {
          Navigator.push(Constant.navigatorKey.currentContext!,
              MaterialPageRoute(
            builder: (context) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (context) => LoadChatMessagesCubit(),
                  ),
                  BlocProvider(
                    create: (context) => SendMessageCubit(),
                  ),
                  BlocProvider(
                    create: (context) => DeleteMessageCubit(),
                  ),
                ],
                child: Builder(builder: (context) {
                  final Map<String, dynamic> notificationData =
                      Map<String, dynamic>.from(payload ?? {});
                  final String? currency =
                      NotificationService.extractCurrency(notificationData);
                  final String? currencySymbol =
                      NotificationService.extractCurrencySymbol(
                          notificationData);
                  final List<ChatParticipant>? participants =
                      NotificationService.getCachedParticipants(
                            (conversationId ?? '').toString(),
                            itemOfferId: itemOfferIdParsed > 0
                                ? itemOfferIdParsed
                                : null,
                            senderId: senderId?.toString(),
                            itemId: itemId?.toString(),
                          ) ??
                          NotificationService.buildParticipantsFromNotification(
                            data: notificationData,
                          );
                  return ChatScreen(
                    profilePicture: userProfile ?? "",
                    userName: username ?? "",
                    itemImage: itemImage ?? "",
                    itemTitle: itemName ?? "",
                    userId: senderId ?? "",
                    itemId: itemId ?? "",
                    date: date ?? "",
                    itemOfferId: itemOfferIdParsed,
                    conversationId: (conversationId ?? '').toString(),
                    itemPrice: NotificationService.getPrice(itemPrice!)!,
                    itemOfferPrice:
                        NotificationService.getPrice(itemOfferPrice),
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
    } else if (payload?['type'] == "offer") {
      if (HiveUtils.isUserAuthenticated()) {
        var username = payload?['user_name'];
        var itemImage = payload?['item_image'];
        var itemName = payload?['item_name'];
        var userProfile = payload?['user_profile'];
        var senderId = payload?['user_id'];
        var itemId = payload?['item_id'];
        var date = payload?['created_at'];
        var conversationId = payload?['conversation_id'];
        var itemPrice = payload?['item_price'];
        var itemOfferPrice = payload?['item_offer_amount'];
        final String? itemOfferIdRaw = payload?['item_offer_id'];

        final int itemOfferIdParsed =
            int.tryParse(itemOfferIdRaw?.toString() ?? '') ?? 0;

        Future.delayed(
          Duration.zero,
          () {
            Navigator.push(Constant.navigatorKey.currentContext!,
                MaterialPageRoute(
              builder: (context) {
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (context) => LoadChatMessagesCubit(),
                    ),
                    BlocProvider(
                      create: (context) => SendMessageCubit(),
                    ),
                    BlocProvider(
                      create: (context) => DeleteMessageCubit(),
                    ),
                  ],
                  child: Builder(builder: (context) {
                    final Map<String, dynamic> notificationData =
                        Map<String, dynamic>.from(payload ?? {});
                    final String? currency =
                        NotificationService.extractCurrency(
                      notificationData,
                    );
                    final String? currencySymbol =
                        NotificationService.extractCurrencySymbol(
                            notificationData);
                    final List<ChatParticipant>? participants =
                        NotificationService.getCachedParticipants(
                              (conversationId ?? '').toString(),
                              itemOfferId: itemOfferIdParsed > 0
                                  ? itemOfferIdParsed
                                  : null,
                              senderId: senderId?.toString(),
                              itemId: itemId?.toString(),
                            ) ??
                            NotificationService
                                .buildParticipantsFromNotification(
                              data: notificationData,
                            );
                    return ChatScreen(
                      profilePicture: userProfile ?? "",
                      userName: username ?? "",
                      itemImage: itemImage ?? "",
                      itemTitle: itemName ?? "",
                      userId: senderId ?? "",
                      itemId: itemId ?? "",
                      date: date ?? "",
                      itemOfferId: itemOfferIdParsed,
                      conversationId: (conversationId ?? '').toString(),
                      itemPrice: NotificationService.getPrice(itemPrice!)!,
                      itemOfferPrice:
                          NotificationService.getPrice(itemOfferPrice),
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
        /* Future.delayed(Duration.zero, () {
          Navigator.popUntil(
              Constant.navigatorKey.currentContext!, (route) => route.isFirst);
          MainActivity.globalKey.currentState?.onItemTapped(1);
        });*/
      } else {
        Future.delayed(Duration.zero, () {
          HelperUtils.goToNextPage(Routes.notificationPage,
              Constant.navigatorKey.currentContext!, false);
        });
      }
    } else if (payload?['type'] == "item-update") {
      Future.delayed(Duration.zero, () {
        Navigator.popUntil(
            Constant.navigatorKey.currentContext!, (route) => route.isFirst);
        MainActivity.globalKey.currentState?.onItemTapped(2);
      });
    } else if (receivedAction.payload?["item_id"] != null &&
        receivedAction.payload?["item_id"] != '') {
      print("stuck here");
      String id = receivedAction.payload?["item_id"] ?? "";

      DataOutput<ItemModel> item =
          await ItemRepository().fetchItemFromItemId(int.parse(id));

      Future.delayed(
        Duration.zero,
        () {
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
        },
      );
    } else if (payload?['type'] == "payment") {
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
        Navigator.pushNamed(
            Constant.navigatorKey.currentContext!, Routes.notificationPage);
        /*HelperUtils.goToNextPage(Routes.notificationPage,
              Constant.navigatorKey.currentContext!, false);*/
      });
    }
  }
}
