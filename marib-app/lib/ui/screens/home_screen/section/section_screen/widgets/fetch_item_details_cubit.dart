import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
// استبدل بهيكل موديلك الحقيقي
import 'package:marib/data/model/item/item_model.dart';



// TODO: اربط ريبوزيتوري مشروعك هنا

abstract class ItemDetailsRepository {
  Future<ItemModel> fetchById(int id);
}

class FetchItemDetailsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchItemDetailsInitial extends FetchItemDetailsState {}

class FetchItemDetailsInProgress extends FetchItemDetailsState {}

class FetchItemDetailsSuccess extends FetchItemDetailsState {
  final ItemModel item;
  FetchItemDetailsSuccess(this.item);
  @override
  List<Object?> get props => [item];
}

class FetchItemDetailsFailure extends FetchItemDetailsState {
  final String message;
  FetchItemDetailsFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class FetchItemDetailsCubit extends Cubit<FetchItemDetailsState> {
  final ItemDetailsRepository repo;

  // كاش بسيط داخل الذاكرة
  final Map<int, ItemModel> _cache = {};

  FetchItemDetailsCubit(this.repo) : super(FetchItemDetailsInitial());

  bool hasInCache(int id) => _cache.containsKey(id);
  ItemModel? fromCache(int id) => _cache[id];

  Future<void> fetch(int id) async {
    // لو موجود في الكاش، أعده فورًا
    if (_cache.containsKey(id)) {
      emit(FetchItemDetailsSuccess(_cache[id]!));
      return;
    }

    emit(FetchItemDetailsInProgress());
    try {
      final item = await repo.fetchById(id); // ← اربطها بنقطتك API
      _cache[id] = item;
      emit(FetchItemDetailsSuccess(item));
    } catch (e) {
      emit(FetchItemDetailsFailure(e.toString()));
    }
  }
}
