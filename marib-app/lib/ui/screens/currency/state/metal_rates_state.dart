import 'package:marib/data/model/metal_rate.dart';

class MetalsRatesState {
  MetalsRatesState({
    required List<MetalRate> goldRates,
    required List<MetalRate> displayGoldRates,
    required List<MetalRate> silverRates,
    required List<MetalRate> displaySilverRates,
    required List<MetalRate> otherRates,
    required List<MetalRate> displayOtherRates,
    required Set<int> watchlist,
  })  : goldRates = List<MetalRate>.unmodifiable(goldRates),
        displayGoldRates = List<MetalRate>.unmodifiable(displayGoldRates),
        silverRates = List<MetalRate>.unmodifiable(silverRates),
        displaySilverRates = List<MetalRate>.unmodifiable(displaySilverRates),
        otherRates = List<MetalRate>.unmodifiable(otherRates),
        displayOtherRates = List<MetalRate>.unmodifiable(displayOtherRates),
        watchlist = Set<int>.unmodifiable(watchlist);

  final List<MetalRate> goldRates;
  final List<MetalRate> displayGoldRates;
  final List<MetalRate> silverRates;
  final List<MetalRate> displaySilverRates;
  final List<MetalRate> otherRates;
  final List<MetalRate> displayOtherRates;
  final Set<int> watchlist;

  List<MetalRate> get allRates => <MetalRate>[
        ...goldRates,
        ...silverRates,
        ...otherRates,
      ];

  List<MetalRate> get displayRates => <MetalRate>[
        ...displayGoldRates,
        ...displaySilverRates,
        ...displayOtherRates,
      ];

  bool get hasAnyRates => displayRates.isNotEmpty;
}
