import 'dart:math';

import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/favourites_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FavoriteState {}

class FavoriteInitial extends FavoriteState {}

class FavoriteFetchInProgress extends FavoriteState {}

class FavoriteFetchSuccess extends FavoriteState {
  final List<ItemModel> favorite;
  final bool isLoadingMore;
  final int totalFavoriteCount;
  final bool hasMoreFetchError;
  final bool hasMore;
  final int page;

  FavoriteFetchSuccess(
      {required this.favorite,
      required this.isLoadingMore,
      required this.totalFavoriteCount,
      required this.hasMoreFetchError,
      required this.page,
      required this.hasMore});

  FavoriteFetchSuccess copyWith({
    List<ItemModel>? favorite,
    bool? isLoadingMore,
    int? totalFavoriteCount,
    bool? hasMoreFetchError,
    bool? hasMore,
    int? page,
  }) {
    return FavoriteFetchSuccess(
      favorite: favorite ?? this.favorite,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      hasMoreFetchError: hasMoreFetchError ?? this.hasMoreFetchError,
      totalFavoriteCount: totalFavoriteCount ?? this.totalFavoriteCount,
    );
  }
}

class FavoriteFetchFailure extends FavoriteState {
  final String errorMessage;

  FavoriteFetchFailure(this.errorMessage);
}

class FavoriteCubit extends Cubit<FavoriteState> {
  final FavoriteRepository favoriteRepository;

  FavoriteCubit(this.favoriteRepository) : super(FavoriteInitial());

  void getFavorite() async {
    try {
      print("🔄 بدء جلب بيانات المفضلة...");
      emit(FavoriteFetchInProgress());
      final result = await favoriteRepository.fetchFavorites(page: 1);

      print("✅ تم جلب البيانات بنجاح:");
      print("📊 عدد العناصر: ${result.modelList.length}");
      print("📈 المجموع الكلي: ${result.total}");

      if (result.modelList.isNotEmpty) {
        print("📝 العناصر:");
        for (int i = 0; i < result.modelList.length; i++) {
          print(
              "   ${i + 1}. ${result.modelList[i].name} (ID: ${result.modelList[i].id})");
        }
      }

      emit(FavoriteFetchSuccess(
          favorite: result.modelList,
          totalFavoriteCount: result.total,
          hasMoreFetchError: false,
          page: 1,
          isLoadingMore: false,
          hasMore: (result.modelList.length < result.total)));
    } catch (e) {
      print("❌ خطأ في جلب المفضلة: $e");
      if (e.toString() == "No Data Found") {
        print("ℹ️ لا توجد بيانات - عرض قائمة فارغة");
        //incase of 0 Favorite length - make it success for fresh users
        emit(FavoriteFetchSuccess(
            favorite: [],
            isLoadingMore: false,
            totalFavoriteCount: 0,
            page: 1,
            hasMoreFetchError: false,
            hasMore: false));
      } else {
        emit(FavoriteFetchFailure(e.toString()));
      }
    }
  }

  bool hasMoreFavorite() {
    return (state is FavoriteFetchSuccess)
        ? (state as FavoriteFetchSuccess).hasMore
        : false;
  }

  void getMoreFavorite() async {
    if (state is FavoriteFetchSuccess) {
      try {
        if ((state as FavoriteFetchSuccess).isLoadingMore) {
          return;
        }
        emit((state as FavoriteFetchSuccess).copyWith(isLoadingMore: true));
        final result = await favoriteRepository.fetchFavorites(
            page: (state as FavoriteFetchSuccess).page + 1);
        List<ItemModel> updatedResults =
            (state as FavoriteFetchSuccess).favorite;
        updatedResults.addAll(result.modelList);
        emit(FavoriteFetchSuccess(
            isLoadingMore: false,
            favorite: updatedResults,
            totalFavoriteCount: result.total,
            hasMoreFetchError: false,
            page: (state as FavoriteFetchSuccess).page + 1,
            hasMore: updatedResults.length < result.total));
      } catch (e) {
        emit(FavoriteFetchSuccess(
            isLoadingMore: false,
            favorite: (state as FavoriteFetchSuccess).favorite,
            hasMoreFetchError: (e.toString() == "No Data Found") ? false : true,
            page: (state as FavoriteFetchSuccess).page + 1,
            totalFavoriteCount:
                (state as FavoriteFetchSuccess).totalFavoriteCount,
            hasMore: (state as FavoriteFetchSuccess).hasMore));
      }
    }
  }

  Future<void> addFavoriteitem(ItemModel model) async {
    await _updateFavorite(model, shouldBeFavorite: true);
  }

  Future<void> removeFavoriteItem(ItemModel model) async {
    await _updateFavorite(model, shouldBeFavorite: false);
  }

  Future<void> _updateFavorite(
      ItemModel model, {
      required bool shouldBeFavorite,
    }) async {
    if (model.id == null) {
      return;
    }

    if (shouldBeFavorite == isItemFavorite(model.id!)) {
      return;
    }

    try {
      await favoriteRepository.manageFavorites(model.id!);
      if (state is FavoriteFetchSuccess) {
        if (shouldBeFavorite) {
          _addFavoriteToState(model);
        } else {
          _removeFavoriteFromState(model);
        }
      }
    } catch (error) {
      print('❌ خطأ في تحديث المفضلة: $error');
    }
  }

  void _addFavoriteToState(ItemModel model) {
    final currentState = state;
    if (currentState is FavoriteFetchSuccess) {
      final updatedFavorites = <ItemModel>[
        model,
        ...currentState.favorite,
      ];
      emit(currentState.copyWith(favorite: List.unmodifiable(updatedFavorites)));
    }
  }

  void _removeFavoriteFromState(ItemModel model) {
    final currentState = state;
    if (currentState is FavoriteFetchSuccess) {
      final updatedFavorites = List<ItemModel>.from(currentState.favorite);
      final indexToRemove =
          updatedFavorites.indexWhere((entry) => entry.id == model.id);
      if (indexToRemove >= 0) {
        final ItemModel removedItem = updatedFavorites[indexToRemove];
        removedItem.totalLikes = max(0, (removedItem.totalLikes ?? 1) - 1);
        updatedFavorites.removeAt(indexToRemove);
        emit(currentState.copyWith(favorite: List.unmodifiable(updatedFavorites)));
      }
    }
  }

  bool isItemFavorite(int itemId) {
    if (state is FavoriteFetchSuccess) {
      final favorite = (state as FavoriteFetchSuccess).favorite;
      return (favorite.isNotEmpty)
          ? (favorite.indexWhere((element) => (element.id == itemId)) != -1)
          : false;
    }
    return false;
  }

  void resetState() {
    emit(FavoriteFetchInProgress());
  }
}
