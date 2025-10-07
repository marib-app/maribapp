import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/cart/cart_cubit.dart';
import 'package:marib/data/cubits/fetch_notifications_cubit.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:marib/data/model/item/cart_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/hive_keys.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hive_flutter/adapters.dart';

import 'package:marib/data/model/system_settings_model.dart';

import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';

import 'package:marib/utils/helper_utils.dart';

class ProfileHeaderWidget extends StatefulWidget {
  const ProfileHeaderWidget({super.key});

  @override
  State<ProfileHeaderWidget> createState() => _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends State<ProfileHeaderWidget>
    with AutomaticKeepAliveClientMixin<ProfileHeaderWidget> {
  bool notificationsSeen = false;
  ValueNotifier isDarkTheme = ValueNotifier(false);
  bool isExpanded = false;

/*  //bool isGuest = false;
  String username = "";
  String email = "";*/

  @override
  void initState() {
    var settings = context.read<FetchSystemSettingsCubit>();
    //userData();
    if (HiveUtils.isUserAuthenticated()) {
      context
          .read<FetchVerificationRequestsCubit>()
          .fetchVerificationRequests();
    }
    if (!const bool.fromEnvironment("force-disable-demo-mode",
        defaultValue: false)) {
      Constant.isDemoModeOn =
          settings.getSetting(SystemSetting.demoMode) ?? false;
    }

    super.initState();
  }

  @override
  void didChangeDependencies() {
    isDarkTheme.value = context.read<AppThemeCubit>().isDarkMode();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    isDarkTheme.dispose();
    super.dispose();
  }

  Widget setIconButtons({
    required String assetName,
    required void Function() onTap,
    Color? color,
    double? height,
    double? width,
  }) {
    return Container(
      height: 36,
      width: 36,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: context.color.textDefaultColor.withOpacity(0.1))),
      child: InkWell(
          onTap: onTap,
          child: SvgPicture.asset(
            assetName,
            height: 24,
            width: 24,
            colorFilter: color == null
                ? ColorFilter.mode(
                    context.color.territoryColor, BlendMode.srcIn)
                : ColorFilter.mode(color, BlendMode.srcIn),
          )),
    );
  }

  Widget getProfileImage() {
    if (HiveUtils.isUserAuthenticated()) {
      if ((HiveUtils.getUserDetails().profile ?? "").isEmpty) {
        return UiUtils.getSvg(
          AppIcons.defaultPersonLogo,
          color: context.color.territoryColor,
          fit: BoxFit.none,
        );
      } else {
        return UiUtils.getImage(
          height: 100,
          width: 100,
          HiveUtils.getUserDetails().profile!,
          fit: BoxFit.cover,
        );
      }
    } else {
      return UiUtils.getSvg(
        AppIcons.defaultPersonLogo,
        color: context.color.territoryColor,
        fit: BoxFit.none,
      );
    }
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

  @override
  bool get wantKeepAlive => true;

  Widget profileHeader() {
    return BlocBuilder<FetchVerificationRequestsCubit,
        FetchVerificationRequestState>(builder: (context, state) {
      return ValueListenableBuilder(
          valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
          builder: (context, Box box, _) {
            return Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      UiUtils.checkUser(
                          onNotGuest: () {
                            HelperUtils.goToNextPage(
                                Routes.showProfile, context, false,
                                args: {"from": "profile"});
                          },
                          context: context);
                    },
                    child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.color.territoryColor)),
                        child: CircleAvatar(
                            backgroundColor: context.color.backgroundColor,
                            radius: 30,
                            child: HiveUtils.isUserAuthenticated()
                                ? (HiveUtils.getUserDetails().profile ?? "")
                                        .isEmpty
                                    ? UiUtils.getSvg(
                                        AppIcons.defaultPersonLogo,
                                        color: context.color.territoryColor,
                                        fit: BoxFit.none,
                                      )
                                    : UiUtils.getImage(
                                        height: 100,
                                        width: 100,
                                        HiveUtils.getUserDetails().profile!,
                                        fit: BoxFit.cover,
                                      )
                                : UiUtils.getSvg(
                                    AppIcons.defaultPersonLogo,
                                    color: context.color.territoryColor,
                                    fit: BoxFit.none,
                                  ))),
                  ),
                  SizedBox(
                    width: context.screenWidth * 0.04,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        (state is FetchVerificationRequestInProgress ||
                                state is FetchVerificationRequestInitial ||
                                state is FetchVerificationRequestFail)
                            ? SizedBox()
                            : (HiveUtils.isUserAuthenticated() &&
                                    ((HiveUtils.getUserDetails().isVerified ==
                                            1) ||
                                        (state as FetchVerificationRequestSuccess)
                                                .data
                                                .status ==
                                            "approved"))
                                ? Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: context.color.forthColor,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        UiUtils.getSvg(AppIcons.verifiedIcon,
                                            width: 14, height: 14),
                                        SizedBox(width: 4),
                                        Text("verifiedLbl".translate(context))
                                            .color(context.color.secondaryColor)
                                            .bold(weight: FontWeight.w500)
                                      ],
                                    ),
                                  )
                                : SizedBox(),
                        // If none of the conditions are met, return an empty widget

                        SizedBox(
                          height: 5,
                        ),
                        if (HiveUtils.isUserAuthenticated()) ...[
                          GestureDetector(
                            onTap: () {
                              UiUtils.checkUser(
                                  onNotGuest: () {
                                    HelperUtils.goToNextPage(
                                        Routes.showProfile, context, false,
                                        args: {"from": "profile"});
                                  },
                                  context: context);
                            },
                            child: SizedBox(
                              width: context.screenWidth * 0.53,
                              child: Text(
                                HiveUtils.getUserDetails().name ?? '',
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              )
                                  .color(context.color.textColorDark)
                                  .size(context.font.large)
                                  .bold(weight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(
                            height: 3,
                          ),
                          SizedBox(
                            width: context.screenWidth * 0.63,
                            child: Text(
                              // /        '#' +
                              (HiveUtils.getUserDetails()?.mobile?.toString() ??
                                  ''),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            )
                                .color(context.color.textColorDark)
                                .size(context.font.small),
                          ),
                        ],

                        if (!HiveUtils.isUserAuthenticated()) ...[
                          SizedBox(
                            width: context.screenWidth * 0.4,
                            child: Text(
                              "anonymous".translate(context),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            )
                                .color(context.color.textColorDark)
                                .size(context.font.large)
                                .bold(weight: FontWeight.w700),
                          ),
                        ],

                        // (state is FetchVerificationRequestInProgress ||
                        //         state is FetchVerificationRequestInitial ||
                        //         state is FetchVerificationRequestFail)
                        //     ? SizedBox()
                        //     : (HiveUtils.isUserAuthenticated() &&
                        //             (((state as FetchVerificationRequestSuccess)
                        //                     .data
                        //                     .status) ==
                        //                 "rejected"))
                        //         ? Column(
                        //             mainAxisSize: MainAxisSize.min,
                        //             children: [
                        //                 SizedBox(
                        //                   height: 7,
                        //                 ),
                        //                 SizedBox(
                        //                   width: context.screenWidth *
                        //                       0.63.rw(context),
                        //                   child: LayoutBuilder(
                        //                     builder: (context, constraints) {
                        //                       // Measure the rendered text
                        //                       final span = TextSpan(
                        //                         text:
                        //                             "${state.data.rejectionReason!}\t",
                        //                         style: TextStyle(
                        //                           fontWeight: FontWeight.w400,
                        //                           fontSize: context.font.small,
                        //                           color: Colors.red,
                        //                         ),
                        //                       );
                        //                       final tp = TextPainter(
                        //                         text: span,
                        //                         maxLines: 2,
                        //                         // Maximum number of lines before overflow
                        //                         textDirection:
                        //                             TextDirection.ltr,
                        //                       );
                        //                       tp.layout(
                        //                           maxWidth:
                        //                               constraints.maxWidth);

                        //                       final isOverflowing =
                        //                           tp.didExceedMaxLines;

                        //                       return Row(
                        //                         crossAxisAlignment:
                        //                             CrossAxisAlignment.end,
                        //                         children: [
                        //                           Expanded(
                        //                             child: Text(
                        //                               "${state.data.rejectionReason!}\t",
                        //                               maxLines:
                        //                                   isExpanded ? null : 2,
                        //                               softWrap: true,
                        //                               overflow: isExpanded
                        //                                   ? TextOverflow.visible
                        //                                   : TextOverflow
                        //                                       .ellipsis,
                        //                             )
                        //                                 .color(Colors.red)
                        //                                 .bold(
                        //                                     weight:
                        //                                         FontWeight.w400)
                        //                                 .size(
                        //                                     context.font.small),
                        //                           ),
                        //                           if (isOverflowing) // Conditionally show the button
                        //                             Padding(
                        //                               padding:
                        //                                   EdgeInsetsDirectional
                        //                                       .only(start: 3),
                        //                               child: GestureDetector(
                        //                                 onTap: () {
                        //                                   setState(() {
                        //                                     isExpanded =
                        //                                         !isExpanded; // Toggle the expanded state
                        //                                   });
                        //                                 },
                        //                                 child: Text(
                        //                                   isExpanded
                        //                                       ? "readLessLbl"
                        //                                           .translate(
                        //                                               context)
                        //                                       : "readMoreLbl"
                        //                                           .translate(
                        //                                               context),
                        //                                 )
                        //                                     .color(context.color
                        //                                         .textDefaultColor)
                        //                                     .bold(
                        //                                         weight:
                        //                                             FontWeight
                        //                                                 .w400)
                        //                                     .size(context
                        //                                         .font.small),
                        //                               ),
                        //                             ),
                        //                         ],
                        //                       );
                        //                     },
                        //                   ),
                        //                 )
                        //               ])
                        //         : SizedBox.shrink(),

                        // (state is FetchVerificationRequestInProgress ||
                        //         state is FetchVerificationRequestInitial ||
                        //         state is FetchVerificationRequestFail)
                        //     ? SizedBox()
                        //     : (HiveUtils.isUserAuthenticated() &&
                        //             (((state as FetchVerificationRequestSuccess)
                        //                     .data
                        //                     .status) !=
                        //                 "approved"))
                        //         ? Column(
                        //             mainAxisSize: MainAxisSize.min,
                        //             children: [
                        //               SizedBox(
                        //                 height: 12,
                        //               ),
                        //               Row(
                        //                 mainAxisSize: MainAxisSize.min,
                        //                 mainAxisAlignment:
                        //                     MainAxisAlignment.spaceEvenly,
                        //                 children: [
                        //                   SizedBox(
                        //                       child: Container(
                        //                     padding: EdgeInsets.symmetric(
                        //                         horizontal: 12, vertical: 4),
                        //                     decoration: BoxDecoration(
                        //                       borderRadius:
                        //                           BorderRadius.circular(5),
                        //                       color: ((state).data.status ==
                        //                               'rejected')
                        //                           ? Colors.red
                        //                           : context
                        //                               .color.territoryColor,
                        //                     ),
                        //                     child: Text(sellerStatus(
                        //                             (state).data.status!))
                        //                         .color(context
                        //                             .color.secondaryColor)
                        //                         .size(context.font.small)
                        //                         .bold(weight: FontWeight.w500),
                        //                   )),
                        //                   if ((state).data.status ==
                        //                       'rejected') ...[
                        //                     SizedBox(
                        //                       width: 12,
                        //                     ),
                        //                     InkWell(
                        //                       child: SizedBox(
                        //                           child: Container(
                        //                         padding: EdgeInsets.symmetric(
                        //                             horizontal: 12,
                        //                             vertical: 4),
                        //                         decoration: BoxDecoration(
                        //                           borderRadius:
                        //                               BorderRadius.circular(5),
                        //                           color: context
                        //                               .color.territoryColor,
                        //                         ),
                        //                         child: Text("resubmit"
                        //                                 .translate(context))
                        //                             .color(context
                        //                                 .color.secondaryColor)
                        //                             .size(context.font.small)
                        //                             .bold(
                        //                                 weight:
                        //                                     FontWeight.w500),
                        //                       )),
                        //                       onTap: () {
                        //                         Navigator.pushNamed(
                        //                             context,
                        //                             Routes
                        //                                 .sellerIntroVerificationScreen,
                        //                             arguments: {
                        //                               "isResubmitted": true
                        //                             }).then((value) {
                        //                           if (value == 'refresh') {
                        //                             context
                        //                                 .read<
                        //                                     FetchVerificationRequestsCubit>()
                        //                                 .fetchVerificationRequests();
                        //                           }
                        //                         });
                        //                       },
                        //                     )
                        //                   ],
                        //                 ],
                        //               ),
                        //             ],
                        //           )
                        //         : SizedBox.shrink(),

                        // (state is FetchVerificationRequestInProgress ||
                        //         state is FetchVerificationRequestInitial ||
                        //         state is FetchVerificationRequestSuccess)
                        //     ? SizedBox()
                        //     : (HiveUtils.isUserAuthenticated() &&
                        //             ((HiveUtils.getUserDetails().isVerified ==
                        //                     0) ||
                        //                 (state is FetchVerificationRequestFail))
                        //         ? Column(
                        //             mainAxisSize: MainAxisSize.min,
                        //             children: [
                        //               SizedBox(
                        //                 height: 7,
                        //               ),
                        //               InkWell(
                        //                 child: SizedBox(
                        //                     child: Container(
                        //                   padding: EdgeInsets.symmetric(
                        //                       horizontal: 12, vertical: 4),
                        //                   decoration: BoxDecoration(
                        //                     borderRadius:
                        //                         BorderRadius.circular(5),
                        //                     color: context.color.territoryColor,
                        //                   ),
                        //                   child: Text("getVerificationBadge"
                        //                           .translate(context))
                        //                       .color(
                        //                           context.color.secondaryColor)
                        //                       .size(context.font.small)
                        //                       .bold(weight: FontWeight.w500),
                        //                 )),
                        //                 onTap: () {
                        //                   Navigator.pushNamed(
                        //                       context,
                        //                       Routes
                        //                           .sellerIntroVerificationScreen,
                        //                       arguments: {
                        //                         "isResubmitted": false
                        //                       }).then((value) {
                        //                     if (value == 'refresh') {
                        //                       context
                        //                           .read<
                        //                               FetchVerificationRequestsCubit>()
                        //                           .fetchVerificationRequests();
                        //                     }
                        //                   });
                        //                 },
                        //               ),
                        //             ],
                        //           )
                        //         : SizedBox.shrink()),
                      ],
                    ),
                  ),
                  //const Spacer(),

                  // Align(
                  //   alignment: AlignmentDirectional.centerEnd,
                  //   child: Stack(
                  //     clipBehavior: Clip
                  //         .none, // Allows the badge to be outside the icon's bounds
                  //     children: [
                  //       IconButton(
                  //         icon: UiUtils.getSvg(
                  //           AppIcons.cart,
                  //           height: 24,
                  //           width: 24,
                  //           color: context.color.territoryColor,
                  //         ),
                  //         onPressed: () {
                  //           Navigator.pushNamed(context, Routes.cart);
                  //         },
                  //       ),
                  //       if (context.watch<CartCubit>().totalItems > 0)
                  //         Positioned(
                  //           top: -1,
                  //           right: -1,
                  //           child: Container(
                  //             padding: EdgeInsets.symmetric(
                  //                 vertical: 2, horizontal: 6),
                  //             decoration: BoxDecoration(
                  //               color:
                  //                   context.color.territoryColor, // Badge color
                  //               borderRadius: BorderRadius.circular(12),
                  //             ),
                  //             child: Text(
                  //               context
                  //                   .watch<CartCubit>()
                  //                   .totalItems
                  //                   .toString(),
                  //               style: TextStyle(
                  //                 color: Colors.white,
                  //                 fontSize: 12,
                  //                 fontWeight: FontWeight.bold,
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //     ],
                  //   ),
                  // ),

                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: UiUtils.getSvg(
                            AppIcons.cart,
                            height: 24,
                            width: 24,
                            color: context.color.territoryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              notificationsSeen = true;
                            });
                            UiUtils.checkUser(
                              onNotGuest: () {
                                Navigator.pushNamed(context, Routes.cart);
                              },
                              context: context,
                            );
                          },
                        ),
                        Positioned(
                          top: -1,
                          right: -1,
                          child: BlocBuilder<CartCubit, List<Cart>>(
                            builder: (context, cartItems) {
                              final totalItems = cartItems.length;
                              if (totalItems == 0)
                                return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: context
                                      .color.territoryColor, // لون البادج
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  totalItems.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: UiUtils.getSvg(
                            AppIcons.notification,
                            height: 24,
                            width: 24,
                            color: context.color.territoryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              notificationsSeen = true;
                            });
                            UiUtils.checkUser(
                              onNotGuest: () {
                                Navigator.pushNamed(
                                    context, Routes.notificationPage);
                              },
                              context: context,
                            );
                          },
                        ),
                        Positioned(
                          top: -1,
                          right: -1,
                          child: notificationsSeen
                              ? const SizedBox.shrink()
                              : BlocBuilder<FetchNotificationsCubit,
                                  FetchNotificationsState>(
                                  builder: (context, state) {
                                    int notifCount = 0;
                                    if (state is FetchNotificationsSuccess) {
                                      notifCount =
                                          state.notificationdata.length;
                                    }
                                    if (notifCount == 0)
                                      return const SizedBox.shrink();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: context.color.territoryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        notifCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      icon: UiUtils.getSvg(
                        AppIcons.aboutUs,
                        height: 24,
                        width: 24,
                        color: context.color.territoryColor,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          Routes.info,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context, statusBarColor: context.color.secondaryColor),
      child: profileHeader(),
    );
  }
}
