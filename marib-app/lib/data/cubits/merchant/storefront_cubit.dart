import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/merchant/storefront_model.dart';
import 'package:marib/data/repositories/merchant/storefront_repository.dart';

abstract class StorefrontState extends Equatable {
  const StorefrontState();

  @override
  List<Object?> get props => const <Object?>[];
}

class StorefrontInitial extends StorefrontState {
  const StorefrontInitial();
}

class StorefrontLoading extends StorefrontState {
  const StorefrontLoading();
}

class StorefrontFailure extends StorefrontState {
  const StorefrontFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class StorefrontSuccess extends StorefrontState {
  const StorefrontSuccess(this.details);

  final StorefrontDetails details;

  @override
  List<Object?> get props => <Object?>[details];
}

class StorefrontCubit extends Cubit<StorefrontState> {
  StorefrontCubit({
    StorefrontRepository? repository,
  })  : _repository = repository ?? const StorefrontRepository(),
        super(const StorefrontInitial());

  final StorefrontRepository _repository;

  Future<void> load(String identifier) async {
    final String normalized = identifier.trim();
    if (normalized.isEmpty) {
      emit(const StorefrontFailure('invalid-store'));
      return;
    }

    emit(const StorefrontLoading());
    try {
      final StorefrontDetails details =
          await _repository.fetchStore(normalized);
      emit(StorefrontSuccess(details));
    } catch (error) {
      emit(StorefrontFailure(error.toString()));
    }
  }
}
