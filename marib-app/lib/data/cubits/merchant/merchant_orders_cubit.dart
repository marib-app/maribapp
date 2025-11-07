import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/merchant/merchant_order.dart';
import 'package:marib/data/repositories/merchant_repository.dart';

abstract class MerchantOrdersState {
  const MerchantOrdersState();
}

class MerchantOrdersInitial extends MerchantOrdersState {
  const MerchantOrdersInitial();
}

class MerchantOrdersLoading extends MerchantOrdersState {
  const MerchantOrdersLoading();
}

class MerchantOrdersSuccess extends MerchantOrdersState {
  const MerchantOrdersSuccess({
    required this.orders,
    required this.hasMore,
    required this.isLoadingMore,
    required this.statusFilter,
  });

  final List<MerchantOrder> orders;
  final bool hasMore;
  final bool isLoadingMore;
  final String statusFilter;

  MerchantOrdersSuccess copyWith({
    List<MerchantOrder>? orders,
    bool? hasMore,
    bool? isLoadingMore,
    String? statusFilter,
  }) {
    return MerchantOrdersSuccess(
      orders: orders ?? this.orders,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class MerchantOrdersFailure extends MerchantOrdersState {
  const MerchantOrdersFailure(this.error);

  final dynamic error;
}

class MerchantOrdersCubit extends Cubit<MerchantOrdersState> {
  MerchantOrdersCubit({MerchantRepository? repository})
      : _repository = repository ?? const MerchantRepository(),
        super(const MerchantOrdersInitial());

  final MerchantRepository _repository;
  int _nextPage = 1;
  String _statusFilter = '';

  Future<void> load({String status = ''}) async {
    _statusFilter = status;
    emit(const MerchantOrdersLoading());
    try {
      final result = await _repository.fetchOrders(status: _statusFilter);
      _nextPage = result.nextPage;
      emit(MerchantOrdersSuccess(
        orders: result.data,
        hasMore: result.hasMore,
        isLoadingMore: false,
        statusFilter: _statusFilter,
      ));
    } catch (error) {
      emit(MerchantOrdersFailure(error));
    }
  }

  Future<void> refresh() async {
    await load(status: _statusFilter);
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! MerchantOrdersSuccess) return;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.fetchOrders(
        status: currentState.statusFilter,
        page: _nextPage,
      );
      _nextPage = result.nextPage;
      emit(
        currentState.copyWith(
          orders: [...currentState.orders, ...result.data],
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      emit(MerchantOrdersFailure(error));
    }
  }
}
