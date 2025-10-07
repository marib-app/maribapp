import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class CheckInternet {
  CheckInternet();

  static Connectivity connectivity = Connectivity();

  static Future<void> check({
    required FutureOr<void> Function() onInternet,
    FutureOr<void> Function()? onNoInternet,
  }) async {
    final List<ConnectivityResult> connectivityResult =
        await connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (onNoInternet != null) {
        await Future.sync(onNoInternet);
      }
    } else {
      await Future.sync(onInternet);
    }
  }
}
