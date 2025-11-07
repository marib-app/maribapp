import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/merchant/merchant_dashboard_summary.dart';
import 'package:marib/data/repositories/merchant_repository.dart';

abstract class MerchantDashboardState {
  const MerchantDashboardState();
}

class MerchantDashboardInitial extends MerchantDashboardState {
  const MerchantDashboardInitial();
}

class MerchantDashboardLoading extends MerchantDashboardState {
  const MerchantDashboardLoading();
}

class MerchantDashboardSuccess extends MerchantDashboardState {
  const MerchantDashboardSuccess(this.summary);

  final MerchantDashboardSummary summary;
}

class MerchantDashboardFailure extends MerchantDashboardState {
  const MerchantDashboardFailure(this.error);

  final dynamic error;
}

class MerchantDashboardCubit extends Cubit<MerchantDashboardState> {
  MerchantDashboardCubit({MerchantRepository? repository})
      : _repository = repository ?? const MerchantRepository(),
        super(const MerchantDashboardInitial());

  final MerchantRepository _repository;

  Future<void> load() async {
    emit(const MerchantDashboardLoading());
    try {
      final summary = await _repository.fetchDashboardSummary();
      emit(MerchantDashboardSuccess(summary));
    } catch (error) {
      emit(MerchantDashboardFailure(error));
    }
  }

  Future<void> refresh() async {
    try {
      final summary = await _repository.fetchDashboardSummary();
      emit(MerchantDashboardSuccess(summary));
    } catch (error) {
      emit(MerchantDashboardFailure(error));
    }
  }
}
