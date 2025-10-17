<?php

namespace App\Http\Controllers;
use App\Enums\OrderStatus as OrderStatusEnum;
use App\Exceptions\CheckoutValidationException;
use App\Services\DepartmentSupportService;
use Illuminate\Support\Str;
use App\Services\DepartmentPolicyService;
use App\Services\OrderCancellationService;

use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderIdempotencyKey;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Services\InvoicePdfService;
use App\Services\OrderCheckoutService;
use App\Services\Payments\OrderPaymentService;
use App\Services\TelemetryService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Arr;
use Throwable;


class OrderApiController extends Controller
{
    public function __construct(
        private readonly OrderCheckoutService $checkoutService,
        private readonly InvoicePdfService $invoicePdfService,
        private readonly OrderPaymentService $orderPaymentService,
        private readonly TelemetryService $telemetryService,
        private readonly DepartmentPolicyService $departmentPolicyService,

        private readonly DepartmentSupportService $departmentSupportService,
        private readonly OrderCancellationService $orderCancellationService,

    ) {
    }

    public function index(Request $request): JsonResponse
    {

        $validated = $request->validate([
            'status' => ['nullable', Rule::in(OrderStatusEnum::values())],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
            'page' => ['nullable', 'integer', 'min:1'],
        ]);



        $user = $request->user();

        $status = $validated['status'] ?? null;
        $perPage = $validated['per_page'] ?? 15;


        $orders = Order::query()
            ->with(['items'])
            ->where('user_id', $user->getKey())
            ->when($status, static fn ($query) => $query->where('order_status', $status))
            ->latest()
            ->paginate($perPage);

        $orders->getCollection()->transform(static function (Order $order) {
            return $order->append(['status_display', 'status_reserve_options', 'actions']);
        });


        return response()->json($orders);
    }

    public function store(Request $request): JsonResponse
    {
        try {

            $validated = $request->validate([
                'address_id' => ['required', 'integer'],
                'department' => ['nullable', 'string', 'max:191'],
                'coupon_code' => ['nullable', 'string', 'max:191'],
                'notes' => ['nullable', 'string'],
                'billing_address' => ['nullable', 'string'],
                'payment_method' => ['nullable', 'string', 'max:191'],
                'force_requote' => ['sometimes', 'boolean'],
                'tax_rate' => ['nullable', 'numeric', 'min:0'],
                'delivery_payment_timing' => [
                    'nullable',
                    'string',
                    Rule::in(OrderCheckoutService::allowedDeliveryPaymentTimingTokens()),

                ],
                'delivery_user_note' => ['nullable', 'string'],
                'deposit_enabled' => ['sometimes', 'boolean'],

            ], [
                'address_id.required' => __('يجب اختيار عنوان صالح لإتمام الطلب.'),
                'address_id.integer' => __('يجب اختيار عنوان صالح لإتمام الطلب.'),
            ]);
        } catch (ValidationException $exception) {
            if ($this->isAddressRequiredException($exception)) {
                return $this->addressValidationErrorResponse($exception);
            }
            throw $exception;
        }
            




        if (isset($validated['delivery_payment_timing'])) {
            $validated['delivery_payment_timing'] = OrderCheckoutService::normalizeTimingToken(
                $validated['delivery_payment_timing']
            );
        }

        $user = $request->user();
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        return DB::transaction(function () use ($user, $validated, $idempotencyKey) {
            $existingKey = OrderIdempotencyKey::query()
                ->where('key', $idempotencyKey)
                ->lockForUpdate()
                ->first();

            if ($existingKey !== null) {
                if ($existingKey->user_id !== $user->getKey()) {
                    throw ValidationException::withMessages([
                        'Idempotency-Key' => __('مفتاح التكرار المرسل مرتبط بمستخدم مختلف.'),
                    ]);
                }

                $order = Order::query()
                    ->with('items')
                    ->where('user_id', $user->getKey())
                    ->find($existingKey->order_id);

                if ($order === null) {
                    throw ValidationException::withMessages([
                        'Idempotency-Key' => __('تعذر العثور على الطلب المرتبط بمفتاح التكرار.'),
                    ]);
                }

                $paymentIntent = $this->createDefaultPaymentIntent($user, $order, $idempotencyKey);

                $order = $order->fresh(['items']);
                $policy = $this->departmentPolicyService->policyFor($order->department);

                return response()->json([
                    'message' => __('تم إنشاء الطلب بنجاح.'),
                    'order' => $order,
                   
                    'payment_intent' => $this->buildPaymentIntentResponse($order, $paymentIntent, $user, $idempotencyKey),
                   
                    'policy' => $policy,
                    'support' => $this->departmentSupportService->supportFor($order->department),

                ]);



            }

            try {
                $order = $this->checkoutService->checkout($user, $validated);


            } catch (ValidationException $exception) {
                if ($this->isAddressRequiredException($exception)) {
                    return $this->addressValidationErrorResponse($exception);
                }

                throw $exception;



            } catch (CheckoutValidationException $exception) {
                return response()->json([
                    'status' => false,
                    'message' => $exception->getMessage(),
                    'code' => $exception->getErrorCode(),
                ], Response::HTTP_UNPROCESSABLE_ENTITY);
            }

            
            OrderIdempotencyKey::create([
                'key' => $idempotencyKey,
                'user_id' => $user->getKey(),
                'order_id' => $order->getKey(),
            ]);

            $paymentIntent = $this->createDefaultPaymentIntent($user, $order, $idempotencyKey);

            $order = $order->fresh(['items']);
            $policy = $this->departmentPolicyService->policyFor($order->department);

            
            return response()->json([
                'message' => __('تم إنشاء الطلب بنجاح.'),
                'order' => $order,
                'payment_intent' => $this->buildPaymentIntentResponse($order, $paymentIntent, $user, $idempotencyKey),

                'policy' => $policy,          
                'support' => $this->departmentSupportService->supportFor($order->department),


            ], 201);
        });
    }


