import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/model/wallet/wallet_filter.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/data/repositories/wallet_repository.dart';

abstract class WalletSummaryState {}

class WalletSummaryInitial extends WalletSummaryState {}

class WalletSummaryLoading extends WalletSummaryState {
  WalletSummaryLoading({this.previous});

  final WalletSummaryLoadSuccess? previous;
}

class WalletSummaryLoadSuccess extends WalletSummaryState {
  WalletSummaryLoadSuccess({
    required this.summary,
    this.appliedFilter,
  });

  final WalletSummary summary;
  final String? appliedFilter;

  List<WalletFilter> get availableFilters => summary.availableFilters;

  WalletSummaryLoadSuccess copyWith({
    WalletSummary? summary,
    String? appliedFilter,
  }) {
    return WalletSummaryLoadSuccess(
      summary: summary ?? this.summary,
      appliedFilter: appliedFilter ?? this.appliedFilter,
    );
  }
}

class WalletSummaryFailure extends WalletSummaryState {
  WalletSummaryFailure(this.error);

  final dynamic error;
}

class WalletSummaryCubit extends Cubit<WalletSummaryState> {
  WalletSummaryCubit({WalletRepository? repository})
      : _repository = repository ?? WalletRepository(),
        super(WalletSummaryInitial());

  final WalletRepository _repository;
  String? _cachedFilter;

  Future<void> fetchSummary({String? filter, bool forceReload = false}) async {
    final trimmed = filter?.trim();
    final normalizedFilter = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _cachedFilter = normalizedFilter ?? _cachedFilter;

    if (!forceReload && state is WalletSummaryLoadSuccess) {
      final current = state as WalletSummaryLoadSuccess;
      if ((normalizedFilter ?? '') == (current.appliedFilter ?? '')) {
        return;
      }
    }

    emit(WalletSummaryLoading(previous: state is WalletSummaryLoadSuccess ? state as WalletSummaryLoadSuccess : null));
    try {
      final summary = await _repository.fetchSummary(filter: _cachedFilter);
      emit(
        WalletSummaryLoadSuccess(
          summary: summary,
          appliedFilter: _cachedFilter,
        ),
      );
    } catch (e) {
      emit(WalletSummaryFailure(e));
    }
  }

  Future<void> refresh() async {
    await fetchSummary(filter: _cachedFilter, forceReload: true);
  }

  void clearFilters() {
    _cachedFilter = null;
    if (state is WalletSummaryLoadSuccess) {
      final current = state as WalletSummaryLoadSuccess;
      emit(current.copyWith(appliedFilter: null));
    }
  }
}