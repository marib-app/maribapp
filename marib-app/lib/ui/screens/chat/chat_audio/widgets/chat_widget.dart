// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'dart:async';

import 'dart:io';

import 'package:any_link_preview/any_link_preview.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/data/cubits/chat/send_message.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/ui/screens/chat/chat_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/chat_message_handler.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:marib/utils/notification/notification_service.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marib/data/cubits/chat/chat_message_tracker.dart';

part "parts/attachment.part.dart";

part "parts/linkpreview.part.dart";

part "parts/recordmsg.part.dart";

////Please don't make changes without sufficent knowledege in this file. otherwise you will be responsable for it
///
//This will store and ensure that msg is already sent so we don't have to send it again

class ChatMessage extends StatefulWidget {
  final int? id;
  final int senderId;
  final int itemOfferId;
  final String message;
  final String file;
  final String audio;
  final String createdAt;
  final String updatedAt;
  final String? messageType;
  final bool? isSentNow;
  final String? status;
  final String? deliveredAt;
  final String? readAt;

  const ChatMessage(
      {super.key,
      this.id,
      required this.senderId,
      required this.itemOfferId,
        String? message,
        String? file,
        String? audio,
      required this.createdAt,
      required this.updatedAt,
      this.messageType,
        this.isSentNow,
        this.status,
        this.deliveredAt,
        this.readAt})
      : message = message ?? '',
        file = file ?? '',
        audio = audio ?? '';

  Map toJson() {
    Map data = {};

    data['key'] = key;
    data['id'] = this.id;
    data['sender_id'] = this.senderId;
    data['item_offer_id'] = this.itemOfferId;
    data['message'] = message;
    data['file'] = file;
    data['audio'] = audio;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['is_sent_now'] = this.isSentNow;
    data['message_type'] = this.messageType;
    data['status'] = status;
    data['delivered_at'] = deliveredAt;
    data['read_at'] = readAt;
    return data;
  }

  factory ChatMessage.fromJson(Map json) {
    var chat = ChatMessage(
        key: json['key'],
        id: json['id'],
        senderId: json['sender_id'],
        itemOfferId: json['item_offer_id'],
        message: json['message'],
        file: json['file'],
        audio: json['audio'],
        createdAt: json['created_at'],
        updatedAt: json['updated_at'],
        isSentNow: json['is_sent_now'],
        messageType: json['message_type'],
        status: json['status'],
        deliveredAt: json['delivered_at'],
        readAt: json['read_at']);

    return chat;
  }

  @override
  State<ChatMessage> createState() => ChatMessageState();
}

