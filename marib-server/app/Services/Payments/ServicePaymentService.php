<?php

namespace App\Services\Payments;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Services\OrderCheckoutService;
use App\Services\PaymentFulfillmentService;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;
use App\Services\Payments\Concerns\HandlesManualBankConfirmation;
use App\Services\WalletService;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use Illuminate\Validation\ValidationException;
use RuntimeException;

class ServicePaymentService
{
    use HandlesManualBankConfirmation;

    /**
     * فقط المحفظة والتحويل البنكي اليدوي مسموحان لخدمات الدفع.
     *
     * @var array<int, string>
     */
    public const SUPPORTED_METHODS = [
        'wallet',
        'manual_bank',
        'east_yemen_bank',
    ];

    /**
     * بوابات الدفع القديمة التي يجب قبولها كعرف.
     *
     * @var array<string, array<int, string>>
     */
    private const LEGACY_METHOD_ALIASES = [
        'manual_bank' => ['manual', 'manual_banks', 'bank_transfer'],
        'wallet' => ['wallet_gateway', 'wallet_payment'],
    ];

    public function __construct(
        private readonly DatabaseManager $db,
        private readonly WalletService $walletService,
        private readonly PaymentFulfillmentService $fulfillmentService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly CreateOrLinkManualPaymentRequest $manualPaymentLinker,
    ) {
    }

    /**
     * @param array<string, mixed> $data
     */
    public function initiate(User $user, ServiceRequest $serviceRequest, string $method, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        $normalizedMethod = $this->normalizePaymentMethod($method);

        $serviceRequest->loadMissing('service');
        $service = $serviceRequest->service;

        if (! $service instanceof Service) {
            throw ValidationException::withMessages([
                'service_request_id' => __('Service request is missing its linked service.'),
            ]);
        }

        return $this->db->transaction(function () use ($user, $serviceRequest, $service, $normalizedMethod, $idempotencyKey, $data) {
            $transaction = $this->findOrCreateTransaction($user, $serviceRequest, $service, $normalizedMethod, $idempotencyKey, $data);

            if ($normalizedMethod === 'manual_bank') {
                $this->attachManualTransferHint($user, $serviceRequest, $service, $transaction, $normalizedMethod, $idempotencyKey, $data);
            }

            return $transaction->fresh();
        });
    }

    /**
     * @param array<string, mixed> $data
     */
    public function confirm(User $user, PaymentTransaction $transaction, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        if ($transaction->payment_status === 'succeed') {
            return $transaction;
        }

        if ((int) $transaction->user_id !== $user->getKey()) {
            throw ValidationException::withMessages([
                'transaction' => __('المعاملة المحددة لا تخص المستخدم.'),
            ]);
        }

        $serviceRequest = $transaction->payable instanceof ServiceRequest
            ? $transaction->payable
            : null;

        if (! $serviceRequest && $transaction->payable_type === ServiceRequest::class) {
            $serviceRequest = ServiceRequest::find($transaction->payable_id);
        }

        if (! $serviceRequest) {
            $metaRequestId = data_get($transaction->meta, 'service.request_id');
            if ($metaRequestId) {
                $serviceRequest = ServiceRequest::find($metaRequestId);
            }
        }

        if (! $serviceRequest) {
            throw ValidationException::withMessages([
                'transaction' => __('تعذر العثور على الطلب المرتبط بالمعاملة.'),
            ]);
        }

        if ((int) $serviceRequest->user_id !== $user->getKey()) {
            throw ValidationException::withMessages([
                'transaction' => __('المعاملة المحددة لا تخص المستخدم.'),
            ]);
        }

        $serviceRequest->loadMissing('service');
        $service = $serviceRequest->service;

        if (! $service instanceof Service) {
            throw ValidationException::withMessages([
                'service_request_id' => __('Service request is missing its linked service.'),
            ]);
        }

        $rawMethod = Arr::get($data, 'payment_method');

        if (! is_string($rawMethod) || $rawMethod === '') {
            $rawMethod = $transaction->payment_gateway;
        }

        $method = $this->normalizePaymentMethod($rawMethod);
        $data['payment_method'] = $method;

        if ($transaction->payment_gateway !== $method) {
            $transaction->payment_gateway = $method;
            $transaction->save();
        }

        $manualContext = null;

        if ($method === 'manual_bank') {
            $manualContext = $this->prepareManualBankConfirmationPayload(
                $user,
                $transaction,
                ServiceRequest::class,
                $serviceRequest->getKey(),
                $method,
                $idempotencyKey,
                $data
            );

            if ($manualContext !== null) {
                $data = $manualContext['data'];
            }
        }

        $meta = $this->mergeServiceMeta($transaction->meta ?? [], $service, $data);
        $meta = $this->mergePaymentPayloadMeta($meta, $transaction, $data);

        if ($manualContext !== null) {
            $meta = $this->mergeManualConfirmationMeta(
                $meta,
                $data,
                $manualContext['manual_payment_request'],
                $transaction,
                $idempotencyKey
            );
            $transaction->manual_payment_request_id = $manualContext['manual_payment_request']->getKey();
        }

        $options = [
            'payment_gateway' => $method,
            'meta' => $meta,
            'payment_reference' => $data['reference'] ?? null,
        ];

        if ($method === 'wallet') {
            $walletTransaction = $this->debitWallet($user, $transaction, $idempotencyKey, $service, $data);
            $options['wallet_transaction'] = $walletTransaction;
        }

        if ($transaction->manual_payment_request_id) {
            $options['manual_payment_request_id'] = $transaction->manual_payment_request_id;
        }

        $result = $this->fulfillmentService->fulfill(
            $transaction,
            ServiceRequest::class,
            $serviceRequest->getKey(),
            $user->getKey(),
            $options
        );

        if ($result['error'] ?? true) {
            throw ValidationException::withMessages([
                'payment' => $result['message'] ?? __('تعذر إكمال عملية الدفع حالياً.'),
            ]);
        }

        if (! empty($options['payment_reference'])) {
            $transaction->payment_id = $options['payment_reference'];
        }

        $transaction->payable_type = ServiceRequest::class;
        $transaction->payable_id = $serviceRequest->getKey();
        $transaction->payment_status = 'succeed';
        $transaction->meta = $options['meta'];
        $transaction->save();

        if ($serviceRequest->payment_transaction_id !== $transaction->getKey() || $serviceRequest->payment_status !== 'paid') {
            $serviceRequest->payment_transaction_id = $transaction->getKey();
            $serviceRequest->payment_status = 'paid';
            $serviceRequest->save();
        }

        return $transaction->fresh();
    }

