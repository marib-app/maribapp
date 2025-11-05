
part of 'chat_list_screen.dart';

extension _ChatListScreenUi on _ChatListScreenState {


  Widget buildChatListScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.color;

    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? Colors.white12 : Colors.black12;
    final background = isDark ? Colors.black : Colors.white;
    final onBackground = isDark ? Colors.white : Colors.black;
    final Color brand = colors.territoryColor;

    // نفس منطق CurrencyTabBar في الخط
    final base = theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final selected = base.copyWith(fontWeight: FontWeight.w700, height: 1.1);
    final unselected = base.copyWith(fontWeight: FontWeight.w500, height: 1.1);

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: colors.secondaryColor,
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: colors.backgroundColor,
          appBar: UiUtils.buildAppBar(
            context,
            title: "message".translate(context),
            // ارتفاع أكبر شوي لاستيعاب الحاوية + الـ Divider
            bottomHeight: 78,
            actions: [
              InkWell(
                child: UiUtils.getSvg(
                  AppIcons.blockedUserIcon,
                  color: colors.textDefaultColor,
                ),
                onTap: () {
                  Navigator.pushNamed(context, Routes.blockedUserListScreen);
                },
              ),
            ],
            bottom: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: TabBar(
                    // نفس شكل وسلوك CurrencyTabBar
                    tabs: [
                      Tab(text: 'buying'.translate(context)),
                      Tab(text: 'selling'.translate(context)),
                    ],
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(color: brand, width: 3),
                      insets: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    labelStyle: selected,
                    unselectedLabelStyle: unselected,
                    labelColor: onBackground,
                    unselectedLabelColor: onBackground.withOpacity(0.5),
                    overlayColor:
                    MaterialStateProperty.all(Colors.transparent),
                  ),
                ),
              ),
              Divider(
                height: 0,
                thickness: 0.5,
                color: colors.textDefaultColor.withOpacity(0.2),
              ),
            ],
          ),
          body: TabBarView(
            children: [
              buildBuyingChatListData(),
              buildSellingChatListData(),
            ],
          ),
        ),
      ),
    );
  }


  Widget buildBuyingChatListData() {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<GetBuyerChatListCubit>().setContext(context);
        context.read<GetBuyerChatListCubit>().fetch();
      },
      color: context.color.territoryColor,
      child: BlocBuilder<GetBuyerChatListCubit, GetBuyerChatListState>(
        builder: (context, state) {
          if (state is GetBuyerChatListFailed) {
            if (state.error is ApiException &&
                (state.error as ApiException).errorMessage == "no-internet") {
              return NoInternet(onRetry: () {
                context.read<GetBuyerChatListCubit>().fetch();
              });
            }
            return NoChatFound(
              onRetry: () {
                context.read<GetBuyerChatListCubit>().setContext(context);
                context.read<GetBuyerChatListCubit>().fetch();
              },
            );

          }

          if (state is GetBuyerChatListInProgress) {
            return buildChatListLoadingShimmer();
          }

          if (state is GetBuyerChatListSuccess) {
            if (state.chatedUserList.isEmpty) {
              return NoChatFound(
                onRetry: () {
                  context.read<GetBuyerChatListCubit>().setContext(context);
                  context.read<GetBuyerChatListCubit>().fetch();
                },
              );

            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: chatBuyerScreenController,
                    itemCount: state.chatedUserList.length,
                    padding: const EdgeInsetsDirectional.all(16),
                    itemBuilder: (context, index) {
                      final ChatedUser c = state.chatedUserList[index];

                      final seller = c.seller; // قد تكون null
                      final item = c.item; // قد يكون null

                      final id = c.sellerId?.toString() ?? '';
                      final itemId = c.itemId?.toString() ?? '';
                      final buyerId = c.buyerId?.toString() ?? '';

                      final profilePicture = seller?.profile ?? '';
                      final userName = seller?.name ?? '';

                      final itemPicture = item?.image ?? '';
                      final itemName = item?.name ?? '';

                      final itemPrice = (item?.price ?? 0.0);
                      final itemAmount = c.amount; // قد تكون null
                      final status = item?.status;


                      final itemCurrency = item?.currency;
                      final itemCurrencySymbol = item?.currencySymbol;

                      final date = c.createdAt ?? '';


                      final isPurchased = item?.isPurchased ?? 0;
                      final alreadyReview = _hasAnyReview(item);

                      final itemOfferId = (c.itemOfferId ?? c.id) ?? 0;


                      final unreadCount = c.unreadMessagesCount ?? 0;
                      final lastMessage = c.lastMessage;
                      final participants = c.participants;



                      final conversationId =
                          c.conversationId ?? c.id?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(top: 9.0),
                        child: ChatTile(
                          id: id,
                          itemId: itemId,
                          profilePicture: profilePicture,
                          userName: userName,
                          itemPicture: itemPicture,
                          itemName: itemName,
                          unreadCount: unreadCount,
                          lastMessage: lastMessage,

                          conversationId: conversationId,

                          date: date,
                          itemOfferId: itemOfferId,
                          itemPrice: itemPrice,
                          itemAmount: itemAmount,
                          status: status,
                          buyerId: buyerId,
                          isPurchased: isPurchased,
                          alreadyReview: alreadyReview,
                          participants: participants,
                          itemCurrency: itemCurrency,
                          itemCurrencySymbol: itemCurrencySymbol,
                        ),
                      );
                    },
                  ),
                ),
                if (state.isLoadingMore) UiUtils.progress(),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }


  Widget buildSellingChatListData() {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<GetSellerChatListCubit>().setContext(context);
        context.read<GetSellerChatListCubit>().fetch();
      },
      color: context.color.territoryColor,
      child: BlocBuilder<GetSellerChatListCubit, GetSellerChatListState>(
        builder: (context, state) {
          if (state is GetSellerChatListFailed) {
            if (state.error is ApiException &&
                (state.error as ApiException).errorMessage == "no-internet") {
              return NoInternet(onRetry: () {
                context.read<GetSellerChatListCubit>().fetch();
              });
            }
            return NoChatFound(
              onRetry: () {
                context.read<GetSellerChatListCubit>().setContext(context);
                context.read<GetSellerChatListCubit>().fetch();
              },
            );

          }

          if (state is GetSellerChatListInProgress) {
            return buildChatListLoadingShimmer();
          }

          if (state is GetSellerChatListSuccess) {
            if (state.chatedUserList.isEmpty) {
              return NoChatFound(
                onRetry: () {
                  context.read<GetSellerChatListCubit>().setContext(context);
                  context.read<GetSellerChatListCubit>().fetch();
                },
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: chatSellerScreenController,
                    itemCount: state.chatedUserList.length,
                    padding: const EdgeInsetsDirectional.all(16),
                    itemBuilder: (context, index) {
                      final ChatedUser c = state.chatedUserList[index];

                      final buyer = c.buyer; // قد تكون null
                      final item = c.item; // قد يكون null

                      final id = c.buyerId?.toString() ?? '';
                      final itemId = c.itemId?.toString() ?? '';
                      final buyerId = c.buyerId?.toString() ?? '';

                      final profilePicture = buyer?.profile ?? '';
                      final userName = buyer?.name ?? '';

                      final itemPicture = item?.image ?? '';
                      final itemName = item?.name ?? '';

                      final itemPrice = (item?.price ?? 0.0);
                      final itemAmount = c.amount;
                      final status = item?.status;
                      final itemCurrency = item?.currency;
                      final itemCurrencySymbol = item?.currencySymbol;
                      final date = c.createdAt ?? '';



                      final isPurchased = item?.isPurchased ?? 0;
                      final alreadyReview = _hasAnyReview(item);

                      final itemOfferId = (c.itemOfferId ?? c.id) ?? 0;

                      final unreadCount = c.unreadMessagesCount ?? 0;
                      final lastMessage = c.lastMessage;
                      final participants = c.participants;



                      final conversationId =
                          c.conversationId ?? c.id?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(top: 9.0),
                        child: ChatTile(
                          id: id,
                          itemId: itemId,
                          conversationId:
                          c.conversationId ?? c.id?.toString() ?? '',
                          profilePicture: profilePicture,
                          userName: userName,
                          itemPicture: itemPicture,
                          itemName: itemName,
                          unreadCount: unreadCount,
                          lastMessage: lastMessage,
                          date: date,
                          itemOfferId: itemOfferId,
                          itemPrice: itemPrice,
                          itemAmount: itemAmount,
                          status: status,
                          buyerId: buyerId,
                          isPurchased: isPurchased,
                          alreadyReview: alreadyReview,
                          participants: participants,
                          itemCurrency: itemCurrency,
                          itemCurrencySymbol: itemCurrencySymbol,

                        ),
                      );
                    },
                  ),
                ),
                if (state.isLoadingMore) UiUtils.progress(),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget buildChatListLoadingShimmerUi() {
    return ListView.builder(
      itemCount: 10,
      padding: const EdgeInsetsDirectional.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(top: 9.0),
          child: SizedBox(
            height: 74,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
                    highlightColor:
                    Theme.of(context).colorScheme.shimmerHighlightColor,
                    child: Stack(
                      children: [
                        const SizedBox(width: 58, height: 58),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 42,
                            height: 42,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .shimmerContentColor,
                              border: Border.all(
                                width: 1.5,
                                color: Colors.white,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: Colors.white, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: context.color.territoryColor,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomShimmer(
                        height: 10,
                        borderRadius: 5,
                        width: context.screenWidth * 0.53,
                      ),
                      CustomShimmer(
                        height: 10,
                        borderRadius: 5,
                        width: context.screenWidth * 0.3,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
