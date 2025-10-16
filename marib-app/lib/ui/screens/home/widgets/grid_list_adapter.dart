import 'dart:math';

import 'package:marib/ui/screens/home_screen/home_screen.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:marib/ui/screens/native_ads_screen.dart';

enum ListUiType { Grid, List, Mixed }

class GridListAdapter extends StatelessWidget {
  final ListUiType type;
  final Widget Function(BuildContext, int, bool) builder;
  final Widget Function(BuildContext, int)? listSaperator;
  final int total;
  final int? crossAxisCount;
  final double? height;
  final Axis? listAxis;
  final ScrollController? controller;
  final bool? isNotSidePadding;
  final bool mixMode;

  const GridListAdapter({
    super.key,
    required this.type,
    required this.builder,
    required this.total,
    this.crossAxisCount,
    this.height,
    this.listAxis,
    this.listSaperator,
    this.controller,
    this.isNotSidePadding,
    this.mixMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (type == ListUiType.List) {
      return SizedBox(
        height: listAxis == Axis.horizontal ? height : null,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(
              horizontal: isNotSidePadding != null ? 0 : sidePadding),
          scrollDirection: listAxis ?? Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => builder(context, index, false),
          itemCount: total,
          separatorBuilder: listSaperator ?? ((c, i) => Container()),
        ),
      );
    } else if (type == ListUiType.Grid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: sidePadding),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
            crossAxisCount: crossAxisCount ?? 2,
            height: height ?? 1,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15),
        itemBuilder: (context, index) => builder(context, index, false),
        itemCount: total,
      );
    } else if (type == ListUiType.Mixed) {
      List<Widget> children = [];
      int gridCount = Constant.nativeAdsAfterItemNumber;
      int listCount = 1;

      for (int i = 0; i < total; i += gridCount + listCount) {
        children.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: sidePadding, vertical: 15 / 2),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
                    crossAxisCount: crossAxisCount ?? 2,
                    height: height ?? 1,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15),
            itemBuilder: (context, index) => builder(context, i + index, true),
            itemCount: min(gridCount, total - i),
          ),
        );

        int listItemCount = min(listCount, total - i - gridCount);
        if (listItemCount > 0) {
          children.add(NativeAdWidget(
            type: TemplateType.medium,
          ));
        }
      }

      return Column(
        children: children,
      );
    } else {
      return Container();
    }
  }
}
