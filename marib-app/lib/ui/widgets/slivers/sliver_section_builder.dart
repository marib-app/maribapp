import 'package:flutter/widgets.dart';

import 'catalog_section.dart';

/// Converts a [CatalogSection] definition into its respective sliver widget.
class SliverSectionBuilder extends StatelessWidget {
  const SliverSectionBuilder({
    super.key,
    required this.section,
  });

  final CatalogSection section;

  @override
  Widget build(BuildContext context) {
    final Widget baseSliver = switch (section) {
      CatalogListSection listSection => _buildList(listSection),
      CatalogGridSection gridSection => _buildGrid(gridSection),
      CatalogBoxSection boxSection => _buildBox(boxSection),
      CatalogPersistentHeaderSection headerSection =>
          _buildPersistentHeader(headerSection),
      CatalogSliverSection sliverSection => sliverSection.sliver,
    };

    Widget sliver = baseSliver;
    if (section.padding != null) {
      sliver = SliverPadding(
        padding: section.padding!,
        sliver: sliver,
      );
    }

    if (section.key != null) {
      sliver = KeyedSubtree(key: section.key!, child: sliver);
    }

    return sliver;
  }

  Widget _buildList(CatalogListSection section) {
    if (section.itemCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final delegate = SliverChildBuilderDelegate(
      section.itemBuilder,
      childCount: section.itemCount,
      addAutomaticKeepAlives: section.addAutomaticKeepAlives,
      addRepaintBoundaries: section.addRepaintBoundaries,
      addSemanticIndexes: section.addSemanticIndexes,
      semanticIndexCallback:
      section.semanticIndexCallback ?? _defaultSemanticIndexCallback,
      semanticIndexOffset: section.semanticIndexOffset,
      findChildIndexCallback: section.findChildIndexCallback,
    );

    if (section.itemExtent != null) {
      return SliverFixedExtentList(
        itemExtent: section.itemExtent!,
        delegate: delegate,
      );
    }

    if (section.prototypeItem != null) {
      return SliverPrototypeExtentList(
        prototypeItem: section.prototypeItem!,
        delegate: delegate,
      );
    }

    return SliverList(
      delegate: delegate,
    );
  }

  Widget _buildGrid(CatalogGridSection section) {
    if (section.itemCount == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        section.itemBuilder,
        childCount: section.itemCount,
        addAutomaticKeepAlives: section.addAutomaticKeepAlives,
        addRepaintBoundaries: section.addRepaintBoundaries,
        addSemanticIndexes: section.addSemanticIndexes,
        semanticIndexCallback:
        section.semanticIndexCallback ?? _defaultSemanticIndexCallback,
        semanticIndexOffset: section.semanticIndexOffset,
        findChildIndexCallback: section.findChildIndexCallback,
      ),
      gridDelegate: section.gridDelegate,
    );
  }

  Widget _buildBox(CatalogBoxSection section) {
    return SliverToBoxAdapter(
      child: section.child,
    );
  }

  Widget _buildPersistentHeader(CatalogPersistentHeaderSection section) {
    return SliverPersistentHeader(
      delegate: section.delegate,
      pinned: section.pinned,
      floating: section.floating || section.snap,

    );
  }
}

int? _defaultSemanticIndexCallback(Widget _, int __) => null;