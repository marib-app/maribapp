import 'package:marib/data/model/classified_model.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/repositories/classified_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class FetchclassifiedState {}

class FetchClassifiedInitial extends FetchclassifiedState {}

class FetchClassifiedInProgress extends FetchclassifiedState {}

class FetchClassifiedSuccess extends FetchclassifiedState {
  final bool isLoadingMore;
  final bool loadingMoreError;
  final List<ClassifiedModel> classifiedModel;
  final int page;
  final int total;

  FetchClassifiedSuccess({
    required this.isLoadingMore,
    required this.loadingMoreError,
    required this.classifiedModel,
    required this.page,
    required this.total,
  });

  FetchClassifiedSuccess copyWith({
    bool? isLoadingMore,
    bool? loadingMoreError,
    List<ClassifiedModel>? classifiedModel,
    int? page,
    int? total,
  }) {
    return FetchClassifiedSuccess(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingMoreError: loadingMoreError ?? this.loadingMoreError,
      classifiedModel: classifiedModel ?? this.classifiedModel,
      page: page ?? this.page,
      total: total ?? this.total,
    );
  }
}

class FetchClassifiedFailure extends FetchclassifiedState {
  final dynamic errorMessage;

  FetchClassifiedFailure(this.errorMessage);
}

class FetchClassifiedCubit extends Cubit<FetchclassifiedState> {
  FetchClassifiedCubit() : super(FetchClassifiedInitial());

  final ClassifiedRepository _classifiedRepository = ClassifiedRepository();

  Future<void> fetchclassified() async {
    try {
      emit(FetchClassifiedInProgress());

      DataOutput<ClassifiedModel> result = await _classifiedRepository.fetchclassified(page: 1);

      emit(
        FetchClassifiedSuccess(
            isLoadingMore: false,
            loadingMoreError: false,
          classifiedModel: result.modelList,
            page: 1,
            total: result.total),
      );
    } catch (e) {
      emit(FetchClassifiedFailure(e));
    }
  }

  Future<void> fetchclassifiedmore() async {
    try {
      if (state is FetchClassifiedSuccess) {
        if ((state as FetchClassifiedSuccess).isLoadingMore) {
          return;
        }

        emit((state as FetchClassifiedSuccess).copyWith(isLoadingMore: true));

        DataOutput<ClassifiedModel> result = await _classifiedRepository.fetchclassified(
          page: (state as FetchClassifiedSuccess).page + 1,
        );

        FetchClassifiedSuccess blogModelState = (state as FetchClassifiedSuccess);
        blogModelState.classifiedModel.addAll(result.modelList);
        emit(FetchClassifiedSuccess(
            isLoadingMore: false,
            loadingMoreError: false,
            classifiedModel: blogModelState.classifiedModel,
            page: (state as FetchClassifiedSuccess).page + 1,
            total: result.total));
      }
    } catch (e) {
      emit((state as FetchClassifiedSuccess)
          .copyWith(isLoadingMore: false, loadingMoreError: true));
    }
  }

  bool hasMoreData() {
    if (state is FetchClassifiedSuccess) {
      return (state as FetchClassifiedSuccess).classifiedModel.length <
          (state as FetchClassifiedSuccess).total;
    }
    return false;
  }
}
