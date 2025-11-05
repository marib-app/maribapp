part of 'chat_screen.dart';

extension _ChatScreenUiCore on _ChatScreenState {
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
    var attachmentMIME = "";
    if (messageAttachment != null) {
      attachmentMIME =
          (messageAttachment?.path?.split(".").last.toLowerCase()) ?? "";
    }

    final presenceText = _presenceLabel(context);
    final Color presenceColor = (_otherParticipantStatus?.isTyping ?? false)
        ? context.color.territoryColor
        : context.color.textLightColor;
    final resolvedCurrencySymbol = _resolveCurrencySymbol();

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        currentlyChatingWith = "";
        showDeletebutton.value = false;

        currentlyChatItemId = "";
        notificationStreamSubsctription.cancel();
        ChatMessageHandler.flushMessages();
        //context.read<ChatMessageHandlerCubit>().flushMessages();
        return;
      },
      /*  onWillPop: () async {
      currentlyChatingWith = "";
      showDelet ebutton.value = false;

      currentlyChatItemId = "";
      notificationStreamSubsctription.cancel();
      ChatMessageHandler.flushMessages();
      return true;
    },*/
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (messageAttachment != null) ...[
                    if (supportedImageTypes.contains(attachmentMIME)) ...[
                      Container(
                        decoration: BoxDecoration(
                            color: context.color.secondaryColor,
                            border: Border.all(
                                color: context.color.borderColor, width: 1.5)),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: SizedBox(
                                  height: 100,
                                  width: 100,
                                  child: GestureDetector(
                                    onTap: () {
                                      UiUtils.showFullScreenImage(context,
                                          provider: FileImage(File(
                                            messageAttachment?.path ?? "",
                                          )));
                                    },
                                    child: Image.file(
                                      File(
                                        messageAttachment?.path ?? "",
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  )),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(messageAttachment?.name ?? ""),
                                Text(HelperUtils.getFileSizeString(
                                  bytes: messageAttachment!.size,
                                ).toString()),
                              ],
                            )
                          ],
                        ),
                      )
                    ] else ...[
                      Container(
                        color: context.color.secondaryColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child:
                              AttachmentMessage(url: messageAttachment!.path!),
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                  BottomAppBar(
                    padding: const EdgeInsetsDirectional.all(10),
                    elevation: 5,
                    color: context.color.secondaryColor,
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: widget.status == "review" ||
                              widget.status == "rejected" ||
                              widget.status == "sold out" ||
                              widget.status == "inactive"
                          ? Container(
                              height: 40,
                              width: double.maxFinite,
                              color: context.color.secondaryColor,
                              alignment: Alignment.center,
                              child: Text(
                                      "${"thisItemIs".translate(context)} ${widget.status}")
                                  .size(context.font.large))
                          : Column(
                              children: [
                                BlocProvider(
                                    create: (context) => UnblockUserCubit(),
                                    child: Builder(builder: (context) {
                                      bool isBlocked = context
                                          .read<BlockedUsersListCubit>()
                                          .isUserBlocked(
                                              int.parse(widget.userId));
                                      return BlocConsumer<BlockedUsersListCubit,
                                              BlockedUsersListState>(
                                          listener: (context, state) {
                                        if (state is BlockedUsersListSuccess) {
                                          isBlocked = context
                                              .read<BlockedUsersListCubit>()
                                              .isUserBlocked(
                                                  int.parse(widget.userId));
                                        }
                                      }, builder:
                                              (context, blockedUsersListState) {
                                        return isBlocked
                                            ? BlocListener<UnblockUserCubit,
                                                    UnblockUserState>(
                                                listener:
                                                    (context, unblockState) {
                                                  if (unblockState
                                                      is UnblockUserSuccess) {
                                                    // Remove the unblocked user from the list
                                                    context
                                                        .read<
                                                            BlockedUsersListCubit>()
                                                        .unblockUser(int.parse(
                                                            widget.userId));
                                                    HelperUtils
                                                        .showSnackBarMessage(
                                                            context,
                                                            unblockState
                                                                .message);
                                                  } else if (unblockState
                                                      is UnblockUserFail) {
                                                    HelperUtils
                                                        .showSnackBarMessage(
                                                            context,
                                                            unblockState.error
                                                                .toString());
                                                  }
                                                },
                                                child: InkWell(
                                                  child: Text(
                                                          "youBlockedThisContact"
                                                              .translate(
                                                                  context))
                                                      .color(context
                                                          .color.textColorDark
                                                          .withOpacity(0.7)),
                                                  onTap: () async {
                                                    var unBlock = await UiUtils
                                                        .showBlurredDialoge(
                                                      context,
                                                      dialoge: BlurredDialogBox(
                                                        acceptButtonName:
                                                            "unBlockLbl"
                                                                .translate(
                                                                    context),
                                                        content: Text(
                                                          "${"unBlockLbl".translate(context)}\t${widget.userName}\t${"toSendMessage".translate(context)}"
                                                              .translate(
                                                                  context),
                                                        ),
                                                      ),
                                                    );
                                                    if (unBlock == true) {
                                                      Future.delayed(
                                                          Duration.zero, () {
                                                        context
                                                            .read<
                                                                UnblockUserCubit>()
                                                            .unBlockUser(
                                                              blockUserId: int
                                                                  .parse(widget
                                                                      .userId),
                                                            );
                                                      });
                                                    }
                                                  },
                                                ))
                                            : SizedBox();
                                      });
                                    })),
                                SizedBox(
                                  height: 8,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: controller,
                                        cursorColor:
                                            context.color.territoryColor,
                                        onTap: () {
                                          showDeletebutton.value = false;
                                        },
                                        textInputAction:
                                            TextInputAction.newline,
                                        minLines: 1,
                                        maxLines: null,
                                        decoration: InputDecoration(
                                          suffixIconColor:
                                              context.color.textLightColor,
                                          suffixIcon: IconButton(
                                            onPressed: () async {
                                              if (messageAttachment == null) {
                                                final FilePickerResult?
                                                    pickedAttachment =
                                                    await FilePicker.platform
                                                        .pickFiles(
                                                  allowMultiple: false,
                                                  type: FileType.custom,
                                                  allowedExtensions: [
                                                    'jpg',
                                                    'jpeg',
                                                    'png'
                                                  ],
                                                );

                                                _setMessageAttachment(
                                                    pickedAttachment
                                                        ?.files.first);
                                              } else {
                                                _setMessageAttachment(null);
                                              }
                                            },
                                            icon: messageAttachment != null
                                                ? const Icon(Icons.close)
                                                : Transform.rotate(
                                                    angle: -3.14 / 5.0,
                                                    child: const Icon(
                                                      Icons.attachment,
                                                    ),
                                                  ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 6, horizontal: 8),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              borderSide: BorderSide(
                                                  color: context
                                                      .color.territoryColor)),
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              borderSide: BorderSide(
                                                  color: context
                                                      .color.territoryColor)),
                                          hintText:
                                              "writeHere".translate(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 9.5,
                                    ),
                                    if (showRecordButton)
                                      RecordButton(
                                        controller: _recordButtonAnimation,
                                        callback: (path) {
                                          /*if (Constant.isDemoModeOn) {
                                  HelperUtils.showSnackBarMessage(
                                      context,
                                      "thisActionNotValidDemo"
                                          .translate(context));
                                  return;
                                }*/

                                          final DateTime now = DateTime.now();

                                          ChatMessageHandler.add(
                                            ChatMessageModal(
                                              localId:
                                                  _generateLocalMessageId(),
                                              senderId: int.tryParse(
                                                      HiveUtils.getUserId() ??
                                                          '') ??
                                                  0,
                                              receiverId:
                                                  int.tryParse(widget.userId),
                                              itemOfferId: widget.itemOfferId,
                                              itemId:
                                                  int.tryParse(widget.itemId),
                                              message: controller.text,
                                              audio: path,
                                              file: '',
                                              messageType: 'audio',
                                              createdAt: now.toIso8601String(),
                                              updatedAt: now.toIso8601String(),
                                              isSentNow: true,
                                            ),
                                          );

                                          totalMessageCount++;

                                          setState(() {});
                                        },
                                        isSending: false,
                                      ),
                                    if (!showRecordButton)
                                      GestureDetector(
                                        onTap: () {
                                          /* if (Constant.isDemoModeOn) {
                                  HelperUtils.showSnackBarMessage(
                                      context,
                                      "thisActionNotValidDemo"
                                          .translate(context));
                                  return;
                                }*/
                                          showDeletebutton.value = false;

                                          //if file is selected then user can send message without text
                                          if (controller.text.trim().isEmpty &&
                                              messageAttachment == null) return;
                                          //This is adding Chat widget in stream with BlocProvider , because we will need to do api process to store chat message to server, when it will be added to list it's initState method will be called

                                          String? messageType;
                                          final attachmentPath =
                                              messageAttachment?.path;
                                          if (attachmentPath != null &&
                                              attachmentPath.isNotEmpty) {
                                            messageType =
                                                _isImageAttachmentPath(
                                                        attachmentPath)
                                                    ? 'image'
                                                    : 'file';
                                          } else if (controller.text
                                              .trim()
                                              .isNotEmpty) {
                                            messageType = 'text';
                                          }
                                          final DateTime now = DateTime.now();

                                          ChatMessageHandler.add(
                                            ChatMessageModal(
                                              localId:
                                                  _generateLocalMessageId(),
                                              senderId: int.tryParse(
                                                      HiveUtils.getUserId() ??
                                                          '') ??
                                                  0,
                                              receiverId:
                                                  int.tryParse(widget.userId),
                                              itemOfferId: widget.itemOfferId,
                                              itemId:
                                                  int.tryParse(widget.itemId),
                                              message: controller.text,
                                              audio: '',
                                              file:
                                                  messageAttachment?.path ?? '',
                                              messageType: messageType,
                                              createdAt: now.toIso8601String(),
                                              updatedAt: now.toIso8601String(),
                                              isSentNow: true,
                                            ),
                                          );
                                          totalMessageCount++;
                                          controller.text = "";
                                          _setMessageAttachment(null);
                                        },
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              context.color.territoryColor,
                                          child: Icon(
                                            Icons.send,
                                            color: context.color.buttonColor,
                                          ),
                                        ),
                                      )
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
          appBar: AppBar(
            centerTitle: false,
            automaticallyImplyLeading: false,
            leading: Material(
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              type: MaterialType.circle,
              child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                      padding: EdgeInsetsDirectional.only(start: 15),
                      child: Directionality(
                        textDirection: Directionality.of(context),
                        child: RotatedBox(
                          quarterTurns:
                              Directionality.of(context) == TextDirection.rtl
                                  ? 2
                                  : -4,
                          child: UiUtils.getSvg(AppIcons.arrowLeft,
                              fit: BoxFit.none,
                              color: context.color.textDefaultColor),
                        ),
                      ))),
            ),
            backgroundColor: context.color.secondaryColor,
            elevation: 0,
            iconTheme: IconThemeData(color: context.color.territoryColor),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(70),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Divider(
                    color: context.color.borderColor.darken(40),
                    thickness: 1,
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 25, vertical: 0),
                    color: context.color.secondaryColor,
                    height: 63,
                    child: Row(
                      children: [
                        FittedBox(
                          fit: BoxFit.none,
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                Widgets.showLoader(context);

                                DataOutput<ItemModel> dataOutput =
                                    await ItemRepository().fetchItemFromItemId(
                                        int.parse(widget.itemId));

                                Future.delayed(
                                  Duration.zero,
                                  () {
                                    Widgets.hideLoder(context);
                                    Navigator.pushNamed(
                                        context, Routes.adDetailsScreen,
                                        arguments: {
                                          "model": dataOutput.modelList[0],
                                        });
                                  },
                                );
                              } catch (e) {
                                Widgets.hideLoder(context);
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: SizedBox(
                                width: 47,
                                height: 47,
                                child: UiUtils.getImage(
                                  widget.itemImage,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 10),
                        // Adding horizontal space between items
                        Expanded(
                          child: Container(
                            color: context.color.secondaryColor,
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.itemTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                  )
                                      .color(context.color.textDefaultColor)
                                      .size(context.font.large),
                                ),
                                Padding(
                                  padding:
                                      EdgeInsetsDirectional.only(start: 15.0),
                                  child: Text(
                                    _formatPriceWithCurrency(
                                      widget.itemPrice,
                                      resolvedCurrencySymbol,
                                    ),
                                  )
                                      .color(context.color.textDefaultColor)
                                      .size(context.font.large)
                                      .bold(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
            actions: [
              MultiBlocProvider(
                providers: [
                  BlocProvider(create: (context) => UnblockUserCubit()),
                  BlocProvider(create: (context) => BlockUserCubit()),
                ],
                child: Builder(builder: (context) {
                  bool isBlocked = context
                      .read<BlockedUsersListCubit>()
                      .isUserBlocked(int.parse(widget.userId));
                  return BlocConsumer<BlockedUsersListCubit,
                      BlockedUsersListState>(
                    listener: (context, state) {
                      if (state is BlockedUsersListSuccess) {
                        isBlocked = context
                            .read<BlockedUsersListCubit>()
                            .isUserBlocked(int.parse(widget.userId));
                      }
                    },
                    builder: (context, blockedUsersListState) {
                      return BlocListener<BlockUserCubit, BlockUserState>(
                        listener: (context, blockState) {
                          if (blockState is BlockUserSuccess) {
                            // Add the blocked user to the list
                            context
                                .read<BlockedUsersListCubit>()
                                .addBlockedUser(
                                  BlockedUserModel(
                                      id: int.parse(widget.userId),
                                      name: widget.userName,
                                      profile: widget.profilePicture
                                      // Add other necessary user data
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
                              // Remove the unblocked user from the list
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
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(end: 30.0),
                            child: Container(
                              height: 24,
                              width: 24,
                              alignment: AlignmentDirectional.center,
                              child: PopupMenuButton(
                                color: context.color.secondaryColor,
                                offset: Offset(-12, 15),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(17),
                                    bottomRight: Radius.circular(17),
                                    topLeft: Radius.circular(17),
                                    topRight: Radius.circular(0),
                                  ),
                                ),
                                child: SvgPicture.asset(
                                  AppIcons.more,
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                  colorFilter: ColorFilter.mode(
                                    context.color.textDefaultColor,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                itemBuilder: (context) => [
                                  if (!isBlocked)
                                    PopupMenuItem(
                                      onTap: () async {
                                        var block =
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
                                      },
                                      child: Text("blockLbl".translate(context))
                                          .color(context.color.textColorDark),
                                    )
                                  else
                                    PopupMenuItem(
                                      onTap: () async {
                                        var unBlock =
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
                                      },
                                      child: Text(
                                              "unBlockLbl".translate(context))
                                          .color(context.color.textColorDark),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              )
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
                                context.color.buttonColor, BlendMode.srcIn),
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
                                    child: Container(
                                      color: const Color.fromARGB(69, 0, 0, 0),
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
                  const SizedBox(
                    width: 10,
                  ),
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
                            Text(presenceText)
                                .size(context.font.smaller)
                                .color(presenceColor),
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
                      showDeletebutton.value = false;
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      showDeletebutton.value = false;
                    },
                    child: BlocConsumer<LoadChatMessagesCubit,
                        LoadChatMessagesState>(
                      listener: (context, state) {
                        if (state is LoadChatMessagesSuccess) {
                          ChatMessageHandler.loadMessages(state.messages);

                          totalMessageCount = state.messages.length;
                          isFetchedFirstTime = true;
                          setState(() {});
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
                                  final Widget? loadingMoreWidget =
                                      isLoadingMore
                                          ? Text("loading".translate(context))
                                          : null;

                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      !snapshot.hasData) {
                                    return loadingMoreWidget ?? offerWidget();
                                  }

                                  final List<ChatMessageModal> messages =
                                      snapshot.data ?? <ChatMessageModal>[];
                                  if (messages.isEmpty) {
                                    return offerWidget();
                                  }

                                  final List<_ChatListEntry> renderItems =
                                      _buildRenderableMessages(
                                          messages, context);

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      loadingMoreWidget ??
                                          const SizedBox.shrink(),
                                      Expanded(
                                        child: ListView.builder(
                                          key: ValueKey(
                                              'chat_list_${messages.length}_${renderItems.length}'),
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
                                                  context, entry.dateLabel!);
                                            }
                                            return _buildChatMessageWidget(
                                                entry.message!);
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                            if ((state is LoadChatMessagesInProgress))
                              Center(
                                child: UiUtils.progress(),
                              )
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
    );
  }

String _generateLocalMessageId() {
    final int timestamp = DateTime.now().microsecondsSinceEpoch;
    final String userId = HiveUtils.getUserId() ?? '0';
    return 'local_${userId}_$timestamp';
  }
}
