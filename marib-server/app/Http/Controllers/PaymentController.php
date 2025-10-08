<?php

namespace App\Http\Controllers;
use App\Models\Package;
use App\Http\Resources\ManualPaymentRequestResource;
use App\Http\Resources\PaymentTransactionResource;
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

        if ($request->filled('manual_bank_id') && ! $request->filled('bank_id')) {
            $request->merge(['bank_id' => $request->input('manual_bank_id')]);
        }

        $normalizedMethod = strtolower((string) $request->input('payment_method', 'manual'));
        $request->merge(['payment_method' => $normalizedMethod]);

        $rules = [
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package'])],
            'payment_method' => ['nullable', 'string', 'max:191', Rule::in(['manual', 'manual_bank'])],


            'payment_method' => ['required', 'string', 'max:191'],
            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'bank_id' => ['required_if:payment_method,manual,manual_bank', 'nullable', 'integer', 'exists:manual_banks,id'],
            'bank_account_id' => ['nullable', 'string', 'max:191'],

            'amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
        ];

        if ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        $validated = $request->validate($rules);


        if (!isset($validated['note']) && $request->filled('notes')) {
            $validated['note'] = $request->input('notes');
        }

        if (!isset($validated['metadata']) && $request->has('metadata') && is_array($request->input('metadata'))) {
            $validated['metadata'] = $request->input('metadata');
        }


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



        if ($request->filled('manual_bank_id') && ! $request->filled('bank_id')) {
            $request->merge(['bank_id' => $request->input('manual_bank_id')]);
        }

        if ($request->filled('bank_id') && ! $request->filled('manual_bank_id')) {
            $request->merge(['manual_bank_id' => $request->input('bank_id')]);
        }

        $rules = [
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package'])],


            'amount' => ['nullable', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string', 'max:191'],
            'note' => ['nullable', 'string'],
            'manual_bank_id' => ['required', 'integer', 'exists:manual_banks,id'],
            'bank_account_id' => ['nullable', 'string', 'max:191'],
            'metadata' => ['nullable', 'array'],

            'auto_confirm' => ['sometimes', 'boolean'],
        ];

        if ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        $validated = $request->validate($rules);

        if (! isset($validated['note']) && $request->filled('notes')) {
            $validated['note'] = $request->input('notes');
        }

        if (! isset($validated['metadata']) && $request->has('metadata') && is_array($request->input('metadata'))) {
            $validated['metadata'] = $request->input('metadata');
        }

        $validated['bank_id'] = $validated['manual_bank_id'];


        if ($purpose === 'package') {
            $package = Package::findOrFail($validated['package_id']);

            $transaction = $this->packagePaymentService->createManual(
                $request->user(),
                $package,
                $idempotencyKey,
                $validated
            );

            $transaction->loadMissing('manualPaymentRequest.manualBank');

            $manualRequest = $transaction->manualPaymentRequest?->loadMissing('paymentTransaction.order', 'payable');

            $transactionResource = PaymentTransactionResource::make($transaction)->resolve();
            $manualRequestResource = $manualRequest
                ? ManualPaymentRequestResource::make($manualRequest)->resolve()
                : null;


            return response()->json([
                'message' => __('تم تسجيل الدفع اليدوي.'),
                'transaction' => $transactionResource,
                'payment_transaction' => $transactionResource,
                'manual_payment_request' => $manualRequestResource,
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

        $transaction->loadMissing('manualPaymentRequest.manualBank');

        $manualRequest = $transaction->manualPaymentRequest?->loadMissing('paymentTransaction.order', 'payable');

        $transactionResource = PaymentTransactionResource::make($transaction)->resolve();
        $manualRequestResource = $manualRequest
            ? ManualPaymentRequestResource::make($manualRequest)->resolve()
            : null;

        return response()->json([
            'message' => __('تم تسجيل الدفع اليدوي.'),
            'transaction' => $transactionResource,
            'payment_transaction' => $transactionResource,
            'manual_payment_request' => $manualRequestResource,
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