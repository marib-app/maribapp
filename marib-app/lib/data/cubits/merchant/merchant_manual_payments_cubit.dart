import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/merchant/merchant_manual_payment.dart';
import 'package:marib/data/repositories/merchant_repository.dart';

abstract class MerchantManualPaymentsState {
  const MerchantManualPaymentsState();
}

class MerchantManualPaymentsInitial extends MerchantManualPaymentsState {
  const MerchantManualPaymentsInitial();
}

class MerchantManualPaymentsLoading extends MerchantManualPaymentsState {
  const MerchantManualPaymentsLoading();
}

class MerchantManualPaymentsSuccess extends MerchantManualPaymentsState {
  const MerchantManualPaymentsSuccess({
    required this.requests,
    required this.hasMore,
    required this.isLoadingMore,
    required this.statusFilter,
  });

  final List<MerchantManualPayment> requests;
  final bool hasMore;
  final bool isLoadingMore;
  final String statusFilter;

  MerchantManualPaymentsSuccess copyWith({
    List<MerchantManualPayment>? requests,
    bool? hasMore,
    bool? isLoadingMore,
    String? statusFilter,
  }) {
    return MerchantManualPaymentsSuccess(
      requests: requests ?? this.requests,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class MerchantManualPaymentsFailure extends MerchantManualPaymentsState {
  const MerchantManualPaymentsFailure(this.error);

  final dynamic error;
}

class MerchantManualPaymentsCubit extends Cubit<MerchantManualPaymentsState> {
  MerchantManualPaymentsCubit({MerchantRepository? repository})
      : _repository = repository ?? const MerchantRepository(),
        super(const MerchantManualPaymentsInitial());

  final MerchantRepository _repository;
  int _nextPage = 1;
  String _statusFilter = '';

  Future<void> load({String status = ''}) async {
    _statusFilter = status;
    emit(const MerchantManualPaymentsLoading());
    try {
      final result =
          await _repository.fetchManualPayments(status: _statusFilter);
      _nextPage = result.nextPage;
      emit(MerchantManualPaymentsSuccess(
        requests: result.data,
        hasMore: result.hasMore,
        isLoadingMore: false,
        statusFilter: _statusFilter,
      ));
    } catch (error) {
      emit(MerchantManualPaymentsFailure(error));
    }
  }

  Future<void> refresh() async {
    await load(status: _statusFilter);
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! MerchantManualPaymentsSuccess) return;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.fetchManualPayments(
        status: currentState.statusFilter,
        page: _nextPage,
      );
      _nextPage = result.nextPage;
      emit(
        currentState.copyWith(
          requests: [...currentState.requests, ...result.data],
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      emit(MerchantManualPaymentsFailure(error));
    }
  }

  Future<void> decide({
    required int manualPaymentId,
    required String decision,
    String? note,
    bool notifyCustomer = true,
  }) async {
    await _repository.decideManualPayment(
      manualPaymentId: manualPaymentId,
      decision: decision,
      note: note,
      notifyCustomer: notifyCustomer,
    );
    await refresh();
  }
}
