import 'package:flutter/material.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

enum StoreReviewDialogVariant {
  management,
  publishing,
}

Future<void> showStoreReviewDialog(
  BuildContext context, {
  StoreReviewDialogVariant variant = StoreReviewDialogVariant.management,
}) {
  final String titleKey = switch (variant) {
    StoreReviewDialogVariant.publishing => 'storePendingPublishingTitle',
    StoreReviewDialogVariant.management => 'storePendingManagementTitle',
  };
  final String bodyKey = switch (variant) {
    StoreReviewDialogVariant.publishing => 'storePendingPublishingBody',
    StoreReviewDialogVariant.management => 'storePendingManagementBody',
  };

  final ThemeData theme = Theme.of(context);

  return UiUtils.showBlurredDialoge(
    context,
    dialoge: BlurredDialogBox(
      title: titleKey.translate(context),
      svgImagePath: AppIcons.warning,
      svgImageColor: theme.colorScheme.error,
      showCancleButton: false,
      acceptButtonName: 'ok'.translate(context),
      content: Text(
        bodyKey.translate(context),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: context.font.normal,
          color: context.color.textColorDark,
          height: 1.5,
        ),
      ),
    ),
  );
}
