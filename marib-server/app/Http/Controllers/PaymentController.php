<?php

namespace App\Http\Controllers;
use App\Models\Package;

use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Services\Payments\OrderPaymentService;
use App\Services\Payments\PackagePaymentService;
use Illuminate\Validation\Rule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class PaymentController extends Controller
{
    public function __construct(
        private readonly OrderPaymentService $orderPaymentService,
        private readonly PackagePaymentService $packagePaymentService
    )
    {
    }

    public function initiate(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        $purpose = $request->input('purpose', 'order');

        if ($purpose === 'package' && ! $request->filled('package_id') && $request->filled('order_id')) {
            $request->merge(['package_id' => $request->input('order_id')]);
        }

        $rules = [
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package'])],


            'payment_method' => ['required', 'string', 'max:191'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
        ];

        if ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        $validated = $request->validate($rules);

        if ($purpose === 'package') {
            $package = Package::findOrFail($validated['package_id']);

            $transaction = $this->packagePaymentService->initiate(
                $request->user(),
                $package,
                $validated['payment_method'],
                $idempotencyKey,
                $validated
            );

            return response()->json([
                'message' => __('تم إنشاء عملية الدفع بنجاح.'),
                'transaction' => $transaction->fresh(),
            ]);
        }

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


            'note' => ['nullable', 'string'],
            'payment_method' => ['nullable', 'string', 'max:191'],

        ]);

        $transaction = PaymentTransaction::query()
            ->with('payable')
            ->findOrFail($validated['transaction_id']);

        if ($transaction->payable_type === Package::class) {
            $updated = $this->packagePaymentService->confirm(
                $request->user(),
                $transaction,
                $idempotencyKey,
                $validated
            );
        } else {
            $updated = $this->orderPaymentService->confirm(
                $request->user(),
                $transaction,
                $idempotencyKey,
                $validated
            );
        }

        return response()->json([
            'message' => __('تم تأكيد عملية الدفع.'),
            'transaction' => $updated->fresh(),
        ]);
    }

    public function manual(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        $purpose = $request->input('purpose', 'order');

        if ($purpose === 'package' && ! $request->filled('package_id') && $request->filled('order_id')) {
            $request->merge(['package_id' => $request->input('order_id')]);
        }

        $rules = [
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package'])],


            'amount' => ['nullable', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string', 'max:191'],
            'note' => ['nullable', 'string'],
            'auto_confirm' => ['sometimes', 'boolean'],
        ];

        if ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        $validated = $request->validate($rules);

        if ($purpose === 'package') {
            $package = Package::findOrFail($validated['package_id']);

            $transaction = $this->packagePaymentService->createManual(
                $request->user(),
                $package,
                $idempotencyKey,
                $validated
            );

            return response()->json([
                'message' => __('تم تسجيل الدفع اليدوي.'),
                'transaction' => $transaction,
            ], $transaction->payment_status === 'succeed' ? 200 : 202);
        }

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