import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/ui/screens/chat/chatTile.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
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
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

part 'chat_list_screen_ui.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
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
    super.initState();
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

  // ---------------------- Buying ----------------------
  Widget buyingChatListData() => buildBuyingChatListData();

  // ---------------------- Selling ----------------------
  Widget sellingChatListData() => buildSellingChatListData();

  // ---------------------- Shimmer ----------------------
  Widget buildChatListLoadingShimmer() => buildChatListLoadingShimmerUi();

  @override
  bool get wantKeepAlive => true;
}