    /**
     * تسجيل دفع يدوي لخدمة مدفوعة.
     *
     * @param array<string, mixed> $data
     */
    public function createManual(User $user, ServiceRequest $serviceRequest, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        return $this->db->transaction(function () use ($user, $serviceRequest, $idempotencyKey, $data) {
            $method = $this->normalizePaymentMethod('manual_bank');
            $data['payment_method'] = $method;

            $serviceRequest->loadMissing('service');
            $service = $serviceRequest->service;

            if (! $service instanceof Service) {
                throw ValidationException::withMessages([
                    'service_request_id' => __('Service request is missing its linked service.'),
                ]);
            }

            $transaction = $this->findOrCreateTransaction($user, $serviceRequest, $service, $method, $idempotencyKey, $data);

            $manualRequest = $this->manualPaymentLinker->handle(
                $user,
                ServiceRequest::class,
                $serviceRequest->getKey(),
                $transaction,
                $data
            );

            $transaction->manual_payment_request_id = $manualRequest->getKey();

            $meta = $this->mergeServiceMeta($transaction->meta ?? [], $service, $data);
            $meta = $this->mergeManualPayloadMeta($meta, $data, $transaction);

            $transaction->payable_type = ServiceRequest::class;
            $transaction->payable_id = $serviceRequest->getKey();
            $transaction->payment_status = Arr::get($data, 'auto_confirm') ? 'succeed' : 'pending';
            $transaction->payment_id = $data['reference'] ?? $transaction->payment_id;
            $transaction->meta = $meta;
            $transaction->save();

            if ($serviceRequest->payment_transaction_id !== $transaction->getKey() || $serviceRequest->payment_status !== 'paid') {
                $serviceRequest->payment_transaction_id = $transaction->getKey();
                if ($serviceRequest->payment_status !== 'paid') {
                    $serviceRequest->payment_status = $transaction->payment_status === 'succeed' ? 'paid' : 'pending';
                }
                $serviceRequest->save();
            }

            return $transaction->fresh()->loadMissing('manualPaymentRequest.manualBank');
        });
    }

