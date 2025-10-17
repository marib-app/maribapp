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

  Widget _buildProfileAvatar(
      BuildContext context, ParticipantStatus? presenceStatus) {

    final borderColor = context.color.textDefaultColor.withOpacity(0.08);
    final bool hasProfileImage = profilePicture.trim().isNotEmpty;
    final bool isOnline = presenceStatus?.isOnline == true;
    final bool isTyping = presenceStatus?.isTyping == true;
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
        PositionedDirectional(
    bottom: -2,
    end: -2,
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.color.secondaryColor,
        boxShadow: [
          BoxShadow(
            color: context.color.textDefaultColor.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isTyping || isOnline
                    ? context.color.territoryColor
                    : context.color.textLightColor.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTyping
                    ? Icons.edit_note_rounded
                    : (isOnline
                    ? Icons.check_rounded
                    : Icons.lock_outline_rounded),
                size: isTyping ? 14 : 12,
                color: isTyping || isOnline
                    ? context.color.buttonColor
                    : context.color.textColorDark.withOpacity(0.7),
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
      return ShimmerBox(
        width: 44,
        height: 44,
        borderRadius: BorderRadius.circular(10),
        animate: false,
        baseColor: context.color.territoryColor.withOpacity(0.1),
        highlightColor: context.color.territoryColor.withOpacity(0.2),
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
    Widget preview = _buildAdImage(context);
    if (hasImage) {
      preview = GestureDetector(
        onTap: () {
          UiUtils.showFullScreenImage(
            context,
            provider: CachedNetworkImageProvider(itemPicture),
          );
        },
        child: preview,
      );
    }

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.color.territoryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.territoryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          preview,
          const SizedBox(width: 10),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
                  .bold()
                  .size(context.font.small)
                  .color(context.color.textColorDark),
              if (price != null) ...[
          const SizedBox(height: 4),
      Text(price)
          .size(context.font.smaller)
          .color(context.color.textLightColor),
                ],
                ],
              ),
          ),
          ],
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

    final Widget? unreadBadge = _buildUnreadBadge(context);
    final Widget? adCard = _buildAdCard(context);
    final String timeLabel = _timeLabel();
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
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.color.textDefaultColor.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: context.color.textDefaultColor.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
                    _buildProfileAvatar(context, presenceStatus),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                              .bold()
                              .size(context.font.large)
                              .color(context.color.textColorDark),
                          const SizedBox(height: 6),
                          Text(
                            _previewText(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                              .size(context.font.normal)
                              .color(context.color.textLightColor),
                          if (timeLabel.isNotEmpty || unreadBadge != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (timeLabel.isNotEmpty)
                                  Text(timeLabel)
                                      .size(context.font.smaller)
                                      .color(context.color.textLightColor),
                                if (timeLabel.isNotEmpty && unreadBadge != null)
                                  const SizedBox(width: 8),
                                if (unreadBadge != null) unreadBadge,
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (adCard != null) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: context.color.textDefaultColor.withOpacity(0.08),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: adCard,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
