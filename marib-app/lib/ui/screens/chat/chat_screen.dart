import 'dart:async';
import 'dart:io';
import 'package:marib/utils/notification/chat_message_handler.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:marib/data/cubits/chat/load_chat_messages.dart';
import 'package:marib/data/cubits/chat/send_message.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:marib/ui/screens/chat/chat_audio/widgets/record_button.dart';
import 'package:marib/ui/screens/widgets/animated_routes/transparant_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/data/cubits/add_item_review_cubit.dart';
import 'package:marib/data/cubits/chat/block_user_cubit.dart';
import 'package:marib/data/cubits/chat/delete_message_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/customHeroAnimation.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/cubits/chat/unblock_user_cubit.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:marib/data/repositories/chat_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:marib/data/cubits/chat/get_seller_chat_users_cubit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:marib/data/cubits/chat/get_seller_chat_users_cubit.dart';
import 'dart:async';
import 'package:marib/utils/chat/chat_sync_controller.dart';
import 'package:marib/data/model/chat/chat_message_modal.dart';
import 'package:marib/utils/chat/conversation_id_utils.dart';

part 'chat_screen_ui.dart';

int totalMessageCount = 0;

ValueNotifier<bool> showDeletebutton = ValueNotifier<bool>(false);

ValueNotifier<int> selectedMessageid = ValueNotifier<int>(-5);

class ChatScreen extends StatefulWidget {
  final String? from;
  final int itemOfferId;
  final double? itemOfferPrice;
  final double itemPrice;
  final String profilePicture;
  final String userName;
  final String itemImage;
  final String itemTitle;
  final String userId; //for which we are messageing
  final String itemId;
  final String date;
  final String conversationId;

  final String? status;
  final String? buyerId;
  final int isPurchased;
  final bool alreadyReview;
  final List<ChatParticipant>? participants;
  final ChatLastMessage? lastMessage;
  final String? currency;
  final String? currencySymbol;

  const ChatScreen({
    super.key,
    required this.profilePicture,
    required this.userName,
    required this.itemImage,
    required this.itemTitle,
    required this.userId,
    required this.itemId,
    required this.date,
    required this.conversationId,
    this.from,
    required this.itemOfferId,
    this.status,
    required this.itemPrice,
    this.itemOfferPrice,
    this.buyerId,
    required this.isPurchased,
    required this.alreadyReview,
    this.participants,
    this.lastMessage,
    this.currency,
    this.currencySymbol,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _recordButtonAnimation = AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 500,
    ),
  );
  TextEditingController controller = TextEditingController();
  PlatformFile? messageAttachment;
  bool isFetchedFirstTime = false;
  double scrollPositionWhenLoadMore = 0;
  final StreamController<PermissionStatus> _notificationStatusController =
      StreamController<PermissionStatus>.broadcast();
  late final Stream<PermissionStatus> notificationStream =
      notificationPermission();
  late StreamSubscription<PermissionStatus> notificationStreamSubsctription;
  Timer? _notificationStatusTimer;
  PermissionStatus? _lastEmittedPermissionStatus;

  bool isNotificationPermissionGranted = true;
  bool showRecordButton = true;
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  late final ScrollController _pageScrollController = ScrollController()
    ..addListener(_handleScroll);

  ParticipantStatus? _otherParticipantStatus;
  String? _otherParticipantName;
  StreamSubscription<UserPresenceEvent>? _presenceEventSubscription;
  List<ChatParticipant>? _fallbackParticipants;
  VoidCallback? _participantStatusListener;

  late final ChatSyncController _chatSyncController;
  StreamSubscription<List<ChatMessageModal>>? _chatMessagesSubscription;