    /**
     * @param array<string, mixed> $data
     */
    private function findOrCreateTransaction(
        User $user,
        ServiceRequest $serviceRequest,
        Service $service,
        string $method,
        string $idempotencyKey,
        array $data = []
    ): PaymentTransaction {
        $existing = PaymentTransaction::query()
            ->where('user_id', $user->getKey())
            ->whereIn('payment_gateway', $this->expandLegacyMethods($method))
            ->where('idempotency_key', $idempotencyKey)
            ->lockForUpdate()
            ->first();

        if ($existing) {
            if ((int) $existing->payable_id !== $serviceRequest->getKey()) {
                throw ValidationException::withMessages([
                    'idempotency' => __('المعاملة المرتبطة بالمفتاح المرسل تتعلق بطلب مختلف.'),
                ]);
            }

            if ($existing->payment_gateway !== $method) {
                $existing->payment_gateway = $method;
                $existing->save();
            }

            if ($existing->payable_type !== ServiceRequest::class) {
                $existing->payable_type = ServiceRequest::class;
                $existing->save();
            }

            return $existing;
        }

        $amount = $this->resolveServiceAmount($service, $data);

        $currency = $this->resolveServiceCurrency($service, $data);

        if ($method === 'wallet') {
            $currency = $this->assertWalletCurrencyCompatibility($user, $currency, true);
        }

        $meta = $this->buildInitialMeta($service, $amount, $currency, $method, $data);

        return PaymentTransaction::create([
            'user_id' => $user->getKey(),
            'amount' => $amount,
            'currency' => $currency,
            'payment_gateway' => $method,
            'payment_status' => 'pending',
            'payable_type' => ServiceRequest::class,
            'payable_id' => $serviceRequest->getKey(),
            'idempotency_key' => $idempotencyKey,
            'meta' => $meta,
        ]);
    }

    /**
     * @param array<string, mixed> $data
     */
    private function attachManualTransferHint(
        User $user,
        ServiceRequest $serviceRequest,
        Service $service,
        PaymentTransaction $transaction,
        string $method,
        string $idempotencyKey,
        array $data = []
    ): void {
        $manualRequest = $transaction->manualPaymentRequest instanceof ManualPaymentRequest
            ? $transaction->manualPaymentRequest
            : null;

        if (! $manualRequest instanceof ManualPaymentRequest) {
            $manualRequest = $this->manualPaymentRequestService->findOpenManualPaymentRequestForPayable(
                ServiceRequest::class,
                $serviceRequest->getKey()
            );
        }

        if (! $manualRequest instanceof ManualPaymentRequest) {
            $manualRequest = $this->manualPaymentRequestService->createFromTransaction(
                $user,
                ServiceRequest::class,
                $serviceRequest->getKey(),
                $transaction,
                array_merge($data, [
                    'payment_gateway' => $method,
                    'idempotency_key' => $transaction->idempotency_key ?? $idempotencyKey,
                ])
            );
        } else {
            if ($manualRequest->payment_transaction_id !== $transaction->getKey()) {
                $manualRequest->payment_transaction_id = $transaction->getKey();
                $manualRequest->save();
            }
        }

        if ((int) $transaction->manual_payment_request_id !== $manualRequest->getKey()) {
            $transaction->manual_payment_request_id = $manualRequest->getKey();
            $transaction->save();
        }
    }

