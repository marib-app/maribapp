import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/merchant/merchant_store_snapshot.dart';
import 'package:marib/data/repositories/merchant_repository.dart';
import 'package:marib/utils/hive_utils.dart';

class MerchantStoreState {
  const MerchantStoreState({
    this.snapshot,
    this.loading = false,
    this.error,
  });

  factory MerchantStoreState.initial() {
    final Map<String, dynamic>? cached = HiveUtils.getMerchantStoreRaw();
    return MerchantStoreState(
      snapshot:
          cached == null ? null : MerchantStoreSnapshot.fromMap(cached),
    );
  }

  final MerchantStoreSnapshot? snapshot;
  final bool loading;
  final dynamic error;

  bool get hasStore => snapshot != null;
  bool get isApproved => snapshot?.isApproved ?? false;
  bool get requiresReview => snapshot?.isPendingReview ?? false;

  MerchantStoreState copyWith({
    MerchantStoreSnapshot? snapshot,
    bool? loading,
    dynamic error,
    bool clearError = false,
  }) {
    return MerchantStoreState(
      snapshot: snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MerchantStoreCubit extends Cubit<MerchantStoreState> {
  MerchantStoreCubit({MerchantRepository? repository})
      : _repository = repository ?? const MerchantRepository(),
        super(MerchantStoreState.initial());

  final MerchantRepository _repository;
  bool _syncInFlight = false;

  Future<void> load({bool forceRefresh = false}) async {
    if (_syncInFlight) {
      return;
    }
    if (!forceRefresh && state.loading) {
      return;
    }
    _syncInFlight = true;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final MerchantStoreSnapshot? snapshot =
          await _repository.fetchStoreProfile();
      await HiveUtils.setMerchantStoreRaw(snapshot?.toMap());
      emit(
        state.copyWith(
          snapshot: snapshot,
          loading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, error: error));
    } finally {
      _syncInFlight = false;
    }
  }
}
