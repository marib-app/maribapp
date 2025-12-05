import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/ui/screens/chat/chatTile.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:marib/data/cubits/chat/get_seller_chat_users_cubit.dart';
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/utils/constant.dart';
import 'package:flutter/scheduler.dart';

part 'chat_list_screen_ui.dart';

enum _ChatFilter { all, selling, buying, unread }



class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      settings: settings,
      builder: (context) {
        return const ChatListScreen();
      },
    );
  }

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  ScrollController chatBuyerScreenController = ScrollController();
  ScrollController chatSellerScreenController = ScrollController();
  final ScrollController _combinedController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, ParticipantStatus?> _presenceSeeded = {};

  @override
  void initState() {
    if (HiveUtils.isUserAuthenticated()) {
      context.read<GetBuyerChatListCubit>().setContext(context);
      context.read<GetSellerChatListCubit>().setContext(context);
      context.read<GetBuyerChatListCubit>().fetch();
      context.read<GetSellerChatListCubit>().fetch();
      context.read<BlockedUsersListCubit>().blockedUsersList();

      chatBuyerScreenController.addListener(() {
        if (chatBuyerScreenController.isEndReached()) {
          if (context.read<GetBuyerChatListCubit>().hasMoreData()) {
            context.read<GetBuyerChatListCubit>().loadMore();
          }
        }
      });

      chatSellerScreenController.addListener(() {
        if (chatSellerScreenController.isEndReached()) {
          if (context.read<GetSellerChatListCubit>().hasMoreData()) {
            context.read<GetSellerChatListCubit>().loadMore();
          }
        }
      });
    }
    _searchController.addListener(_handleSearchChanged);
    super.initState();
  }

  @override
  void dispose() {
    chatBuyerScreenController.dispose();
    chatSellerScreenController.dispose();
    _combinedController.dispose();
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildChatListScreen(context);

  }

  // helper: هل يوجد أي تقييم؟
  bool _hasAnyReview(Item? item) {
    if (item == null) return false;
    if (item.review != null) return true;
    final list = item.reviews;
    return list != null && list.isNotEmpty;
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() {
      _searchQuery = next;
    });
  }

  bool _matchesSearch(ChatedUser chat) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final query = _searchQuery.toLowerCase();
    bool contains(String? source) =>
        source != null && source.toLowerCase().contains(query);

    return contains(chat.seller?.name) ||
        contains(chat.buyer?.name) ||
        contains(chat.item?.name) ||
        contains(chat.lastMessage?.message);
  }

  bool _isFavoriteChat(ChatedUser chat) {
    return chat.isFavorite == true;
  }

  List<ChatedUser> _filterChats(
    List<ChatedUser> source, {
    bool unreadOnly = false,
    bool favoriteOnly = false,
  }) {
    return source.where((chat) {
      if (unreadOnly && (chat.unreadMessagesCount ?? 0) == 0) {
        return false;
      }
      if (favoriteOnly && !_isFavoriteChat(chat)) {
        return false;
      }
      return _matchesSearch(chat);
    }).toList();
  }

  DateTime _chatTimestamp(ChatedUser chat) {
    final candidates = [
      chat.lastMessage?.createdAt,
      chat.updatedAt,
      chat.createdAt,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _seedPresence({
    required String userId,
    required ParticipantStatus status,
    String? conversationId,
    int? itemOfferId,
  }) {
    if (userId.isEmpty) return;
    // لا نرسخ حالات أوفلاين، فقط Online/Typing حتى لا نكسر الحالات الصحيحة.
    final bool nextIsOnline = status.isOnline == true || status.isTyping == true;
    if (!nextIsOnline) {
      return;
    }

    final String key = userId;
    final ParticipantStatus? previous = _presenceSeeded[key];
    if (NotificationService.areStatusesEqual(previous, status)) {
      return;
    }
    _presenceSeeded[key] = status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.cacheUserPresence(
        userId: userId,
        status: status,
        conversationId: conversationId,
        itemOfferId: itemOfferId,
      );
    });
  }

  // ---------------------- Buying ----------------------
  Widget buyingChatListData() => buildBuyingChatListData();


  // ---------------------- Selling ----------------------
  Widget sellingChatListData() => buildSellingChatListData();


  // ---------------------- Shimmer ----------------------
  Widget buildChatListLoadingShimmer() =>
      buildChatListLoadingShimmerUi();

  @override
  bool get wantKeepAlive => true;
}

class _ChatEntry {
  final ChatedUser chat;
  final bool isSellerSide;

  _ChatEntry(this.chat, this.isSellerSide);
}

class _TabMeta {
  final String label;
  final int count;

  const _TabMeta({required this.label, required this.count});
}