    /**
     * @param array<string, mixed>|null $meta
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function mergeServiceMeta($meta, Service $service, array $data = []): array
    {
        if (! is_array($meta)) {
            $meta = [];
        }

        $serviceMeta = array_filter([
            'id' => $service->getKey(),
            'title' => $service->title,
            'slug' => $service->slug,
            'price' => $service->price !== null ? (float) $service->price : null,
            'currency' => $service->currency,
            'service_uid' => $service->service_uid,
        ], static fn ($value) => $value !== null && $value !== '');

        $meta['service'] = array_replace_recursive($serviceMeta, Arr::get($meta, 'service', []));

        if (isset($data['payment_transaction_id'])) {
            $meta['service']['payment_transaction_id'] = $data['payment_transaction_id'];
        }

        if (isset($data['reference']) && is_string($data['reference']) && trim($data['reference']) !== '') {
            $meta['service']['reference'] = trim((string) $data['reference']);
        }

        return $meta;
    }

    /**
     * @param array<string, mixed> $meta
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function mergePaymentPayloadMeta(array $meta, PaymentTransaction $transaction, array $data = []): array
    {
        $payload = Arr::get($meta, 'payload');

        if (! is_array($payload)) {
            $payload = [];
        }

        $payload = array_replace_recursive($payload, array_filter([
            'payment_method' => $data['payment_method'] ?? null,
            'reference' => $data['reference'] ?? null,
            'currency' => $data['currency'] ?? $transaction->currency,
        ], static fn ($value) => $value !== null && $value !== ''));

        if (isset($data['metadata']) && is_array($data['metadata'])) {
            $payload['metadata'] = array_replace_recursive($payload['metadata'] ?? [], $data['metadata']);
        }

        $meta['payload'] = $payload;

        return $meta;
    }

    /**
     * @param array<string, mixed> $meta
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function mergeManualPayloadMeta(array $meta, array $data, PaymentTransaction $transaction): array
    {
        $meta = $this->mergePaymentPayloadMeta($meta, $transaction, $data);

        $manualMeta = Arr::get($meta, 'manual');

        if (! is_array($manualMeta)) {
            $manualMeta = [];
        }

        $manualMetaUpdates = array_filter([
            'note' => Arr::get($data, 'note'),
            'reference' => Arr::get($data, 'reference'),
            'attachments' => Arr::get($data, 'attachments'),
            'receipt_path' => Arr::get($data, 'receipt_path'),
            'receipt_url' => Arr::get($data, 'receipt_url'),
        ], static function ($value) {
            if (is_array($value)) {
                return $value !== [];
            }

            return $value !== null && $value !== '';
        });

        if (! empty($manualMetaUpdates)) {
            $manualMeta = array_replace_recursive($manualMeta, $manualMetaUpdates);
            $meta['manual'] = $manualMeta;
        }

        return $meta;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function debitWallet(User $user, PaymentTransaction $transaction, string $idempotencyKey, Service $service, array $data = [])
    {
        try {
            $currency = strtoupper((string) ($transaction->currency ?? $this->resolveServiceCurrency($service, $data)));

            return $this->walletService->debit($user, $idempotencyKey, (float) $transaction->amount, [
                'payment_transaction' => $transaction,
                'meta' => array_merge($transaction->meta ?? [], [
                    'service_id' => $service->getKey(),
                ]),
                'currency' => $currency,
            ]);
        } catch (RuntimeException $exception) {
            throw ValidationException::withMessages([
                'payment' => $exception->getMessage(),
            ]);
        }
    }

    /**
     * @param array<string, mixed> $data
     */
    private function buildInitialMeta(Service $service, float $amount, string $currency, string $method, array $data = []): array
    {
        $meta = [
            'service' => [
                'id' => $service->getKey(),
                'title' => $service->title,
                'price' => $service->price !== null ? (float) $service->price : null,
                'currency' => $service->currency,
                'service_uid' => $service->service_uid,
            ],
            'payload' => [
                'payment_method' => $method,
                'currency' => $currency,
                'amount' => $amount,
            ],
        ];

        if (isset($data['metadata']) && is_array($data['metadata'])) {
            $meta['payload']['metadata'] = $data['metadata'];
        }

        if ($service->price_note) {
            $meta['service']['price_note'] = $service->price_note;
        }

        return $meta;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function resolveServiceAmount(Service $service, array $data = []): float
    {
        $override = isset($data['amount']) ? (float) $data['amount'] : null;

        $amount = $override !== null && $override > 0
            ? $override
            : ($service->price !== null ? (float) $service->price : 0.0);

        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => __('لا يوجد مبلغ مستحق لهذه الخدمة.'),
            ]);
        }

        return round($amount, 2);
    }

    /**
     * @param array<string, mixed> $data
     */
    private function resolveServiceCurrency(Service $service, array $data = []): string
    {
        $currency = isset($data['currency']) && is_string($data['currency'])
            ? strtoupper(trim($data['currency']))
            : null;

        if ($currency === null || $currency === '') {
            $currency = $service->currency ?: config('app.currency', 'YER');
        }

        return strtoupper($currency);
    }

    private function normalizePaymentMethod(?string $method): string
    {
        $normalizedMethod = OrderCheckoutService::normalizePaymentMethod($method);

        if (! is_string($normalizedMethod) || $normalizedMethod === '') {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة لهذه الخدمة.'),
            ]);
        }

        $normalizedMethod = mb_strtolower($normalizedMethod);

        if (! in_array($normalizedMethod, self::SUPPORTED_METHODS, true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة لهذه الخدمة.'),
            ]);
        }

        return $normalizedMethod;
    }

    /**
     * @return array<int, string>
     */
    private function expandLegacyMethods(string $method): array
    {
        return array_values(array_unique(array_merge([
            $method,
        ], self::LEGACY_METHOD_ALIASES[$method] ?? [])));
    }

    private function assertWalletCurrencyCompatibility(User $user, string $currency, bool $allowCreation): string
    {
        $currency = strtoupper($currency);

        $hasMatchingAccount = $this->walletService->hasAccount($user, $currency);
        $hasAnyAccount = $this->walletService->hasAccount($user);

        if (! $hasMatchingAccount) {
            if ($hasAnyAccount || ! $allowCreation) {
                throw ValidationException::withMessages([
                    'currency' => __('لا تملك المحفظة حساباً بهذه العملة.'),
                ]);
            }
        }

        return $currency;
    }

}
