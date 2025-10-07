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
          height: 90,
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
