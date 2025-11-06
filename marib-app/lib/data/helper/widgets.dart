import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Widgets {
  static bool isLoadingShowing = false;
  static BuildContext? _loaderDialogContext;

  static void showLoader(BuildContext context) async {
    if (isLoadingShowing) {
      return;
    }
    isLoadingShowing = true;
    showDialog(
        context: context,
        barrierDismissible: true,
        useSafeArea: true,
        builder: (BuildContext context) {
          _loaderDialogContext = context;
          return AnnotatedRegion(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.black.withOpacity(0),
            ),
            child: SafeArea(
              child: PopScope(
                canPop: true,
                onPopInvoked: (didPop) {
                  if (isLoadingShowing) {
                    isLoadingShowing = false;
                  }
                  _loaderDialogContext = null;
                  if (!didPop) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },
                child: Center(
                  child: UiUtils.progress(
                    normalProgressColor: context.color.territoryColor,
                  ),
                ),
                /*onWillPop: () {
                  return Future(
                    () => false,
                  );
                },*/
              ),
            ),
          );
        });
  }

  static void hideLoder(BuildContext context) {
    if (isLoadingShowing) {
      isLoadingShowing = false;
      if (_loaderDialogContext != null) {
        Navigator.of(_loaderDialogContext!, rootNavigator: true).pop();
        _loaderDialogContext = null;
      } else {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }
  }

  static Center noDataFound(String errorMsg) {
    return Center(child: Text(errorMsg));
  }
}
