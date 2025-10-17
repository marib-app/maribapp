import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/item/purchase_options.dart';
import 'package:marib/data/repositories/item/item_purchase_options_repository.dart';

abstract class FetchItemPurchaseOptionsState extends Equatable {
  const FetchItemPurchaseOptionsState();

  @override
  List<Object?> get props => const [];
}

class FetchItemPurchaseOptionsInitial extends FetchItemPurchaseOptionsState {
  const FetchItemPurchaseOptionsInitial();
}

class FetchItemPurchaseOptionsInProgress extends FetchItemPurchaseOptionsState {
  const FetchItemPurchaseOptionsInProgress();
}

class FetchItemPurchaseOptionsSuccess extends FetchItemPurchaseOptionsState {
  const FetchItemPurchaseOptionsSuccess(this.options);

  final ItemPurchaseOptions options;

  @override
  List<Object?> get props => <Object?>[options];
}

class FetchItemPurchaseOptionsFailure extends FetchItemPurchaseOptionsState {
  const FetchItemPurchaseOptionsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class FetchItemPurchaseOptionsCubit
    extends Cubit<FetchItemPurchaseOptionsState> {
  FetchItemPurchaseOptionsCubit(this._repository)
      : super(const FetchItemPurchaseOptionsInitial());

  final ItemPurchaseOptionsRepository _repository;
  final Map<int, ItemPurchaseOptions> _cache = <int, ItemPurchaseOptions>{};

  Future<void> fetch({required int itemId, bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(itemId)) {
      emit(FetchItemPurchaseOptionsSuccess(_cache[itemId]!));
      return;
    }

    emit(const FetchItemPurchaseOptionsInProgress());

    try {
      final ItemPurchaseOptions options = await _repository.fetch(itemId);
      _cache[itemId] = options;
      emit(FetchItemPurchaseOptionsSuccess(options));
    } catch (error) {
      emit(FetchItemPurchaseOptionsFailure(error.toString()));
    }
  }

  void clearCacheFor(int itemId) {
    _cache.remove(itemId);
  }
}