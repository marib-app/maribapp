<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ManualPaymentRequestResource;
use App\Http\Resources\PaymentTransactionResource;
use App\Http\Resources\Payments\SubjectResource;
use App\Models\ManualPaymentRequest;
use App\Models\Order;
use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\VerificationPayment;
use App\Models\VerificationRequest;
use App\Models\Wifi\WifiPlan;
use App\Services\Logging\PaymentTrace;
use App\Services\LegalNumberingService;
use App\Services\Payments\OrderPaymentService;
use App\Services\OrderCheckoutService;
use App\Services\PaymentFulfillmentService;
use App\Services\WalletService;
use App\Services\Payments\PackagePaymentService;
use App\Services\Payments\ServicePaymentService;
use App\Services\Payments\WifiPlanPaymentService;
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
        private readonly PackagePaymentService $packagePaymentService,
        private readonly WifiPlanPaymentService $wifiPlanPaymentService,
        private readonly PaymentFulfillmentService $paymentFulfillmentService,
        private readonly LegalNumberingService $legalNumberingService,
        private readonly WalletService $walletService
    ) {
    }

    public function initiate(Request $request): JsonResponse
    {
        $user = $request->user() ?? Auth::user();

        if (! $user) {
            return response()->json(['message' => __('Unauthenticated.')], 401);
        }

        $purpose = strtolower($request->input('purpose', 'service'));
        $supportedPurposes = ['service', 'order', 'wifi_plan', 'package', 'verification'];

        if (! in_array($purpose, $supportedPurposes, true)) {
            throw ValidationException::withMessages([
                'purpose' => __('Unsupported payment purpose.'),
            ]);
        }

        try {
            if ($purpose === 'service') {
                return $this->initiateServicePayment($request, $user->getKey());
            }

            if ($purpose === 'wifi_plan') {
                return $this->initiateWifiPlanPayment($request, $user->getKey());
            }

            if ($purpose === 'package') {
                return $this->initiatePackagePayment($request, $user->getKey());
            }

            if ($purpose === 'verification') {
                return $this->initiateVerificationPayment($request, $user->getKey());
            }

            return $this->initiateOrderPayment($request, $user->getKey());
        } catch (ValidationException $exception) {
            if ($purpose === 'wifi_plan') {
                Log::warning('payment.initiate.wifi_plan.validation_failed', [
                    'user_id' => $user->getKey(),
                    'errors' => $exception->errors(),
                    'request_extract' => [
                        'payment_method' => $request->input('payment_method'),
                        'currency' => $request->input('currency'),
                        'wifi_plan_id' => $request->input('wifi_plan_id'),
                    ],
                ]);
            }

            throw $exception;
        }
    }

    public function confirm(Request $request): JsonResponse
    {
        $user = $request->user() ?? Auth::user();

        if (! $user) {
            return response()->json(['message' => __('Unauthenticated.')], 401);
        }

        $purpose = strtolower($request->input('purpose', 'service'));
        $supportedPurposes = ['service', 'order', 'wifi_plan', 'package', 'verification'];

        if (! in_array($purpose, $supportedPurposes, true)) {
            throw ValidationException::withMessages([
                'purpose' => __('Unsupported payment purpose.'),
            ]);
        }

        if ($purpose === 'service') {
            return $this->confirmServicePayment($request, $user->getKey());
        }

        if ($purpose === 'wifi_plan') {
            return $this->confirmWifiPlanPayment($request, $user->getKey());
        }

        if ($purpose === 'package') {
            return $this->confirmPackagePayment($request, $user->getKey());
        }

        if ($purpose === 'verification') {
            return $this->confirmVerificationPayment($request, $user->getKey());
        }

        return $this->confirmOrderPayment($request, $user->getKey());
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

        $method = $this->normalizePaymentMethodForPurpose($validated['payment_method'], 'service');
        $currency = strtoupper(trim($validated['currency']));

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        $requestUser = $request->user() ?? Auth::user();

        if (! $requestUser) {
            return response()->json(['message' => __('Unauthenticated.')], 401);
        }

        $requestedIdempotencyKey = $this->resolveIdempotencyKey($request, [
            'purpose' => 'service',
            'user' => $userId,
            'service_request' => $serviceRequest->getKey(),
            'method' => $method,
            'currency' => $currency,
            'amount' => $validated['amount'] ?? $serviceRequest->service?->price ?? '',
        ]);

        $idempotencyKey = Str::orderedUuid()->toString();

        $existing = null;

        if (! $existing) {
            $data = [
                'amount' => $validated['amount'] ?? null,
                'currency' => $currency,
                'metadata' => $validated['metadata'] ?? null,
            ];

            $transaction = $this->servicePaymentService->initiate(
                $requestUser,
                $serviceRequest,
                $method,
                $idempotencyKey,
                $data
            );

            $existing = $transaction;
        }

        if ($existing->payment_gateway === 'wallet'
            && strtolower((string) $existing->payment_status) !== 'succeed') {
            $existing = $this->servicePaymentService->confirm(
                $requestUser,
                $existing,
                $existing->idempotency_key ?? $idempotencyKey,
                [
                    'currency' => $currency,
                    'amount' => $validated['amount'] ?? null,
                    'metadata' => $validated['metadata'] ?? null,
                ]
            )->fresh();

            $serviceRequest->refresh();

            $autoConfirmedStatus = $this->inferStatusCode($existing);

            PaymentTrace::trace('payment.confirm.service', [
                'user_id' => $userId,
                'payable_type' => ServiceRequest::class,
                'payable_id' => $serviceRequest->getKey(),
                'payment_transaction_id' => $existing->getKey(),
                'idempotency_key' => $existing->idempotency_key,
                'requested_idempotency_key' => $requestedIdempotencyKey,
                'status_code' => $autoConfirmedStatus,
            ], $request);
        }

        $serviceRequest->refresh()->loadMissing('service');
        $existing = $existing->fresh();

        $service = $serviceRequest->service;
        $quote = null;

        if ($service instanceof Service) {
            try {
                $quote = $this->servicePaymentService->resolvePaymentQuote($service);
            } catch (ValidationException $exception) {
                $fallbackCurrency = strtoupper(
                    (string) ($existing->currency ?? $currency ?? $service->currency ?? config('app.currency', 'YER'))
                );

                $quote = [
                    'amount' => max(0.0, (float) ($existing->amount ?? 0.0)),
                    'currency' => $fallbackCurrency,
                ];
            }

            $existing->forceFill([
                'amount' => $quote['amount'],
                'currency' => $quote['currency'],
            ]);

            $meta = $existing->meta ?? [];

            if (is_array($meta)) {
                data_set($meta, 'payload.amount', $quote['amount']);
                data_set($meta, 'payload.currency', $quote['currency']);
                data_set($meta, 'payload.payment_method', $existing->payment_gateway);
                $existing->meta = $meta;
            }

            if ($existing->isDirty(['amount', 'currency', 'meta'])) {
                $existing->save();
                $existing = $existing->fresh();
            }
        }

        $statusCode = $this->inferStatusCode($existing);

        if ($statusCode === 200 && strtolower((string) $existing->payment_gateway) === 'wallet') {
            ManualPaymentRequest::query()
                ->where('payable_type', ServiceRequest::class)
                ->where('payable_id', $serviceRequest->getKey())
                ->whereIn('status', ManualPaymentRequest::OPEN_STATUSES)
                ->get()
                ->each(static function (ManualPaymentRequest $manualRequest): void {
                    $updates = [
                        'payment_transaction_id' => null,
                        'status' => ManualPaymentRequest::STATUS_REJECTED,
                    ];

                    $manualRequest->forceFill($updates)->saveQuietly();
                });
        }

        $availableGateways = [];

        if ($service instanceof Service && $quote !== null) {
            $normalizedGateway = strtolower((string) $existing->payment_gateway);

            if ($normalizedGateway === 'wallet' && $statusCode === 200) {
                $availableGateways = ['wallet'];
            } else {
                $availableGateways = $this->servicePaymentService->determineAvailableGateways(
                    $requestUser,
                    $serviceRequest,
                    $service,
                    [
                        'amount' => $quote['amount'],
                        'currency' => $quote['currency'],
                    ]
                );
            }
        }

        PaymentTrace::trace('payment.initiate.service', [
            'user_id' => $userId,
            'payable_type' => ServiceRequest::class,
            'payable_id' => $serviceRequest->getKey(),
            'payment_transaction_id' => $existing->getKey(),
            'idempotency_key' => $existing->idempotency_key,
            'requested_idempotency_key' => $requestedIdempotencyKey,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildServiceResponse($existing, $serviceRequest, $statusCode, $availableGateways);
    }

    private function initiateWifiPlanPayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'payment_method' => ['required', 'string', 'max:191'],
            'currency' => ['required', 'string', 'size:3'],
            'wifi_plan_id' => ['required', 'integer', 'exists:wifi_plans,id'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'metadata' => ['nullable', 'array'],
        ]);

        $plan = WifiPlan::query()
            ->with('network')
            ->findOrFail($validated['wifi_plan_id']);

        $method = $this->normalizePaymentMethodForPurpose($validated['payment_method'], 'wifi_plan');
        $currency = strtoupper(trim($validated['currency'] ?? ''));

        if (in_array($method, ['wallet', 'east_yemen_bank'], true)) {
            $currency = $this->walletService->getPrimaryCurrency();
        } elseif ($currency === '') {
            $fallbackCurrency = strtoupper(trim((string) ($plan->currency ?: config('app.currency', 'SAR'))));

            if ($fallbackCurrency !== '') {
                $currency = $fallbackCurrency;
            }
        }

        if ($currency === '') {
            throw ValidationException::withMessages([
                'currency' => __('validation.required', ['attribute' => 'currency']),
            ]);
        }

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        if (! in_array($method, ['wallet', 'east_yemen_bank'], true)
            && is_string($plan->currency)
            && $plan->currency !== '') {
            $planCurrency = strtoupper(trim($plan->currency));
            if ($planCurrency !== '' && $planCurrency !== $currency) {
                throw ValidationException::withMessages([
                    'currency' => __('gateway_currency_unsupported'),
                ]);
            }
        }

        $requestUser = $request->user() ?? Auth::user();

        if (! $requestUser) {
            return response()->json(['message' => __('Unauthenticated.')], 401);
        }

        $requestedIdempotencyKey = $this->resolveIdempotencyKey($request, [
            'purpose' => 'wifi_plan',
            'user' => $userId,
            'wifi_plan' => $plan->getKey(),
            'method' => $method,
            'currency' => $currency,
            'amount' => $validated['amount'] ?? $plan->price ?? '',
        ], false);

        $idempotencyKey = $requestedIdempotencyKey;

        $existing = PaymentTransaction::query()
            ->where('user_id', $userId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if (! $existing) {
            $payload = [
                'amount' => $validated['amount'] ?? null,
                'currency' => $currency,
                'metadata' => $validated['metadata'] ?? null,
            ];

            $transaction = $this->wifiPlanPaymentService->initiate(
                $requestUser,
                $plan,
                $method,
                $idempotencyKey,
                $payload
            );

            $existing = $transaction->fresh();
        }

        if (
            $existing->payment_gateway === 'wallet'
            && strtolower((string) $existing->payment_status) !== 'succeed'
        ) {
            $confirmation = $this->wifiPlanPaymentService->confirm(
                $requestUser,
                $existing,
                $existing->idempotency_key ?? $idempotencyKey,
                [
                    'currency' => $currency,
                    'amount' => $validated['amount'] ?? null,
                    'metadata' => $validated['metadata'] ?? null,
                ]
            );

            $confirmedTransaction = $confirmation['transaction'] ?? $existing;
            $existing = $confirmedTransaction->fresh();
        }

        $statusCode = $this->inferStatusCode($existing);
        $availableGateways = WifiPlanPaymentService::supportedMethods();

        PaymentTrace::trace('payment.initiate.wifi_plan', [
            'user_id' => $userId,
            'payable_type' => WifiPlan::class,
            'payable_id' => $plan->getKey(),
            'payment_transaction_id' => $existing->getKey(),
            'idempotency_key' => $existing->idempotency_key,
            'requested_idempotency_key' => $requestedIdempotencyKey,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildWifiPlanResponse($existing, $plan, $statusCode, $availableGateways);
    }

    private function initiatePackagePayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'payment_method' => ['required', 'string', 'max:191'],
            'currency' => ['nullable', 'string', 'size:3'],
            'package_id' => ['required', 'integer', 'exists:packages,id'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'metadata' => ['nullable', 'array'],
        ]);

        $package = Package::query()->findOrFail($validated['package_id']);
        $requestUser = $request->user() ?? Auth::user();

        if (! $requestUser) {
            return response()->json(['message' => __('Unauthenticated.')], 401);
        }

        $method = $this->normalizePaymentMethodForPurpose($validated['payment_method'], 'package');
        $currency = strtoupper(trim($validated['currency'] ?? (string) config('app.currency', 'SAR')));
        if ($currency === '') {
            $currency = strtoupper((string) config('app.currency', 'SAR'));
        }

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        $idempotencyKey = $this->resolveIdempotencyKey($request, [
            'purpose' => 'package',
            'user' => $userId,
            'package' => $package->getKey(),
            'method' => $method,
            'currency' => $currency,
            'amount' => $validated['amount'] ?? $package->final_price ?? '',
        ]);

        $existing = PaymentTransaction::query()
            ->where('user_id', $userId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if (! $existing) {
            $payload = [
                'amount' => $validated['amount'] ?? null,
                'currency' => $currency,
                'metadata' => $validated['metadata'] ?? null,
            ];

            $transaction = $this->packagePaymentService->initiate(
                $requestUser,
                $package,
                $method,
                $idempotencyKey,
                $payload
            );

            $existing = $transaction;
        }

        if ($existing->payment_gateway === 'wallet'
            && strtolower((string) $existing->payment_status) !== 'succeed') {
            $existing = $this->packagePaymentService->confirm(
                $requestUser,
                $existing,
                $existing->idempotency_key ?? $idempotencyKey,
                [
                    'currency' => $currency,
                    'amount' => $validated['amount'] ?? null,
                    'metadata' => $validated['metadata'] ?? null,
                ]
            )->fresh();
        }

        $package->refresh();

        $statusCode = $this->inferStatusCode($existing);
        $availableGateways = PackagePaymentService::supportedMethods();

        PaymentTrace::trace('payment.initiate.package', [
            'user_id' => $userId,
            'payable_type' => Package::class,
            'payable_id' => $package->getKey(),
            'payment_transaction_id' => $existing->getKey(),
            'idempotency_key' => $existing->idempotency_key,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildPackageResponse($existing, $package, $statusCode, $availableGateways);
    }

    private function initiateVerificationPayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'payment_method' => ['required', 'string', 'max:191'],
            'currency' => ['nullable', 'string', 'size:3'],
            'amount' => ['required', 'numeric', 'min:0'],
            'metadata' => ['nullable', 'array'],
        ]);

        $method = $this->normalizePaymentMethodForPurpose($validated['payment_method'], 'verification');
        $currency = strtoupper(trim($validated['currency'] ?? (string) config('app.currency', 'SAR')));
        if ($currency === '') {
            $currency = strtoupper((string) config('app.currency', 'SAR'));
        }

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        $idempotencyKey = $this->resolveIdempotencyKey($request, [
            'purpose' => 'verification',
            'user' => $userId,
            'method' => $method,
            'currency' => $currency,
            'amount' => $validated['amount'],
        ]);

        $existing = PaymentTransaction::query()
            ->where('user_id', $userId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if (! $existing) {
            $payload = [
                'amount' => $validated['amount'],
                'currency' => $currency,
                'metadata' => $validated['metadata'] ?? null,
                'payment_gateway' => $method,
                'payment_status' => 'pending',
                'user_id' => $userId,
                'idempotency_key' => $idempotencyKey,
                'payable_type' => VerificationRequest::class,
                'payable_id' => VerificationRequest::firstOrCreate(
                    ['user_id' => $userId],
                    ['status' => 'pending']
                )->getKey(),
            ];

            $existing = PaymentTransaction::create($payload);
        }

        $existing->loadMissing(['manualPaymentRequest.manualBank']);

        $response = [
            'transaction' => PaymentTransactionResource::make($existing)->resolve(),
            'manual_payment_request' => $existing->manualPaymentRequest
                ? ManualPaymentRequestResource::make($existing->manualPaymentRequest)->resolve()
                : null,
            'subject' => null,
            'next' => null,
            'payment_transaction_id' => $existing->getKey(),
            'payment_intent_id' => $existing->idempotency_key,
            'available_gateways' => ['manual_bank', 'east_yemen_bank', 'wallet'],
            'allowed_gateways' => ['manual_bank', 'east_yemen_bank', 'wallet'],
        ];

        return response()->json($response, $this->inferStatusCode($existing));
    }

    private function initiateOrderPayment(Request $request, int $userId): JsonResponse
    {


        $incomingCurrency = $request->input('currency');
        $incomingAmount = $request->input('amount');

        if (! is_string($incomingCurrency) || trim($incomingCurrency) === '') {
            $request->merge(['currency' => null]);
        }

        if ($incomingAmount === '' || $incomingAmount === null) {
            $request->merge(['amount' => null]);
        } 
        
        $validated = $request->validate([
            'payment_method' => ['required', 'string', 'max:191'],
            'currency' => ['nullable', 'string', 'size:3'],
            'order_id' => ['required', 'integer', 'exists:orders,id'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'metadata' => ['nullable', 'array'],
        ]);

        $order = Order::query()
            ->where('user_id', $userId)
            ->findOrFail($validated['order_id']);

        $method = $this->normalizePaymentMethodForPurpose($validated['payment_method'], 'order');
        $currency = strtoupper(trim($validated['currency']));

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        $order = $order->refreshOrderNumber();

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

        $idempotencyKey = $validated['idempotency_key']
            ?? $transaction->idempotency_key
            ?? Str::uuid()->toString();

        if (! $transaction->idempotency_key) {
            $transaction->idempotency_key = $idempotencyKey;
            $transaction->save();
            $transaction->refresh();
        }

        $confirmationPayload = $this->buildPaymentConfirmationPayload($request, $transaction, 'service');

        $freshTransaction = $this->servicePaymentService->confirm(
            $request->user(),
            $transaction,
            $idempotencyKey,
            $confirmationPayload
        )->fresh();

        
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

    private function confirmWifiPlanPayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'transaction_id' => ['nullable', 'integer'],
            'idempotency_key' => ['nullable', 'string', 'max:64'],
            'wifi_plan_id' => ['nullable', 'integer', 'exists:wifi_plans,id'],
        ]);

        if (empty($validated['transaction_id']) && empty($validated['idempotency_key'])) {
            throw ValidationException::withMessages([
                'transaction_id' => __('A transaction reference is required.'),
            ]);
        }

        $transaction = $this->resolveTransactionReference(
            $userId,
            $validated['transaction_id'] ?? null,
            $validated['idempotency_key'] ?? null
        );

        $planId = $validated['wifi_plan_id']
            ?? ($transaction->payable_type === WifiPlan::class ? (int) $transaction->payable_id : null);

        if (! $planId) {
            throw ValidationException::withMessages([
                'wifi_plan_id' => __('WiFi plan is required for this payment.'),
            ]);
        }

        $plan = WifiPlan::query()
            ->with('network')
            ->findOrFail($planId);

        if ($transaction->payable_type !== WifiPlan::class || (int) $transaction->payable_id !== (int) $plan->getKey()) {
            throw ValidationException::withMessages([
                'transaction_id' => __('Payment transaction does not belong to the selected WiFi plan.'),
            ]);
        }

        $idempotencyKey = $validated['idempotency_key']
            ?? $transaction->idempotency_key
            ?? Str::orderedUuid()->toString();

        if (! $transaction->idempotency_key) {
            $transaction->idempotency_key = $idempotencyKey;
            $transaction->save();
            $transaction->refresh();
        }

        $payload = $this->buildPaymentConfirmationPayload($request, $transaction, 'wifi_plan');

        $confirmation = $this->wifiPlanPaymentService->confirm(
            $request->user(),
            $transaction,
            $idempotencyKey,
            $payload
        );

        $freshTransaction = ($confirmation['transaction'] ?? $transaction)->fresh();

        $statusCode = $this->inferStatusCode($freshTransaction);

        PaymentTrace::trace('payment.confirm.wifi_plan', [
            'user_id' => $userId,
            'payable_type' => WifiPlan::class,
            'payable_id' => $plan->getKey(),
            'payment_transaction_id' => $freshTransaction->getKey(),
            'idempotency_key' => $freshTransaction->idempotency_key,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildWifiPlanResponse(
            $freshTransaction,
            $plan,
            $statusCode,
            null,
            $confirmation['delivery'] ?? null
        );
    }

    private function confirmPackagePayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'transaction_id' => ['nullable', 'integer'],
            'idempotency_key' => ['nullable', 'string', 'max:64'],
            'package_id' => ['required', 'integer', 'exists:packages,id'],
        ]);

        if (empty($validated['transaction_id']) && empty($validated['idempotency_key'])) {
            throw ValidationException::withMessages([
                'transaction_id' => __('A transaction reference is required.'),
            ]);
        }

        $package = Package::query()->findOrFail($validated['package_id']);

        $transaction = $this->resolveTransactionReference(
            $userId,
            $validated['transaction_id'] ?? null,
            $validated['idempotency_key'] ?? null
        );

        $idempotencyKey = $validated['idempotency_key']
            ?? $transaction->idempotency_key
            ?? Str::uuid()->toString();

        if (! $transaction->idempotency_key) {
            $transaction->idempotency_key = $idempotencyKey;
            $transaction->save();
            $transaction->refresh();
        }

        $confirmationPayload = $this->buildPaymentConfirmationPayload($request, $transaction, 'package');

        $freshTransaction = $this->packagePaymentService->confirm(
            $request->user(),
            $transaction,
            $idempotencyKey,
            $confirmationPayload
        )->fresh();

        $package->refresh();

        $statusCode = $this->inferStatusCode($freshTransaction);

        PaymentTrace::trace('payment.confirm.package', [
            'user_id' => $userId,
            'payable_type' => Package::class,
            'payable_id' => $package->getKey(),
            'payment_transaction_id' => $freshTransaction->getKey(),
            'idempotency_key' => $freshTransaction->idempotency_key,
            'status_code' => $statusCode,
        ], $request);

        return $this->buildPackageResponse($freshTransaction, $package, $statusCode);
    }



    /**
     * @return array<string, mixed>
     */
    private function buildPaymentConfirmationPayload(
        Request $request,
        PaymentTransaction $transaction,
        string $purpose
    ): array
    {
        $input = $request->all();
        $payload = [];

        $arrayKeys = [
            'metadata',
            'attachments',
            'transfer',
            'payment',
        ];

        foreach ($arrayKeys as $key) {
            if (array_key_exists($key, $input) && is_array($input[$key])) {
                $payload[$key] = $input[$key];
            }
        }

        $scalarKeys = [
            'amount',
            'currency',
            'reference',
            'note',
            'receipt_path',
            'bank_name',
            'manual_bank_id',
            'bank_id',
            'bank_account_id',
            'manual_payment_request_id',
        ];

        foreach ($scalarKeys as $key) {
            if (array_key_exists($key, $input)) {
                $payload[$key] = $input[$key];
            }
        }

        if (! array_key_exists('manual_bank_id', $payload) && isset($payload['bank_id'])) {
            $payload['manual_bank_id'] = $payload['bank_id'];
        }

        if ($transaction->manual_payment_request_id && ! array_key_exists('manual_payment_request_id', $payload)) {
            $payload['manual_payment_request_id'] = $transaction->manual_payment_request_id;
        }

        if (! array_key_exists('manual_bank_id', $payload)) {
            $manualBankFromMeta = data_get($transaction->meta, 'payload.manual_bank_id')
                ?? data_get($transaction->meta, 'manual_payment_request.manual_bank_id');

            if ($manualBankFromMeta !== null && $manualBankFromMeta !== '') {
                $payload['manual_bank_id'] = $manualBankFromMeta;
            }
        }

        if (! array_key_exists('currency', $payload)) {
            $currencyFromMeta = data_get($transaction->meta, 'payload.currency');

            if (is_string($currencyFromMeta) && $currencyFromMeta !== '') {
                $payload['currency'] = $currencyFromMeta;
            } elseif (is_string($transaction->currency) && $transaction->currency !== '') {
                $payload['currency'] = $transaction->currency;
            }
        }

        if (! array_key_exists('amount', $payload) && $transaction->amount !== null) {
            $payload['amount'] = $transaction->amount;
        }

        $methodHint = $this->resolvePaymentMethodHint($request, $transaction, $payload, $purpose);

        if ($methodHint === null) {
            throw ValidationException::withMessages([
                'payment_method' => __('Unable to determine payment method for confirmation.'),
            ]);
        }

        $payload['payment_method'] = $methodHint;

        if ($methodHint === 'wallet') {
            $payload['currency'] = $this->walletService->getPrimaryCurrency();
        }

        unset($payload['bank_id']);

        return $payload;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function resolvePaymentMethodHint(
        Request $request,
        PaymentTransaction $transaction,
        array $payload,
        string $purpose
    ): ?string {
        $candidates = [];

        foreach (['payment_method', 'payment_gateway', 'gateway', 'method', 'channel', 'paymentMethod'] as $key) {
            $value = $request->input($key);

            if (is_string($value)) {
                $candidates[] = $value;
            }
        }

        if (isset($payload['payment_method']) && is_string($payload['payment_method'])) {
            $candidates[] = $payload['payment_method'];
        }

        $meta = is_array($transaction->meta) ? $transaction->meta : [];
        $metaCandidates = [
            data_get($meta, 'payload.payment_method'),
            data_get($meta, 'payload.payment_gateway'),
            data_get($meta, 'payload.gateway'),
            data_get($meta, 'payment_method'),
            data_get($meta, 'gateway'),
            data_get($meta, 'manual.payment_method'),
            data_get($meta, 'manual.payment_gateway'),
            data_get($meta, 'manual.gateway'),
        ];

        foreach ($metaCandidates as $candidate) {
            if (is_string($candidate)) {
                $candidates[] = $candidate;
            }
        }

        if (is_string($transaction->payment_gateway)) {
            $candidates[] = $transaction->payment_gateway;
        }

        if ($transaction->manual_payment_request_id) {
            $candidates[] = 'manual_bank';
        }

        foreach ($candidates as $candidate) {
            $normalized = $this->normalizeServicePaymentMethodHint($candidate);

            if ($normalized === null) {
                continue;
            }

            try {
                return $this->normalizePaymentMethodForPurpose($normalized, $purpose);
            } catch (ValidationException $exception) {
                // Ignore invalid hints and continue searching other candidates.
            }
        }

        return null;
    }

    private function normalizeServicePaymentMethodHint(?string $candidate): ?string
    {
        if (! is_string($candidate)) {
            return null;
        }

        $trimmed = trim($candidate);

        return $trimmed === '' ? null : $trimmed;
    }

    private function confirmVerificationPayment(Request $request, int $userId): JsonResponse
    {
        $validated = $request->validate([
            'payment_method' => ['required', 'string', 'max:191'],
            'currency' => ['nullable', 'string', 'size:3'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'payment_transaction_id' => ['nullable', 'integer', 'exists:payment_transactions,id'],
        ]);

        $method = $this->normalizePaymentMethodForPurpose($validated['payment_method'], 'verification');
        $currency = strtoupper(trim($validated['currency'] ?? (string) config('app.currency', 'SAR')));
        if ($currency === '') {
            $currency = strtoupper((string) config('app.currency', 'SAR'));
        }

        if (! PaymentGatewayCurrencyPolicy::supports($method, $currency)) {
            throw ValidationException::withMessages([
                'currency' => __('gateway_currency_unsupported'),
            ]);
        }

        $transaction = PaymentTransaction::query()
            ->where('user_id', $userId)
            ->when($validated['payment_transaction_id'] ?? null, static function ($query, $id) {
                $query->whereKey($id);
            })
            ->orderByDesc('id')
            ->firstOrFail();

        $verificationRequest = VerificationRequest::firstOrCreate(
            ['user_id' => $userId],
            ['status' => 'pending']
        );

        if ($transaction->payable_type !== VerificationRequest::class || $transaction->payable_id !== $verificationRequest->getKey()) {
            $transaction->payable_type = VerificationRequest::class;
            $transaction->payable_id = $verificationRequest->getKey();
        }

        $statusCode = $this->inferStatusCode($transaction);

        $transaction->payment_gateway = $method;
        $transaction->currency = $currency;
        $transaction->amount = $validated['amount'] ?? $transaction->amount;
        $transaction->payment_status = 'succeed';
        $transaction->save();

        $verificationPayment = VerificationPayment::updateOrCreate(
            [
                'verification_request_id' => $verificationRequest->getKey(),
            ],
            [
                'user_id' => $userId,
                'amount' => $transaction->amount,
                'currency' => $transaction->currency,
                'status' => 'paid',
                'meta' => [
                    'gateway' => $transaction->payment_gateway,
                    'payment_transaction_id' => $transaction->getKey(),
                ],
            ]
        );

        return response()->json([
            'transaction' => PaymentTransactionResource::make($transaction->loadMissing('manualPaymentRequest.manualBank'))->resolve(),
            'manual_payment_request' => $transaction->manualPaymentRequest
                ? ManualPaymentRequestResource::make($transaction->manualPaymentRequest)->resolve()
                : null,
            'payment_transaction_id' => $transaction->getKey(),
            'payment_intent_id' => $transaction->idempotency_key,
            'verification_payment_id' => $verificationPayment->getKey(),
            'available_gateways' => ['manual_bank', 'east_yemen_bank', 'wallet'],
            'allowed_gateways' => ['manual_bank', 'east_yemen_bank', 'wallet'],
        ], $statusCode);
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

    private function buildServiceResponse(
        PaymentTransaction $transaction,
        ServiceRequest $serviceRequest,
        int $statusCode,
        ?array $availableGateways = null
    ): JsonResponse
    {
        $transaction->loadMissing([
            'manualPaymentRequest.manualBank',
            'manualPaymentRequest.paymentTransaction.order',
            'manualPaymentRequest.paymentTransaction.walletTransaction',
        ]);

        if ($transaction->manual_payment_request_id === null
            || strtolower((string) $transaction->payment_gateway) === 'wallet') {
            $transaction->setRelation('manualPaymentRequest', null);
        }

        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        $response = [
            'transaction' => PaymentTransactionResource::make($transaction)->resolve(),
            'manual_payment_request' => $manualRequest
                ? ManualPaymentRequestResource::make($manualRequest)->resolve()
                : null,
            'subject' => SubjectResource::make($serviceRequest)->resolve(),
            'next' => $this->buildNextNavigation($transaction, 'service', $serviceRequest->getKey()),
            'payment_transaction_id' => $transaction->getKey(),
            'payment_intent_id' => $transaction->idempotency_key,
        ];

        if (is_array($availableGateways)) {
            $normalizedGateways = array_values(array_unique(array_filter(
                $availableGateways,
                static fn ($value) => is_string($value) && $value !== ''
            )));

            $response['available_gateways'] = $normalizedGateways;
            $response['allowed_gateways'] = $normalizedGateways;
        }

        return response()->json($response, $statusCode);
    }

    private function buildWifiPlanResponse(
        PaymentTransaction $transaction,
        WifiPlan $plan,
        int $statusCode,
        ?array $availableGateways = null,
        ?array $delivery = null
    ): JsonResponse {
        $transaction->loadMissing([
            'manualPaymentRequest.manualBank',
            'manualPaymentRequest.paymentTransaction.order',
            'manualPaymentRequest.paymentTransaction.walletTransaction',
        ]);

        if ($transaction->manual_payment_request_id === null
            || strtolower((string) $transaction->payment_gateway) === 'wallet') {
            $transaction->setRelation('manualPaymentRequest', null);
        }

        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        $response = [
            'transaction' => PaymentTransactionResource::make($transaction)->resolve(),
            'manual_payment_request' => $manualRequest
                ? ManualPaymentRequestResource::make($manualRequest)->resolve()
                : null,
            'subject' => SubjectResource::make([
                'type' => 'wifi_plan',
                'id' => $plan->getKey(),
                'number' => $plan->name,
                'status' => $plan->status,
            ])->resolve(),
            // لا نعيد توجيه المستخدم بعد شراء الواي فاي
            'next' => null,
            'payment_transaction_id' => $transaction->getKey(),
            'payment_intent_id' => $transaction->idempotency_key,
        ];

        if (is_array($availableGateways)) {
            $normalizedGateways = array_values(array_unique(array_filter(
                $availableGateways,
                static fn ($value) => is_string($value) && $value !== ''
            )));

            $response['available_gateways'] = $normalizedGateways;
            $response['allowed_gateways'] = $normalizedGateways;
        }

        if (is_array($delivery) && ! empty($delivery)) {
            $response['delivery'] = $delivery;
        }

        return response()->json($response, $statusCode);
    }

    private function buildPackageResponse(
        PaymentTransaction $transaction,
        Package $package,
        int $statusCode,
        ?array $availableGateways = null
    ): JsonResponse {
        $transaction->loadMissing([
            'manualPaymentRequest.manualBank',
            'manualPaymentRequest.paymentTransaction.order',
            'manualPaymentRequest.paymentTransaction.walletTransaction',
        ]);

        if ($transaction->manual_payment_request_id === null
            || strtolower((string) $transaction->payment_gateway) === 'wallet') {
            $transaction->setRelation('manualPaymentRequest', null);
        }

        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        $response = [
            'transaction' => PaymentTransactionResource::make($transaction)->resolve(),
            'manual_payment_request' => $manualRequest
                ? ManualPaymentRequestResource::make($manualRequest)->resolve()
                : null,
            'subject' => SubjectResource::make([
                'type' => 'package',
                'id' => $package->getKey(),
                'number' => $package->name,
                'status' => $package->status ?? null,
            ])->resolve(),
            'next' => $this->buildNextNavigation($transaction, 'package', $package->getKey()),
            'payment_transaction_id' => $transaction->getKey(),
            'payment_intent_id' => $transaction->idempotency_key,
        ];

        if (is_array($availableGateways)) {
            $normalizedGateways = array_values(array_unique(array_filter(
                $availableGateways,
                static fn ($value) => is_string($value) && $value !== ''
            )));

            $response['available_gateways'] = $normalizedGateways;
            $response['allowed_gateways'] = $normalizedGateways;
        }

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
            'next' => $this->buildNextNavigation($transaction, 'order', $order->getKey()),
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

    private function buildNextNavigation(PaymentTransaction $transaction, string $context, int $subjectId): array
    {
        $canonical = ManualPaymentRequest::canonicalGateway($transaction->payment_gateway);

        if ($canonical === null) {
            $gatewayCode = $transaction->gateway_code;
            if (is_string($gatewayCode) && $gatewayCode !== '') {
                $canonical = ManualPaymentRequest::canonicalGateway($gatewayCode) ?? $gatewayCode;
            }
        }

        if ($canonical === null && $transaction->manual_payment_request_id !== null) {
            $canonical = 'manual_bank';
        }

        $canonical = is_string($canonical) ? strtolower(trim($canonical)) : null;

        if ($canonical === 'manual_banks') {
            $canonical = 'manual_bank';
        }

        if (in_array($canonical, ['manual_bank', 'east_yemen_bank'], true)) {
            return [
                'resource' => 'payment_transactions',
                'route' => 'transactions.history',
                'show_url' => url('/api/payment-transactions'),
                'transaction_id' => (string) $transaction->getKey(),
                'dismiss' => true,
            ];
        }

        if ($canonical === 'wallet') {
            return [
                'resource' => 'wallet_transactions',
                'route' => 'wallet.transactions',
                'show_url' => url('/api/wallet/transactions'),
                'transaction_id' => (string) $transaction->getKey(),
                'dismiss' => true,
            ];
        }

        if ($context === 'order') {
            return [
                'resource' => 'orders',
                'route' => 'transactions.history',
                'show_url' => url(sprintf('/api/orders/%d', $subjectId)),
                'transaction_id' => (string) $transaction->getKey(),
                'dismiss' => true,
            ];
        }

        if ($context === 'wifi_plan') {
            return [
                'resource' => 'wifi_plans',
                'route' => 'wifi.plans.show',
                'show_url' => url(sprintf('/api/wifi/plans/%d', $subjectId)),
                'transaction_id' => (string) $transaction->getKey(),
                'dismiss' => true,
            ];
        }

        if ($context === 'package') {
            return [
                'resource' => 'packages',
                'route' => 'packages.show',
                'show_url' => null,
                'transaction_id' => (string) $transaction->getKey(),
                'dismiss' => true,
            ];
        }

        return [
            'resource' => 'service_requests',
            'route' => 'service_requests.show',
            'show_url' => url(sprintf('/api/service-requests/%d', $subjectId)),
            'transaction_id' => (string) $transaction->getKey(),
            'dismiss' => true,
        ];
    }

    private function normalizePaymentMethodForPurpose(string $method, string $purpose): string
    {
        $token = OrderCheckoutService::normalizePaymentMethod($method);

        if ($token === null || trim($token) === '') {
            $token = ManualPaymentRequest::canonicalGateway($method);
        } else {
            $token = ManualPaymentRequest::canonicalGateway($token) ?? $token;
        }

        if ($token === null || trim($token) === '') {
            throw ValidationException::withMessages([
                'payment_method' => __('Unsupported payment method.'),
            ]);
        }

        $token = strtolower(trim($token));

        $token = match ($token) {
            'manual_banks' => 'manual_bank',
            'bank_alsharq' => 'east_yemen_bank',
            default => $token,
        };

        $allowed = match ($purpose) {
            'service' => ServicePaymentService::SUPPORTED_METHODS,
            'wifi_plan' => WifiPlanPaymentService::supportedMethods(),
            'package' => PackagePaymentService::supportedMethods(),
            default => OrderPaymentService::supportedMethods(),
        };

        if (! in_array($token, $allowed, true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('Unsupported payment method.'),
            ]);
        }

        return $token;
    }

    private function resolveIdempotencyKey(Request $request, array $components, bool $allowHeader = true): string
    {
        if ($allowHeader) {
            $headerKey = $request->header('Idempotency-Key');

            if (is_string($headerKey) && trim($headerKey) !== '') {
                return Str::limit(trim($headerKey), 64, '');
            }
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
        $department = 'services';
        $nextIdentifier = (int) (ServiceRequest::query()->max('id') ?? 0) + 1;

        $candidate = trim((string) $this->legalNumberingService->formatOrderNumber($nextIdentifier, $department));

        if ($candidate === '') {
            $candidate = (string) $nextIdentifier;
        }

        if ($this->serviceRequestNumberExists($candidate)) {
            return $this->fallbackServiceRequestNumber();
        }

        return $candidate;
    }

    private function serviceRequestNumberExists(string $number): bool
    {
        return ServiceRequest::query()
            ->where('request_number', $number)
            ->exists();
    }

    private function fallbackServiceRequestNumber(): string
    {
        $prefix = 'SR-' . now()->format('Ymd');

        do {
            $candidate = $prefix . '-' . Str::padLeft((string) random_int(0, 999999), 6, '0');
        } while ($this->serviceRequestNumberExists($candidate));

        return $candidate;
    }
}
