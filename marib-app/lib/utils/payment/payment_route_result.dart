enum PaymentRouteKind { walletSuccess, bankTransferCreated }

class PaymentRouteResult {
  const PaymentRouteResult._({
    required this.kind,
    this.walletTxnId,
    this.manualRequestId,
  });

  const PaymentRouteResult.wallet(int? transactionId)
      : this._(
    kind: PaymentRouteKind.walletSuccess,
    walletTxnId: transactionId,
  );

  const PaymentRouteResult.bank(int? requestId)
      : this._(
    kind: PaymentRouteKind.bankTransferCreated,
    manualRequestId: requestId,
  );

  final PaymentRouteKind kind;
  final int? walletTxnId;
  final int? manualRequestId;
}