  String get _effectiveConversationId {
    final String normalized = normalizeConversationId(widget.conversationId);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    if (widget.itemOfferId > 0) {
      return widget.itemOfferId.toString();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();

    final String effectiveConversationId = _effectiveConversationId;
    _chatSyncController = ChatSyncController(
      conversationId: effectiveConversationId,
      itemOfferId: widget.itemOfferId > 0 ? widget.itemOfferId : null,
    );
    _chatMessagesSubscription =
        ChatMessageHandler.getChatStream().listen(_handleChatSyncStream);
    if (effectiveConversationId.isNotEmpty) {
      unawaited(_chatSyncController.setPresenceOnline());
    }

    context.read<LoadChatMessagesCubit>().load(
          itemOfferId: widget.itemOfferId,
          conversationId: widget.conversationId,
        );

    final String trimmedConversationId = widget.conversationId.trim();
    final String resolvedConversationId = trimmedConversationId.isNotEmpty
        ? trimmedConversationId
        : widget.userId;
    final String resolvedItemIdentifier =
        widget.itemOfferId > 0 ? widget.itemOfferId.toString() : widget.itemId;

    currentlyChatItemId = resolvedItemIdentifier;
    currentlyChatingWith = effectiveConversationId.isNotEmpty
        ? effectiveConversationId
        : resolvedConversationId;

    _otherParticipantStatus =
        NotificationService.participantStatusNotifier.value ??
            _otherParticipantStatus;

    _participantStatusListener = () {
      final ParticipantStatus? latest =
          NotificationService.participantStatusNotifier.value;
      if (!mounted) {
        _otherParticipantStatus = latest;
        return;
      }
      setState(() {
        _otherParticipantStatus = latest;
      });
    };
    NotificationService.participantStatusNotifier
        .addListener(_participantStatusListener!);

    _cacheInitialParticipants(widget.participants);

    _fallbackParticipants = widget.participants
        ?.map(
          (participant) => ChatParticipant.fromJson(participant.toJson()),
        )
        .toList();

    unawaited(_preparePresenceHandling());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markConversationAsRead();
    });

