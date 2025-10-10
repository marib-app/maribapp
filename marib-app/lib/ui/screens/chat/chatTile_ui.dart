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
          participant.additionalData?['id']?.toString() ??
          '';
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

  Widget? _buildPresenceBadge(BuildContext context, ParticipantStatus? status) {
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

  String? _priceLabel() {
    final double rawPrice = itemAmount ?? itemPrice;
    if (rawPrice <= 0) {
      return null;
    }

    final String formatted = HelperUtils.formatPrice(rawPrice);
    if (formatted.isEmpty) {
      return null;
    }

    final String currency = (itemCurrencySymbol ?? itemCurrency ?? '').trim();
    if (currency.isEmpty) {
      return formatted;
    }
    return '$formatted $currency';
  }

  Widget _buildProfileAvatar(BuildContext context, bool showOnlineIndicator) {
    final borderColor = context.color.textDefaultColor.withOpacity(0.08);
    final bool hasProfileImage = profilePicture.trim().isNotEmpty;

    Widget avatar;
    if (!hasProfileImage) {
      avatar = Container(
        color: context.color.territoryColor.withOpacity(0.12),
        child: Center(
          child: SvgPicture.asset(
            AppIcons.profile,
            height: 20,
            width: 20,
            colorFilter:
                ColorFilter.mode(context.color.territoryColor, BlendMode.srcIn),
          ),
        ),
      );
    } else {
      avatar = UiUtils.getImage(
        profilePicture,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
      );
    }

    final widget = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: avatar,
          ),
        ),
        if (showOnlineIndicator)
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: context.color.territoryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.color.secondaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );

    if (!hasProfileImage) {
      return widget;
    }

    return GestureDetector(
      onTap: () {
        UiUtils.showFullScreenImage(
          context,
          provider: CachedNetworkImageProvider(profilePicture),
        );
      },
      child: widget,
    );
  }

  Widget _buildAdImage(BuildContext context) {
    if (itemPicture.trim().isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.color.territoryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: SvgPicture.asset(
            AppIcons.placeHolder,
            width: 28,
            height: 28,
            colorFilter: ColorFilter.mode(
              context.color.textLightColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: UiUtils.getImage(
        itemPicture,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget? _buildAdCard(BuildContext context) {
    if (itemName.trim().isEmpty && itemPicture.trim().isEmpty) {
      return null;
    }

    final String? price = _priceLabel();
    final bool hasImage = itemPicture.trim().isNotEmpty;
    final Widget imagePreview = hasImage
        ? GestureDetector(
            onTap: () {
              UiUtils.showFullScreenImage(
                context,
                provider: CachedNetworkImageProvider(itemPicture),
              );
            },
            child: _buildAdImage(context),
          )
        : _buildAdImage(context);

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.color.borderColor.withOpacity(0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.color.textDefaultColor.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            imagePreview,
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ).bold().color(context.color.textColorDark),
                  if (price != null) ...[
                    const SizedBox(height: 6),
                    Text(price)
                        .size(context.font.smaller)
                        .color(context.color.textLightColor),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget? _buildUnreadBadge(BuildContext context) {
    if (unreadCount <= 0) {
      return null;
    }

    final String label = unreadCount > 99 ? '99+' : unreadCount.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.color.territoryColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.color.buttonColor,
          fontSize: context.font.smaller,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildChatTile(BuildContext context) {
    final ParticipantStatus? presenceStatus = _otherParticipantStatus();
    final bool showOnlineIndicator = presenceStatus?.isOnline == true;
    final Widget? presenceBadge = _buildPresenceBadge(context, presenceStatus);
    final Widget? unreadBadge = _buildUnreadBadge(context);
    final Widget? adCard = _buildAdCard(context);
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
          constraints: const BoxConstraints(minHeight: 120),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.color.borderColor,
              width: 1.5,
            ),
          ),
          width: MediaQuery.of(context).size.width,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileAvatar(context, showOnlineIndicator),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  userName,
                                  maxLines: 1,
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
                              }),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (presenceBadge != null) ...[
                            presenceBadge,
                            const SizedBox(height: 6),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _previewText(context),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ).color(context.color.textLightColor),
                              ),
                              if (unreadBadge != null) ...[
                                const SizedBox(width: 8),
                                unreadBadge,
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (adCard != null) ...[
                  const SizedBox(height: 14),
                  adCard,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
