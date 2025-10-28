<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ManualPaymentRequestResource;
use App\Http\Resources\PaymentTransactionResource;
use App\Http\Resources\Payments\SubjectResource;
use App\Models\ManualPaymentRequest;
use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\ServiceRequest;
use App\Services\Logging\PaymentTrace;
use App\Services\Payments\OrderPaymentService;
use App\Services\PaymentFulfillmentService;
use App\Services\Payments\ServicePaymentService;
use App\Support\Payments\PaymentGatewayCurrencyPolicy;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class PaymentController extends Controller
{
    public function __construct(
        private readonly ServicePaymentService $servicePaymentService,
        private readonly OrderPaymentService $orderPaymentService,
        private readonly PaymentFulfillmentService $paymentFulfillmentService
    ) {
    }

    public function initiate(Request $request): JsonResponse
    {
        $user = $request->user() ?? Auth::user();

        if (! $user) {
            return response()->json(['message' => __('Unauthenticated.')], 401);
        }

        $purpose = strtolower($request->input('purpose', 'service'));

        if (! in_array($purpose, ['service', 'order'], true)) {
            throw ValidationException::withMessages([
                'purpose' => __('Unsupported payment purpose.'),
            ]);
        }

        return $purpose === 'service'
            ? $this->initiateServicePayment($request, $user->getKey())
            : $this->initiateOrderPayment($request, $user->getKey());
    }

    public function confirm(Request $request): JsonResponse
    {
        $user = $request->user() ?? Auth::user();

        if (! $user) {
            return response()->json(['message' => __('Unauthenticated.')], 401);
        }

        $purpose = strtolower($request->input('purpose', 'service'));

        if (! in_array($purpose, ['service', 'order'], true)) {
            throw ValidationException::withMessages([
                'purpose' => __('Unsupported payment purpose.'),
            ]);
        }

        return $purpose === 'service'
            ? $this->confirmServicePayment($request, $user->getKey())
            : $this->confirmOrderPayment($request, $user->getKey());
    }

    private function initiateServicePayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'payment_method' => ['required', 'string', 'max:191'],
            'currency' => ['required', 'string', 'size:3'],
            'service_request_id' => ['required', 'integer', 'exists:service_requests,id'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'metadata' => ['nullable', 'array'],
            'order_id' => ['prohibited'],
        ]);

        $serviceRequest = ServiceRequest::query()
            ->with('service')
            ->whereKey($validated['service_request_id'])
            ->firstOrFail();

        if ((int) $serviceRequest->user_id !== $userId) {
            return response()->json(['message' => __('Service request not found.')], 404);
        }

        if (! $serviceRequest->request_number) {
            $serviceRequest->request_number = $this->generateServiceRequestNumber();
            $serviceRequest->save();
        }

        $method = strtolower(trim($validated['payment_method']));
        $currency = strtoupper(trim($validated['currency']));

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        $idempotencyKey = $this->resolveIdempotencyKey($request, [
            'purpose' => 'service',
            'user' => $userId,
            'service_request' => $serviceRequest->getKey(),
            'method' => $method,
            'currency' => $currency,
            'amount' => $validated['amount'] ?? $serviceRequest->service?->price ?? '',
        ]);

        $existing = PaymentTransaction::query()
            ->where('user_id', $userId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if (! $existing) {
            $data = [
                'amount' => $validated['amount'] ?? null,
                'currency' => $currency,
                'metadata' => $validated['metadata'] ?? null,
            ];

            $transaction = $this->servicePaymentService->initiate(
                $request->user(),
                $serviceRequest,
                $method,
                $idempotencyKey,
                $data
            );

            $existing = $transaction;
        }

        $statusCode = $this->inferStatusCode($existing);

        PaymentTrace::trace('payment.initiate.service', [
            'user_id' => $userId,
            'payable_type' => ServiceRequest::class,
            'payable_id' => $serviceRequest->getKey(),
            'payment_transaction_id' => $existing->getKey(),
            'idempotency_key' => $existing->idempotency_key,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildServiceResponse($existing, $serviceRequest, $statusCode);
    }

    private function initiateOrderPayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'payment_method' => ['required', 'string', 'max:191'],
            'currency' => ['required', 'string', 'size:3'],
            'order_id' => ['required', 'integer', 'exists:orders,id'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'metadata' => ['nullable', 'array'],
        ]);

        $order = Order::query()
            ->where('user_id', $userId)
            ->findOrFail($validated['order_id']);

        $method = strtolower(trim($validated['payment_method']));
        $currency = strtoupper(trim($validated['currency']));

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        $idempotencyKey = $this->resolveIdempotencyKey($request, [
            'purpose' => 'order',
            'user' => $userId,
            'order' => $order->getKey(),
            'method' => $method,
            'currency' => $currency,
            'amount' => $validated['amount'] ?? $order->total ?? '',
        ]);

        $existing = PaymentTransaction::query()
            ->where('user_id', $userId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if (! $existing) {
            $transaction = $this->orderPaymentService->initiate(
                $request->user(),
                $order,
                $method,
                $idempotencyKey,
                $validated
            );

            $existing = $transaction;
        }

        $statusCode = $this->inferStatusCode($existing);

        PaymentTrace::trace('payment.initiate.order', [
            'user_id' => $userId,
            'payable_type' => Order::class,
            'payable_id' => $order->getKey(),
            'payment_transaction_id' => $existing->getKey(),
            'idempotency_key' => $existing->idempotency_key,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildOrderResponse($existing, $order, $statusCode);
    }

    private function confirmServicePayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'transaction_id' => ['nullable', 'integer'],
            'idempotency_key' => ['nullable', 'string', 'max:64'],
            'service_request_id' => ['required', 'integer', 'exists:service_requests,id'],
        ]);

        if (empty($validated['transaction_id']) && empty($validated['idempotency_key'])) {
            throw ValidationException::withMessages([
                'transaction_id' => __('A transaction reference is required.'),
            ]);
        }

        $serviceRequest = ServiceRequest::query()
            ->with('service')
            ->whereKey($validated['service_request_id'])
            ->firstOrFail();

        if ((int) $serviceRequest->user_id !== $userId) {
            return response()->json(['message' => __('Service request not found.')], 404);
        }

        $transaction = $this->resolveTransactionReference(
            $userId,
            $validated['transaction_id'] ?? null,
            $validated['idempotency_key'] ?? null
        );

        $result = $this->paymentFulfillmentService->fulfill(
            $transaction,
            ServiceRequest::class,
            $serviceRequest->getKey(),
            $userId,
            [
                'payment_gateway' => $transaction->payment_gateway,
            ]
        );

        $freshTransaction = $result['transaction'] ?? $transaction->fresh();
        $serviceRequest->refresh();

        $statusCode = $this->inferStatusCode($freshTransaction);

        PaymentTrace::trace('payment.confirm.service', [
            'user_id' => $userId,
            'payable_type' => ServiceRequest::class,
            'payable_id' => $serviceRequest->getKey(),
            'payment_transaction_id' => $freshTransaction->getKey(),
            'idempotency_key' => $freshTransaction->idempotency_key,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildServiceResponse($freshTransaction, $serviceRequest, $statusCode);
    }

    private function confirmOrderPayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'transaction_id' => ['nullable', 'integer'],
            'idempotency_key' => ['nullable', 'string', 'max:64'],
            'order_id' => ['required', 'integer', 'exists:orders,id'],
        ]);

        if (empty($validated['transaction_id']) && empty($validated['idempotency_key'])) {
            throw ValidationException::withMessages([
                'transaction_id' => __('A transaction reference is required.'),
            ]);
        }

        $order = Order::query()
            ->where('user_id', $userId)
            ->findOrFail($validated['order_id']);

        $transaction = $this->resolveTransactionReference(
            $userId,
            $validated['transaction_id'] ?? null,
            $validated['idempotency_key'] ?? null
        );

        $result = $this->paymentFulfillmentService->fulfill(
            $transaction,
            Order::class,
            $order->getKey(),
            $userId,
            [
                'payment_gateway' => $transaction->payment_gateway,
            ]
        );

        $freshTransaction = $result['transaction'] ?? $transaction->fresh();
        $order->refresh();

        $statusCode = $this->inferStatusCode($freshTransaction);

        PaymentTrace::trace('payment.confirm.order', [
            'user_id' => $userId,
            'payable_type' => Order::class,
            'payable_id' => $order->getKey(),
            'payment_transaction_id' => $freshTransaction->getKey(),
            'idempotency_key' => $freshTransaction->idempotency_key,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildOrderResponse($freshTransaction, $order, $statusCode);
    }

    private function buildServiceResponse(PaymentTransaction $transaction, ServiceRequest $serviceRequest, int $statusCode): JsonResponse
    {
        $transaction->loadMissing([
            'manualPaymentRequest.manualBank',
            'manualPaymentRequest.paymentTransaction.order',
            'manualPaymentRequest.paymentTransaction.walletTransaction',
        ]);

        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        $response = [
            'transaction' => PaymentTransactionResource::make($transaction)->resolve(),
            'manual_payment_request' => $manualRequest
                ? ManualPaymentRequestResource::make($manualRequest)->resolve()
                : null,
            'subject' => SubjectResource::make($serviceRequest)->resolve(),
            'next' => [
                'resource' => 'service_requests',
                'show_url' => url(sprintf('/api/service-requests/%d', $serviceRequest->getKey())),
            ],
        ];

        return response()->json($response, $statusCode);
    }

    private function buildOrderResponse(PaymentTransaction $transaction, Order $order, int $statusCode): JsonResponse
    {
        $transaction->loadMissing([
            'manualPaymentRequest.manualBank',
            'manualPaymentRequest.paymentTransaction.order',
            'manualPaymentRequest.paymentTransaction.walletTransaction',
        ]);

        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        $response = [
            'transaction' => PaymentTransactionResource::make($transaction)->resolve(),
            'manual_payment_request' => $manualRequest
                ? ManualPaymentRequestResource::make($manualRequest)->resolve()
                : null,
            'subject' => SubjectResource::make([
                'type' => 'order',
                'id' => $order->getKey(),
                'number' => $order->order_number,
                'status' => $order->payment_status ?? $order->status ?? null,
            ])->resolve(),
            'next' => [
                'resource' => 'orders',
                'show_url' => url(sprintf('/api/orders/%d', $order->getKey())),
            ],
        ];

        return response()->json($response, $statusCode);
    }

    private function resolveTransactionReference(int $userId, ?int $transactionId, ?string $idempotencyKey): PaymentTransaction
    {
        $query = PaymentTransaction::query()->where('user_id', $userId);

        if ($transactionId) {
            $query->whereKey($transactionId);
        } elseif ($idempotencyKey) {
            $query->where('idempotency_key', trim($idempotencyKey));
        }

        $transaction = $query->first();

        if (! $transaction) {
            throw ValidationException::withMessages([
                'transaction_id' => __('Payment transaction not found.'),
            ]);
        }

        return $transaction;
    }

    private function inferStatusCode(PaymentTransaction $transaction): int
    {
        $status = strtolower((string) $transaction->payment_status);

        if ($status === 'succeed' || $status === 'approved') {
            return 200;
        }

        if ($transaction->manualPaymentRequest instanceof ManualPaymentRequest) {
            return 402;
        }

        return 202;
    }

    private function resolveIdempotencyKey(Request $request, array $components): string
    {
        $headerKey = $request->header('Idempotency-Key');

        if (is_string($headerKey) && trim($headerKey) !== '') {
            return Str::limit(trim($headerKey), 64, '');
        }

        $payload = json_encode($components);

        if ($payload === false) {
            $payload = implode('|', array_map(
                static fn ($value) => is_scalar($value) ? (string) $value : serialize($value),
                $components
            ));
        }

        $hash = hash('sha256', $payload);

        return substr($hash, 0, 64);
    }

    private function generateServiceRequestNumber(): string
    {
        $prefix = 'SR-' . now()->format('Ymd');

        do {
            $candidate = $prefix . '-' . Str::padLeft((string) random_int(0, 999999), 6, '0');
        } while (
            ServiceRequest::query()
                ->where('request_number', $candidate)
                ->exists()
        );

        return $candidate;
    }
}
