enum PaymentRouteKind { walletSuccess, bankTransferCreated }

class PaymentRouteResult {
  const PaymentRouteResult._({
    required this.kind,
    this.walletTxnId,
    this.manualRequestId,
    this.delivery,
  });

  const PaymentRouteResult.wallet(
    int? transactionId, {
    Map<String, dynamic>? delivery,
  }) : this._(
          kind: PaymentRouteKind.walletSuccess,
          walletTxnId: transactionId,
          delivery: delivery,
        );

  const PaymentRouteResult.bank(int? requestId)
      : this._(
          kind: PaymentRouteKind.bankTransferCreated,
          manualRequestId: requestId,
        );

  final PaymentRouteKind kind;
  final int? walletTxnId;
  final int? manualRequestId;
  final Map<String, dynamic>? delivery;
}
