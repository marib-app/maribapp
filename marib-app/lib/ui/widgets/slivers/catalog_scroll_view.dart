import 'package:flutter/widgets.dart';

import 'catalog_section.dart';
import 'sliver_section_builder.dart';

/// Wrapper around [CustomScrollView] that renders a list of [CatalogSection]
/// instances and wires the [ScrollController] into the
/// [PrimaryScrollController] tree when provided.
class CatalogScrollView extends StatelessWidget {
  const CatalogScrollView({
    super.key,
    required this.sections,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.physics,
    this.primary,
    this.shrinkWrap = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.cacheExtent,
    this.anchor = 0.0,
    this.scrollBehavior,
  });

  final List<CatalogSection> sections;
  final ScrollController? controller;
  final Axis scrollDirection;
  final ScrollPhysics? physics;
  final bool? primary;
  final bool shrinkWrap;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final double? cacheExtent;
  final double anchor;
  final ScrollBehavior? scrollBehavior;

  @override
  Widget build(BuildContext context) {
    final effectiveController = controller ?? PrimaryScrollController.maybeOf(context);

    Widget scrollable = CustomScrollView(
      scrollDirection: scrollDirection,
      controller: controller ?? effectiveController,
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      cacheExtent: cacheExtent,
      anchor: anchor,
      restorationId: restorationId,
      clipBehavior: clipBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      slivers: sections
          .map((section) => SliverSectionBuilder(section: section))
          .toList(growable: false),
    );

    if (controller != null) {
      scrollable = PrimaryScrollController(
        controller: controller!,
        child: scrollable,
      );
    }

    if (scrollBehavior != null) {
      scrollable = ScrollConfiguration(
        behavior: scrollBehavior!,
        child: scrollable,
      );
    }

    return scrollable;
  }
}