   public function show(Request $request, Order $order): JsonResponse
    {
        $user = $request->user();

        abort_if($order->user_id !== $user->getKey(), Response::HTTP_NOT_FOUND);

        $order->loadMissing([
            'items',
            'items.item',
            'seller',
            'coupon',
            'history.user',
            'paymentTransactions',
        ]);

        $order->append(['status_display', 'status_reserve_options', 'actions']);
        $policy = $this->departmentPolicyService->policyFor($order->department);



        return response()->json([
            'order' => $order,
            'payment_intent' => $this->buildPaymentIntentResponse($order, null, $user),
            'policy' => $policy,

            'support' => $this->departmentSupportService->supportFor($order->department),


        ]);
    }



    public function cancel(Request $request, Order $order): JsonResponse
    {
        $user = $request->user();

        abort_if($order->user_id !== $user->getKey(), Response::HTTP_NOT_FOUND);

        if (! $order->canBeCancelled()) {
            return response()->json([
                'status' => false,
                'message' => __('لا يمكن إلغاء الطلب في حالته الحالية.'),
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $order = $this->orderCancellationService->cancel($order, $user->getKey());
        $order->append(['status_display', 'status_reserve_options', 'actions']);

        $policy = $this->departmentPolicyService->policyFor($order->department);

        return response()->json([
            'message' => __('تم إلغاء الطلب بنجاح.'),
            'order' => $order,
            'payment_intent' => $this->buildPaymentIntentResponse($order, null, $user),
            'policy' => $policy,
            'support' => $this->departmentSupportService->supportFor($order->department),
        ]);
    }



    public function collectDelivery(Request $request, int $orderId): JsonResponse
    {
        $validated = $request->validate([
            'amount' => ['required', 'numeric', 'min:0'],
            'collected_at' => ['nullable', 'date'],
            'note' => ['nullable', 'string'],
        ]);

        $order = Order::query()
            ->where('user_id', $request->user()->getKey())
            ->findOrFail($orderId);

        $timestamp = isset($validated['collected_at'])
            ? Carbon::parse($validated['collected_at'])
            : Carbon::now();

        $requestedAmount = round((float) $validated['amount'], 2);
        $codDue = $this->resolveOrderCodDue($order);
        $collectedAmount = $this->normalizeCollectedAmount($requestedAmount, $codDue);
        $codOutstanding = $this->calculateCodOutstanding($codDue, $collectedAmount);
        $onlineOutstanding = $this->resolveOnlineOutstanding($order);
        $remainingBalance = max(round($onlineOutstanding + $codOutstanding, 2), 0.0);
        $deliveryPaymentStatus = $this->resolveDeliveryPaymentStatus($codDue, $codOutstanding, $onlineOutstanding);

        $order->delivery_collected_amount = $collectedAmount;
        
        
        
        $order->delivery_collected_at = $timestamp;
        $order->delivery_cod_due = $codOutstanding;
        $order->delivery_payment_status = $deliveryPaymentStatus;

        $order->recordStatusTimestamp('delivery_collected', $timestamp);

        $collectionPayload = array_filter([
            'amount' => $order->delivery_collected_amount,
            'recorded_by' => $request->user()->getKey(),
            'recorded_at' => $order->delivery_collected_at?->toIso8601String(),
            'note' => $validated['note'] ?? null,
        ], static fn ($value) => $value !== null);



        $order->mergePaymentPayload([
            'delivery_collection' => $collectionPayload,
            'delivery_payment' => Arr::whereNotNull([
                'delivery_payment_status' => $deliveryPaymentStatus,
                'cod_due' => $codDue,
                'cod_outstanding' => $codOutstanding,
            ]),
            'delivery_payment_status' => $deliveryPaymentStatus,
            'payment_summary' => Arr::whereNotNull([
                'cod_due' => $codDue,
                'cod_outstanding' => $codOutstanding,
                'online_outstanding' => $onlineOutstanding,
                'remaining_balance' => $remainingBalance,
            ]),


        ]);
        $order->forceFill([
            'delivery_collected_amount' => $order->delivery_collected_amount,
            'delivery_collected_at' => $order->delivery_collected_at,
            'delivery_cod_due' => $order->delivery_cod_due,
            'delivery_payment_status' => $order->delivery_payment_status,

            'status_timestamps' => $order->status_timestamps,
            'payment_payload' => $order->payment_payload,
        ])->save();

        $this->telemetryService->record('orders.delivery_collection.recorded', [
            'order_id' => $order->getKey(),
            'user_id' => $request->user()->getKey(),
            'requested_amount' => $requestedAmount,
            'recorded_amount' => $order->delivery_collected_amount,
            'cod_due' => $codDue,
            'cod_outstanding' => $codOutstanding,
            'delivery_payment_status' => $deliveryPaymentStatus,
            'remaining_balance' => $remainingBalance,
        ]);



        if (! empty($validated['note'])) {
            OrderHistory::create([
                'order_id' => $order->getKey(),
                'user_id' => $request->user()->getKey(),
                'status_from' => $order->order_status,
                'status_to' => $order->order_status,
                'comment' => $validated['note'],
                'notify_customer' => false,
            ]);
        }

        return response()->json([
            'message' => __('تم تسجيل مبلغ التوصيل بنجاح.'),
            'order' => $order->refresh(),
        ]);
    }


    private function resolveOrderCodDue(Order $order): float
    {
        $summary = $order->payment_summary;

        if (is_array($summary) && array_key_exists('cod_due', $summary) && $summary['cod_due'] !== null) {
            return max(round((float) $summary['cod_due'], 2), 0.0);
        }

        $payloadCodDue = data_get($order->payment_payload, 'delivery_payment.cod_due');

        if ($payloadCodDue !== null) {
            return max(round((float) $payloadCodDue, 2), 0.0);
        }

        $summaryPayloadCodDue = data_get($order->payment_payload, 'payment_summary.cod_due');

        if ($summaryPayloadCodDue !== null) {
            return max(round((float) $summaryPayloadCodDue, 2), 0.0);
        }

        if ($order->delivery_cod_due !== null) {
            return max(round((float) $order->delivery_cod_due, 2), 0.0);
        }

        return 0.0;
    }

    private function normalizeCollectedAmount(float $requestedAmount, float $codDue): float
    {
        $amount = max(round($requestedAmount, 2), 0.0);

        if ($codDue > 0.0) {
            $amount = min($amount, $codDue);
        }

        return $amount;
    }

    private function calculateCodOutstanding(float $codDue, float $collectedAmount): float
    {
        return max(round($codDue - $collectedAmount, 2), 0.0);
    }

    private function resolveOnlineOutstanding(Order $order): float
    {
        $summary = $order->payment_summary;

        if (is_array($summary) && array_key_exists('online_outstanding', $summary) && $summary['online_outstanding'] !== null) {
            return max(round((float) $summary['online_outstanding'], 2), 0.0);
        }

        $summaryPayload = data_get($order->payment_payload, 'payment_summary.online_outstanding');

        if ($summaryPayload !== null) {
            return max(round((float) $summaryPayload, 2), 0.0);
        }

        $deliveryPayload = data_get($order->payment_payload, 'delivery_payment.online_outstanding');

        if ($deliveryPayload !== null) {
            return max(round((float) $deliveryPayload, 2), 0.0);
        }

        return 0.0;
    }

    private function resolveDeliveryPaymentStatus(float $codDue, float $codOutstanding, float $onlineOutstanding): string
    {
        if ($codDue <= 0.0 && $onlineOutstanding <= 0.0) {
            return 'waived';
        }

        if ($codOutstanding <= 0.0) {
            return 'paid';
        }

        return 'pending';
    }



    public function invoice(Request $request, int $orderId): Response
    {
        $order = Order::query()
            ->with(['items', 'user'])
            ->where('user_id', $request->user()->getKey())
            ->findOrFail($orderId);

        if ($order->hasOutstandingBalance()) {
            return response()->json([
                'message' => __('orders.invoice.balance_outstanding'),
            ], Response::HTTP_FORBIDDEN);
        }


        $pdf = $this->invoicePdfService->generate($order);
        $fileName = sprintf('invoice-%s.pdf', $order->order_number);

        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="' . $fileName . '"',
        ]);
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
    private function createDefaultPaymentIntent(User $user, Order $order, string $idempotencyKey): ?PaymentTransaction
    {
        $defaultIntent = $order->payment_payload['default_intent'] ?? [];
        $existingTransactionId = data_get($defaultIntent, 'transaction_id');
        $existingTransaction = null;
        $shouldForceUniqueIdempotencyKey = false;



        if ($existingTransactionId) {
            $existingTransaction = PaymentTransaction::query()->find($existingTransactionId);
            $expiresAt = $this->parseDefaultPaymentIntentExpiry($defaultIntent);
            $hasExpired = $this->hasDefaultPaymentIntentExpired($expiresAt) || $existingTransaction === null;

            if ($hasExpired) {
                $this->expireDefaultPaymentIntent($order, $existingTransaction);
                $order->refresh();
                $defaultIntent = $order->payment_payload['default_intent'] ?? [];
                $existingTransactionId = null;
                $existingTransaction = null;
                $shouldForceUniqueIdempotencyKey = true;
            } else {
                return $existingTransaction;
            }
        
        }

        $method = $this->resolveDefaultPaymentMethod($order);

        if (! is_string($method) || $method === '') {
            return null;
        }

        $idempotencySuffix = $shouldForceUniqueIdempotencyKey ? Str::uuid()->toString() : null;
        $intentIdempotencyKey = $this->buildDefaultPaymentIdempotencyKey(
            $order,
            $idempotencyKey,
            $method,
            $idempotencySuffix
        );



        try {
            $transaction = $this->orderPaymentService->initiate(
                $user,
                $order,
                $method,
                $intentIdempotencyKey
            );
        } catch (ValidationException $exception) {
            Log::info('orders.default_payment_intent.skipped', [
                'order_id' => $order->getKey(),
                'user_id' => $user->getKey(),
                'method' => $method,
                'message' => $exception->getMessage(),
            ]);

            return null;
        } catch (Throwable $throwable) {
            Log::warning('orders.default_payment_intent.failed', [
                'order_id' => $order->getKey(),
                'user_id' => $user->getKey(),
                'method' => $method,
                'message' => $throwable->getMessage(),
            ]);

            return null;
        }
        $expiresAt = $this->calculateDefaultPaymentIntentExpiry($order);

        $order->mergePaymentPayload([
            'default_intent' => array_filter([
                'transaction_id' => $transaction->getKey(),
                'method' => $transaction->payment_gateway,
                'amount' => $transaction->amount !== null ? (float) $transaction->amount : null,
                'currency' => $transaction->currency,
                'idempotency_key' => $transaction->idempotency_key,
                'expires_at' => $expiresAt->toIso8601String(),


            ], static fn ($value) => $value !== null),
        ]);

        if (! $order->payment_method) {
            $order->payment_method = $transaction->payment_gateway;
        }

        $order->forceFill([
            'payment_method' => $order->payment_method,
            'payment_payload' => $order->payment_payload,
        ])->save();

        return $transaction->fresh();
    }

    private function resolveDefaultPaymentMethod(Order $order): ?string
    {
        $candidates = [
            is_string($order->payment_method) ? $order->payment_method : null,
            data_get($order->payment_payload, 'default_intent.method'),
            config('orders.default_payment_method'),
        ];

        foreach ($candidates as $candidate) {
            $normalized = OrderCheckoutService::normalizePaymentMethod(is_string($candidate) ? $candidate : null);

            if (is_string($normalized) && $normalized !== '') {
                return mb_strtolower($normalized);
            }
        }

        return null;
    
    }

    private function buildDefaultPaymentIdempotencyKey(
        Order $order,
        string $idempotencyKey,
        string $method,
        ?string $suffix = null
    ): string {
        $parts = ['order', $order->getKey(), $method, $idempotencyKey];

        if ($suffix !== null) {
            $parts[] = $suffix;
        }

        return implode(':', $parts);


    }

    private function buildPaymentIntentResponse(
        Order $order,
        ?PaymentTransaction $transaction = null,
        ?User $user = null,
        ?string $idempotencyKey = null
    ): ?array {



        $summary = $order->delivery_payment_summary;
        $defaultIntent = $order->payment_payload['default_intent'] ?? [];

        $transactionId = $transaction?->getKey() ?? data_get($defaultIntent, 'transaction_id');



        if ($transaction === null && $transactionId !== null) {
            $transaction = PaymentTransaction::query()->find($transactionId);
        }

        $expiresAt = $this->parseDefaultPaymentIntentExpiry($defaultIntent);
        $hasExpired = $this->hasDefaultPaymentIntentExpired($expiresAt) || ($transactionId !== null && $transaction === null);

        if ($hasExpired) {
            $this->expireDefaultPaymentIntent($order, $transaction);
            $order->refresh();
            $transaction = null;
            $transactionId = null;
            $defaultIntent = $order->payment_payload['default_intent'] ?? [];

            if ($user) {
                $refreshIdempotencyKey = $idempotencyKey ?? Str::uuid()->toString();
                $transaction = $this->createDefaultPaymentIntent($user, $order, $refreshIdempotencyKey);
                $order->refresh();
                $defaultIntent = $order->payment_payload['default_intent'] ?? [];
                $transactionId = $transaction?->getKey();
            }
        }

        $rawMethod = $transaction?->payment_gateway ?? data_get($defaultIntent, 'method');
        $method = OrderCheckoutService::normalizePaymentMethod(is_string($rawMethod) ? $rawMethod : null);

        if (! is_string($method) || $method === '') {
            $method = is_string($rawMethod) ? mb_strtolower($rawMethod) : null;
        }



        if ($method === null && $transactionId === null && $summary === null) {
            return null;
        }

        $reference = $transactionId !== null ? (string) $transactionId : null;
        $currency = $transaction?->currency
            ?? data_get($defaultIntent, 'currency')
            ?? strtoupper((string) config('app.currency', 'SAR'));

        $nowAmount = $summary['online_payable'] ?? null;
        $onDeliveryAmount = $summary['cod_due'] ?? null;

        return [
            'method' => $method,
            'reference' => $reference,
            'transaction_id' => $transactionId,
            'currency' => $currency,
            'amounts' => [
                'now' => $nowAmount !== null ? (float) $nowAmount : null,
                'on_delivery' => $onDeliveryAmount !== null ? (float) $onDeliveryAmount : null,
            ],

            'expires_at' => data_get($defaultIntent, 'expires_at'),


        ];
    }




    private function parseDefaultPaymentIntentExpiry(array $defaultIntent): ?Carbon
    {
        $expiresAt = data_get($defaultIntent, 'expires_at');

        if (! is_string($expiresAt) || trim($expiresAt) === '') {
            return null;
        }

        try {
            return Carbon::parse($expiresAt);
        } catch (Throwable) {
            return null;
        }
    }

    private function hasDefaultPaymentIntentExpired(?Carbon $expiresAt): bool
    {
        if ($expiresAt === null) {
            return true;
        }

        return $expiresAt->lessThanOrEqualTo(Carbon::now());
    }

    private function expireDefaultPaymentIntent(Order $order, ?PaymentTransaction $transaction): void
    {
        if ($transaction && $transaction->payment_status === 'pending') {
            $updates = [
                'payment_status' => 'cancelled',
            ];

            if ($transaction->order_id !== null && ! Str::contains($transaction->order_id, ':expired:')) {
                $updates['order_id'] = sprintf('%s:expired:%s', $transaction->order_id, Str::uuid());
            }

            $transaction->forceFill($updates)->save();
        }

        $payload = $order->payment_payload ?? [];
        unset($payload['default_intent']);

        $order->forceFill([
            'payment_payload' => $payload,
        ])->save();
    }

    private function resolveDefaultPaymentIntentTtlMinutes(Order $order): int
    {
        $config = config('orders.default_payment_intent', []);
        $department = $order->department;
        $overrides = Arr::get($config, 'department_overrides', []);

        if (is_array($overrides) && $department && array_key_exists($department, $overrides)) {
            return max(1, (int) $overrides[$department]);
        }

        return max(1, (int) ($config['ttl_minutes'] ?? 60 * 24));
    }

    private function calculateDefaultPaymentIntentExpiry(Order $order): Carbon
    {
        return Carbon::now()->addMinutes($this->resolveDefaultPaymentIntentTtlMinutes($order));
    }





    private function addressValidationErrorResponse(ValidationException $exception): JsonResponse
    {
        $errors = $exception->errors();
        $message = collect($errors)->flatten()->first() ?? __('يجب اختيار عنوان صالح لإتمام الطلب.');

        return response()->json([
            'status' => false,
            'code' => 'address_required',
            'message' => $message,
            'errors' => $errors,
        ], 422);
    }

    private function isAddressRequiredException(ValidationException $exception): bool
    {
        if ($exception->errorBag === 'address_required') {
            return true;
        }

        return array_key_exists('address_id', $exception->errors());
    }
}
