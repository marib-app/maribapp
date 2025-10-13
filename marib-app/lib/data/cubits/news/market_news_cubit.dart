import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/market_news.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/repositories/market_news_repository.dart';

abstract class MarketNewsState {}

class MarketNewsInitial extends MarketNewsState {}

class MarketNewsLoading extends MarketNewsState {}

class MarketNewsFailure extends MarketNewsState {
  final dynamic error;

  MarketNewsFailure(this.error);
}

class MarketNewsSuccess extends MarketNewsState {
  final List<MarketNews> news;
  final int page;
  final int total;
  final bool isLoadingMore;
  final bool loadingMoreError;

  MarketNewsSuccess({
    required this.news,
    required this.page,
    required this.total,
    this.isLoadingMore = false,
    this.loadingMoreError = false,
  });

  MarketNewsSuccess copyWith({
    List<MarketNews>? news,
    int? page,
    int? total,
    bool? isLoadingMore,
    bool? loadingMoreError,
  }) {
    return MarketNewsSuccess(
      news: news ?? this.news,
      page: page ?? this.page,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadingMoreError: loadingMoreError ?? this.loadingMoreError,
    );
  }
}

class MarketNewsCubit extends Cubit<MarketNewsState> {
  MarketNewsCubit(this._repository,
      {this.itemId, this.governorateId, this.tag, this.search, this.perPage = 10})
      : super(MarketNewsInitial());

  final MarketNewsRepository _repository;
  final int? itemId;
  final int? governorateId;
  final String? tag;
  final String? search;
  final int perPage;

  Future<void> fetch({int page = 1}) async {
    try {
      emit(MarketNewsLoading());
      final DataOutput<MarketNews> result = await _repository.fetchNews(
        page: page,
        perPage: perPage,
        itemId: itemId,
        governorateId: governorateId,
        tag: tag,
        search: search,
      );

      emit(MarketNewsSuccess(
        news: List<MarketNews>.from(result.modelList),
        page: result.page ?? page,
        total: result.total,
      ));
    } catch (error) {
      emit(MarketNewsFailure(error));
    }
  }

  Future<void> refresh() async {
    await fetch(page: 1);
  }

  Future<void> loadMore() async {
    if (state is! MarketNewsSuccess) {
      return;
    }
    final MarketNewsSuccess current = state as MarketNewsSuccess;
    if (current.isLoadingMore || !hasMoreData()) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true, loadingMoreError: false));

    try {
      final DataOutput<MarketNews> result = await _repository.fetchNews(
        page: current.page + 1,
        perPage: perPage,
        itemId: itemId,
        governorateId: governorateId,
        tag: tag,
        search: search,
      );

      final List<MarketNews> combined =
      List<MarketNews>.from(current.news)..addAll(result.modelList);

      emit(MarketNewsSuccess(
        news: combined,
        page: result.page ?? (current.page + 1),
        total: result.total,
        isLoadingMore: false,
        loadingMoreError: false,
      ));
    } catch (error) {
      emit(current.copyWith(isLoadingMore: false, loadingMoreError: true));
    }
  }

  bool hasMoreData() {
    if (state is! MarketNewsSuccess) {
      return false;
    }
    final MarketNewsSuccess current = state as MarketNewsSuccess;
    return current.news.length < current.total;
  }
}