class ChatMessageState extends State<ChatMessage>
    with AutomaticKeepAliveClientMixin {
  bool isChatSent = false;
  bool selectedMessage = false;
  static bool isMounted = false;
  bool _sendFailed = false;
  String? link;
  final ValueNotifier _linkAddNotifier = ValueNotifier("");
  String? _currentStatus;
  String? _currentDeliveredAt;
  String? _currentReadAt;
  StreamSubscription<ChatMessageStatusUpdate>? _statusSubscription;


  @override
  void initState() {

    _currentStatus = widget.status;
    _currentDeliveredAt = widget.deliveredAt;
    _currentReadAt = widget.readAt;
    _listenForStatusUpdates();

    if (widget.senderId.toString() == HiveUtils.getUserId() &&
        (widget.isSentNow == true) &&
        isChatSent == false) {
      final tracker = ChatMessageTracker.instance;
      if (!tracker.contains(widget.key)) {

        context.read<SendMessageCubit>().send(
              attachment: widget.file,
              message: widget.message,
              itemOfferId: widget.itemOfferId,
              audio: widget.audio,
            );
      }
      tracker.track(widget.key);

      isMounted = true;
    }

    super.initState();
  }

  @override
  void dispose() {
    ChatMessageTracker.instance.remove(widget.key);
    _statusSubscription?.cancel();

    super.dispose();
  }

  void _listenForStatusUpdates() {
    _statusSubscription?.cancel();
    final int? messageId = widget.id;
    if (messageId == null) {
      return;
    }
    _statusSubscription =
        NotificationService.messageStatusStream.listen((update) {
          if (update.messageId != messageId) {
            return;
          }
          if (!mounted) {
            _currentStatus = update.status ?? _currentStatus;
            _currentDeliveredAt =
                update.deliveredAt ?? _currentDeliveredAt;
            _currentReadAt = update.readAt ?? _currentReadAt;
            return;
          }
          setState(() {
            _currentStatus = update.status ?? _currentStatus;
            _currentDeliveredAt =
                update.deliveredAt ?? _currentDeliveredAt;
            _currentReadAt = update.readAt ?? _currentReadAt;
          });
        });
  }

  @override
  void didUpdateWidget(covariant ChatMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      _listenForStatusUpdates();
    }
    if (widget.status != oldWidget.status ||
        widget.deliveredAt != oldWidget.deliveredAt ||
        widget.readAt != oldWidget.readAt) {
      if (!mounted) {
        _currentStatus = widget.status ?? _currentStatus;
        _currentDeliveredAt = widget.deliveredAt ?? _currentDeliveredAt;
        _currentReadAt = widget.readAt ?? _currentReadAt;
        return;
      }
      setState(() {
        _currentStatus = widget.status ?? _currentStatus;
        _currentDeliveredAt = widget.deliveredAt ?? _currentDeliveredAt;
        _currentReadAt = widget.readAt ?? _currentReadAt;
      });
    }
  }



  bool get _isSentByMe =>
      widget.senderId.toString() == HiveUtils.getUserId();

  bool get _isRead =>
      (_currentReadAt?.isNotEmpty ?? false) ||
          (_currentStatus?.toLowerCase() == 'read');

  bool get _isDelivered => _isRead ||
      (_currentDeliveredAt?.isNotEmpty ?? false) ||
      (_currentStatus?.toLowerCase() == 'delivered');

  bool get _isSent => _isDelivered ||
      (_currentStatus?.toLowerCase() == 'sent') ||
      (widget.id != null && widget.id! > 0);

  Widget? _buildStatusIcon(BuildContext context) {
    if (!_isSentByMe) {
      return null;
    }

    if (widget.isSentNow == true) {
      if (_sendFailed) {
        return Icon(
          Icons.error,
          size: context.font.smaller,
          color: context.color.primaryColor,
        );
      }
      return Icon(
        Icons.check,
        size: context.font.smaller,
        color: context.color.textLightColor,
      );
    }

    if (_sendFailed) {
      return Icon(
        Icons.error,
        size: context.font.smaller,
        color: context.color.primaryColor,
      );
    }

    if (_isRead) {
      return Icon(
        Icons.done_all,
        size: context.font.smaller,
        color: context.color.primaryColor,
      );
    }

    if (_isDelivered) {
      return Icon(
        Icons.done_all,
        size: context.font.smaller,
        color: context.color.textLightColor,
      );
    }

    if (_isSent) {
      return Icon(
        Icons.check,
        size: context.font.smaller,
        color: context.color.textLightColor,
      );
    }

    return null;
  }


  String _emptyTextIfAttachmentHasNoText() {
    if (widget.file.isNotEmpty) {
      if (widget.message == "[File]") {
        return "";

      }

      return widget.message;
    }

    if (widget.message.isEmpty) {

      return "";
    }
    return widget.message;

  }

  bool _isLink(String input) {
    ///This will check if text contains link
    final matcher = RegExp(
        r"(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)");
    return matcher.hasMatch(input);
  }

  List _replaceLink() {
    //This function will make part of text where link starts. we put invisible charector so we can split it with it
    final linkPattern = RegExp(
        r"(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)");

    ///This is invisible charector [You can replace it with any special charector which generally nobody use]
    const String substringIdentifier = "‎";

    ///This will find and add invisible charector in prefix and suffix
    String splitMapJoin = _emptyTextIfAttachmentHasNoText().splitMapJoin(
      linkPattern,
      onMatch: (match) {
        final String matchedText = match.group(0) ?? '';
        return substringIdentifier + matchedText + substringIdentifier;


        },
      onNonMatch: (match) {
        return match;
      },
    );
    //finally we split it with invisible charector so it will become list
    return splitMapJoin.split(substringIdentifier);
  }

  List<String> _matchAstric(String data) {
    var pattern = RegExp(r"\*(.*?)\*");

    String mapJoin = data.splitMapJoin(
      pattern,
      onMatch: (p0) {
        final String matchText = p0.group(0) ?? '';
        return "‎$matchText‎";
      },
      onNonMatch: (p0) {
        return p0;
      },
    );

    return mapJoin.split("‎");
  }


  String _formattedTimestamp() {
    final DateTime? parsedDate = DateTime.tryParse(widget.createdAt);
    if (parsedDate == null) {
      return '';
    }

    return parsedDate
        .toLocal()
        .toIso8601String()
        .formatDate(format: "hh:mm aa");
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);

    bool isDark =
        context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;
    final Widget? statusIcon = _buildStatusIcon(context);

    return GestureDetector(
      onLongPress: () {
        selectedMessageid.value = (widget.key as ValueKey).value;
        showDeletebutton.value = true;
      },
      onTap: () {
        selectedMessage = false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Container(
          alignment: widget.senderId.toString() == HiveUtils.getUserId()
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          width: MediaQuery.of(context).size.width,
          margin: EdgeInsetsDirectional.only(
            // top: MediaQuery.of(context).size.height * 0.007,
            end: widget.senderId.toString() == HiveUtils.getUserId() ? 20 : 0,
            start: widget.senderId.toString() == HiveUtils.getUserId() ? 0 : 20,
          ),
          child: Column(
            crossAxisAlignment:
                widget.senderId.toString() == HiveUtils.getUserId()
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
            children: [
              Container(
                constraints:
                    BoxConstraints(maxWidth: context.screenWidth * 0.74),
                decoration: BoxDecoration(
                    color: selectedMessage == true
                        ? (widget.senderId.toString() == HiveUtils.getUserId()
                            ? context.color.territoryColor.darken(45)
                            : context.color.secondaryColor.darken(45))
                        : (widget.senderId.toString() == HiveUtils.getUserId()
                            ? context.color.territoryColor.withOpacity(0.3)
                            : context.color.secondaryColor),
                    borderRadius: BorderRadius.circular(8)

                    // BorderRadius.only(
                    //   topRight: widget.isSentByMe
                    //       ? Radius.zero
                    //       : const Radius.circular(10),
                    //   topLeft: widget.isSentByMe
                    //       ? const Radius.circular(10)
                    //       : Radius.zero,
                    //   bottomLeft: const Radius.circular(10),
                    //   bottomRight: const Radius.circular(10),
                    // ),
                    ),
                child: Wrap(
                  runAlignment: WrapAlignment.end,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        child: widget.audio.isNotEmpty
                            ? RecordMessage(
                          url: widget.audio,
                                isSentByMe: widget.senderId.toString() ==
                                    HiveUtils.getUserId(),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.file.isNotEmpty)
                                    AttachmentMessage(url: widget.file),

                                  //This is preview builder for image
                                  ValueListenableBuilder(
                                      valueListenable: _linkAddNotifier,
                                      builder: (context, dynamic value, c) {
                                        if (value == null) {
                                          return const SizedBox.shrink();
                                        }

                                        return FutureBuilder(
                                          future: AnyLinkPreview.getMetadata(
                                              link: value),
                                          builder: (context,
                                              AsyncSnapshot snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.done) {
                                              if (snapshot.data == null) {
                                                return const SizedBox.shrink();
                                              }
                                              return LinkPreviw(
                                                snapshot: snapshot,
                                                link: value,
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        );
                                      }),
                                  SelectableText.rich(
                                    TextSpan(
                                      style: TextStyle(
                                          color: (isDark &&
                                                  widget.senderId.toString() !=
                                                      HiveUtils.getUserId())
                                              ? context.color.buttonColor
                                              : context.color.textDefaultColor),
                                      children: _replaceLink().map((data) {
                                        //This will add link to msg
                                        if (_isLink(data)) {
                                          //This will notify priview object that it has link
                                          _linkAddNotifier.value = data;
                                          _linkAddNotifier.notifyListeners();

                                          return TextSpan(
                                              text: data,
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () async {
                                                  await launchUrl(
                                                      Uri.parse(data));
                                                },
                                              style: TextStyle(
                                                  decoration:
                                                      TextDecoration.underline,
                                                  color: Colors.blue[800]));
                                        }
                                        //This will make text bold
                                        return TextSpan(
                                          text: "",
                                          children:
                                              _matchAstric(data).map((text) {
                                            if (text
                                                    .toString()
                                                    .startsWith("*") &&
                                                text.toString().endsWith("*")) {
                                              return TextSpan(
                                                  text:
                                                      text.replaceAll("*", ""),
                                                  style: TextStyle(
                                                      color: (isDark &&
                                                              widget.senderId
                                                                      .toString() !=
                                                                  HiveUtils
                                                                      .getUserId())
                                                          ? context
                                                              .color.buttonColor
                                                          : context.color
                                                              .textDefaultColor,
                                                      fontWeight:
                                                          FontWeight.w800));
                                            }

                                            return TextSpan(
                                                text: text,
                                                style: TextStyle(
                                                    color: (isDark &&
                                                            widget.senderId
                                                                    .toString() !=
                                                                HiveUtils
                                                                    .getUserId())
                                                        ? context
                                                            .color.buttonColor
                                                        : context.color
                                                            .textDefaultColor));
                                          }).toList(),
                                          style: TextStyle(
                                              color: widget.senderId
                                                          .toString() ==
                                                      HiveUtils.getUserId()
                                                  ? context.color.secondaryColor
                                                  : context
                                                      .color.textColorDark),
                                        );
                                      }).toList(),
                                    ),
                                    style: TextStyle(
                                        color: (isDark &&
                                                widget.senderId.toString() !=
                                                    HiveUtils.getUserId())
                                            ? context.color.buttonColor
                                            : context.color.textDefaultColor),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_isSentByMe && (widget.isSentNow == true)) ...[

                      BlocConsumer<SendMessageCubit, SendMessageState>(
                        listener: (context, state) {
                          if (state is SendMessageSuccess) {
                            isChatSent = true;
                            _sendFailed = false;

                            ///Value which we added locally
                            final ValueKey? uniqueIdentifier =
                                widget.key as ValueKey?;

                            ////We were added local id so whenit completed we will replace it with server message id
                            final Object? identifierValue =
                                uniqueIdentifier?.value;
                            if (identifierValue != null) {
                              ChatMessageHandler.updateMessageId(
                                identifierValue.toString(),
                                state.messageId,
                              );
                            }

                            WidgetsBinding.instance
                                .addPostFrameCallback((timeStamp) {
                              if (!mounted) {
                                return;
                              }
                              setState(() {});
                            });
                          }
                          if (state is SendMessageFailed) {
                            _sendFailed = true;
                            if (mounted) {
                              setState(() {});
                            }
                            HelperUtils.showSnackBarMessage(
                                context, state.error.toString());
                            return;
                          }
                          if (state is SendMessageInProgress) {
                            if (_sendFailed) {
                              _sendFailed = false;
                              if (mounted) {
                                setState(() {});
                              }
                            }
                          }
                        },
                        builder: (context, state) => const SizedBox.shrink(),
                      )
                    ]
                  ],
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(end: 3.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: _isSentByMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Text(
                      _formattedTimestamp(),
                      style: TextStyle(
                        color: context.color.textLightColor,
                      ),
                    ).size(context.font.smaller),
                    if (statusIcon != null) ...[
                      const SizedBox(width: 4),
                      statusIcon,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
