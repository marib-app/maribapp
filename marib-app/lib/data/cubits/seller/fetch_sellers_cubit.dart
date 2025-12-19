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

  FetchSellersSuccess({required this.sellers, required this.hasMore, required this.isLoadingMore});

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
      final result =
          await _sellerRepository.fetchSellers(accountType: accountType);
      final List<UserModel> sellers =
          (result['sellers'] as List<UserModel>? ?? const <UserModel>[]);
      final int currentPage = (result['current_page'] as int?) ?? 1;
      final int lastPage = (result['last_page'] as int?) ?? 1;
      final bool hasMore = currentPage < lastPage;
      emit(FetchSellersSuccess(
        sellers: sellers,
        hasMore: hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(FetchSellersFailure(e.toString()));
    }
  }

  Future<void> fetchSellersMore({required int accountType}) async {
    if (state is FetchSellersSuccess) {
      final currentState = state as FetchSellersSuccess;
      if (currentState.isLoadingMore || !currentState.hasMore) return;

      emit(currentState.copyWith(isLoadingMore: true));

      try {
        final int nextPage =
            (currentState.sellers.length / 200).ceil() + 1; // matches per_page in repository
        final result = await _sellerRepository.fetchSellers(
          accountType: accountType,
          page: nextPage,
        );
        final List<UserModel> newSellers =
            (result['sellers'] as List<UserModel>? ?? const <UserModel>[]);
        final int currentPage = (result['current_page'] as int?) ?? nextPage;
        final int lastPage = (result['last_page'] as int?) ?? currentPage;
        final bool hasMore = currentPage < lastPage;

        final allSellers =
            List<UserModel>.from(currentState.sellers)..addAll(newSellers);
        emit(currentState.copyWith(
          sellers: allSellers,
          hasMore: hasMore,
          isLoadingMore: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(isLoadingMore: false)); // Revert loading state on error
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
