import 'package:marib/data/model/metal_rate.dart';

abstract class MetalRatesState {
  MetalRatesState({
    required List<MetalRate> rates,
    required List<MetalRate> displayRates,
    required Set<int> watchlist,
  })  : rates = List<MetalRate>.unmodifiable(rates),
        displayRates = List<MetalRate>.unmodifiable(displayRates),
        watchlist = Set<int>.unmodifiable(watchlist);

  final List<MetalRate> rates;
  final List<MetalRate> displayRates;
  final Set<int> watchlist;

  bool get hasRates => displayRates.isNotEmpty;
}

class GoldRatesState extends MetalRatesState {
  GoldRatesState({
    required List<MetalRate> rates,
    required List<MetalRate> displayRates,
    required Set<int> watchlist,
  }) : super(rates: rates, displayRates: displayRates, watchlist: watchlist);
}

class SilverRatesState extends MetalRatesState {
  SilverRatesState({
    required List<MetalRate> rates,
    required List<MetalRate> displayRates,
    required Set<int> watchlist,
  }) : super(rates: rates, displayRates: displayRates, watchlist: watchlist);
}