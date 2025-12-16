
// lib/ui/screens/user_profile/profile_screen.dart
// هذا هو "ملف المنطق" وهو الملف الذي يُستورد كما كان من أي مكان آخر.
// يُبقي الرمز ProfileScreen معرفاً (لأن الـ part أدناه يحتوي الواجهة).
import 'package:marib/app/app_scroll_behavior.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:marib/ui/screens/competitions/competitions_screen.dart';

import 'package:marib/ui/screens/competitions/competitions_screen.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/auth/authentication_cubit.dart';
import 'package:marib/data/cubits/auth/delete_user_cubit.dart';
import 'package:marib/data/cubits/category/fetch_category_cubit.dart';
import 'package:marib/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';
import 'package:marib/data/cubits/profile/profile_stats_cubit.dart';
import 'package:marib/data/cubits/merchant/merchant_store_cubit.dart';
import 'package:marib/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/data/cubits/system/fetch_language_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/cubits/system/language_cubit.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/data/model/system_settings_model.dart';
import 'package:marib/data/model/merchant/merchant_store_snapshot.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_keys.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/ui/widgets/dialogs/store_review_dialogs.dart';
import 'package:marib/utils/merchant_display_helper.dart';
import 'package:marib/ui/widgets/verification_subscription_sheet.dart';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
part 'profile_screen_ui.dart';

