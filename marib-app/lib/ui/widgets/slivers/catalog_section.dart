import 'package:flutter/widgets.dart';

/// Represents a section inside catalog like list/grid/ad.
/// Each section is lazily built via sliver when consumed.
typedef CatalogIndexedWidgetBuilder = Widget Function(
    BuildContext context,
    int index,
    );

typedef CatalogSemanticIndexCallback = int? Function(
    Widget widget,
    int localIndex,
    );

typedef CatalogChildIndexGetter = int? Function(Key key);

/// Base contract for a lazily built section within a catalog oriented screen.
///
/// Each section describes its layout requirements while the rendering is
/// delegated to the sliver section builder utilities.
sealed class CatalogSection {
  const CatalogSection({this.key, this.padding});

  /// Optional key applied to the produced sliver.
  final Key? key;

  /// Optional padding around section.
  final EdgeInsetsGeometry? padding;
}

/// Section that renders a vertical list using the provided [itemBuilder].
class CatalogListSection extends CatalogSection {
  const CatalogListSection({
    super.key,
    super.padding,
    required this.itemCount,
    required this.itemBuilder,
    this.itemExtent,
    this.prototypeItem,
    this.addAutomaticKeepAlives = false,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticIndexCallback,
    this.semanticIndexOffset = 0,
    this.findChildIndexCallback,
  })  : assert(itemCount >= 0, 'itemCount must be >= 0'),
        assert(
        itemExtent == null || prototypeItem == null,
        'itemExtent and prototypeItem are mutually exclusive',
        );

  final int itemCount;
  final CatalogIndexedWidgetBuilder itemBuilder;
  final double? itemExtent;
  final Widget? prototypeItem;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final CatalogSemanticIndexCallback? semanticIndexCallback;
  final int semanticIndexOffset;
  final CatalogChildIndexGetter? findChildIndexCallback;
}

/// Section that renders a sliver grid.
class CatalogGridSection extends CatalogSection {
  const CatalogGridSection({
    super.key,
    super.padding,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.addAutomaticKeepAlives = false,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticIndexCallback,
    this.semanticIndexOffset = 0,
    this.findChildIndexCallback,
  }) : assert(itemCount >= 0, 'itemCount must be >= 0');

  final int itemCount;
  final CatalogIndexedWidgetBuilder itemBuilder;
  final SliverGridDelegate gridDelegate;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final CatalogSemanticIndexCallback? semanticIndexCallback;
  final int semanticIndexOffset;
  final CatalogChildIndexGetter? findChildIndexCallback;
}

/// Section that inflates a static widget through [SliverToBoxAdapter].
class CatalogBoxSection extends CatalogSection {
  const CatalogBoxSection({
    super.key,
    super.padding,
    required this.child,
  });

  final Widget child;
}

/// Section that pins a [SliverPersistentHeaderDelegate].
class CatalogPersistentHeaderSection extends CatalogSection {
  const CatalogPersistentHeaderSection({
    super.key,
    super.padding,
    required this.delegate,
    this.pinned = false,
    this.floating = false,
    this.snap = false,

  });

  final SliverPersistentHeaderDelegate delegate;
  final bool pinned;
  final bool floating;
  final bool snap;

}

/// Allows injecting an already configured sliver into the catalog pipeline.
class CatalogSliverSection extends CatalogSection {
  const CatalogSliverSection({
    super.key,
    super.padding,
    required this.sliver,
  });

  final Widget sliver;
}