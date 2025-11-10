import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/public_space.dart';
import '../controllers/places_controller.dart';
import '../widgets/place_card.dart';

enum SpaceFilter { all, online, offline, maintenance }

class PlacesScreen extends HookConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = useState(SpaceFilter.all);
    final spacesState = ref.watch(placesControllerProvider);

    Future<void> refresh() =>
        ref.read(placesControllerProvider.notifier).refresh();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public areas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SegmentedButton<SpaceFilter>(
              segments: const [
                ButtonSegment(
                  value: SpaceFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.apps),
                ),
                ButtonSegment(
                  value: SpaceFilter.online,
                  label: Text('Online'),
                  icon: Icon(Icons.wifi_tethering),
                ),
                ButtonSegment(
                  value: SpaceFilter.offline,
                  label: Text('Offline'),
                  icon: Icon(Icons.portable_wifi_off),
                ),
                ButtonSegment(
                  value: SpaceFilter.maintenance,
                  label: Text('Maintenance'),
                  icon: Icon(Icons.build_circle_outlined),
                ),
              ],
              selected: {filter.value},
              onSelectionChanged: (value) {
                filter.value = value.first;
              },
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: AsyncValueWidget<List<PublicSpace>>(
                value: spacesState,
                data: (spaces) {
                  final filtered = _applyFilter(spaces, filter.value);
                  if (filtered.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No spaces found for this filter')),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final space = filtered[index];
                      return PlaceCard(
                        space: space,
                        onTap: () => context.go('/dashboard/spaces/${space.id}'),
                        onToggle: (enabled) => ref
                            .read(placesControllerProvider.notifier)
                            .toggle(space.id, enabled),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PublicSpace> _applyFilter(List<PublicSpace> spaces, SpaceFilter filter) {
    switch (filter) {
      case SpaceFilter.all:
        return spaces;
      case SpaceFilter.online:
        return spaces
            .where((space) => space.status == SpaceStatus.online)
            .toList();
      case SpaceFilter.offline:
        return spaces
            .where((space) => space.status == SpaceStatus.offline)
            .toList();
      case SpaceFilter.maintenance:
        return spaces
            .where((space) => space.status == SpaceStatus.maintenance)
            .toList();
    }
  }
}
