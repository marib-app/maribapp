import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/wallet/wallet_operation_options.dart';
import 'package:marib/data/model/wallet/wallet_withdrawal.dart';
import 'package:marib/data/repositories/wallet_operations_repository.dart';

abstract class WalletWithdrawalsState {}

class WalletWithdrawalsInitial extends WalletWithdrawalsState {}

class WalletWithdrawalsLoading extends WalletWithdrawalsState {}

class WalletWithdrawalsFailure extends WalletWithdrawalsState {
  WalletWithdrawalsFailure(this.error);

  final dynamic error;
}

class WalletWithdrawalsSuccess extends WalletWithdrawalsState {
  WalletWithdrawalsSuccess({
    required this.withdrawals,
    required this.hasMore,
    required this.currentPage,
    this.options,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.isRefreshing = false,
    this.lastError,
  });

  final List<WalletWithdrawal> withdrawals;
  final bool hasMore;
  final int currentPage;
  final WalletOperationOptions? options;
  final bool isLoadingMore;
  final bool isSubmitting;
  final bool isRefreshing;
  final dynamic lastError;

  WalletWithdrawalsSuccess copyWith({
    List<WalletWithdrawal>? withdrawals,
    bool? hasMore,
    int? currentPage,
    WalletOperationOptions? options,
    bool? isLoadingMore,
    bool? isSubmitting,
    bool? isRefreshing,
    dynamic lastError,
  }) {
    return WalletWithdrawalsSuccess(
      withdrawals: withdrawals ?? this.withdrawals,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      options: options ?? this.options,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastError: lastError,
    );
  }
}

class WalletWithdrawalsCubit extends Cubit<WalletWithdrawalsState> {
  WalletWithdrawalsCubit({WalletOperationsRepository? repository})
      : _repository = repository ?? WalletOperationsRepository(),
        super(WalletWithdrawalsInitial());

  final WalletOperationsRepository _repository;
  bool _loadingMore = false;
  String? _clientTag;

  Future<void> loadInitial({bool includeOptions = true}) async {
    emit(WalletWithdrawalsLoading());
    try {
      final result =
          await _repository.fetchWithdrawals(includeOptions: includeOptions);
      _emitSuccess(result);
    } catch (e) {
      emit(WalletWithdrawalsFailure(e));
    }
  }

  Future<void> refresh({bool includeOptions = false}) async {
    final currentState = state;
    if (currentState is WalletWithdrawalsSuccess) {
      emit(currentState.copyWith(isRefreshing: true, lastError: null));
    } else {
      emit(WalletWithdrawalsLoading());
    }

    try {
      final result = await _repository.fetchWithdrawals(
        includeOptions:
            includeOptions || currentState is! WalletWithdrawalsSuccess,
      );
      _emitSuccess(result);
    } catch (e) {
      if (currentState is WalletWithdrawalsSuccess) {
        emit(currentState.copyWith(isRefreshing: false, lastError: e));
      } else {
        emit(WalletWithdrawalsFailure(e));
      }
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore) return;
    final currentState = state;
    if (currentState is! WalletWithdrawalsSuccess) return;
    if (!currentState.hasMore) return;

    _loadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final result = await _repository.fetchWithdrawals(
        page: nextPage,
        includeOptions: false,
      );
      final meta = result.data.extraData?.data is WalletWithdrawalsMeta
          ? result.data.extraData!.data as WalletWithdrawalsMeta
          : WalletWithdrawalsMeta(currentPage: nextPage);

      emit(
        currentState.copyWith(
          withdrawals: [...currentState.withdrawals, ...result.data.modelList],
          hasMore: meta.hasMore,
          currentPage: meta.currentPage,
          isLoadingMore: false,
          options: result.options ?? currentState.options,
        ),
      );
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false, lastError: e));
    } finally {
      _loadingMore = false;
    }
  }

  Future<WalletWithdrawal?> submitWithdrawal(
      Map<String, dynamic> payload) async {
    final currentState = state;
    if (currentState is WalletWithdrawalsSuccess) {
      emit(currentState.copyWith(isSubmitting: true, lastError: null));
    } else {
      emit(WalletWithdrawalsLoading());
    }

    try {
      final result = await _repository.submitWithdrawal(payload: payload);
      if (currentState is WalletWithdrawalsSuccess) {
        emit(
          currentState.copyWith(
            withdrawals: [result, ...currentState.withdrawals],
            isSubmitting: false,
            lastError: null,
          ),
        );
      } else {
        await loadInitial();
      }
      return result;
    } catch (e) {
      if (currentState is WalletWithdrawalsSuccess) {
        emit(currentState.copyWith(isSubmitting: false, lastError: e));
      } else {
        emit(WalletWithdrawalsFailure(e));
      }
      rethrow;
    }
  }

  Future<WalletOperationOptions?> loadOptions(
      {String? clientTag, bool force = false}) async {
    final currentState = state;
    final normalizedTag =
        clientTag?.trim().isEmpty == true ? null : clientTag?.trim();
    if (!force &&
        currentState is WalletWithdrawalsSuccess &&
        currentState.options != null &&
        (normalizedTag ?? _clientTag) == _clientTag) {
      return currentState.options;
    }

    final options = await _repository.fetchWithdrawalOptions(
        clientTag: normalizedTag ?? _clientTag);
    _clientTag = options?.clientTag ?? normalizedTag ?? _clientTag;

    if (currentState is WalletWithdrawalsSuccess) {
      emit(currentState.copyWith(options: options));
    }

    return options;
  }

  void _emitSuccess(WalletWithdrawalsResult result) {
    final meta = result.data.extraData?.data is WalletWithdrawalsMeta
        ? result.data.extraData!.data as WalletWithdrawalsMeta
        : const WalletWithdrawalsMeta();
    final options = result.options;
    _clientTag = options?.clientTag ?? _clientTag;

    emit(
      WalletWithdrawalsSuccess(
        withdrawals: result.data.modelList,
        hasMore: meta.hasMore,
        currentPage: meta.currentPage,
        options: options,
      ),
    );
  }
}
