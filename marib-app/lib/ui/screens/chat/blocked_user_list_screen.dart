import 'package:cached_network_image/cached_network_image.dart';
import 'package:marib/data/cubits/chat/unblock_user_cubit.dart';
import 'package:marib/ui/screens/home_screen/home_screen.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:marib/data/model/chat/chated_user_model.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
part 'blocked_user_list_screen_ui.dart';

class BlockedUserListScreen extends StatefulWidget {
  const BlockedUserListScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) {
        return const BlockedUserListScreen();
      },
    );
  }

  @override
  State<BlockedUserListScreen> createState() => _BlockedUserListScreenState();
}

class _BlockedUserListScreenState extends State<BlockedUserListScreen> {
  late final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    context.read<BlockedUsersListCubit>().blockedUsersList();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) => buildBlockedUserListScreen(context);

  Widget userList(BuildContext context, BlockedUserModel user) =>
      buildUserList(context, user);
}
