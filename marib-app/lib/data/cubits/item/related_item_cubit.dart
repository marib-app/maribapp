import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchRelatedItemsState {}

class FetchRelatedItemsInitial extends FetchRelatedItemsState {}

class FetchRelatedItemsInProgress extends FetchRelatedItemsState {}

class FetchRelatedItemsSuccess extends FetchRelatedItemsState {
  final bool isLoadingMore;
  final bool loadingMoreError;
  final List<ItemSummary> itemSummaries;
  final int page;
  final int total;
  final int? categoryId;

  FetchRelatedItemsSuccess(
      {required this.isLoadingMore,
      required this.loadingMoreError,
        required this.itemSummaries,
      required this.page,
      required this.total,
      this.categoryId});

  FetchRelatedItemsSuccess copyWith(
      {bool? isLoadingMore,
      bool? loadingMoreError,
        List<ItemSummary>? itemSummaries,

      int? page,
      int? total,
      int? categoryId}) {
    return FetchRelatedItemsSuccess(
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

class FetchRelatedItemsFailure extends FetchRelatedItemsState {
  final String errorMessage;

  FetchRelatedItemsFailure(this.errorMessage);
}

class FetchRelatedItemsCubit extends Cubit<FetchRelatedItemsState> {
  FetchRelatedItemsCubit({ItemRepository? itemRepository})
      : _itemRepository = itemRepository ?? ItemRepository(),
        super(FetchRelatedItemsInitial());

  final ItemRepository _itemRepository;


  Future<void> fetchRelatedItems(
      {required int categoryId,
      String? country,
      String? state,
      String? city,
      int? areaId}) async {
    try {
      emit(FetchRelatedItemsInProgress());

      DataOutput<ItemSummary> result =
      await _itemRepository.fetchItemSummariesFromCatId(
          categoryId: categoryId, page: 1);

      emit(
        FetchRelatedItemsSuccess(
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
        FetchRelatedItemsFailure(
          e.toString(),
        ),
      );
    }
  }

  Future<void> fetchRelatedItemsMore(
      {required int categoryId,
      String? country,
      String? state,
      String? city,
      int? areaId}) async {
    try {
      if (state is FetchRelatedItemsSuccess) {
        if ((state as FetchRelatedItemsSuccess).isLoadingMore) {
          return;
        }
        emit((state as FetchRelatedItemsSuccess).copyWith(isLoadingMore: true));

        final FetchRelatedItemsSuccess currentState =
        state as FetchRelatedItemsSuccess;

        DataOutput<ItemSummary> result =
        await _itemRepository.fetchItemSummariesFromCatId(
        categoryId: categoryId,
          page: currentState.page + 1,
        );

        final List<ItemSummary> updatedSummaries =
        List<ItemSummary>.from(currentState.itemSummaries)
          ..addAll(result.modelList);

        emit(FetchRelatedItemsSuccess(
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
        (state as FetchRelatedItemsSuccess).copyWith(
          isLoadingMore: false,
          loadingMoreError: true,
        ),
      );
    }
  }

  bool hasMoreData() {
    if (state is FetchRelatedItemsSuccess) {
      return (state as FetchRelatedItemsSuccess).itemSummaries.length <
          (state as FetchRelatedItemsSuccess).total;
    }
    return false;
  }
}
