part of 'chat_screen.dart';

extension _ChatScreenUi on _ChatScreenState {
  String _resolveCurrencySymbol() {
    final symbol = widget.currencySymbol?.trim();
    if (symbol != null && symbol.isNotEmpty) {
      return symbol;
    }
    final code = widget.currency?.trim();
    if (code != null && code.isNotEmpty) {
      return code;
    }
    final fallback = Constant.currencySymbol;
    if (fallback.trim().isNotEmpty) {
      return fallback;
    }
    return '';
  }

  String _formatPriceWithCurrency(num price, String currency) {
    final String formatted = HelperUtils.formatPrice(price);
    final String priceLabel = formatted.isEmpty ? '—' : formatted;
    final String trimmedCurrency = currency.trim();
    if (trimmedCurrency.isEmpty) {
      return priceLabel;
    }
    final bool containsLetter = RegExp(r'[A-Za-z]').hasMatch(trimmedCurrency);
    if (containsLetter) {
      return '$priceLabel $trimmedCurrency';
    }
    return '$trimmedCurrency $priceLabel';
  }

  Widget buildChatScreen(BuildContext context) {
    var chatBackground = "assets/chat_background/light.svg";

    final presenceText = _presenceLabel(context);
    final bool isOnline = _otherParticipantStatus?.isOnline == true;
    // شارة خضراء عند الاتصال، رمادية عند عدمه
    final Color presenceColor = isOnline ? Colors.green : Colors.grey;
    final resolvedCurrencySymbol = _resolveCurrencySymbol();
    final bool hideListingCard = widget.from == "wifi";

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: Colors.transparent,
      ),
      child: PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          currentlyChatingWith = "";
          _clearSelection();
          currentlyChatItemId = "";
          notificationStreamSubsctription.cancel();
          ChatMessageHandler.flushMessages();
          return;
        },
        child: SafeArea(
          top: false, // مهم عشان ما يضيف فراغ أسود فوق الـ AppBar
          child: Scaffold(
            backgroundColor: context.color.backgroundColor,
            bottomNavigationBar: _ChatBottomBar(state: this),
            appBar: AppBar(
              centerTitle: false,
              automaticallyImplyLeading: false,
              toolbarHeight: 60, // زيادة بسيطة في ارتفاع الـ AppBar
              systemOverlayStyle: UiUtils.getSystemUiOverlayStyle(
                context: context,
                statusBarColor: Colors.transparent,
              ),
              leading: Material(
                clipBehavior: Clip.antiAlias,
                color: Colors.transparent,
                type: MaterialType.circle,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 15),
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: RotatedBox(
                        quarterTurns:
                            Directionality.of(context) == TextDirection.rtl
                                ? 2
                                : -4,
                        child: UiUtils.getSvg(
                          AppIcons.arrowLeft,
                          fit: BoxFit.none,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              backgroundColor: context.color.secondaryColor,
              elevation: 0,
              iconTheme: IconThemeData(color: context.color.territoryColor),
              bottom: hideListingCard
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(70),
                      child: _ChatHeader(
                        state: this,
                        presenceText: presenceText,
                        presenceColor: presenceColor,
                        resolvedCurrencySymbol: resolvedCurrencySymbol,
                      ),
                    ),
              actions: [
                MultiBlocProvider(
                  providers: [
                    BlocProvider(create: (context) => UnblockUserCubit()),
                    BlocProvider(create: (context) => BlockUserCubit()),
                  ],
                  child: Builder(
                    builder: (context) {
                      // ← هنا تتحكم يدويًا في مكان الزر أفقيًا
                      // قيمة موجبة تحركه لليمين (في LTR) وسالبة لليسار
                      const double blockButtonOffsetX = 4.0;

                      return BlocListener<BlockUserCubit, BlockUserState>(
                        listener: (context, blockState) {
                          if (blockState is BlockUserSuccess) {
                            context
                                .read<BlockedUsersListCubit>()
                                .addBlockedUser(
                                  BlockedUserModel(
                                    id: int.parse(widget.userId),
                                    name: widget.userName,
                                    profile: widget.profilePicture,
                                  ),
                                );
                            HelperUtils.showSnackBarMessage(
                                context, blockState.message);
                          } else if (blockState is BlockUserFail) {
                            HelperUtils.showSnackBarMessage(
                                context, blockState.error.toString());
                          }
                        },
                        child: BlocListener<UnblockUserCubit, UnblockUserState>(
                          listener: (context, unblockState) {
                            if (unblockState is UnblockUserSuccess) {
                              context
                                  .read<BlockedUsersListCubit>()
                                  .unblockUser(int.parse(widget.userId));
                              HelperUtils.showSnackBarMessage(
                                  context, unblockState.message);
                            } else if (unblockState is UnblockUserFail) {
                              HelperUtils.showSnackBarMessage(
                                  context, unblockState.error.toString());
                            }
                          },
                          child: BlocConsumer<BlockedUsersListCubit,
                              BlockedUsersListState>(
                            listener: (context, state) {},
                            builder: (context, blockedUsersListState) {
                              final bool isBlocked = context
                                  .read<BlockedUsersListCubit>()
                                  .isUserBlocked(int.parse(widget.userId));

                              final String label = isBlocked
                                  ? "unBlockLbl".translate(context)
                                  : "blockLbl".translate(context);

                              final Color iconColor = isBlocked
                                  ? Colors.greenAccent.shade400
                                  : Colors.redAccent.shade200;

                              return Padding(
                                // قلّل/كبّر end لو حاب تعدّل المارجن كمان
                                padding:
                                    const EdgeInsetsDirectional.only(end: 14.0),
                                child: Transform.translate(
                                  offset: Offset(blockButtonOffsetX, 0),
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      minimumSize: const Size(0, 0),
                                      foregroundColor:
                                          context.color.textDefaultColor,
                                    ),
                                    onPressed: () async {
                                      if (!isBlocked) {
                                        final block =
                                            await UiUtils.showBlurredDialoge(
                                          context,
                                          dialoge: BlurredDialogBox(
                                            acceptButtonName:
                                                "blockLbl".translate(context),
                                            title:
                                                "${"blockLbl".translate(context)}\t${widget.userName}?",
                                            content: Text(
                                              "blockWarning".translate(context),
                                            ),
                                          ),
                                        );
                                        if (block == true) {
                                          Future.delayed(Duration.zero, () {
                                            context
                                                .read<BlockUserCubit>()
                                                .blockUser(
                                                  blockUserId:
                                                      int.parse(widget.userId),
                                                );
                                          });
                                        }
                                      } else {
                                        final unBlock =
                                            await UiUtils.showBlurredDialoge(
                                          context,
                                          dialoge: BlurredDialogBox(
                                            acceptButtonName:
                                                "unBlockLbl".translate(context),
                                            content: Text(
                                              "${"unBlockLbl".translate(context)}\t${widget.userName}\t${"toSendMessage".translate(context)}"
                                                  .translate(context),
                                            ),
                                          ),
                                        );
                                        if (unBlock == true) {
                                          Future.delayed(Duration.zero, () {
                                            context
                                                .read<UnblockUserCubit>()
                                                .unBlockUser(
                                                  blockUserId:
                                                      int.parse(widget.userId),
                                                );
                                          });
                                        }
                                      }
                                    },
                                    icon: Icon(
                                      isBlocked
                                          ? Icons.lock_open_rounded
                                          : Icons.block_rounded,
                                      size: 18,
                                      color: iconColor,
                                    ),
                                    label: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: context.font.smaller,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              title: FittedBox(
                fit: BoxFit.none,
                child: Row(
                  children: [
                    widget.profilePicture == ""
                        ? CircleAvatar(
                            backgroundColor: context.color.territoryColor,
                            child: SvgPicture.asset(
                              AppIcons.profile,
                              colorFilter: ColorFilter.mode(
                                context.color.buttonColor,
                                BlendMode.srcIn,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                TransparantRoute(
                                  barrierDismiss: true,
                                  builder: (context) {
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      child: Stack(
                                        children: [
                                          Container(
                                            color: const Color.fromARGB(
                                                69, 0, 0, 0),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            child: CustomImageHeroAnimation(
                              type: CImageType.Network,
                              image: widget.profilePicture,
                              child: CircleAvatar(
                                backgroundImage: CachedNetworkImageProvider(
                                  widget.profilePicture,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {},
                      child: SizedBox(
                        width: context.screenWidth * 0.45,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.userName)
                                .color(context.color.textColorDark)
                                .size(context.font.normal),
                            if (presenceText != null && presenceText.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: presenceColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(presenceText)
                                        .size(context.font.smaller)
                                        .color(presenceColor),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: BlocProvider(
              create: (context) => AddItemReviewCubit(),
              child: Stack(
                children: [
                  SvgPicture.asset(
                    chatBackground,
                    height: MediaQuery.of(context).size.height,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width,
                  ),
                  BlocListener<DeleteMessageCubit, DeleteMessageState>(
                    listener: (context, state) {
                      if (state is DeleteMessageSuccess) {
                        ChatMessageHandler.removeMessage(state.id);
                        _clearSelection();
                      }
                    },
                    child: GestureDetector(
                      onTap: () {
                        _clearSelection();
                      },
                      child: BlocConsumer<LoadChatMessagesCubit,
                          LoadChatMessagesState>(
                        listener: (context, state) {
                          if (state is LoadChatMessagesSuccess) {
                            ChatMessageHandler.loadMessages(state.messages);
                            if (_shouldRestoreScrollAfterLoadMore &&
                                !state.isLoadingMore) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!_pageScrollController.hasClients) {
                                  return;
                                }
                                final position = _pageScrollController.position;
                                final double newMax = position.maxScrollExtent;
                                final double prevMax =
                                    _maxScrollExtentBeforeLoadMore;
                                final double savedOffset =
                                    scrollPositionWhenLoadMore;
                                // Maintain distance from bottom when more items are prepended.
                                double offsetFromEnd = prevMax - savedOffset;
                                if (!offsetFromEnd.isFinite ||
                                    offsetFromEnd < 0) {
                                  offsetFromEnd = 0;
                                }
                                double targetOffset = newMax - offsetFromEnd;
                                if (!targetOffset.isFinite) {
                                  targetOffset = savedOffset;
                                }
                                targetOffset = targetOffset.clamp(
                                  position.minScrollExtent,
                                  newMax,
                                );
                                _pageScrollController.jumpTo(targetOffset);
                              });
                              _shouldRestoreScrollAfterLoadMore = false;
                              scrollPositionWhenLoadMore = 0;
                              _maxScrollExtentBeforeLoadMore = 0;
                            }

                            _loadMoreRequestInFlight = false;
                          }
                          if (state is LoadChatMessagesFailed) {
                            _shouldRestoreScrollAfterLoadMore = false;
                            scrollPositionWhenLoadMore = 0;
                            _maxScrollExtentBeforeLoadMore = 0;
                            _loadMoreRequestInFlight = false;
                          }
                        },
                        builder: (context, state) {
                          return Stack(
                            children: [
                              StreamBuilder<List<ChatMessageModal>>(
                                stream: ChatMessageHandler.getChatStream(),
                                builder: (context,
                                    AsyncSnapshot<List<ChatMessageModal>>
                                        snapshot) {
                                  final bool isLoadingMore =
                                      state is LoadChatMessagesSuccess &&
                                          state.isLoadingMore;
                                  final Widget loadMoreBanner = SizedBox(
                                    height: 28,
                                    child: isLoadingMore
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text("loading".translate(context)),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  );

                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      !snapshot.hasData) {
                                    return loadMoreBanner;
                                  }

                                  // Filter the global chat stream to only messages
                                  // that belong to this conversation (by participants
                                  // and item/itemOffer identifiers). The ChatMessageHandler
                                  // is global and may contain messages for other chats,
                                  // so filter here to avoid cross-chat duplicates.
                                  final List<ChatMessageModal> allMessages =
                                      snapshot.data ?? <ChatMessageModal>[];
                                  final int currentUserId = int.tryParse(
                                          HiveUtils.getUserId() ?? '') ??
                                      0;
                                  final int otherUserId =
                                      int.tryParse(widget.userId) ?? 0;
                                  final int widgetItemOfferId =
                                      widget.itemOfferId;
                                  final int widgetItemId =
                                      int.tryParse(widget.itemId) ?? 0;

                                  final List<ChatMessageModal> messages =
                                      allMessages.where((m) {
                                    final int mOffer = m.itemOfferId ?? 0;
                                    final int mItem = m.itemId ?? 0;
                                    final int s = m.senderId ?? 0;
                                    final int r = m.receiverId ?? 0;

                                    // If this chat is tied to an itemOfferId, require it to match.
                                    if (widgetItemOfferId > 0) {
                                      if (mOffer != widgetItemOfferId)
                                        return false;
                                    } else if (widgetItemId > 0) {
                                      // Otherwise, require itemId match when available.
                                      if (mItem != widgetItemId) return false;
                                    }

                                    // Looser participant matching: accept messages where either
                                    // sender or receiver matches current user or the other user.
                                    // Remote messages sometimes omit receiver/sender fields or
                                    // use different conventions; strict pair-matching filtered
                                    // out valid server messages. This looser rule preserves
                                    // server (checked) messages while still filtering unrelated chats.
                                    final bool participantsMatch =
                                        s == currentUserId ||
                                            r == currentUserId ||
                                            s == otherUserId ||
                                            r == otherUserId;

                                    if (!participantsMatch) return false;

                                    return true;
                                  }).toList();

                                  if (messages.isEmpty) {
                                    return offerWidget();
                                  }

                                  final List<_ChatListEntry> renderItems =
                                      _buildRenderableMessages(
                                          messages, context);

                                  // إصلاح الـ Column: يجب أن يكون max وليس min مع Expanded
                                  return Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      loadMoreBanner,
                                      Expanded(
                                        child: ListView.builder(
                                          key: const PageStorageKey<String>(
                                              'chat_messages_list'),
                                          reverse: true,
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          controller: _pageScrollController,
                                          addAutomaticKeepAlives: true,
                                          itemCount: renderItems.length + 1,
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          itemBuilder: (context, index) {
                                            if (index == renderItems.length) {
                                              return offerWidget();
                                            }
                                            final _ChatListEntry entry =
                                                renderItems[index];
                                            if (entry.isDateSeparator) {
                                              return _buildMessageDateChip(
                                                context,
                                                entry.dateLabel!,
                                              );
                                            }
                                            return _buildChatMessageWidget(
                                              entry.message!,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (state is LoadChatMessagesInProgress)
                                Center(
                                  child: UiUtils.progress(),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildOfferWidget() {
    if (widget.from == "wifi") {
      return const SizedBox.shrink();
    }
    final offerCurrencySymbol = _resolveCurrencySymbol();
    final double? offerPrice = widget.itemOfferPrice;

    if (offerPrice == null) {
      return const SizedBox.shrink();
    }

    final String offerLabel =
        _formatPriceWithCurrency(offerPrice, offerCurrencySymbol);

    final bool isCurrentUserBuyer =
        int.parse(HiveUtils.getUserId()!) == int.parse(widget.buyerId!);

    if (isCurrentUserBuyer) {
      // عرض المستخدم الحالي (المشتري) – يمين
      return Align(
        alignment: AlignmentDirectional.topEnd,
        child: Container(
          margin:
              const EdgeInsetsDirectional.only(top: 15, bottom: 15, end: 15),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: context.color.territoryColor.withOpacity(0.3),
            ),
            color: context.color.territoryColor.withOpacity(0.17),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(0),
              topLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("yourOffer".translate(context))
                  .color(context.color.textDefaultColor.withOpacity(0.5)),
              const SizedBox(height: 6), // مسافة بين “عرضك” والقيمة
              Text(offerLabel)
                  .bold()
                  .size(context.font.larger)
                  .color(context.color.textDefaultColor),
            ],
          ),
        ),
      );
    } else {
      // عرض الطرف الآخر – يسار
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: Container(
          margin:
              const EdgeInsetsDirectional.only(top: 15, bottom: 15, start: 15),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: context.color.territoryColor.withOpacity(0.3),
            ),
            color: context.color.territoryColor.withOpacity(0.17),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              topLeft: Radius.circular(0),
              bottomRight: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("offerLbl".translate(context))
                  .color(context.color.textDefaultColor.withOpacity(0.5)),
              const SizedBox(height: 8), // مسافة بين “العرض” والقيمة
              Text(offerLabel)
                  .bold()
                  .size(context.font.larger)
                  .color(context.color.textDefaultColor),
            ],
          ),
        ),
      );
    }
  }

  List<_ChatListEntry> _buildRenderableMessages(
      List<ChatMessageModal> messages, BuildContext context) {
    final List<_ChatListEntry> items = <_ChatListEntry>[];
    String? previousDate;
    for (int index = messages.length - 1; index >= 0; index--) {
      final ChatMessageModal message = messages[index];
      final String? label = _formatDateLabel(message.createdAt, context);
      if (label != null && label != previousDate) {
        items.insert(0, _ChatListEntry.date(label));
        previousDate = label;
      }
      items.insert(0, _ChatListEntry.message(message));
    }
    return items;
  }

  String? _formatDateLabel(String? createdAt, BuildContext context) {
    if (createdAt == null || createdAt.isEmpty) {
      return null;
    }
    try {
      final DateTime parsed = DateTime.parse(createdAt).toLocal();
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime yesterday = today.subtract(const Duration(days: 1));

      if (!parsed.isBefore(today)) {
        return "today".translate(context);
      }
      if (!parsed.isBefore(yesterday)) {
        return "yesterday".translate(context);
      }
      return parsed.toString().formatDate();
    } catch (_) {
      return createdAt;
    }
  }

  Widget _buildMessageDateChip(BuildContext context, String formattedDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: context.color.territoryColor.withOpacity(0.3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text(formattedDate),
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessageWidget(ChatMessageModal modal) {
    final String? localKey = modal.localId;
    final Key messageKey;
    if ((modal.id ?? 0) > 0) {
      messageKey = ValueKey(modal.id);
    } else if (localKey != null && localKey.isNotEmpty) {
      messageKey = ValueKey(localKey);
    } else {
      messageKey = ValueKey(modal.hashCode);
    }

    final bool isSelected = modal.id != null && modal.id == selectedMessageId;

    final ChatMessage chatWidget = ChatMessage(
      key: messageKey,
      id: modal.id,
      senderId: modal.senderId ?? 0,
      itemOfferId: modal.itemOfferId ?? widget.itemOfferId,
      message: modal.message ?? '',
      file: modal.file ?? '',
      audio: modal.audio ?? '',
      createdAt: modal.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: modal.updatedAt ?? modal.createdAt ?? '',
      messageType: modal.messageType,
      isSentNow: modal.isSentNow,
      status: modal.status,
      deliveredAt: modal.deliveredAt,
      readAt: modal.readAt,
      isSelected: isSelected,
      isDeleteMode: isDeleteMode,
      onSelected: _onMessageSelected,
      onSelectionCleared: _clearSelection,
    );

    if (modal.isSentNow) {
      return BlocProvider(
        key:
            ValueKey('provider_${localKey ?? modal.id ?? chatWidget.hashCode}'),
        create: (_) => SendMessageCubit(),
        child: chatWidget,
      );
    }

    return chatWidget;
  }

  String _generateLocalMessageId() {
    final int timestamp = DateTime.now().microsecondsSinceEpoch;
    final String userId = HiveUtils.getUserId() ?? '0';
    return 'local_${userId}_$timestamp';
  }
}

class _ChatHeader extends StatelessWidget {
  final _ChatScreenState state;
  final String? presenceText; // غير مستخدمة هنا
  final Color presenceColor; // غير مستخدم
  final String resolvedCurrencySymbol;

  const _ChatHeader({
    Key? key,
    required this.state,
    this.presenceText,
    required this.presenceColor,
    required this.resolvedCurrencySymbol,
  }) : super(key: key);

  Future<void> _openAd(BuildContext ctx) async {
    if (state.isListingUnavailable) {
      HelperUtils.showSnackBarMessage(
        ctx,
        "chatAdUnavailableHint".translate(ctx),
      );
      return;
    }

    Widgets.showLoader(ctx);
    try {
      final DataOutput<ItemModel> dataOutput =
          await ItemRepository().fetchItemFromItemId(
        int.parse(state.widget.itemId),
      );

      if (dataOutput.modelList.isEmpty) {
        throw StateError('listing-missing');
      }

      Widgets.hideLoder(ctx);
      Navigator.pushNamed(
        ctx,
        Routes.adDetailsScreen,
        arguments: {
          "model": dataOutput.modelList.first,
        },
      );
    } catch (_) {
      Widgets.hideLoder(ctx);
      state._markListingUnavailable();
      HelperUtils.showSnackBarMessage(
        ctx,
        "chatAdUnavailable".translate(ctx),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;

    final bool disableTap = state.isListingUnavailable;

    return Padding(
      // تفصل البطاقة عن الـ AppBar ومن الجانبين
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        elevation: 6,
        shadowColor: ctx.color.borderColor.withOpacity(0.25),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: disableTap ? null : () => _openAd(ctx),
          splashColor: ctx.color.territoryColor.withOpacity(0.15),
          highlightColor: ctx.color.territoryColor.withOpacity(0.08),
          child: Stack(
            children: [
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: ctx.color.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ctx.color.borderColor.withOpacity(0.4),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: UiUtils.getImage(
                          state.widget.itemImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.widget.itemTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          )
                              .color(ctx.color.textDefaultColor)
                              .size(ctx.font.large)
                              .bold(),
                          const SizedBox(height: 4),
                          Text(
                            'اضغط لمشاهدة تفاصيل الإعلان',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          )
                              .color(
                                ctx.color.textDefaultColor.withOpacity(0.6),
                              )
                              .size(ctx.font.small),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ctx.color.territoryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        state._formatPriceWithCurrency(
                          state.widget.itemPrice,
                          resolvedCurrencySymbol,
                        ),
                      )
                          .color(ctx.color.territoryColor)
                          .size(ctx.font.small)
                          .bold(),
                    ),
                  ],
                ),
              ),
              if (disableTap)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: ctx.color.backgroundColor.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: ctx.color.textDefaultColor.withOpacity(0.8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "chatAdUnavailableHint".translate(ctx),
                            textAlign: TextAlign.center,
                          )
                              .color(ctx.color.textDefaultColor)
                              .size(ctx.font.normal),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBottomBar extends StatefulWidget {
  final _ChatScreenState state;

  const _ChatBottomBar({Key? key, required this.state}) : super(key: key);

  @override
  _ChatBottomBarState createState() => _ChatBottomBarState();
}

class _ChatBottomBarState extends State<_ChatBottomBar> {
  bool get _hasText => widget.state.controller.text.trim().isNotEmpty;
  bool get _hasAttachment => widget.state.messageAttachment != null;
  bool get _canSendMessage => _hasText || _hasAttachment;

  @override
  Widget build(BuildContext context) {
    final PlatformFile? messageAttachment = widget.state.messageAttachment;
    final List<String> supportedImageTypes = widget.state.supportedImageTypes;
    final bool isDeleteMode = widget.state.isDeleteMode;
    final int otherUserId = int.tryParse(widget.state.widget.userId) ?? 0;
    final bool isBlocked =
        context.watch<BlockedUsersListCubit>().isUserBlocked(otherUserId);
    final String attachmentMime = _resolveAttachmentMime(messageAttachment);

    return SafeArea(
      bottom: true,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            if (isBlocked) _buildBlockButton(context, otherUserId),
            if (isDeleteMode) _buildDeleteToolbar(context),
            if (messageAttachment != null)
              _buildAttachmentWidget(
                context,
                messageAttachment,
                supportedImageTypes,
                attachmentMime,
              ),
            _buildBottomAppBar(context, isBlocked),
          ],
        ),
      ),
    );
  }

  String _resolveAttachmentMime(PlatformFile? file) {
    final String? extension = file?.extension;
    if (extension != null && extension.isNotEmpty) {
      return extension.toLowerCase();
    }
    final String path = file?.path ?? '';
    if (path.isEmpty) {
      return '';
    }
    final List<String> segments = path.split('.');
    if (segments.length < 2) {
      return '';
    }
    return segments.last.toLowerCase();
  }

  Future<void> _deleteSelectedMessage(BuildContext context) async {
    final int? messageId = widget.state.selectedMessageId;
    if (messageId == null) {
      widget.state._clearSelection();
      return;
    }

    final bool? shouldDelete = await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: "deleteBtnLbl".translate(context),
        content: Text(
          "msgWillNotRecover".translate(context),
          textAlign: TextAlign.center,
        ),
        acceptButtonName: "deleteBtnLbl".translate(context),
      ),
    );

    if (shouldDelete == true && mounted) {
      context.read<DeleteMessageCubit>().delete(messageId);
    }
  }

  Widget _buildDeleteToolbar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String toolbarLabel = widget.state.selectedMessageId != null
        ? "message".translate(context)
        : "selectLbl".translate(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.color.borderColor.withOpacity(0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              color: context.color.textDefaultColor,
              onPressed: widget.state._clearSelection,
            ),
            Expanded(
              child: Text(
                toolbarLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).size(context.font.normal),
            ),
            IconButton(
              onPressed: widget.state.selectedMessageId == null
                  ? null
                  : () => _deleteSelectedMessage(context),
              icon: const Icon(Icons.delete_outline_rounded),
              color: theme.colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputField(BuildContext context, bool isBlocked) {
    return TextField(
      enabled: !isBlocked,
      controller: widget.state.controller,
      cursorColor: context.color.territoryColor,
      onTap: widget.state._clearSelection,
      textInputAction: TextInputAction.newline,
      minLines: 1,
      maxLines: null,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: context.color.territoryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: context.color.territoryColor),
        ),
        hintText: "writeHere".translate(context),
      ),
    );
  }

  Widget _buildBlockButton(BuildContext context, int otherUserId) {
    final String promptText =
        "${"unBlockLbl".translate(context)} ${widget.state.widget.userName} ${"toSendMessage".translate(context)}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          onPressed: () async {
            final bool? unBlock = await UiUtils.showBlurredDialoge(
              context,
              dialoge: BlurredDialogBox(
                acceptButtonName: "unBlockLbl".translate(context),
                content: Text(
                  promptText,
                  textAlign: TextAlign.center,
                ),
              ),
            );
            if (unBlock == true && mounted) {
              context
                  .read<UnblockUserCubit>()
                  .unBlockUser(blockUserId: otherUserId);
            }
          },
          child: Text(
            "unBlockLbl".translate(context),
            style: TextStyle(
              color: context.color.territoryColor,
              fontSize: context.font.smaller,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentWidget(
    BuildContext context,
    PlatformFile messageAttachment,
    List<String> supportedImageTypes,
    String attachmentMIME,
  ) {
    final bool isImage = supportedImageTypes.contains(attachmentMIME);
    final String filePath = messageAttachment.path ?? '';
    final List<Widget> children = <Widget>[];

    if (isImage && filePath.isNotEmpty) {
      children.add(
        GestureDetector(
          onTap: () {
            UiUtils.showFullScreenImage(
              context,
              provider: FileImage(File(filePath)),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(filePath),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
      children.add(const SizedBox(width: 12));
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                messageAttachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ).size(context.font.normal),
              const SizedBox(height: 4),
              Text(
                HelperUtils.getFileSizeString(
                  bytes: messageAttachment.size,
                ),
              ).size(context.font.smaller),
            ],
          ),
        ),
      );
    } else {
      children.add(
        Expanded(
          child: AttachmentMessage(
            url: filePath,
          ),
        ),
      );
    }

    children.add(const SizedBox(width: 8));
    children.add(
      IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => widget.state._setMessageAttachment(null),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.color.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildBottomAppBar(BuildContext context, bool isBlocked) {
    return BottomAppBar(
      padding: const EdgeInsetsDirectional.all(10),
      elevation: 5,
      color: context.color.secondaryColor,
      child: Directionality(
        textDirection: Directionality.of(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildAttachmentButton(context, isBlocked),
                const SizedBox(width: 10),
                Expanded(child: _buildMessageInputField(context, isBlocked)),
                const SizedBox(width: 10),
                _buildActionButton(context, isBlocked),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButton(BuildContext context, bool isBlocked) {
    final Color iconColor = isBlocked
        ? context.color.textLightColor.withOpacity(0.5)
        : context.color.textDefaultColor;
    return Container(
      decoration: BoxDecoration(
        color: context.color.backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.color.borderColor.withOpacity(0.4)),
      ),
      child: IconButton(
        onPressed: isBlocked ? null : _handleAttachmentTap,
        icon: Icon(
          widget.state.messageAttachment != null
              ? Icons.close_rounded
              : Icons.attach_file_outlined,
        ),
        color: iconColor,
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isBlocked) {
    final bool shouldShowRecordButton =
        widget.state.showRecordButton && !isBlocked;
    if (shouldShowRecordButton) {
      final AnimationController? controller =
          widget.state._recordButtonAnimation;
      if (controller != null) {
        return SizedBox(
          height: 56,
          width: 56,
          child: RecordButton(
            controller: controller,
            callback: (path) =>
                widget.state._handleRecordedAudio(path as String?),
            isSending: false,
          ),
        );
      }
    }
    return _buildSendButton(context, isBlocked);
  }

  Widget _buildSendButton(BuildContext context, bool isBlocked) {
    final bool enabled = _canSendMessage && !isBlocked;
    return GestureDetector(
      onTap: enabled ? _handleSendPressed : null,
      child: CircleAvatar(
        radius: 22,
        backgroundColor: enabled
            ? context.color.territoryColor
            : context.color.territoryColor.withOpacity(0.3),
        child: Icon(
          Icons.send_rounded,
          color: context.color.buttonColor,
        ),
      ),
    );
  }

  Future<void> _handleAttachmentTap() async {
    widget.state._clearSelection();
    if (widget.state.messageAttachment != null) {
      widget.state._setMessageAttachment(null);
      return;
    }
    final FilePickerResult? pickedAttachment =
        await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: widget.state.supportedImageTypes,
    );
    widget.state._setMessageAttachment(pickedAttachment?.files.first);
  }

  void _handleSendPressed() {
    if (!_canSendMessage) {
      return;
    }

    final String trimmedMessage = widget.state.controller.text.trim();
    final String? attachmentPath = widget.state.messageAttachment?.path;
    String? messageType;

    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      messageType = widget.state._isImageAttachmentPath(attachmentPath)
          ? 'image'
          : 'file';
    } else if (trimmedMessage.isNotEmpty) {
      messageType = 'text';
    }

    final DateTime now = DateTime.now();

    ChatMessageHandler.add(
      ChatMessageModal(
        localId: widget.state._generateLocalMessageId(),
        senderId: int.tryParse(HiveUtils.getUserId() ?? '') ?? 0,
        receiverId: int.tryParse(widget.state.widget.userId),
        itemOfferId: widget.state.widget.itemOfferId,
        itemId: int.tryParse(widget.state.widget.itemId),
        message: trimmedMessage,
        audio: '',
        file: widget.state.messageAttachment?.path ?? '',
        messageType: messageType,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
        isSentNow: true,
      ),
    );

    widget.state.controller.clear();
    widget.state._setMessageAttachment(null);
  }
}

class _ChatListEntry {
  final ChatMessageModal? message;
  final String? dateLabel;

  bool get isDateSeparator => dateLabel != null;

  const _ChatListEntry._({this.message, this.dateLabel});

  factory _ChatListEntry.message(ChatMessageModal message) =>
      _ChatListEntry._(message: message);

  factory _ChatListEntry.date(String label) =>
      _ChatListEntry._(dateLabel: label);
}
