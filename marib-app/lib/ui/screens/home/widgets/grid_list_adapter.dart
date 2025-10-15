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
  final Widget? trailing;

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
    this.trailing,

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
      final int columns = max(crossAxisCount ?? 2, 1);
      final double verticalSpacing = 15 / 2;
      final int adsInterval = max(Constant.nativeAdsAfterItemNumber, 1);

      final List<_MixedEntry> entries = <_MixedEntry>[];
      int itemIndex = 0;

      while (itemIndex < total) {
        final int itemsThisRow = min(columns, total - itemIndex);
        entries.add(_MixedEntry.row(
          startIndex: itemIndex,
          count: itemsThisRow,
        ));
        itemIndex += itemsThisRow;

        final bool shouldInsertAd =
            itemIndex % adsInterval == 0 && itemIndex < total;
        if (shouldInsertAd) {
          entries.add(const _MixedEntry.ad());
        }
      }

      if (trailing != null) {
        entries.add(_MixedEntry.trailing(trailing!));
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final _MixedEntry entry = entries[index];

            switch (entry.type) {
              case _MixedEntryType.row:
                final Widget row = _MixedGridRow(
                  builder: builder,
                  entry: entry,
                  columns: columns,
                );

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sidePadding,
                    vertical: verticalSpacing,
                  ),
                  child: height != null
                      ? SizedBox(height: height, child: row)
                      : row,
                );
              case _MixedEntryType.ad:
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sidePadding,
                    vertical: verticalSpacing,
                  ),
                  child: const NativeAdWidget(
                    type: TemplateType.medium,
                  ),
                );
              case _MixedEntryType.trailing:
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sidePadding,
                    vertical: verticalSpacing,
                  ),
                  child: entry.trailing!,
                );
            }
          },
          childCount: entries.length,
        ),
      );
    } else {
      return Container();
    }
  }
}




class _MixedGridRow extends StatelessWidget {
  const _MixedGridRow({
    required this.builder,
    required this.entry,
    required this.columns,
  });

  final Widget Function(BuildContext, int, bool) builder;
  final _MixedEntry entry;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];

    for (int i = 0; i < entry.count; i++) {
      final int globalIndex = entry.startIndex! + i;
      children.add(
        Expanded(
          child: builder(context, globalIndex, true),
        ),
      );
      if (i != entry.count - 1) {
        children.add(const SizedBox(width: 15));
      }
    }

    final int remaining = columns - entry.count;
    for (int j = 0; j < remaining; j++) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 15));
      }
      children.add(const Expanded(child: SizedBox.shrink()));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

enum _MixedEntryType { row, ad, trailing }

class _MixedEntry {
  const _MixedEntry._(this.type, {this.startIndex, this.count = 0, this.trailing});

  factory _MixedEntry.row({required int startIndex, required int count}) =>
      _MixedEntry._(
        _MixedEntryType.row,
        startIndex: startIndex,
        count: count,
      );

  const _MixedEntry.ad() : this._(_MixedEntryType.ad);

  factory _MixedEntry.trailing(Widget widget) =>
      _MixedEntry._(_MixedEntryType.trailing, trailing: widget);

  final _MixedEntryType type;
  final int? startIndex;
  final int count;
  final Widget? trailing;
}