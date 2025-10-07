
part of 'chat_list_screen.dart';

extension _ChatListScreenUi on _ChatListScreenState {
  Widget buildChatListScreen(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: UiUtils.buildAppBar(
            context,
            title: "message".translate(context),
            bottomHeight: 49,
            actions: [
              InkWell(
                child: UiUtils.getSvg(AppIcons.blockedUserIcon,
                    color: context.color.textDefaultColor),
                onTap: () {
                  Navigator.pushNamed(context, Routes.blockedUserListScreen);
                },
              )
            ],
            bottom: [
              TabBar(
                tabs: [
                  Tab(text: 'buying'.translate(context)),
                  Tab(text: 'selling'.translate(context)),
                ],
                indicatorColor: context.color.textDefaultColor,
                indicatorWeight: 1.5,
                labelColor: context.color.textDefaultColor,
                unselectedLabelColor:
                context.color.textDefaultColor.withOpacity(0.5),
                labelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                indicatorSize: TabBarIndicatorSize.tab,
              ),
              Divider(
                height: 0,
                thickness: 0.5,
                color: context.color.textDefaultColor.withOpacity(0.2),
              ),
            ],
          ),
          body: TabBarView(
            children: [
              buyingChatListData(),
              sellingChatListData(),
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
            return const NoChatFound();
          }

          if (state is GetBuyerChatListInProgress) {
            return buildChatListLoadingShimmer();
          }

          if (state is GetBuyerChatListSuccess) {
            if (state.chatedUserList.isEmpty) {
              return const NoChatFound();
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: chatBuyerScreenController,
                    shrinkWrap: true,
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
            return const NoChatFound();
          }

          if (state is GetSellerChatListInProgress) {
            return buildChatListLoadingShimmer();
          }

          if (state is GetSellerChatListSuccess) {
            if (state.chatedUserList.isEmpty) {
              return const NoChatFound();
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: chatSellerScreenController,
                    shrinkWrap: true,
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
      physics: const BouncingScrollPhysics(),
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
                              color: Colors.grey,
                              border:
                              Border.all(width: 1.5, color: Colors.white),
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