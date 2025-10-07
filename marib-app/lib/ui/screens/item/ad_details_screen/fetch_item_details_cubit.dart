import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/data/repositories/item/item_repository.dart';

abstract class ItemDetailsRepository {
  Future<ItemModel> fetchById(int id);
}

class RealItemDetailsRepository implements ItemDetailsRepository {
  RealItemDetailsRepository({ItemRepository? itemRepository})
      : _itemRepository = itemRepository ?? ItemRepository();

  final ItemRepository _itemRepository;

  @override
  Future<ItemModel> fetchById(int id) async {
    final result = await _itemRepository.fetchItemFromItemId(id);
    if (result.modelList.isEmpty) {
      throw StateError('Item with id $id not found');
    }
    return result.modelList.first;
  }
}

abstract class FetchItemDetailsState extends Equatable {
  const FetchItemDetailsState();

  @override
  List<Object?> get props => const [];
}

class FetchItemDetailsInitial extends FetchItemDetailsState {
  const FetchItemDetailsInitial();
}

class FetchItemDetailsInProgress extends FetchItemDetailsState {
  const FetchItemDetailsInProgress();
}

class FetchItemDetailsSuccess extends FetchItemDetailsState {
  const FetchItemDetailsSuccess(this.item);

  final ItemModel item;

  @override
  List<Object?> get props => [item];
}

class FetchItemDetailsFailure extends FetchItemDetailsState {
  const FetchItemDetailsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class FetchItemDetailsCubit extends Cubit<FetchItemDetailsState> {
  FetchItemDetailsCubit(this._repository)
      : super(const FetchItemDetailsInitial());

  final ItemDetailsRepository _repository;
  final Map<int, ItemModel> _cache = <int, ItemModel>{};

  Future<void> fetch(int itemId, {bool forceRefresh = false}) async {
    if (itemId <= 0) {
      emit(const FetchItemDetailsFailure('Invalid item id'));
      return;
    }

    if (!forceRefresh && _cache.containsKey(itemId)) {
      emit(FetchItemDetailsSuccess(_cache[itemId]!));
      return;
    }

    emit(const FetchItemDetailsInProgress());
    try {
      final item = await _repository.fetchById(itemId);
      _cache[itemId] = item;
      emit(FetchItemDetailsSuccess(item));
    } catch (error) {
      emit(FetchItemDetailsFailure(error.toString()));
    }
  }

  void seed(ItemModel item) {
    final int? id = item.id;
    if (id != null) {
      _cache[id] = item;
    }
    emit(FetchItemDetailsSuccess(item));
  }
}
