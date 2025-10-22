<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Services\InvoicePdfService;
use Illuminate\Http\Response;
use Illuminate\Http\Request;

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
        $document = $this->invoicePdfService->renderDocument($order);


        if ($document->hasPdf()) {
            return response($document->pdf, 200, [
                'Content-Type' => 'application/pdf',
                'Content-Disposition' => 'inline; filename="' . $document->fileName . '"',
            ]);
        }

        $html = $this->invoicePdfService->renderPreviewHtml($order, $document, [
            'preview_download_url' => null,
        ]);

        return response($html, 200, [
            'Content-Type' => 'text/html; charset=UTF-8',
        ]);
    }

    public function preview(Request $request, Order $order): Response
    {
        if (! $request->hasValidSignature()) {
            abort(403);
        }

        $expectedUser = (int) ($request->query('user'));

        if ($expectedUser !== (int) $order->user_id) {
            abort(403);
        }

        if ($order->hasOutstandingBalance()) {
            abort(403, __('orders.invoice.balance_outstanding'));
        }

        $document = $this->invoicePdfService->renderDocument($order);
        $html = $this->invoicePdfService->renderPreviewHtml($order, $document, [
            'preview_download_url' => $document->hasPdf()
                ? route('orders.invoice.pdf', $order)
                : null,
            'preview_request_user' => $request->query('user'),
        ]);

        return response($html, 200, [
            'Content-Type' => 'text/html; charset=UTF-8',

            
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