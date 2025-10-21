import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart' as lottie;

typedef LottieComposition = lottie.LottieComposition;

Future<LottieComposition> loadLottieComposition(
    String path, {
      AssetBundle? bundle,
    }) {
  return lottie.AssetLottie(
    path,
    bundle: bundle,
  ).load();
}