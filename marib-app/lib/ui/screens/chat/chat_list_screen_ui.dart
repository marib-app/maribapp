
part of 'chat_list_screen.dart';

extension _ChatListScreenUi on _ChatListScreenState {
  static bool _isOnlineStatus(ParticipantStatus? status) =>
      status?.isOnline == true || status?.isTyping == true;


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
    final buyerState = context.watch<GetBuyerChatListCubit>().state;
    final sellerState = context.watch<GetSellerChatListCubit>().state;

    int _countChats(GetBuyerChatListState state) {
      return state is GetBuyerChatListSuccess ? state.chatedUserList.length : 0;
    }

    int _countSeller(GetSellerChatListState state) {
      return state is GetSellerChatListSuccess ? state.chatedUserList.length : 0;
    }

    int _countUnread(GetBuyerChatListState b, GetSellerChatListState s) {
      int sum = 0;
      if (b is GetBuyerChatListSuccess) {
        sum += b.chatedUserList
            .fold<int>(0, (acc, c) => acc + (c.unreadMessagesCount ?? 0));
      }
      if (s is GetSellerChatListSuccess) {
        sum += s.chatedUserList
            .fold<int>(0, (acc, c) => acc + (c.unreadMessagesCount ?? 0));
      }
      return sum;
    }

