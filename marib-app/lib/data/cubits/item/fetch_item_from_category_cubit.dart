import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchItemFromCategoryState {}

class FetchItemFromCategoryInitial extends FetchItemFromCategoryState {}

class FetchItemFromCategoryInProgress extends FetchItemFromCategoryState {}

class FetchItemFromCategorySuccess extends FetchItemFromCategoryState {
  final bool isLoadingMore;
  final bool loadingMoreError;
  final List<ItemSummary> itemSummaries;
  final int page;
  final int total;
  final int? categoryId;

  FetchItemFromCategorySuccess(
      {required this.isLoadingMore,
        required this.loadingMoreError,
        required this.itemSummaries,
        required this.page,
        required this.total,
        this.categoryId});

  FetchItemFromCategorySuccess copyWith(
      {bool? isLoadingMore,
        bool? loadingMoreError,
        List<ItemSummary>? itemSummaries,
        int? page,
        int? total,
        int? categoryId}) {
    return FetchItemFromCategorySuccess(
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadingMoreError: loadingMoreError ?? this.loadingMoreError,
        itemSummaries: itemSummaries ?? this.itemSummaries,
        page: page ?? this.page,
        total: total ?? this.total,
        categoryId: categoryId ?? this.categoryId);
  }
  List<ItemModel> get itemSkeletons =>
      itemSummaries.map((summary) => summary.toItemModelSkeleton()).toList();
}

class FetchItemFromCategoryFailure extends FetchItemFromCategoryState {
  final String errorMessage;

  FetchItemFromCategoryFailure(this.errorMessage);
}

class FetchItemFromCategoryCubit extends Cubit<FetchItemFromCategoryState> {
  FetchItemFromCategoryCubit({ItemRepository? itemRepository})
      : _itemRepository = itemRepository ?? ItemRepository(),
        super(FetchItemFromCategoryInitial());

  final ItemRepository _itemRepository;


  Future<void> fetchItemFromCategory({
    required int categoryId,
    required String search,
    String? sortBy,
    ItemFilterModel? filter,
  }) async {
    try {
      emit(FetchItemFromCategoryInProgress());

      DataOutput<ItemSummary> result =
      await _itemRepository.fetchItemFromCatId(
        categoryId: categoryId,
        page: 1,
        search: search,
        sortBy: sortBy,
        filter: filter,

      );
      emit(
        FetchItemFromCategorySuccess(
          isLoadingMore: false,
          loadingMoreError: false,
          itemSummaries: result.modelList,
          page: 1,
          total: result.total,
          categoryId: categoryId,
        ),
      );
    } catch (e) {
      emit(
        FetchItemFromCategoryFailure(
          e.toString(),
        ),
      );
    }
  }

  Future<void> fetchItemFromCategoryMore({
    required int catId,
    required String? search,
    String? sortBy,
    ItemFilterModel? filter,
  }) async {
    try {
      if (state is FetchItemFromCategorySuccess) {
        if ((state as FetchItemFromCategorySuccess).isLoadingMore) {
          return;
        }
        emit((state as FetchItemFromCategorySuccess)
            .copyWith(isLoadingMore: true));

        final FetchItemFromCategorySuccess currentState =
        state as FetchItemFromCategorySuccess;

        DataOutput<ItemSummary> result =
        await _itemRepository.fetchItemFromCatId(

          categoryId: catId,
          page: currentState.page + 1,
          search: search,
          sortBy: sortBy,
          filter: filter,

        );

        final List<ItemSummary> updatedSummaries =
        List<ItemSummary>.from(currentState.itemSummaries)
          ..addAll(result.modelList);

        emit(FetchItemFromCategorySuccess(
          isLoadingMore: false,
          loadingMoreError: false,
          itemSummaries: updatedSummaries,
          page: currentState.page + 1,
          total: result.total,
          categoryId: currentState.categoryId,
        ));
      }
    } catch (e) {
      emit(
        (state as FetchItemFromCategorySuccess).copyWith(
          isLoadingMore: false,
          loadingMoreError: true,
        ),
      );
    }
  }

  bool hasMoreData() {
    if (state is FetchItemFromCategorySuccess) {
      return (state as FetchItemFromCategorySuccess).itemSummaries.length <
          (state as FetchItemFromCategorySuccess).total;
    }
    return false;
  }
}