    notificationStreamSubsctription =
        notificationStream.listen(_updateNotificationPermissionState);
    unawaited(_initializeNotificationPermissionFlow());
    controller.addListener(() {
      final bool hasText = controller.text.trim().isNotEmpty;
      _updateInputMode();
      _chatSyncController.onTypingChanged(hasText);
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.status == "sold out" &&
          widget.isPurchased == 1 &&
          !widget.alreadyReview) {
        ratingsAlertDialog();
      }
    });
  }

  Stream<PermissionStatus> notificationPermission() {
    return _notificationStatusController.stream;
  }

  void _updateNotificationPermissionState(PermissionStatus permissionStatus) {
    final bool newValue = permissionStatus.isGranted;
    if (isNotificationPermissionGranted != newValue) {
      isNotificationPermissionGranted = newValue;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _initializeNotificationPermissionFlow() async {
    await _emitCurrentNotificationStatus();

    if (!mounted) {
      return;
    }

    final PermissionStatus? currentStatus = _lastEmittedPermissionStatus;
    if (currentStatus == null ||
        _shouldStopMonitoringPermission(currentStatus)) {
      return;
    }

    final PermissionStatus requestedStatus =
        await Permission.notification.request();
    _emitPermissionStatus(requestedStatus);

    if (!mounted || _shouldStopMonitoringPermission(requestedStatus)) {
      return;
    }

    _startPermissionStatusMonitoring();
  }

  Future<void> _emitCurrentNotificationStatus() async {
    final PermissionStatus status = await Permission.notification.status;
    _emitPermissionStatus(status);
  }

  void _startPermissionStatusMonitoring() {
    _notificationStatusTimer?.cancel();
    _notificationStatusTimer =
        Timer.periodic(const Duration(seconds: 5), (Timer timer) async {
      final PermissionStatus status = await Permission.notification.status;
      _emitPermissionStatus(status);

      if (_shouldStopMonitoringPermission(status)) {
        timer.cancel();
      }
    });
  }

  void _emitPermissionStatus(PermissionStatus status) {
    if (_notificationStatusController.isClosed) {
      return;
    }
    if (_lastEmittedPermissionStatus == status) {
      return;
    }
    _lastEmittedPermissionStatus = status;
    _notificationStatusController.add(status);
  }

  bool _shouldStopMonitoringPermission(PermissionStatus status) {
    return status.isGranted || status.isPermanentlyDenied;
  }

  void _cacheInitialParticipants(List<ChatParticipant>? participants) {
    if (participants == null || participants.isEmpty) {
      return;
    }
    NotificationService.cacheParticipants(
      participants: participants,
      conversationId: widget.conversationId,
      itemOfferId: widget.itemOfferId > 0 ? widget.itemOfferId : null,
      senderId: widget.userId,
      itemId: widget.itemId,
    );
  }

  void _initializePresence() {
    final participants = _resolveParticipants();
    if (participants == null || participants.isEmpty) {
      return;
    }
    final String? userIdStr = HiveUtils.getUserId();
    final int? currentUserId = int.tryParse(userIdStr ?? '');
    ParticipantStatus? resolvedStatus;
    String? resolvedName;
    if (currentUserId != null) {
      for (final participant in participants) {
        if (participant.userId != null && participant.userId != currentUserId) {
          resolvedStatus = participant.status ?? resolvedStatus;
          resolvedName = participant.name ?? resolvedName;
          break;
        }
      }
    }
    resolvedStatus ??= _otherParticipantStatus;
    resolvedName ??= _otherParticipantName;
    final bool shouldUpdate = resolvedStatus != _otherParticipantStatus ||
        resolvedName != _otherParticipantName;
    if (!shouldUpdate) {
      return;
    }
    if (mounted) {
      setState(() {
        _otherParticipantStatus = resolvedStatus;
        _otherParticipantName = resolvedName;
      });
    } else {
      _otherParticipantStatus = resolvedStatus;
      _otherParticipantName = resolvedName;
    }
  }

  Future<void> _preparePresenceHandling() async {
    if (_fallbackParticipants != null && _fallbackParticipants!.isNotEmpty) {
      _initializePresence();
    }

    final List<ChatParticipant>? participants =
        await _loadParticipantsIfNeeded();

    if (!mounted) {
      if (participants != null && participants.isNotEmpty) {
        _fallbackParticipants = participants;
      }
      return;
    }

    if (participants != null && participants.isNotEmpty) {
      setState(() {
        _fallbackParticipants = participants;
      });
    }

    _initializePresence();

    _presenceEventSubscription ??=
        NotificationService.userPresenceEvents.listen((event) {
      if (!mounted) {
        return;
      }
      setState(() {
        _otherParticipantStatus = event.status;
      });
    });

    final UserPresenceEvent? latestEvent =
        NotificationService.userPresenceEventNotifier.value;
    final ParticipantStatus? latestStatus = latestEvent?.status ??
        NotificationService.participantStatusNotifier.value;

    if (latestStatus != null && latestStatus != _otherParticipantStatus) {
      setState(() {
        _otherParticipantStatus = latestStatus;
      });
    }
  }

  void _handleScroll() {
    if (!_pageScrollController.hasClients) {
      return;
    }
    if (_pageScrollController.offset >=
        _pageScrollController.position.maxScrollExtent) {
      if (context.read<LoadChatMessagesCubit>().hasMoreChat()) {
        setState(() {});
        context.read<LoadChatMessagesCubit>().loadMore();
      }
    }
  }

  List<ChatParticipant>? _resolveParticipants() {
    final participants = widget.participants;
    if (participants != null && participants.isNotEmpty) {
      return participants;
    }
    return _fallbackParticipants;
  }

  Future<List<ChatParticipant>?> _loadParticipantsIfNeeded() async {
    if (widget.participants != null && widget.participants!.isNotEmpty) {
      return widget.participants!
          .map(
            (participant) => ChatParticipant.fromJson(participant.toJson()),
          )
          .toList();
    }

    final String conversationId = widget.conversationId;
    final int itemOfferId = widget.itemOfferId;

    List<ChatParticipant>? resolvedParticipants =
        NotificationService.getCachedParticipants(
      conversationId,
      itemOfferId: itemOfferId > 0 ? itemOfferId : null,
      senderId: widget.userId,
      itemId: widget.itemId,
    );

    resolvedParticipants ??=
        _findParticipantsFromCubit(conversationId, itemOfferId, widget.userId);

    final List<ChatParticipant>? notificationParticipants =
        NotificationService.buildParticipantsFromNotification(
      data: {
        'user_id': widget.userId,
        'user_name': widget.userName,
        'user_profile': widget.profilePicture,
      },
    );

    if (resolvedParticipants == null || resolvedParticipants.isEmpty) {
      resolvedParticipants = notificationParticipants;
    }

    final bool shouldFetchFromRepository = resolvedParticipants == null ||
        resolvedParticipants.isEmpty ||
        resolvedParticipants.every((participant) => participant.status == null);

    if (shouldFetchFromRepository) {
      final List<ChatParticipant>? repositoryParticipants =
          await _fetchParticipantsFromRepository(
        conversationId,
        itemOfferId,
      );

      if (repositoryParticipants != null && repositoryParticipants.isNotEmpty) {
        resolvedParticipants = repositoryParticipants;
      }
    }

    if (resolvedParticipants != null && resolvedParticipants.isNotEmpty) {
      _cacheInitialParticipants(resolvedParticipants);
    }
    return resolvedParticipants;
  }

  List<ChatParticipant>? _findParticipantsFromCubit(
      String conversationId, int itemOfferId, String userId) {
    try {
      final buyerState = context.read<GetBuyerChatListCubit>().state;
      if (buyerState is GetBuyerChatListSuccess) {
        for (final chat in buyerState.chatedUserList) {
          if (_doesChatMatch(chat, conversationId, itemOfferId, userId)) {
            final participants = chat.participants;
            if (participants != null && participants.isNotEmpty) {
              return participants
                  .map(
                    (participant) =>
                        ChatParticipant.fromJson(participant.toJson()),
                  )
                  .toList();
            }
            break;
          }
        }
      }
    } catch (_) {}

    try {
      final sellerState = context.read<GetSellerChatListCubit>().state;
      if (sellerState is GetSellerChatListSuccess) {
        for (final chat in sellerState.chatedUserList) {
          if (_doesChatMatch(chat, conversationId, itemOfferId, userId)) {
            final participants = chat.participants;
            if (participants != null && participants.isNotEmpty) {
              return participants
                  .map(
                    (participant) =>
                        ChatParticipant.fromJson(participant.toJson()),
                  )
                  .toList();
            }
            break;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  bool _doesChatMatch(
      ChatedUser chat, String conversationId, int itemOfferId, String userId) {
    final String candidateConversation =
        chat.conversationId ?? chat.itemOfferId?.toString() ?? '';
    if (conversationId.isNotEmpty && candidateConversation.isNotEmpty) {
      if (candidateConversation == conversationId) {
        return true;
      }
    }

    if (itemOfferId > 0 && chat.itemOfferId == itemOfferId) {
      return true;
    }

    if (userId.isNotEmpty) {
      final String buyerId = chat.buyerId?.toString() ?? '';
      final String sellerId = chat.sellerId?.toString() ?? '';
      if (buyerId == userId || sellerId == userId) {
        return true;
      }
    }

    return false;
  }

  Future<List<ChatParticipant>?> _fetchParticipantsFromRepository(
      String conversationId, int itemOfferId) async {
    final ChatRepostiory repository = ChatRepostiory();
    try {
      final ChatedUser? conversation =
          await repository.fetchConversationDetails(
        conversationId: conversationId,
        itemOfferId: itemOfferId > 0 ? itemOfferId : null,
      );
      if (conversation?.participants != null &&
          conversation!.participants!.isNotEmpty) {
        return conversation.participants!
            .map(
                (participant) => ChatParticipant.fromJson(participant.toJson()))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  void _markConversationAsRead() {
    if (widget.conversationId.isEmpty) return;
    try {
      context
          .read<GetBuyerChatListCubit>()
          .markConversationRead(widget.conversationId);
    } catch (_) {}
    try {
      context
          .read<GetSellerChatListCubit>()
          .markConversationRead(widget.conversationId);
    } catch (_) {}
  }

  void _handleChatSyncStream(List<ChatMessageModal> messages) {
    final String? userIdStr = HiveUtils.getUserId();
    final int? currentUserId = int.tryParse(userIdStr ?? '');
    if (currentUserId == null) {
      return;
    }

    final List<int> deliverIds = <int>[];
    final List<int> readIds = <int>[];

    for (final ChatMessageModal message in messages) {
      final int? messageId = message.id;
      if (messageId == null || messageId <= 0) {
        continue;
      }

      final int? senderId = message.senderId;
      if (senderId == null || senderId == currentUserId) {
        continue;
      }

      final String status = (message.status ?? '').toLowerCase();
      final bool deliveredKnown = (message.deliveredAt?.isNotEmpty ?? false) ||
          status == 'delivered' ||
          status == 'read';
      final bool readKnown =
          (message.readAt?.isNotEmpty ?? false) || status == 'read';

      if (!deliveredKnown) {
        deliverIds.add(messageId);
      }
      if (!readKnown) {
        readIds.add(messageId);
      }
    }

    if (deliverIds.isNotEmpty) {
      _chatSyncController.markDelivered(deliverIds);
    }
    if (readIds.isNotEmpty) {
      _chatSyncController.markRead(readIds);
    }
  }

  void _updateInputMode() {
    final bool hasText = controller.text.trim().isNotEmpty;
    showRecordButton = !hasText && messageAttachment == null;
  }

  String? _presenceLabel(BuildContext context) {
    final status = _otherParticipantStatus;
    if (status == null) {
      return null;
    }
    if (status.isTyping == true) {
      return "typingNow".translate(context);
    }
    if (status.isOnline == true) {
      return "onlineNow".translate(context);
    }
    final lastSeen = status.lastSeen;
    if (lastSeen != null && lastSeen.isNotEmpty) {
      try {
        final formatted = lastSeen.formatDate();
        final template = "lastSeenAt".translate(context);
        return template.contains('%s')
            ? template.replaceFirst('%s', formatted)
            : "$template $formatted";
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _isImageAttachmentPath(String? path) {
    if (path == null || path.isEmpty) {
      return false;
    }
    final clean = path.split('?').first.toLowerCase();
    const candidates = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return candidates.any((ext) => clean.endsWith(ext));
  }

  @override
  void dispose() {
    notificationStreamSubsctription.cancel();
    _notificationStatusTimer?.cancel();
    _notificationStatusController.close();
    controller.dispose();
    _feedbackController.dispose();
    _recordButtonAnimation.dispose();
    _pageScrollController.removeListener(_handleScroll);
    _pageScrollController.dispose();
    _presenceEventSubscription?.cancel();
    _chatMessagesSubscription?.cancel();

    if (_participantStatusListener != null) {
      NotificationService.participantStatusNotifier
          .removeListener(_participantStatusListener!);
    }

    _chatSyncController.onTypingChanged(false);
    unawaited(_chatSyncController.setPresenceOffline());
    _chatSyncController.dispose();
    currentlyChatingWith = '';
    currentlyChatItemId = '';

    NotificationService.clearParticipantStatus();
    super.dispose();
  }

  List<String> supportedImageTypes = [
    'jpeg',
    'jpg',
    'png',
    'gif',
    'webp',
    'animated_webp',
  ];

  void ratingsAlertDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,

      // Set to false if you don't want the dialog to close by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.color.secondaryColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Center(child: Text("rateSeller".translate(context))),
          content: BlocListener<AddItemReviewCubit, AddItemReviewState>(
            listener: (context, state) {
              if (state is AddItemReviewInSuccess) {
                Widgets.hideLoder(context);
                Navigator.pop(context);
                context
                    .read<GetBuyerChatListCubit>()
                    .updateAlreadyReview(int.parse(widget.itemId));
                HelperUtils.showSnackBarMessage(context, state.responseMessage);
              }
              if (state is AddItemReviewFailure) {
                Widgets.hideLoder(context);
                Navigator.pop(context);
                HelperUtils.showSnackBarMessage(
                    context, state.error.toString());
              }
              if (state is AddItemReviewInProgress) {
                Widgets.showLoader(context);
              }
            },
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStater) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('rateYourExperience'.translate(context))
                          .color(context.color.textLightColor),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(
                          5,
                          (index) => InkWell(
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 30,
                            ),
                            onTap: () {
                              setStater(() {
                                _rating = index + 1;
                              });
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _feedbackController,
                        decoration: InputDecoration(
                          hintText: 'shareYourExperience'.translate(context),
                          hintStyle:
                              TextStyle(color: context.color.textLightColor),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide:
                                BorderSide(color: context.color.territoryColor),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: BorderSide(
                              color:
                                  context.color.textLightColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          UiUtils.buildButton(context, onPressed: () {
                            _feedbackController.clear();
                            _rating = 0;
                            Navigator.of(context).pop();
                          },
                              buttonTitle: "cancelBtnLbl".translate(context),
                              radius: 8,
                              fontSize: 12,
                              width: context.screenWidth / 4,
                              textColor: context.color.textDefaultColor,
                              buttonColor: context.color.backgroundColor,
                              showElevation: false,
                              height: 39),
                          UiUtils.buildButton(context, showElevation: false,
                              onPressed: () {
                            context.read<AddItemReviewCubit>().addItemReview(
                                itemId: int.parse(widget.itemId),
                                rating: _rating,
                                review: _feedbackController.text.trim());
                          },
                              fontSize: 12,
                              disabled: _rating < 1,
                              disabledColor: context.color.deactivateColor,
                              buttonTitle: "submitBtnLbl".translate(context),
                              radius: 8,
                              width: context.screenWidth / 4,
                              textColor: context.color.secondaryColor,
                              buttonColor: context.color.territoryColor,
                              height: 39),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          /*actions: [

            */ /*ElevatedButton(
              onPressed: _rating >= 1
                  ? () {
                      context.read<AddItemReviewCubit>().addItemReview(
                          itemId: int.parse(widget.itemId),
                          rating: _rating,
                          review: _feedbackController.text.trim());
                    }
                  : null, // Disable button if rating is less than 1
              style: ElevatedButton.styleFrom(
                backgroundColor: _rating >= 1
                    ? context.color.territoryColor
                    : context.color.deactivateColor,
              ),
              child: Text("submitBtnLbl".translate(context)),
            ),*/ /*
          ],*/
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => buildChatScreen(context);

  Widget offerWidget() => buildOfferWidget();
}
