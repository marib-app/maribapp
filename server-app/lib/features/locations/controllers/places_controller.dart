import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../data/models/public_space.dart';
import '../../../data/repositories/places_repository.dart';

final placesControllerProvider =
    AsyncNotifierProvider<PlacesController, List<PublicSpace>>(
  PlacesController.new,
);

class PlacesController extends AsyncNotifier<List<PublicSpace>> {
  late final PlacesRepository _repository = ref.read(placesRepositoryProvider);

  @override
  Future<List<PublicSpace>> build() async {
    return _loadSpaces();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadSpaces);
  }

  Future<void> toggle(int id, bool enabled) async {
    final previous = state.value;
    if (previous != null) {
      state = AsyncValue.data([
        for (final space in previous)
          space.id == id
              ? space.copyWith(
                  status: enabled ? SpaceStatus.online : SpaceStatus.offline,
                )
              : space,
      ]);
    }

    final result = await _repository.toggleAvailability(id, enabled);
    result.when(
      success: (space) {
        final current = state.value ?? [];
        state = AsyncValue.data([
          for (final existing in current)
            if (existing.id == space.id) space else existing,
        ]);
      },
      failure: (error) {
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
  }

  Future<List<PublicSpace>> _loadSpaces() async {
    final result = await _repository.fetchSpaces();
    return result.when(
      success: (data) => data,
      failure: (error) => throw error,
    );
  }
}
