import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/repositories/item/item_repository.dart';

class FetchNearbyItemsState {}

class FetchNearbyItemsInitial extends FetchNearbyItemsState {}

class FetchNearbyItemsInProgress extends FetchNearbyItemsState {}

class FetchNearbyItemsSuccess extends FetchNearbyItemsState {
  final int total;
  final int page;
  final bool isLoadingMore;
  final bool hasError;
  final List<ItemModel> items;
  final double latitude;
  final double longitude;
  final double radiusKm;

  FetchNearbyItemsSuccess({
    required this.total,
    required this.page,
    required this.isLoadingMore,
    required this.hasError,
    required this.items,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
  });

  FetchNearbyItemsSuccess copyWith({
    int? total,
    int? page,
    bool? isLoadingMore,
    bool? hasError,
    List<ItemModel>? items,
  }) {
    return FetchNearbyItemsSuccess(
      total: total ?? this.total,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      items: items ?? this.items,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }
}

class FetchNearbyItemsFailed extends FetchNearbyItemsState {
  final dynamic error;

  FetchNearbyItemsFailed(this.error);
}

class FetchNearbyItemsCubit extends Cubit<FetchNearbyItemsState> {
  FetchNearbyItemsCubit() : super(FetchNearbyItemsInitial());

  final ItemRepository _itemRepository = ItemRepository();

  Future<void> fetchNearbyItems({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    try {
      emit(FetchNearbyItemsInProgress());
      final filter = ItemFilterModel(
        latitude: latitude,
        longitude: longitude,
        sortBy: 'nearest',
        radius: radiusKm.round(),
      );
      final DataOutput<ItemModel> result =
          await _itemRepository.searchItem('', filter, page: 1);
      final sorted = _sortByDistance(
        items: result.modelList,
        latitude: latitude,
        longitude: longitude,
      );

      emit(
        FetchNearbyItemsSuccess(
          total: result.total,
          page: 1,
          isLoadingMore: false,
          hasError: false,
          items: sorted,
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
        ),
      );
    } catch (e) {
      emit(FetchNearbyItemsFailed(e.toString()));
    }
  }

  Future<void> fetchMore() async {
    if (state is! FetchNearbyItemsSuccess) return;
    final current = state as FetchNearbyItemsSuccess;
    if (current.isLoadingMore) return;
    if (current.items.length >= current.total) return;

    try {
      emit(current.copyWith(isLoadingMore: true));
      final filter = ItemFilterModel(
        latitude: current.latitude,
        longitude: current.longitude,
        sortBy: 'nearest',
        radius: current.radiusKm.round(),
      );
      final DataOutput<ItemModel> result = await _itemRepository.searchItem(
        '',
        filter,
        page: current.page + 1,
      );

      final sortedNew = _sortByDistance(
        items: [...current.items, ...result.modelList],
        latitude: current.latitude,
        longitude: current.longitude,
      );

      emit(
        current.copyWith(
          page: current.page + 1,
          isLoadingMore: false,
          items: sortedNew,
          total: result.total,
        ),
      );
    } catch (e) {
      emit(FetchNearbyItemsFailed(e.toString()));
    }
  }

  List<ItemModel> _sortByDistance({
    required List<ItemModel> items,
    required double latitude,
    required double longitude,
  }) {
    double haversine(double lat1, double lon1, double lat2, double lon2) {
      const double r = 6371; // km
      final double dLat = _deg2rad(lat2 - lat1);
      final double dLon = _deg2rad(lon2 - lon1);
      final double a = (sin(dLat / 2) * sin(dLat / 2)) +
          cos(_deg2rad(lat1)) *
              cos(_deg2rad(lat2)) *
              (sin(dLon / 2) * sin(dLon / 2));
      final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return r * c;
    }

    return [...items]..sort((a, b) {
        final da = (a.latitude != null && a.longitude != null)
            ? haversine(latitude, longitude, a.latitude!, a.longitude!)
            : double.infinity;
        final db = (b.latitude != null && b.longitude != null)
            ? haversine(latitude, longitude, b.latitude!, b.longitude!)
            : double.infinity;
        return da.compareTo(db);
      });
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
}