// -------------------------------
// منطق الشاشة (mixin) دون Widgets
// -------------------------------
mixin ProfileScreenLogic<T extends StatefulWidget> on State<T> {
  final ValueNotifier<bool> isDarkTheme = ValueNotifier(false);
  final InAppReview _inAppReview = InAppReview.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<FetchSystemSettingsCubit>();

    if (!const bool.fromEnvironment("force-disable-demo-mode", defaultValue: false)) {
      Constant.isDemoModeOn = settings.getSetting(SystemSetting.demoMode) ?? false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isDarkTheme.value = context.read<AppThemeCubit>().isDarkMode();
  }

  @override
  void dispose() {
    isDarkTheme.dispose();
    super.dispose();
  }


  void logOutConfirmWidget() {
    UiUtils.showBlurredDialoge(context,
        dialoge: BlurredDialogBox(
            title: "confirmLogoutTitle".translate(context),
            onAccept: () async {
              Future.delayed(
                Duration.zero,
                    () async {
                  HiveUtils.clear();
                  Constant.favoriteItemList.clear();
                  context.read<UserDetailsCubit>().clear();
                  context.read<FavoriteCubit>().resetState();
                  context.read<UpdatedReportItemCubit>().clearItem();
                  context.read<GetBuyerChatListCubit>().resetState();
                  context.read<BlockedUsersListCubit>().resetState();
                  await FetchSystemSettingsCubit.resetDelegateSectionsFor(
                    context,
                    clearCachedSections: true,
                  );
                  await HiveUtils.logoutUser(
                    context,
                    onLogout: () {},
                  );
                },
              );
            },
            cancelTextColor: context.color.textColorDark,
            svgImagePath: "assets/lottie/logout.json",
            content: Text("confirmLogOutMsg".translate(context))));
  }

  void deleteConfirmWidget() {
    UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: "deleteProfileMessageTitle".translate(context),
        content: Text("yourAdsAndTransactionDelete".translate(context)),
        cancelButtonName: 'no'.translate(context),
        acceptButtonName: "deleteBtnLbl".translate(context),
        onAccept: () async {
          // ضع هنا كود الحذف أو نفس منطقك القديم
        },
      ),
    );
  }



  String sellerStatus(String status) {
    if (status == 'pending') {
      return 'underReview'.translate(context);
    } else if (status == 'approved') {
      return 'approved'.translate(context);
    } else if (status == 'rejected') {
      return 'rejected'.translate(context);
    } else if (status == 'resubmitted') {
      return 'resubmitted'.translate(context);
    } else {
      return '';
    }
  }

  void askToLoginAgain() {
    HelperUtils.showSnackBarMessage(context, 'loginReqMsg'.translate(context));
    HiveUtils.clear();
    Constant.favoriteItemList.clear();
    context.read<UserDetailsCubit>().clear();
    context.read<FavoriteCubit>().resetState();
    context.read<UpdatedReportItemCubit>().clearItem();
    context.read<GetBuyerChatListCubit>().resetState();
    context.read<BlockedUsersListCubit>().resetState();
    FetchSystemSettingsCubit.resetDelegateSectionsFor(
      context,
      clearCachedSections: true,
    );
    HiveUtils.logoutUser(context, onLogout: () {});
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  Future<void> signOut(AuthenticationType? type) async {
    if (type == AuthenticationType.google) {
      await _googleSignIn.signOut();
    } else {
      await _auth.signOut();
    }
  }

  Future<void> proceedToDeleteProfile() async {
    try {
      await _auth.currentUser!.delete().then((_) async {
        final value = await context.read<DeleteUserCubit>().deleteUser();
        HelperUtils.showSnackBarMessage(context, (value["message"]));
        for (int i = 0; i < AuthenticationType.values.length; i++) {
          if (AuthenticationType.values[i].name == HiveUtils.getUserDetails().type) {
            await signOut(AuthenticationType.values[i]);

            HiveUtils.clear();
            Constant.favoriteItemList.clear();
            context.read<UserDetailsCubit>().clear();
            context.read<FavoriteCubit>().resetState();
            context.read<UpdatedReportItemCubit>().clearItem();
            context.read<GetBuyerChatListCubit>().resetState();
            context.read<BlockedUsersListCubit>().resetState();

            await FetchSystemSettingsCubit.resetDelegateSectionsFor(
              context,
              clearCachedSections: true,
            );
            await HiveUtils.logoutUser(context, onLogout: () {});

            Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (route) => false);
          }
        }
      });
    } on FirebaseAuthException catch (error) {
      if (error.code == "requires-recent-login") {
        for (int i = 0; i < AuthenticationType.values.length; i++) {
          if (AuthenticationType.values[i].name == HiveUtils.getUserDetails().type) {
            await signOut(AuthenticationType.values[i]);

            HiveUtils.clear();
            Constant.favoriteItemList.clear();
            context.read<UserDetailsCubit>().clear();
            context.read<FavoriteCubit>().resetState();
            context.read<UpdatedReportItemCubit>().clearItem();
            context.read<GetBuyerChatListCubit>().resetState();
            context.read<BlockedUsersListCubit>().resetState();

            await FetchSystemSettingsCubit.resetDelegateSectionsFor(
              context,
              clearCachedSections: true,
            );
            await HiveUtils.logoutUser(context, onLogout: () {});

            Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (route) => false);
          }
        }
      } else {
        final rawMessage = error.message?.trim();
        final errorMessage = (rawMessage != null && rawMessage.isNotEmpty)
            ? rawMessage
            : 'somethingWentWrong'.translate(context);
        HelperUtils.showSnackBarMessage(context, errorMessage);

      }
    } catch (e) {
      debugPrint("unable to delete user - ${e.toString()}");
    }
  }

  Future<void> rateUs() {
    return _inAppReview.openStoreListing(
      appStoreId: Constant.iOSAppId,
      microsoftStoreId: 'microsoftStoreId',
    );
  }

  void shareApp() {
    try {
      if (Platform.isAndroid) {
        Share.share(
          '${Constant.appName}\n${Constant.playstoreURLAndroid}\n${Constant.shareappText}',
          subject: Constant.appName,
        );
      } else {
        Share.share(
          '${Constant.appName}\n${Constant.appstoreURLios}\n${Constant.shareappText}',
          subject: Constant.appName,
          sharePositionOrigin: Rect.fromLTWH(
            0,
            0,
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height / 2,
          ),
        );
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(context, e.toString());
    }
  }

  Color _getAccountTypeBadgeColor(BuildContext context) {
    final int? accountType = HiveUtils.getUserDetails().userType;
    switch (accountType) {
      case 1:
        return Colors.blue;   // فردي
      case 2:
        return Colors.green;  // عقاري
      case 3:
        return Colors.orange; // تجاري
      default:
        return Colors.grey;
    }
  }

  String _getAccountTypeText() {
    final int? accountType = HiveUtils.getUserDetails().userType;
    switch (accountType) {
      case 1:
        return 'individual'.translate(context);
      case 2:
        return 'realEstate'.translate(context);
      case 3:
        return 'commercial'.translate(context);
      default:
        return 'notSpecified'.translate(context);
    }
  }

  // واجهات لاستخدامها من الواجهة
  Color getAccountTypeBadgeColor(BuildContext context) => _getAccountTypeBadgeColor(context);
  String getAccountTypeText() => _getAccountTypeText();
}




