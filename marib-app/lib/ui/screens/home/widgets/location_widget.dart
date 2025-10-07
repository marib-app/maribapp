/*
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_keys.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../data/cubits/Home/fetch_home_all_items_cubit.dart';
import '../../../../data/cubits/Home/fetch_home_screen_cubit.dart';
import '../../../../data/model/google_place_model.dart';
import '../../../../utils/app_icon.dart';

import '../../../../utils/ui_utils.dart';
import '../../widgets/BottomSheets/choose_location_bottomsheet.dart';

class LocationWidget extends StatelessWidget {
  const LocationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16.rw(context),
          ),
          GestureDetector(
            onTap: () async {
              var result = await showModalBottomSheet(
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20))),
                context: context,
                builder: (context) {
                  return const ChooseLocatonBottomSheet();
                },
              );
              if (result != null) {
                GooglePlaceModel place = (result as GooglePlaceModel);

                HiveUtils.setLocation(
                    city: place.city,
                    state: place.state,
                    country: place.country,
                    placeId: place.placeId,
                    latitude: place.latitude,
                    longitude: place.longitude);

                // Location update removed - displaying all items regardless of location
                // Future.delayed(
                //   Duration.zero,
                //   () {
                //     context.read<FetchHomeScreenCubit>().fetch(
                //           city: HiveUtils.getCityName(),
                //         );
                //     context.read<FetchHomeAllItemsCubit>().fetch(
                //           city: HiveUtils.getCityName(),
                //         );
                //   },
                // );
              }
            },
            child: Container(
              width: 40.rw(context),
              height: 40.rh(context),
              decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(10)),
              child: UiUtils.getSvg(
                AppIcons.location,
                fit: BoxFit.none,
                color: context.color.territoryColor,
              ),
            ),
          ),
          SizedBox(
            width: 10.rw(context),
          ),
          ValueListenableBuilder(
              valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
              builder: (context, value, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("locationLbl".translate(context))
                        .color(context.color.textColorDark)
                        .size(
                          context.font.small,
                        ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        HiveUtils.getCityName() == null
                            ? "---"
                            : ((HiveUtils.getCityName() ?? "") +
                                    (HiveUtils.getStateName() == null ||
                                            HiveUtils.getStateName() == ""
                                        ? ""
                                        : ",") +
                                    (HiveUtils.getStateName() ?? "") +
                                    (HiveUtils.getCountryName() == null ||
                                            HiveUtils.getCountryName() == ""
                                        ? ""
                                        : ",") +
                                    (HiveUtils.getCountryName() ?? "")) +
                                "",
                        maxLines: 1,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      )
                          .color(context.color.textColorDark)
                          .size(context.font.small)
                          .bold(weight: FontWeight.w600),
                    ),
                  ],
                );
              }),
        ],
      ),
    );
  }
}
*/

import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_keys.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:marib/utils/app_icon.dart';

import 'package:marib/utils/ui_utils.dart';

class LocationWidget extends StatelessWidget {
  const LocationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.none,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              Navigator.pushNamed(context, Routes.countriesScreen,
                  arguments: {"from": "home"});
            },
            child: Container(
              width: 40.rw(context),
              height: 40.rh(context),
              decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(10)),
              child: UiUtils.getSvg(
                AppIcons.location,
                fit: BoxFit.none,
                color: context.color.territoryColor,
              ),
            ),
          ),
          SizedBox(
            width: 10.rw(context),
          ),
          ValueListenableBuilder(
              valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
              builder: (context, value, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("locationLbl".translate(context))
                        .color(context.color.textColorDark)
                        .size(
                          context.font.small,
                        ),
                    Text(
                      [
                        HiveUtils.getAreaName(),
                        HiveUtils.getCityName(),
                        HiveUtils.getStateName(),
                        HiveUtils.getCountryName()
                      ]
                              .where((element) =>
                                  element != null && element.isNotEmpty)
                              .join(", ")
                              .isEmpty
                          ? "------"
                          : [
                              HiveUtils.getAreaName(),
                              HiveUtils.getCityName(),
                              HiveUtils.getStateName(),
                              HiveUtils.getCountryName()
                            ]
                              .where((element) =>
                                  element != null && element.isNotEmpty)
                              .join(", ")
                      /*HiveUtils.getCityName() == null
                          ? "---"
                          : (HiveUtils.getAreaName() ?? "") +
                              ((HiveUtils.getAreaName() == null ||
                                          HiveUtils.getAreaName() == ""
                                      ? ""
                                      : ",") +
                                  (HiveUtils.getCityName() ?? "") +
                                  (HiveUtils.getStateName() == null ||
                                          HiveUtils.getStateName() == ""
                                      ? ""
                                      : ",") +
                                  (HiveUtils.getStateName() ?? "") +
                                  (HiveUtils.getCountryName() == null ||
                                          HiveUtils.getCountryName() == ""
                                      ? ""
                                      : ",") +
                                  (HiveUtils.getCountryName() ?? "")) +
                              ""*/
                      ,
                      maxLines: 1,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    )
                        .color(context.color.textColorDark)
                        .size(context.font.small)
                        .bold(weight: FontWeight.w600),
                  ],
                );
              }),
        ],
      ),
    );
  }
}
