
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
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/data/repositories/my_services_repository.dart';
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
import 'package:marib/ui/widgets/verification_badge_loader.dart';
import 'package:marib/data/model/verification_request_model.dart';
import 'package:marib/utils/route_observer.dart';

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

    if (!const bool.fromEnvironment(
        "force-disable-demo-mode", defaultValue: false)) {
      Constant.isDemoModeOn =
          settings.getSetting(SystemSetting.demoMode) ?? false;
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
            content: Text("confirmLogOutMsg".translate(context))));
  }

  void deleteConfirmWidget() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.color.primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;
        bool isDeleting = false;

        Future<void> _deleteOwnedContent() async {
          final itemRepository = ItemRepository();
          int fetchedItems = 0;
          int page = 1;
          while (true) {
            final itemsPage = await itemRepository.fetchMyItems(page: page);
            final items = itemsPage.modelList;
            if (items.isEmpty) break;
            for (final item in items) {
              final id = item.id;
              if (id != null) {
                try {
                  await itemRepository.deleteItem(id);
                } catch (_) {}
              }
            }
            fetchedItems += items.length;
            if (fetchedItems >= itemsPage.total) break;
            page += 1;
          }

          final myServicesRepository = MyServicesRepository();
          int fetchedServices = 0;
          int servicePage = 1;
          while (true) {
            final servicesPage =
                await myServicesRepository.fetchMyServices(page: servicePage);
            final services = servicesPage.modelList;
            if (services.isEmpty) break;
            for (final service in services) {
              final id = service.id;
              if (id != null) {
                try {
                  await myServicesRepository.deleteService(id);
                } catch (_) {}
              }
            }
            fetchedServices += services.length;
            if (fetchedServices >= servicesPage.total) break;
            servicePage += 1;
          }
        }

        Future<void> _performDelete(StateSetter setModalState) async {
          setModalState(() => isDeleting = true);

          try {
            await _deleteOwnedContent();
          } catch (_) {}

          final deleteCubit = sheetContext.read<DeleteUserCubit>();
          final result = await deleteCubit.deleteUser();
          final deleteFailed =
              deleteCubit.state is DeleteUserFetchFailure || result == null;

          if (!mounted) return;

          if (deleteFailed) {
            setModalState(() => isDeleting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("تعذر حذف الحساب، حاول لاحقاً."),
              ),
            );
            return;
          }

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

          if (!mounted) return;

          Navigator.of(sheetContext).pop();
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.login,
            (_) => false,
          );
        }

        const bullets = <String>[
          "سيتم حذف إعلاناتك وكل بياناتها.",
          "سيتم إزالة المحادثات المرتبطة بحسابك.",
          "لن تستطيع استعادة الحساب أو البيانات لاحقاً.",
          "قد تبقى بعض السجلات المالية لأسباب تنظيمية.",
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            return WillPopScope(
              onWillPop: () async => !isDeleting,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  top: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSurface.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "شكراً لتجربتك",
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "قبل حذف حسابك، خذ لحظة لقراءة ما سيحدث بعد التأكيد.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "ماذا يعني حذف حسابك؟",
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ...bullets.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.brightness_1,
                              size: 8,
                              color: colors.error.withOpacity(0.8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface.withOpacity(0.85),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isDeleting
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: colors.outline),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "رجوع",
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: colors.onSurface),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isDeleting
                                ? null
                                : () => _performDelete(setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.error,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isDeleting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onError,
                                    ),
                                  )
                                : Text(
                                    "تأكيد حذف الحساب",
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: colors.onError,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
