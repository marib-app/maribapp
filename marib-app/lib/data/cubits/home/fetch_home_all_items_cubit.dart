import 'package:marib/data/repositories/home/home_repository.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchHomeAllItemsState {}

class FetchHomeAllItemsInitial extends FetchHomeAllItemsState {}

class FetchHomeAllItemsInProgress extends FetchHomeAllItemsState {}

class FetchHomeAllItemsSuccess extends FetchHomeAllItemsState {
  final List<ItemModel> items;
  final bool isLoadingMore;
  final bool loadingMoreError;
  final int page;
  final int total;

  FetchHomeAllItemsSuccess(
      {required this.items,
      required this.isLoadingMore,
      required this.loadingMoreError,
      required this.page,
      required this.total});

  FetchHomeAllItemsSuccess copyWith({
    List<ItemModel>? items,
    bool? isLoadingMore,
    bool? loadingMoreError,
    int? page,
    int? total,
  }) {
    return FetchHomeAllItemsSuccess(
      items: items ?? this.items,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingMoreError: loadingMoreError ?? this.loadingMoreError,
      page: page ?? this.page,
      total: total ?? this.total,
    );
  }
}

class FetchHomeAllItemsFail extends FetchHomeAllItemsState {
  final dynamic error;

  FetchHomeAllItemsFail(this.error);
}

class FetchHomeAllItemsCubit extends Cubit<FetchHomeAllItemsState> {
  FetchHomeAllItemsCubit() : super(FetchHomeAllItemsInitial());

  final HomeRepository _homeRepository = HomeRepository();

  void fetch(
      {String? country,
      String? state,
      String? city,
      int? areaId,
      int? radius,
      double? latitude,
      double? longitude}) async {
    try {
      emit(FetchHomeAllItemsInProgress());
      DataOutput<ItemModel> result =
          await _homeRepository.fetchHomeAllItems(page: 1);

      emit(
        FetchHomeAllItemsSuccess(
          page: 1,
          isLoadingMore: false,
          loadingMoreError: false,
          items: result.modelList,
          total: result.total,
        ),
      );
    } catch (e) {
      emit(FetchHomeAllItemsFail(e.toString()));
    }
  }

  Future<void> fetchMore(
      {String? country,
      String? stateName,
      String? city,
      int? areaId,
      int? radius,
      double? latitude,
      double? longitude}) async {
    try {
      if (state is FetchHomeAllItemsSuccess) {
        if ((state as FetchHomeAllItemsSuccess).isLoadingMore) {
          return;
        }
        emit((state as FetchHomeAllItemsSuccess).copyWith(isLoadingMore: true));
        final FetchHomeAllItemsSuccess currentState =

            (state as FetchHomeAllItemsSuccess);
        final DataOutput<ItemModel> result =
        await _homeRepository.fetchHomeAllItems(
            page: currentState.page + 1);

        final List<ItemModel> combinedItems =
        List<ItemModel>.from(currentState.items)
          ..addAll(result.modelList);


        emit(FetchHomeAllItemsSuccess(
            isLoadingMore: false,
            loadingMoreError: false,
            items: combinedItems,
            page: currentState.page + 1,
            total: result.total));
      }
    } catch (e) {
      emit((state as FetchHomeAllItemsSuccess)
          .copyWith(isLoadingMore: false, loadingMoreError: true));
    }
  }

  bool hasMoreData() {
    if (state is FetchHomeAllItemsSuccess) {
      return (state as FetchHomeAllItemsSuccess).items.length <
          (state as FetchHomeAllItemsSuccess).total;
    }
    return false;
  }
}
