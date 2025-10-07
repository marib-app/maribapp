import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/user_model.dart';
import 'package:marib/data/repositories/seller/seller_repository.dart';

abstract class FetchSellersState {}

class FetchSellersInitial extends FetchSellersState {}

class FetchSellersProgress extends FetchSellersState {}

class FetchSellersSuccess extends FetchSellersState {
  final List<UserModel> sellers;
  final bool hasMore;
  final bool isLoadingMore;

  FetchSellersSuccess(
      {required this.sellers,
      required this.hasMore,
      required this.isLoadingMore});

  FetchSellersSuccess copyWith({
    List<UserModel>? sellers,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return FetchSellersSuccess(
      sellers: sellers ?? this.sellers,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class FetchSellersFailure extends FetchSellersState {
  final String errorMessage;

  FetchSellersFailure(this.errorMessage);
}

class FetchSellersCubit extends Cubit<FetchSellersState> {
  final SellerRepository _sellerRepository;

  FetchSellersCubit(this._sellerRepository) : super(FetchSellersInitial());

  Future<void> fetchSellers({required int accountType}) async {
    try {
      emit(FetchSellersProgress());
      final sellers =
          await _sellerRepository.fetchSellers(accountType: accountType);
      emit(FetchSellersSuccess(
          sellers: sellers, hasMore: sellers.isNotEmpty, isLoadingMore: false));
    } catch (e) {
      emit(FetchSellersFailure(e.toString()));
    }
  }

  Future<void> fetchSellersMore({required int accountType}) async {
    if (state is FetchSellersSuccess) {
      final currentState = state as FetchSellersSuccess;
      if (currentState.isLoadingMore) return;

      emit(currentState.copyWith(isLoadingMore: true));

      try {
        final currentPage = (currentState.sellers.length / 10).ceil() +
            1; // Assuming 10 items per page
        final newSellers = await _sellerRepository.fetchSellers(
            accountType: accountType, page: currentPage);
        final allSellers = List<UserModel>.from(currentState.sellers)
          ..addAll(newSellers);
        emit(currentState.copyWith(
            sellers: allSellers,
            hasMore: newSellers.isNotEmpty,
            isLoadingMore: false));
      } catch (e) {
        emit(currentState.copyWith(
            isLoadingMore: false)); // Revert loading state on error
        // Optionally, emit a failure state or show a snackbar
      }
    }
  }

  bool hasMoreData() {
    if (state is FetchSellersSuccess) {
      return (state as FetchSellersSuccess).hasMore;
    }
    return false;
  }
}
