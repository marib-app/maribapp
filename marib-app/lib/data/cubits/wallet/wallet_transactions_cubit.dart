import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/wallet/wallet_filter.dart';
import 'package:marib/data/model/wallet/wallet_transaction.dart';
import 'package:marib/data/repositories/wallet_repository.dart';

abstract class WalletTransactionsState {}

class WalletTransactionsInitial extends WalletTransactionsState {}

class WalletTransactionsLoading extends WalletTransactionsState {}

class WalletTransactionsFailure extends WalletTransactionsState {
  WalletTransactionsFailure(this.error);

  final dynamic error;
}

class WalletTransactionsSuccess extends WalletTransactionsState {
  WalletTransactionsSuccess({
    required this.transactions,
    required this.hasMore,
    required this.currentPage,
    required this.availableFilters,
    this.appliedFilter,
    this.isLoadingMore = false,
  });

  final List<WalletTransaction> transactions;
  final bool hasMore;
  final int currentPage;
  final List<WalletFilter> availableFilters;
  final String? appliedFilter;
  final bool isLoadingMore;

  WalletTransactionsSuccess copyWith({
    List<WalletTransaction>? transactions,
    bool? hasMore,
    int? currentPage,
    List<WalletFilter>? availableFilters,
    String? appliedFilter,
    bool? isLoadingMore,
  }) {
    return WalletTransactionsSuccess(
      transactions: transactions ?? this.transactions,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      availableFilters: availableFilters ?? this.availableFilters,
      appliedFilter: appliedFilter ?? this.appliedFilter,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class WalletTransactionsCubit extends Cubit<WalletTransactionsState> {
  WalletTransactionsCubit({WalletRepository? repository})
      : _repository = repository ?? WalletRepository(),
        super(WalletTransactionsInitial());

  final WalletRepository _repository;
  bool _loadingMore = false;
  String? _activeFilter;

  Future<void> loadInitial({String? filter}) async {
    _activeFilter = filter ?? _activeFilter;
    emit(WalletTransactionsLoading());
    try {
      final result = await _repository.fetchTransactions(filter: _activeFilter);
      final meta = result.extraData?.data is WalletTransactionsMeta
          ? result.extraData!.data as WalletTransactionsMeta
          : const WalletTransactionsMeta();

      emit(
        WalletTransactionsSuccess(
          transactions: result.modelList,
          hasMore: meta.hasMore,
          currentPage: meta.currentPage,
          availableFilters: meta.availableFilters,
          appliedFilter: _activeFilter,
        ),
      );
    } catch (e) {
      emit(WalletTransactionsFailure(e));
    }
  }

  Future<void> refresh() async {
    if (state is WalletTransactionsSuccess) {
      final current = state as WalletTransactionsSuccess;
      emit(
        current.copyWith(
          isLoadingMore: false,
          transactions: const [],
          availableFilters: const [],
        ),
      );
    } else {
      emit(WalletTransactionsLoading());
    }
    await loadInitial(filter: _activeFilter);
  }

  Future<void> loadMore() async {
    if (_loadingMore) return;
    final currentState = state;
    if (currentState is! WalletTransactionsSuccess) return;
    if (!currentState.hasMore) return;

    _loadingMore = true;
    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final result = await _repository.fetchTransactions(
        page: nextPage,
        filter: _activeFilter,
      );
      final meta = result.extraData?.data is WalletTransactionsMeta
          ? result.extraData!.data as WalletTransactionsMeta
          : WalletTransactionsMeta(currentPage: nextPage);

      final mergedFilters = <String, WalletFilter>{
        for (final f in currentState.availableFilters) f.value: f,
      };
      for (final f in meta.availableFilters) {
        mergedFilters.putIfAbsent(f.value, () => f);
      }

      emit(
        currentState.copyWith(
          transactions: [...currentState.transactions, ...result.modelList],
          hasMore: meta.hasMore,
          currentPage: meta.currentPage,
          availableFilters: mergedFilters.values.toList(),
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(
        currentState.copyWith(
          isLoadingMore: false,
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }

  void applyFilter(String? filter) {
    if ((filter ?? '') == (_activeFilter ?? '')) {
      return;
    }
    _activeFilter = filter?.isEmpty == true ? null : filter;
    loadInitial(filter: _activeFilter);
  }

  void clearFilters() {
    _activeFilter = null;
    loadInitial(filter: null);
  }

  void markTransactionNotified(String idempotencyKey, {String? deeplink}) {
    final currentState = state;
    if (currentState is! WalletTransactionsSuccess) return;
    final updated = currentState.transactions.map((tx) {
      if (tx.idempotencyKey == idempotencyKey || tx.id == idempotencyKey) {
        return tx.copyWith(highlighted: true, deeplink: deeplink ?? tx.deeplink);
      }
      return tx;
    }).toList();
    emit(currentState.copyWith(transactions: updated));
  }
}