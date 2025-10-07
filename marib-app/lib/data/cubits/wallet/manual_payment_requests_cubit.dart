import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/repositories/wallet_operations_repository.dart';
import 'package:marib/utils/payment/manual_payment.dart';

abstract class ManualPaymentRequestsState {}

class ManualPaymentRequestsInitial extends ManualPaymentRequestsState {}

class ManualPaymentRequestsLoading extends ManualPaymentRequestsState {}

class ManualPaymentRequestsFailure extends ManualPaymentRequestsState {
  ManualPaymentRequestsFailure(this.error);

  final dynamic error;
}

class ManualPaymentRequestsSuccess extends ManualPaymentRequestsState {
  ManualPaymentRequestsSuccess({
    required this.requests,
    required this.hasMore,
    required this.currentPage,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.lastError,
  });

  final List<ManualPayment> requests;
  final bool hasMore;
  final int currentPage;
  final bool isLoadingMore;
  final bool isRefreshing;
  final dynamic lastError;

  ManualPaymentRequestsSuccess copyWith({
    List<ManualPayment>? requests,
    bool? hasMore,
    int? currentPage,
    bool? isLoadingMore,
    bool? isRefreshing,
    dynamic lastError,
  }) {
    return ManualPaymentRequestsSuccess(
      requests: requests ?? this.requests,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastError: lastError,
    );
  }
}

class ManualPaymentRequestsCubit extends Cubit<ManualPaymentRequestsState> {
  ManualPaymentRequestsCubit({WalletOperationsRepository? repository})
      : _repository = repository ?? WalletOperationsRepository(),
        super(ManualPaymentRequestsInitial());

  final WalletOperationsRepository _repository;
  bool _loadingMore = false;

  Future<void> loadInitial() async {
    emit(ManualPaymentRequestsLoading());
    try {
      final result = await _repository.fetchManualPaymentRequests();
      _emitSuccess(result);
    } catch (e) {
      emit(ManualPaymentRequestsFailure(e));
    }
  }

  Future<void> refresh() async {
    final currentState = state;
    if (currentState is ManualPaymentRequestsSuccess) {
      emit(currentState.copyWith(isRefreshing: true, lastError: null));
    } else {
      emit(ManualPaymentRequestsLoading());
    }

    try {
      final result = await _repository.fetchManualPaymentRequests();
      _emitSuccess(result);
    } catch (e) {
      if (currentState is ManualPaymentRequestsSuccess) {
        emit(currentState.copyWith(isRefreshing: false, lastError: e));
      } else {
        emit(ManualPaymentRequestsFailure(e));
      }
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore) return;
    final currentState = state;
    if (currentState is! ManualPaymentRequestsSuccess) return;
    if (!currentState.hasMore) return;

    _loadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final result =
          await _repository.fetchManualPaymentRequests(page: nextPage);
      final meta = result.extraData?.data is WalletWithdrawalsMeta
          ? result.extraData!.data as WalletWithdrawalsMeta
          : WalletWithdrawalsMeta(currentPage: nextPage);

      emit(
        currentState.copyWith(
          requests: [...currentState.requests, ...result.modelList],
          hasMore: meta.hasMore,
          currentPage: meta.currentPage,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false, lastError: e));
    } finally {
      _loadingMore = false;
    }
  }

  void _emitSuccess(DataOutput<ManualPayment> result) {
    final meta = result.extraData?.data is WalletWithdrawalsMeta
        ? result.extraData!.data as WalletWithdrawalsMeta
        : const WalletWithdrawalsMeta();

    emit(
      ManualPaymentRequestsSuccess(
        requests: result.modelList,
        hasMore: meta.hasMore,
        currentPage: meta.currentPage,
      ),
    );
  }
}
