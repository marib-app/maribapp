<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Services\Payments\OrderPaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class PaymentController extends Controller
{
    public function __construct(private readonly OrderPaymentService $orderPaymentService)
    {
    }

    public function initiate(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        $validated = $request->validate([
            'order_id' => ['required', 'integer', 'exists:orders,id'],
            'payment_method' => ['required', 'string', 'max:191'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
        ]);

        $order = Order::query()
            ->where('user_id', $request->user()->getKey())
            ->findOrFail($validated['order_id']);

        $transaction = $this->orderPaymentService->initiate(
            $request->user(),
            $order,
            $validated['payment_method'],
            $idempotencyKey,
            $validated
        );

        return response()->json([
            'message' => __('تم إنشاء عملية الدفع بنجاح.'),
            'transaction' => $transaction->fresh(),
        ]);
    }

    public function confirm(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        $validated = $request->validate([
            'transaction_id' => ['required', 'integer', 'exists:payment_transactions,id'],
            'reference' => ['nullable', 'string', 'max:191'],
        ]);

        $transaction = PaymentTransaction::query()
            ->with('payable')
            ->findOrFail($validated['transaction_id']);

        $updated = $this->orderPaymentService->confirm(
            $request->user(),
            $transaction,
            $idempotencyKey,
            $validated
        );

        return response()->json([
            'message' => __('تم تأكيد عملية الدفع.'),
            'transaction' => $updated->fresh(),
        ]);
    }

    public function manual(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        $validated = $request->validate([
            'order_id' => ['required', 'integer', 'exists:orders,id'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string', 'max:191'],
            'note' => ['nullable', 'string'],
            'auto_confirm' => ['sometimes', 'boolean'],
        ]);

        $order = Order::query()
            ->where('user_id', $request->user()->getKey())
            ->findOrFail($validated['order_id']);

        $transaction = $this->orderPaymentService->createManual(
            $request->user(),
            $order,
            $idempotencyKey,
            $validated
        );

        return response()->json([
            'message' => __('تم تسجيل الدفع اليدوي.'),
            'transaction' => $transaction,
        ], $transaction->payment_status === 'succeed' ? 200 : 202);
    }

    private function resolveIdempotencyKey(Request $request): string
    {
        $key = $request->header('Idempotency-Key');

        if (! $key) {
            throw ValidationException::withMessages([
                'Idempotency-Key' => __('حقل Idempotency-Key مطلوب في الترويسة.'),
            ]);
        }

        return trim($key);
    }
}