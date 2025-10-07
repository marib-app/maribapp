<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Services\InvoicePdfService;
use Illuminate\Http\Response;

class OrderDocumentController extends Controller
{
    public function __construct(private readonly InvoicePdfService $invoicePdfService)
    {
    }

    public function invoice(Order $order): Response
    {
        $order->loadMissing(['items', 'user']);

        if ($order->hasOutstandingBalance()) {
            abort(403, __('orders.invoice.balance_outstanding'));
        }

        $pdf = $this->invoicePdfService->generate($order);
        $fileName = sprintf('invoice-%s.pdf', $order->order_number ?? $order->getKey());

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="' . $fileName . '"',
        ]);
    }

    public function depositReceipts(Order $order)
    {
        $receipts = $order->deposit_receipts;

        if ($receipts === []) {
            abort(404);
        }

        $order->loadMissing(['paymentTransactions']);
        $transactions = $order->paymentTransactions->keyBy('id');

        return view('orders.deposit-receipts', [
            'order' => $order,
            'receipts' => collect($receipts)->map(function (array $receipt) use ($transactions) {
                $transaction = $receipt['transaction_id']
                    ? $transactions->get($receipt['transaction_id'])
                    : null;

                return [
                    ...$receipt,
                    'transaction' => $transaction,
                ];
            })->all(),
        ]);
    }
}