    final int buyerCount = _countChats(buyerState);
    final int sellerCount = _countSeller(sellerState);
    final int allCount = buyerCount + sellerCount;
    final int unreadCount = _countUnread(buyerState, sellerState);
    final bool isLoading = buyerState is GetBuyerChatListInProgress ||
        sellerState is GetSellerChatListInProgress;

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: colors.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "message".translate(context),
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
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'تجربة الشات الجديد',
              icon: Icon(
                Icons.auto_awesome,
                color: colors.territoryColor,
              ),
              onPressed: () {
                Navigator.pushNamed(context, Routes.chatListV2);
              },
            ),
          ],
        ),
        body: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: _buildSearchField(context, background, border),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _buildChipTabs(
                  context: context,
                  selected: selected,
                  unselected: unselected,
                  onBackground: onBackground,
                  border: border,
                  allCount: allCount,
                  sellerCount: sellerCount,
                  buyerCount: buyerCount,
                  unreadCount: unreadCount,
                  isLoading: isLoading,
                ),
              ),
              Divider(
                height: 0,
                thickness: 0.5,
                color: colors.textDefaultColor.withOpacity(0.2),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildCombinedChatsTab(_ChatFilter.all),
                    buildSellingChatListData(),
                    buildBuyingChatListData(),
                    _buildCombinedChatsTab(_ChatFilter.unread),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(
    BuildContext context,
    Color background,
    Color border,
  ) {
    final palette = context.color;
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث في الرسائل',
          prefixIcon: Icon(
            Icons.search,
            color: palette.textLightColor,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: palette.textLightColor,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _handleSearchChanged();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildChipTabs({
    required BuildContext context,
    required TextStyle selected,
    required TextStyle unselected,
    required Color onBackground,
    required Color border,
    required int allCount,
    required int sellerCount,
    required int buyerCount,
    required int unreadCount,
    required bool isLoading,
  }) {
    final colors = context.color;
    final List<_TabMeta> tabs = [
      _TabMeta(label: 'الكل', count: allCount),
      _TabMeta(label: 'بيع', count: sellerCount),
      _TabMeta(label: 'شراء', count: buyerCount),
      _TabMeta(label: 'غير مقروء', count: unreadCount),
    ];

    return Builder(
      builder: (ctx) {
        final controller = DefaultTabController.of(ctx)!;
        return AnimatedBuilder(
          animation: controller.animation!,
          builder: (_, __) {
            final current = controller.index;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: colors.secondaryColor,
                    color: colors.territoryColor,
                  ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(tabs.length, (index) {
                      final bool isActive = index == current;
                      final tab = tabs[index];
                      return Padding(
                        padding: EdgeInsetsDirectional.only(
                            end: index == tabs.length - 1 ? 0 : 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab.label,
                                style:
                                    (isActive ? selected : unselected).copyWith(
                                  color: isActive
                                      ? colors.territoryColor
                                      : onBackground,
                                ),
                              ),
                              if (tab.count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isActive
                                            ? colors.territoryColor
                                            : onBackground)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    tab.count > 99
                                        ? '99+'
                                        : tab.count.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? colors.territoryColor
                                          : onBackground,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          selected: isActive,
                          onSelected: (_) => controller.animateTo(index),
                          backgroundColor: colors.secondaryColor.withOpacity(0.6),
                          selectedColor: colors.territoryColor.withOpacity(0.12),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: isActive
                                  ? colors.territoryColor.withOpacity(0.5)
                                  : border,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          elevation: 0,
                          pressElevation: 0,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          showCheckmark: false,
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        );
      },
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

            final filtered = _filterChats(state.chatedUserList);
            if (filtered.isEmpty) {
              return NoChatFound(
                title: _searchQuery.isNotEmpty ? 'لا توجد نتائج' : null,
                subtitle: _searchQuery.isNotEmpty
                    ? 'لا توجد محادثات تطابق البحث الحالي.'
                    : null,
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
                    itemCount: filtered.length,
                    padding: const EdgeInsetsDirectional.all(16),
                    itemBuilder: (context, index) {
                      final ChatedUser c = filtered[index];
                      final status = c.participants
                          ?.map((p) => p.status)
                          .firstWhere((s) => s != null, orElse: () => null);
                      final userKey = (c.sellerId ?? c.buyerId)?.toString() ?? '';
                      if (status != null && userKey.isNotEmpty) {
                        _seedPresence(
                          userId: userKey,
                          status: status,
                          conversationId: c.conversationId ?? c.id?.toString(),
                          itemOfferId: c.itemOfferId,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 9.0),
                        child: _buildChatTileFromChat(
                          c,
                          isSellerSide: false,
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

            final filtered = _filterChats(state.chatedUserList);
            if (filtered.isEmpty) {
              return NoChatFound(
                title: _searchQuery.isNotEmpty ? 'لا توجد نتائج' : null,
                subtitle: _searchQuery.isNotEmpty
                    ? 'لا توجد محادثات تطابق البحث الحالي.'
                    : null,
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
                    itemCount: filtered.length,
                    padding: const EdgeInsetsDirectional.all(16),
                    itemBuilder: (context, index) {
                      final ChatedUser c = filtered[index];
                      final status = c.participants
                          ?.map((p) => p.status)
                          .firstWhere((s) => s != null, orElse: () => null);
                      final userKey = (c.buyerId ?? c.sellerId)?.toString() ?? '';
                      if (status != null && userKey.isNotEmpty) {
                        _seedPresence(
                          userId: userKey,
                          status: status,
                          conversationId: c.conversationId ?? c.id?.toString(),
                          itemOfferId: c.itemOfferId,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 9.0),
                        child: _buildChatTileFromChat(
                          c,
                          isSellerSide: true,
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

  ChatTile _buildChatTileFromChat(
    ChatedUser c, {
    required bool isSellerSide,
  }) {
    final counterpart = isSellerSide ? c.buyer : c.seller;
    final item = c.item;

    final id =
        isSellerSide ? c.buyerId?.toString() ?? '' : c.sellerId?.toString() ?? '';
    final itemId = c.itemId?.toString() ?? '';
    final buyerId = c.buyerId?.toString() ?? '';

    String _counterpartProfile(dynamic user) {
      if (user is Buyer) return user.profile ?? '';
      if (user is Seller) return user.profile ?? '';
      return '';
    }

    String _counterpartName(dynamic user) {
      if (user is Buyer) return user.name ?? '';
      if (user is Seller) return user.name ?? '';
      return '';
    }

    final profilePicture = _counterpartProfile(counterpart);
    final userName = _counterpartName(counterpart);

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

    final conversationId = c.conversationId ?? c.id?.toString() ?? '';

    return ChatTile(
      id: id,
      itemId: itemId,
      conversationId: conversationId,
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
    );
  }

  Widget _buildCombinedChatsTab(_ChatFilter filter) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<GetBuyerChatListCubit>().setContext(context);
        context.read<GetSellerChatListCubit>().setContext(context);
        context.read<GetBuyerChatListCubit>().fetch();
        context.read<GetSellerChatListCubit>().fetch();
      },
      color: context.color.territoryColor,
      child: BlocBuilder<GetBuyerChatListCubit, GetBuyerChatListState>(
        builder: (context, buyerState) {
          return BlocBuilder<GetSellerChatListCubit, GetSellerChatListState>(
            builder: (context, sellerState) {
              final bool buyerLoading = buyerState is GetBuyerChatListInProgress ||
                  buyerState is GetBuyerChatListInitial;
              final bool sellerLoading = sellerState is GetSellerChatListInProgress ||
                  sellerState is GetSellerChatListInitial;

              if (buyerLoading || sellerLoading) {
                return buildChatListLoadingShimmer();
              }

              if (buyerState is GetBuyerChatListFailed &&
                  sellerState is GetSellerChatListFailed) {
                final dynamic buyerError = buyerState.error;
                final dynamic sellerError = sellerState.error;
                final bool noInternet = (buyerError is ApiException &&
                        buyerError.errorMessage == "no-internet") ||
                    (sellerError is ApiException &&
                        sellerError.errorMessage == "no-internet");

                if (noInternet) {
                  return NoInternet(onRetry: () {
                    context.read<GetBuyerChatListCubit>().fetch();
                    context.read<GetSellerChatListCubit>().fetch();
                  });
                }

                return SomethingWentWrong(onReload: () {
                  context.read<GetBuyerChatListCubit>().fetch();
                  context.read<GetSellerChatListCubit>().fetch();
                });
              }

              final buyerList = buyerState is GetBuyerChatListSuccess
                  ? buyerState.chatedUserList
                  : <ChatedUser>[];
              final sellerList = sellerState is GetSellerChatListSuccess
                  ? sellerState.chatedUserList
                  : <ChatedUser>[];

              final List<_ChatEntry> entries = [];

              if (filter != _ChatFilter.selling) {
                entries.addAll(
                  buyerList.map((c) => _ChatEntry(c, false)),
                );
              }
              if (filter != _ChatFilter.buying) {
                entries.addAll(
                  sellerList.map((c) => _ChatEntry(c, true)),
                );
              }

              Iterable<_ChatEntry> filtered = entries.where((entry) {
                final chat = entry.chat;
                if (filter == _ChatFilter.unread &&
                    (chat.unreadMessagesCount ?? 0) == 0) {
                  return false;
                }
                return _matchesSearch(chat);
              });

              final List<_ChatEntry> results = filtered.toList()
                ..sort((a, b) =>
                    _chatTimestamp(b.chat).compareTo(_chatTimestamp(a.chat)));

              if (results.isEmpty) {
                return NoChatFound(
                  title: _searchQuery.isNotEmpty ? 'لا توجد نتائج' : null,
                  subtitle: _searchQuery.isNotEmpty
                      ? 'لا توجد محادثات تطابق البحث الحالي.'
                      : null,
                  onRetry: () {
                    context.read<GetBuyerChatListCubit>().fetch();
                    context.read<GetSellerChatListCubit>().fetch();
                  },
                );
              }

              final bool loadingMore =
                  (buyerState is GetBuyerChatListSuccess &&
                      buyerState.isLoadingMore) ||
                      (sellerState is GetSellerChatListSuccess &&
                          sellerState.isLoadingMore);

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsetsDirectional.all(16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 9.0),
                          child: _buildChatTileFromChat(
                            entry.chat,
                            isSellerSide: entry.isSellerSide,
                          ),
                        );
                      },
                    ),
                  ),
                  if (loadingMore) UiUtils.progress(),
                ],
              );
            },
          );
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


