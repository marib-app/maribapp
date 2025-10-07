import 'package:marib/ui/screens/filter_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

class PostedSinceFilterScreen extends StatefulWidget {
  final List<PostedSinceItem> list;
  final String postedSince;
  final Function update;

  const PostedSinceFilterScreen({
    Key? key,
    required this.list,
    required this.postedSince,
    required this.update,
  }) : super(key: key);

  @override
  State<PostedSinceFilterScreen> createState() => _PostedSinceFilterState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => PostedSinceFilterScreen(
        list: args?['list'],
        postedSince: args?['postedSince'],
        update: args?['update'],
      ),
    );
  }
}

class _PostedSinceFilterState extends State<PostedSinceFilterScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: "postedSinceLbl".translate(context),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: Container(
          color: context.color.secondaryColor,
          child: ListView.separated(
            itemCount: widget.list.length,
            padding: EdgeInsets.zero,
            separatorBuilder: (context, index) {
              return const Divider(
                thickness: 1.2,
                height: 10,
              );
            },
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                  widget.list[index].status,
                  textAlign: TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                    .color(context.color.textDefaultColor)
                    .size(context.font.normal)
                    .bold(
                        weight: index == 0 ? FontWeight.w600 : FontWeight.w500),
                onTap: () {
                  // Handle item selection here
                  widget.update(widget.list[index].value);
                  Navigator.pop(context); // Close the screen after selection
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
