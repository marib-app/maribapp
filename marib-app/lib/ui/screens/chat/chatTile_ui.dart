part of 'chatTile.dart';

extension _ChatTileUi on ChatTile {

  String _timeLabel() {
    final source = lastMessage?.createdAt ?? date;
    if (source.isEmpty) return '';
    try {
      return source.formatDate(format: 'hh:mm aa');
    } catch (_) {
      return '';
    }
  }

  bool _looksLikeImage(String? path, String? messageType) {
    final type = messageType?.toLowerCase() ?? '';
    if (type.contains('image')) {
      return true;
    }
    if (path == null) {
      return false;
    }
    final cleanPath = path.split('?').first.toLowerCase();
    const candidates = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return candidates.any((ext) => cleanPath.endsWith(ext));
  }


  ParticipantStatus? _otherParticipantStatus() {
    if (participants == null || participants!.isEmpty) {
      return null;
    }

    final String currentId = HiveUtils.getUserId() ?? '';
    for (final participant in participants!) {
      final String participantId = participant.userId?.toString() ??
          participant.additionalData?['id']?.toString() ?? '';
      if (participantId.isEmpty || participantId == currentId) {
        continue;
      }
      final ParticipantStatus? status = participant.status;
      if (status != null) {
        return status;
      }
    }
    return null;
  }

  String? _presenceLabel(BuildContext context, ParticipantStatus? status) {
    if (status == null) {
      return null;
    }
    if (status.isTyping == true) {
      return "typingNow".translate(context);
    }
    if (status.isOnline == true) {
      return "onlineNow".translate(context);
    }
    final String? lastSeen = status.lastSeen;
    if (lastSeen != null && lastSeen.isNotEmpty) {
      try {
        final String formatted = lastSeen.formatDate();
        final String template = "lastSeenAt".translate(context);
        return template.contains('%s')
            ? template.replaceFirst('%s', formatted)
            : "$template $formatted";
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Widget? _buildPresenceBadge(
      BuildContext context, ParticipantStatus? status) {
    final String? label = _presenceLabel(context, status);
    if (label == null) {
      return null;
    }

    final bool isTyping = status?.isTyping == true;
    final bool isOnline = status?.isOnline == true;

    final Color foreground = isTyping
        ? context.color.territoryColor
        : (isOnline
        ? context.color.territoryColor
        : context.color.textLightColor);

    final Color background = isTyping
        ? context.color.territoryColor.withOpacity(0.12)
        : context.color.secondaryColor;

    final IconData icon = isTyping
        ? Icons.edit_note_rounded
        : (isOnline ? Icons.circle : Icons.access_time);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: context.font.smaller,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _previewText(BuildContext context) {
    final msg = lastMessage;
    if (msg == null) {
      return itemName;
    }

    final String userId = HiveUtils.getUserId() ?? '';
    final bool isMine = msg.senderId?.toString() == userId;
    final String prefix = isMine ? '${"chatYou".translate(context)}: ' : '';
    final String messageType = (msg.messageType ?? '').toLowerCase();
    if ((msg.audio ?? '').isNotEmpty || messageType.contains('audio')) {
      return prefix + "chatAttachmentAudio".translate(context);
    }
    if (_looksLikeImage(msg.file, msg.messageType)) {
      return prefix + "chatAttachmentImage".translate(context);
    }
    if ((msg.file ?? '').isNotEmpty) {
      return prefix + "chatAttachmentFile".translate(context);
    }
    final text = msg.message?.trim() ?? '';
    if (text.isNotEmpty) {
      return prefix + text;
    }
    return prefix + itemName;
  }


  Widget buildChatTile(BuildContext context) {

    final ParticipantStatus? presenceStatus = _otherParticipantStatus();
    final bool showOnlineIndicator = presenceStatus?.isOnline == true;
    final Widget? presenceBadge =
    _buildPresenceBadge(context, presenceStatus);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, BlurredRouter(
          builder: (context) {
            currentlyChatingWith = conversationId;
            currentlyChatItemId = itemOfferId.toString();
            return MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (context) => LoadChatMessagesCubit(),
                ),
                BlocProvider(
                  create: (context) => DeleteMessageCubit(),
                ),
              ],
              child: Builder(builder: (context) {
                return ChatScreen(
                  profilePicture: profilePicture,
                  itemTitle: itemName,
                  userId: id,
                  itemImage: itemPicture,
                  userName: userName,
                  itemId: itemId,
                  date: date,
                  itemOfferId: itemOfferId,
                  conversationId: conversationId,

                  itemPrice: itemPrice,
                  itemOfferPrice: itemAmount ?? null,
                  status: status,
                  buyerId: buyerId,
                  alreadyReview: alreadyReview,
                  isPurchased: isPurchased,

                  participants: participants,
                  lastMessage: lastMessage,
                  currency: itemCurrency,
                  currencySymbol: itemCurrencySymbol,

                );
              }),
            );
          },
        ));
      },
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 90),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: context.color.borderColor,
              width: 1.5,
            ),
          ),
          width: MediaQuery.of(context).size.width,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,

                  children: [
                    const SizedBox(
                      width: 58,
                      height: 58,
                    ),
                    GestureDetector(
                      onTap: () {
                        UiUtils.showFullScreenImage(context,
                            provider: CachedNetworkImageProvider(itemPicture));
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color: context.color.textDefaultColor
                                    .withOpacity(0.05))),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: UiUtils.getImage(
                            itemPicture,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    if (showOnlineIndicator)
                      PositionedDirectional(
                        bottom: 2,
                        end: 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: context.color.territoryColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.color.secondaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      end: 4,
                      bottom: -2,
                      child: GestureDetector(
                        onTap: () {
                          UiUtils.showFullScreenImage(context,
                              provider:
                              CachedNetworkImageProvider(profilePicture));
                        },
                        child: Container(
                          height: 24,
                          width: 24,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border:
                              Border.all(color: Colors.white, width: 1)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: profilePicture == ""
                                ? CircleAvatar(
                              radius: 18,
                              backgroundColor:
                              context.color.territoryColor,
                              child: SvgPicture.asset(AppIcons.profile,
                                  height: 15,
                                  width: 15,
                                  colorFilter: ColorFilter.mode(
                                      context.color.buttonColor,
                                      BlendMode.srcIn)),
                            )
                                : CircleAvatar(
                              radius: 15,
                              backgroundColor:
                              context.color.territoryColor,
                              backgroundImage:
                              NetworkImage(profilePicture),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [



                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                            ).bold().color(context.color.textColorDark),
                          ),
                          const SizedBox(width: 6),
                          Builder(builder: (context) {
                            final label = _timeLabel();
                            if (label.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Text(label)
                                .size(context.font.smaller)
                                .color(context.color.textLightColor);
                          })
                        ],
                      ),
                      const SizedBox(height: 4),




                      if (presenceBadge != null) ...[
                        presenceBadge,
                        const SizedBox(height: 6),
                      ],
                      Text(
                        itemName,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      )
                          .size(context.font.small)
                          .color(context.color.textColorDark.withOpacity(0.75)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _previewText(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ).color(context.color.textLightColor),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.color.territoryColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: TextStyle(
                                    color: context.color.buttonColor,
                                    fontSize: context.font.smaller,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]
                        ],
                      ),

                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}