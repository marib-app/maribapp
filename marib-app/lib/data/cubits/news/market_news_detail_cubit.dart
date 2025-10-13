import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/model/market_news.dart';
import 'package:marib/data/repositories/market_news_repository.dart';

abstract class MarketNewsDetailState {}

class MarketNewsDetailInitial extends MarketNewsDetailState {}

class MarketNewsDetailLoading extends MarketNewsDetailState {}

class MarketNewsDetailSuccess extends MarketNewsDetailState {
  final MarketNews news;

  MarketNewsDetailSuccess(this.news);
}

class MarketNewsDetailFailure extends MarketNewsDetailState {
  final dynamic error;

  MarketNewsDetailFailure(this.error);
}

class MarketNewsDetailCubit extends Cubit<MarketNewsDetailState> {
  MarketNewsDetailCubit(this._repository) : super(MarketNewsDetailInitial());

  final MarketNewsRepository _repository;

  Future<void> fetch(String slug) async {
    try {
      emit(MarketNewsDetailLoading());
      final MarketNews news = await _repository.fetchDetail(slug);
      emit(MarketNewsDetailSuccess(news));
    } catch (error) {
      emit(MarketNewsDetailFailure(error));
    }
  }

  void seed(MarketNews news) {
    emit(MarketNewsDetailSuccess(news));
  }
}