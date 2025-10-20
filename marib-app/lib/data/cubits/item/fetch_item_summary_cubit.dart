import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/utils/constant.dart';

abstract class FetchItemSummaryState {}

class FetchItemSummaryInitial extends FetchItemSummaryState {}

class FetchItemSummaryLoading extends FetchItemSummaryState {}

class FetchItemSummarySuccess extends FetchItemSummaryState {
  final List<ItemSummary> items;
  final int page;
  final int total;
  final bool isLoadingMore;
  final bool loadingMoreError;
  final int categoryId;
  final String? search;
  final String? sortBy;
  final ItemFilterModel? filter;
  final int perPage;

  FetchItemSummarySuccess({
    required this.items,
    required this.page,
    required this.total,
    required this.categoryId,
    this.isLoadingMore = false,
    this.loadingMoreError = false,
    this.search,
    this.sortBy,
    this.filter,
    required this.perPage,
  });

  FetchItemSummarySuccess copyWith({
    List<ItemSummary>? items,
    int? page,
    int? total,
    bool? isLoadingMore,
    bool? loadingMoreError,
    int? categoryId,
    String? search,
    String? sortBy,
    ItemFilterModel? filter,
    int? perPage,
  }) {
    return FetchItemSummarySuccess(
      items: items ?? this.items,
      page: page ?? this.page,
      total: total ?? this.total,
      categoryId: categoryId ?? this.categoryId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingMoreError: loadingMoreError ?? this.loadingMoreError,
      search: search ?? this.search,
      sortBy: sortBy ?? this.sortBy,
      filter: filter ?? this.filter,
      perPage: perPage ?? this.perPage,
    );
  }
}

class FetchItemSummaryFailure extends FetchItemSummaryState {
  final String errorMessage;

  FetchItemSummaryFailure(this.errorMessage);
}

class FetchItemSummaryCubit extends Cubit<FetchItemSummaryState> {
  static int get defaultPerPage => Constant.loadLimit;

  FetchItemSummaryCubit({ItemRepository? itemRepository})
      : _itemRepository = itemRepository ?? ItemRepository(),
        super(FetchItemSummaryInitial());

  final ItemRepository _itemRepository;

  Future<void> fetchSummaries({
    required int categoryId,
    String? search,
    String? sortBy,
    ItemFilterModel? filter,
    int? perPage,
  }) async {
    final String? normalizedSearch = _sanitizeQuery(search);
    final String? normalizedSort = _sanitizeQuery(sortBy);
    final ItemFilterModel? clonedFilter = _cloneFilter(filter);
    final int effectivePerPage = perPage ?? Constant.loadLimit;

    if (_shouldResetState(
      categoryId,
      normalizedSearch,
      normalizedSort,
      clonedFilter,
      effectivePerPage,
    )) {
      emit(FetchItemSummaryInitial());
    }

    emit(FetchItemSummaryLoading());

    try {
      final DataOutput<ItemSummary> result =
          await _itemRepository.fetchItemSummariesFromCatId(
        categoryId: categoryId,
        page: 1,
        search: normalizedSearch,
        sortBy: normalizedSort,
        filter: clonedFilter,
        perPage: effectivePerPage,
      );

      emit(
        FetchItemSummarySuccess(
          items: result.modelList,
          page: 1,
          total: result.total,
          categoryId: categoryId,
          search: normalizedSearch,
          sortBy: normalizedSort,
          filter: clonedFilter,
          perPage: effectivePerPage,
        ),
      );
    } catch (e) {
      emit(FetchItemSummaryFailure(e.toString()));
    }
  }

  Future<void> loadMoreSummaries() async {
    final currentState = state;
    if (currentState is! FetchItemSummarySuccess) return;
    if (currentState.isLoadingMore) return;
    if (currentState.items.length >= currentState.total) return;

    emit(currentState.copyWith(isLoadingMore: true, loadingMoreError: false));

    try {
      final DataOutput<ItemSummary> result =
          await _itemRepository.fetchItemSummariesFromCatId(
        categoryId: currentState.categoryId,
        page: currentState.page + 1,
        search: currentState.search,
        sortBy: currentState.sortBy,
        filter: currentState.filter,
        perPage: currentState.perPage,
      );

      final List<ItemSummary> updatedItems =
          List<ItemSummary>.from(currentState.items)..addAll(result.modelList);

      emit(
        currentState.copyWith(
          items: updatedItems,
          page: currentState.page + 1,
          total: result.total,
          isLoadingMore: false,
          loadingMoreError: false,
        ),
      );
    } catch (_) {
      emit(
        currentState.copyWith(
          isLoadingMore: false,
          loadingMoreError: true,
        ),
      );
    }
  }

  Future<void> refreshSummaries() async {
    final currentState = state;
    if (currentState is! FetchItemSummarySuccess) return;

    await fetchSummaries(
      categoryId: currentState.categoryId,
      search: currentState.search,
      sortBy: currentState.sortBy,
      filter: currentState.filter,
      perPage: currentState.perPage,
    );
  }

  bool hasMoreData() {
    final currentState = state;
    if (currentState is! FetchItemSummarySuccess) {
      return false;
    }
    return currentState.items.length < currentState.total;
  }

  void reset() {
    emit(FetchItemSummaryInitial());
  }

  bool _shouldResetState(
    int categoryId,
    String? search,
    String? sortBy,
    ItemFilterModel? filter,
    int perPage,
  ) {
    final currentState = state;
    if (currentState is! FetchItemSummarySuccess) {
      return false;
    }

    final bool categoryChanged = currentState.categoryId != categoryId;
    final bool searchChanged = (currentState.search ?? '') != (search ?? '');
    final bool sortChanged = (currentState.sortBy ?? '') != (sortBy ?? '');
    final bool filterChanged = !_filtersEqual(currentState.filter, filter);
    final bool perPageChanged = currentState.perPage != perPage;

    return categoryChanged ||
        searchChanged ||
        sortChanged ||
        filterChanged ||
        perPageChanged;
  }

  bool _filtersEqual(ItemFilterModel? a, ItemFilterModel? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;

    return a.maxPrice == b.maxPrice &&
        a.minPrice == b.minPrice &&
        a.categoryId == b.categoryId &&
        a.postedSince == b.postedSince &&
        a.city == b.city &&
        a.state == b.state &&
        a.country == b.country &&
        a.area == b.area &&
        a.areaId == b.areaId &&
        a.radius == b.radius &&
        a.latitude == b.latitude &&
        a.longitude == b.longitude &&
        a.currency == b.currency &&
        mapEquals(a.customFields ?? const {}, b.customFields ?? const {});
  }

  ItemFilterModel? _cloneFilter(ItemFilterModel? filter) {
    if (filter == null) {
      return null;
    }

    return ItemFilterModel(
      maxPrice: filter.maxPrice,
      minPrice: filter.minPrice,
      categoryId: filter.categoryId,
      postedSince: filter.postedSince,
      city: filter.city,
      state: filter.state,
      country: filter.country,
      area: filter.area,
      areaId: filter.areaId,
      radius: filter.radius,
      latitude: filter.latitude,
      longitude: filter.longitude,
      currency: filter.currency,
      customFields: filter.customFields == null
          ? null
          : Map<String, dynamic>.from(filter.customFields!),
    );
  }

  String? _sanitizeQuery(String? value) {
    if (value == null) {
      return null;
    }

    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
