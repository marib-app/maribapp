import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FetchPopularItemsState {}

class FetchPopularItemsInitial extends FetchPopularItemsState {}

class FetchPopularItemsInProgress extends FetchPopularItemsState {}

class FetchPopularItemsSuccess extends FetchPopularItemsState {
  final int total;
  final int page;
  final bool isLoadingMore;
  final bool hasError;
  final List<ItemModel> items;
  final String? sortBy;

  FetchPopularItemsSuccess(
      {required this.total,
      required this.page,
      required this.isLoadingMore,
      required this.hasError,
      required this.sortBy,
      required this.items});

  FetchPopularItemsSuccess copyWith({
    int? total,
    int? page,
    bool? isLoadingMore,
    bool? hasError,
    List<ItemModel>? items,
    String? sortBy,
    bool? getActiveItems,
  }) {
    return FetchPopularItemsSuccess(
      total: total ?? this.total,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      items: items ?? this.items,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class FetchPopularItemsFailed extends FetchPopularItemsState {
  final dynamic error;

  FetchPopularItemsFailed(this.error);
}

class FetchPopularItemsCubit extends Cubit<FetchPopularItemsState> {
  FetchPopularItemsCubit() : super(FetchPopularItemsInitial());
  final ItemRepository _itemRepository = ItemRepository();

  void fetchPopularItems() async {
    try {
      emit(FetchPopularItemsInProgress());
      DataOutput<ItemModel> result =
          await _itemRepository.fetchPopularItems(page: 1);
      final sorted = _sortByViews(result.modelList);
      emit(FetchPopularItemsSuccess(
          hasError: false,
          isLoadingMore: false,
          page: 1,
          items: sorted,
          total: result.total,
          sortBy: "views"));
    } catch (e) {
      emit(FetchPopularItemsFailed(e.toString()));
    }
  }

  Future<void> fetchMyMoreItems() async {
    try {
      if (state is FetchPopularItemsSuccess) {
        if ((state as FetchPopularItemsSuccess).isLoadingMore) {
          return;
        }
        emit((state as FetchPopularItemsSuccess).copyWith(isLoadingMore: true));

        DataOutput<ItemModel> result =
            await _itemRepository.fetchPopularItems(
          page: (state as FetchPopularItemsSuccess).page + 1,
        );

        FetchPopularItemsSuccess myItemsState =
            (state as FetchPopularItemsSuccess);
        myItemsState.items.addAll(result.modelList);
        final sorted = _sortByViews(myItemsState.items);
        emit(
          FetchPopularItemsSuccess(
            isLoadingMore: false,
            hasError: false,
            items: sorted,
            page: (state as FetchPopularItemsSuccess).page + 1,
            sortBy: "views",
            total: result.total,
          ),
        );
      }
    } catch (e) {
      emit(
        (state as FetchPopularItemsSuccess).copyWith(
          isLoadingMore: false,
          hasError: true,
        ),
      );
    }
  }

  bool hasMoreData() {
    if (state is FetchPopularItemsSuccess) {
      return (state as FetchPopularItemsSuccess).items.length <
          (state as FetchPopularItemsSuccess).total;
    }
    return false;
  }

  List<ItemModel> _sortByViews(List<ItemModel> items) {
    final sorted = [...items];
    sorted.sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
    return sorted;
  }
}
