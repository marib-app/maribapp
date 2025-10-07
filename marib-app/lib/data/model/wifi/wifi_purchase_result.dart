import 'package:equatable/equatable.dart';

import 'package:marib/data/model/wifi/wifi_purchase.dart';

class WifiPurchaseResult extends Equatable {
  const WifiPurchaseResult({
    required this.status,
    required this.isPending,
    required this.requiresAction,
    this.purchase,
    this.message,
    this.redirectUrl,
    this.raw = const <String, dynamic>{},
  });

  final String status;
  final bool isPending;
  final bool requiresAction;
  final WifiPurchase? purchase;
  final String? message;
  final Uri? redirectUrl;
  final Map<String, dynamic> raw;

  List<String> get codes => purchase?.codes ?? const <String>[];

  bool get isWalletPayment => purchase?.isWalletGateway ?? false;

  bool get isSuccess => !isPending;

  @override
  List<Object?> get props => [
    status,
    isPending,
    requiresAction,
    purchase,
    message,
    redirectUrl,
    raw,
  ];
}