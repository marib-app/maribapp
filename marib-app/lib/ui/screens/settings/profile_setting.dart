import 'package:marib/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ★ استبدل/عدّل هذا المسار حسب مكان AppHtml في مشروعك
import 'package:marib/ui/screens/classified_ads/app_html.dart';

import 'package:marib/data/cubits/profile_setting_cubit.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

class ProfileSettings extends StatefulWidget {
  final String? title;
  final String? param;

  const ProfileSettings({super.key, this.title, this.param});

  @override
  ProfileSettingsState createState() => ProfileSettingsState();

  static Route route(RouteSettings routeSettings) {
    final Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ProfileSettings(
        title: arguments?['title'] as String,
        param: arguments?['param'] as String,
      ),
    );
  }
}

class ProfileSettingsState extends State<ProfileSettings> {
  @override
  void initState() {
    super.initState();
    // الجلب الأولي
    Future.delayed(Duration.zero, () {
      if (widget.param != null) {
        context
            .read<ProfileSettingCubit>()
            .fetchProfileSetting(context, widget.param!, forceRefresh: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: widget.title ?? '',
        showBackButton: true,
      ),
      body: BlocBuilder<ProfileSettingCubit, ProfileSettingState>(
        builder: (context, state) {
          if (state is ProfileSettingFetchProgress) {
            return Center(
              child: UiUtils.progress(
                normalProgressColor: context.color.territoryColor,
              ),
            );
          } else if (state is ProfileSettingFetchSuccess) {
            return contentWidget(state, context, widget.param ?? '');
          } else if (state is ProfileSettingFetchFailure) {
            return Widgets.noDataFound(state.errmsg);
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

Widget contentWidget(
    ProfileSettingFetchSuccess state,
    BuildContext context,
    String param,
    ) {
  return RefreshIndicator(
    onRefresh: () async {
      // الدالة ترجع void، فقط استدعِها بدون await
      context
          .read<ProfileSettingCubit>()
          .fetchProfileSetting(context, param, forceRefresh: true);
      return;
    },
    child: SingleChildScrollView(
      physics:
      const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: AppHtml(
        data: state.data.toString(),
        baseUrl: null,
        centerContent: true,
        maxWidth: 720,
        preserveInlineStyles: true,
        selectable: true,
        outerPadding: EdgeInsets.zero,
      ),
    ),
  );
}
