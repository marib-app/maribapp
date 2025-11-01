<?php

namespace App\Services\Payments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\OrderCheckoutService;
use App\Services\PaymentFulfillmentService;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;
use App\Services\Payments\Concerns\HandlesManualBankConfirmation;
use App\Services\LegalNumberingService;
use App\Services\WalletService;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use App\Support\InputSanitizer;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Illuminate\Support\Facades\Log;

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
        'manual_bank' => [
            'manual',
            'manual_banks',
            'manual-bank',
            'manual bank',
            'manualbank',
            'bank_transfer',
            'banktransfer',
            'bank',
            'offline',
            'internal',
        ],
        'east_yemen_bank' => [
            'east',
            'alsharq',
            'al-sharq',
            'bank_alsharq',
        ],
        'wallet' => ['wallet_gateway', 'wallet_payment'],
    ];

    public function __construct(
        private readonly DatabaseManager $db,
        private readonly WalletService $walletService,
        private readonly PaymentFulfillmentService $fulfillmentService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly CreateOrLinkManualPaymentRequest $manualPaymentLinker,
        private readonly LegalNumberingService $legalNumberingService,
    ) {
    }

    /**
     * @param array<string, mixed> $data
     */
    public function initiate(User $user, ServiceRequest $serviceRequest, string $method, string $idempotencyKey, array $data = []): PaymentTransaction
    {
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

        $normalizedMethod = $this->normalizePaymentMethod($method);

        $serviceRequest->loadMissing(['service', 'service.category']);
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
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

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

        $serviceRequest->loadMissing(['service', 'service.category']);
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

        // Avoid updating the DB column `payment_gateway` to 'manual_bank' before a
        // manual_payment_request_id exists. The database has a BEFORE UPDATE
        // trigger that will SIGNAL if a manual_bank PT does not reference a
        // manual_payment_request. Defer setting the gateway until after we have
        // attached/created the manual payment request.
        $deferredGateway = null;
        if ($transaction->payment_gateway !== $method) {
            if ($method === 'manual_bank' && ! $transaction->manual_payment_request_id) {
                $deferredGateway = $method;
            } else {
                $transaction->payment_gateway = $method;
                $transaction->save();
            }
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


        $manualRequest = $manualContext['manual_payment_request'] ?? $transaction->manualPaymentRequest;

        $department = $this->resolvePaymentDepartment(
            $serviceRequest,
            $service,
            $manualRequest instanceof ManualPaymentRequest ? $manualRequest : null
        );

        $data['department'] = $department;


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
            $walletTransaction = $this->debitWallet($user, $transaction, $idempotencyKey, $service, $data, $meta);
            $options['wallet_transaction'] = $walletTransaction;

            $meta = array_replace_recursive($meta, [
                'wallet' => [
                    'transaction_id' => $walletTransaction->getKey(),
                    'idempotency_key' => $walletTransaction->idempotency_key,
                    'currency' => $walletTransaction->currency,
                ],
            ]);
            $options['meta'] = $meta;
        }

        if (in_array($method, ['manual_bank', 'east_yemen_bank'], true)) {
            $department = $this->resolvePaymentDepartment(
                $serviceRequest,
                $service,
                $manualRequest instanceof ManualPaymentRequest ? $manualRequest : null
            );
            $officialReference = $this->legalNumberingService->formatPaymentNumber(
                $transaction->getKey(),
                $department,
                $transaction->payment_id
            );
            $meta = $this->embedOfficialPaymentReference(
                $options['meta'],
                $officialReference,
                $options['payment_reference'] ?? null
            );
            $options['meta'] = $meta;
            $options['payment_reference'] = $officialReference;
            $transaction->payment_id = $officialReference;

        }

        $options['meta'] = $meta;


        if ($transaction->manual_payment_request_id) {
            $options['manual_payment_request_id'] = $transaction->manual_payment_request_id;
        }

        // If we deferred setting the gateway earlier (to avoid DB trigger),
        // apply it now before calling the fulfillment which may save the
        // transaction and therefore invoke DB triggers.
        if ($deferredGateway !== null) {
            $transaction->payment_gateway = $deferredGateway;
            // ensure manual_payment_request_id is present when setting manual_bank
            if ($deferredGateway === 'manual_bank' && ! $transaction->manual_payment_request_id) {
                throw ValidationException::withMessages([
                    'manual_payment_request' => __('Manual payment request is required for manual bank payments.'),
                ]);
            }
            $transaction->save();
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
        // sanitize client input: strip any *_number fields
        $data = InputSanitizer::stripNumberFields($data);

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


            $department = $this->resolvePaymentDepartment($serviceRequest, $service, $manualRequest);
            $data['department'] = $department;


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
        $normalizedGateway = strtolower(trim($method));

        if (in_array($normalizedGateway, ['manual-banks', 'manual bank', 'manualbank', 'bank', 'bank_transfer', 'banktransfer', 'offline', 'internal'], true)) {
            $normalizedGateway = 'manual_bank';
        } elseif (in_array($normalizedGateway, ['alsharq', 'al-sharq', 'bank_alsharq'], true)) {
            $normalizedGateway = 'east_yemen_bank';
        }

        $method = $normalizedGateway;

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

            if ($method === 'wallet' && $existing->manual_payment_request_id) {
                $this->detachManualPaymentArtifacts($existing);
            }

            return $existing;
        }

        $activeDuplicate = PaymentTransaction::query()
            ->where('user_id', $user->getKey())
            ->where('payable_type', ServiceRequest::class)
            ->where('payable_id', $serviceRequest->getKey())
            ->whereIn('payment_gateway', $this->expandLegacyMethods($method))
            ->whereIn(DB::raw("LOWER(COALESCE(payment_status, ''))"), ['pending', 'initiated', 'processing'])
            ->orderByDesc('id')
            ->lockForUpdate()
            ->first();

        if ($activeDuplicate) {
            $needsUpdate = false;

            if ($activeDuplicate->payment_gateway !== $method) {
                $activeDuplicate->payment_gateway = $method;
                $needsUpdate = true;
            }

            if ($activeDuplicate->payable_type !== ServiceRequest::class) {
                $activeDuplicate->payable_type = ServiceRequest::class;
                $needsUpdate = true;
            }

            if (! $activeDuplicate->idempotency_key || trim((string) $activeDuplicate->idempotency_key) === '') {
                $activeDuplicate->idempotency_key = $idempotencyKey;
                $needsUpdate = true;
            }

            if ($needsUpdate) {
                $activeDuplicate->save();
            }

            if ($method === 'wallet' && $activeDuplicate->manual_payment_request_id) {
                $this->detachManualPaymentArtifacts($activeDuplicate);
            }

            return $activeDuplicate;
        }

        $amount = $this->resolveServiceAmount($service, $data);

        $currency = $this->resolveServiceCurrency($service, $data);

        if ($method === 'wallet') {
            $currency = $this->assertWalletCurrencyCompatibility($user, $currency, true);
        }


        $service->loadMissing('category');


        $meta = $this->buildInitialMeta($service, $amount, $currency, $method, $data);
        $meta['context'] = [
            'type' => 'service_request',
            'service_request_id' => $serviceRequest->getKey(),
            'user_id' => $user->getKey(),
        ];

        $manualPaymentRequestId = null;
        $manualPaymentRequest = null;
        if (in_array($method, ['manual_bank', 'east_yemen_bank'], true)) {
            $manualBank = $this->resolveManualBankForRequest($data);

            if (! $manualBank instanceof ManualBank) {
                throw ValidationException::withMessages([
                    'manual_bank_id' => __('Please select a valid manual bank or configure a default bank.'),
                ]);
            }

            $bankName = Arr::get($data, 'bank_name')
                ?? Arr::get($data, 'transfer.bank_name')
                ?? Arr::get($data, 'transfer.bank')
                ?? Arr::get($data, 'payment.bank_name')
                ?? $manualBank->name
                ?? 'unspecified';

            $manualPaymentRequest = ManualPaymentRequest::query()->firstOrCreate(
                [
                    'user_id' => $user->getKey(),
                    'service_request_id' => $serviceRequest->getKey(),
                    'status' => ManualPaymentRequest::STATUS_PENDING,
                ],
                [
                    'manual_bank_id' => $manualBank->getKey(),
                    'payable_type' => ServiceRequest::class,
                    'payable_id' => $serviceRequest->getKey(),
                    'amount' => $amount,
                    'currency' => $currency,
                    'bank_name' => $bankName,
                ]
            );

            $manualRequestUpdates = [];
            if ((int) $manualPaymentRequest->service_request_id !== $serviceRequest->getKey()) {
                $manualRequestUpdates['service_request_id'] = $serviceRequest->getKey();
            }

            if ($manualPaymentRequest->payable_type !== ServiceRequest::class) {
                $manualRequestUpdates['payable_type'] = ServiceRequest::class;
            }

            if ((int) $manualPaymentRequest->payable_id !== $serviceRequest->getKey()) {
                $manualRequestUpdates['payable_id'] = $serviceRequest->getKey();
            }

            if ((int) $manualPaymentRequest->manual_bank_id !== $manualBank->getKey()) {
                $manualRequestUpdates['manual_bank_id'] = $manualBank->getKey();
            }

            if ($manualRequestUpdates !== []) {
                $manualPaymentRequest->forceFill($manualRequestUpdates)->saveQuietly();
            }

            $manualPaymentRequestId = $manualPaymentRequest->getKey();

            $meta['transfer'] = array_merge(
                ['bank_name' => $bankName],
                isset($meta['transfer']) && is_array($meta['transfer']) ? $meta['transfer'] : []
            );

            $meta['transfer']['manual_bank_id'] = $manualBank->getKey();
            $data['manual_bank_id'] = $manualBank->getKey();
        }


        $department = $this->resolvePaymentDepartment(
            $serviceRequest,
            $service,
            $manualPaymentRequest instanceof ManualPaymentRequest ? $manualPaymentRequest : null
        );

        $data['department'] = $department;
        $meta = $this->mergeServiceMeta($meta, $service, $data);


        $transaction = PaymentTransaction::create([
            'user_id' => $user->getKey(),
            'amount' => $amount,
            'currency' => $currency,
            'payment_gateway' => $method,
            'payment_status' => 'pending',
            'payable_type' => ServiceRequest::class,
            'payable_id' => $serviceRequest->getKey(),
            'idempotency_key' => $idempotencyKey,
            'manual_payment_request_id' => $manualPaymentRequestId,
            'meta' => $meta,
        ]);

        $serviceRequest->forceFill([
            'payment_transaction_id' => $transaction->getKey(),
        ])->save();

        if ($manualPaymentRequest instanceof ManualPaymentRequest
            && (int) $manualPaymentRequest->payment_transaction_id !== $transaction->getKey()) {
            $manualPaymentRequest->payment_transaction_id = $transaction->getKey();
            $manualPaymentRequest->save();
        }

        return $transaction;
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
            'category_id' => $service->category_id !== null ? (int) $service->category_id : null,
        ], static fn ($value) => $value !== null && $value !== '');

        $categoryTitle = $this->resolveServiceCategoryTitle($service);

        if ($categoryTitle !== null) {
            $serviceMeta['category_title'] = $categoryTitle;
            $serviceMeta['department'] = $categoryTitle;
            $serviceMeta['section'] = $categoryTitle;
        }

        $existingServiceMeta = Arr::get($meta, 'service');

        if (! is_array($existingServiceMeta)) {
            $existingServiceMeta = [];
        }

        foreach ($serviceMeta as $key => $value) {
            if ($value === null || $value === '') {
                continue;
            }

            if (! array_key_exists($key, $existingServiceMeta) || $this->isEmptyValue($existingServiceMeta[$key])) {
                $existingServiceMeta[$key] = $value;
            }
        }

        $departmentOverride = Arr::get($data, 'department');

        if (is_string($departmentOverride)) {
            $departmentOverride = trim($departmentOverride);

            if ($departmentOverride !== '') {
                $existingServiceMeta['department'] = $departmentOverride;

                if (! array_key_exists('section', $existingServiceMeta) || $this->isEmptyValue($existingServiceMeta['section'] ?? null)) {
                    $existingServiceMeta['section'] = $departmentOverride;
                }

                if (! array_key_exists('category_title', $existingServiceMeta)
                    || $this->isEmptyValue($existingServiceMeta['category_title'] ?? null)) {
                    $existingServiceMeta['category_title'] = $departmentOverride;
                }
            }
        }


        if (isset($data['payment_transaction_id'])) {
            $existingServiceMeta['payment_transaction_id'] = $data['payment_transaction_id'];
        }

        if (isset($data['reference']) && is_string($data['reference']) && trim($data['reference']) !== '') {
            $existingServiceMeta['reference'] = trim((string) $data['reference']);

        }

        $meta['service'] = $existingServiceMeta;




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

    private function debitWallet(
        User $user,
        PaymentTransaction $transaction,
        string $idempotencyKey,
        Service $service,
        array $data = [],
        array $meta = []
    ) {
        try {
            $walletTransactionId = Arr::get($meta, 'wallet.transaction_id')
                ?? Arr::get($transaction->meta, 'wallet.transaction_id');

            if ($walletTransactionId) {
                $existing = WalletTransaction::query()
                    ->whereKey((int) $walletTransactionId)
                    ->lockForUpdate()
                    ->first();

                if ($existing instanceof WalletTransaction) {
                    return $existing;
                }
            }


            $currency = strtoupper((string) ($transaction->currency ?? $this->resolveServiceCurrency($service, $data)));

            $baseMeta = is_array($transaction->meta) ? $transaction->meta : [];

            if ($meta !== []) {
                $baseMeta = array_replace_recursive($baseMeta, $meta);
            }

            $categoryTitle = $this->resolveServiceCategoryTitle($service);

            if (! isset($baseMeta['service']) || ! is_array($baseMeta['service'])) {
                $baseMeta['service'] = [];
            }

            $baseMeta['service']['id'] = $service->getKey();
            $baseMeta['service']['title'] = $service->title;

            if ($service->category_id !== null) {
                $baseMeta['service']['category_id'] = (int) $service->category_id;
            }

            if ($categoryTitle !== null) {
                $baseMeta['service']['category_title'] = $categoryTitle;
                $baseMeta['service']['department'] = $categoryTitle;
                $baseMeta['service']['section'] = $categoryTitle;
            }


            // Diagnostic log to help trace wallet debits for services
            Log::info('ServicePaymentService: debitWallet invoked', [
                'user_id' => $user->getKey(),
                'payment_transaction_id' => $transaction->getKey(),
                'amount' => $transaction->amount,
                'currency' => $currency,
                'meta_keys' => array_keys($baseMeta),
            ]);

            return $this->walletService->debit($user, $idempotencyKey, (float) $transaction->amount, [
                'payment_transaction' => $transaction,
                'meta' => $baseMeta,
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


        if ($service->category_id !== null) {
            $meta['service']['category_id'] = (int) $service->category_id;
        }

        $categoryTitle = $this->resolveServiceCategoryTitle($service);

        if ($categoryTitle !== null) {
            $meta['service']['category_title'] = $categoryTitle;
            $meta['service']['department'] = $categoryTitle;
            $meta['service']['section'] = $categoryTitle;
        }

        $departmentOverride = Arr::get($data, 'department');

        if (is_string($departmentOverride)) {
            $departmentOverride = trim($departmentOverride);

            if ($departmentOverride !== '') {
                $meta['service']['department'] = $departmentOverride;

                if (! array_key_exists('section', $meta['service']) || $this->isEmptyValue($meta['service']['section'] ?? null)) {
                    $meta['service']['section'] = $departmentOverride;
                }

                if (! array_key_exists('category_title', $meta['service'])
                    || $this->isEmptyValue($meta['service']['category_title'] ?? null)) {
                    $meta['service']['category_title'] = $departmentOverride;
                }
            }
        }

 

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

    private function resolveServiceCategoryTitle(Service $service): ?string
    {
        $service->loadMissing('category');

        $category = $service->category;

        if (! $category) {
            return null;
        }

        $title = $category->translated_name ?? $category->name ?? null;

        if (! is_string($title)) {
            return null;
        }

        $trimmed = trim($title);

        return $trimmed !== '' ? $trimmed : null;
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

    private function resolvePaymentDepartment(
        ServiceRequest $serviceRequest,
        Service $service,
        ?ManualPaymentRequest $manualRequest = null
    ): string {
        $candidates = [
            $manualRequest?->department ?? null,
            Arr::get($serviceRequest->payload ?? [], 'department'),
            $this->resolveServiceCategoryTitle($service),
            'services',
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate)) {
                $trimmed = trim($candidate);

                if ($trimmed !== '') {
                    return $this->legalNumberingService->normalizeDepartment($trimmed);
                }
            }
        }

        return $this->legalNumberingService->normalizeDepartment(null);
    }

    private function embedOfficialPaymentReference(
        array $meta,
        string $officialReference,
        ?string $userReference = null
    ): array {
        data_set($meta, 'payment_reference', $officialReference);
        data_set($meta, 'payload.official_reference', $officialReference);
        data_set($meta, 'payload.canonical_reference', $officialReference);
        data_set($meta, 'service.payment_reference', $officialReference);

        if (is_string($userReference) && trim($userReference) !== '') {
            $trimmed = trim($userReference);
            data_set($meta, 'manual.user_reference', $trimmed);
            data_set($meta, 'manual.reference', $trimmed);
            data_set($meta, 'payload.reference', $trimmed);
        }

        return $meta;
    }

    private function isEmptyValue($value): bool
    {
        if ($value === null) {
            return true;
        }

        if (is_string($value)) {
            return trim($value) === '';
        }

        return false;
    }



    private function detachManualPaymentArtifacts(PaymentTransaction $transaction): void
    {
        $manualRequest = $transaction->manualPaymentRequest;

        if ($manualRequest instanceof ManualPaymentRequest) {
            $updates = [
                'payment_transaction_id' => null,
            ];

            if ($manualRequest->status === ManualPaymentRequest::STATUS_PENDING) {
                $updates['status'] = ManualPaymentRequest::STATUS_REJECTED;
            }

            $manualRequest->forceFill($updates)->saveQuietly();
        }

        $transaction->manual_payment_request_id = null;
        $transaction->meta = $this->stripManualMeta($transaction->meta);
        $transaction->payment_gateway_name = null;
        $transaction->gateway_label = null;
        $transaction->channel_label = null;
        $transaction->payment_gateway_label = null;
        $transaction->saveQuietly();
    }

    private function stripManualMeta($meta): array
    {
        if (! is_array($meta)) {
            return [];
        }

        unset($meta['manual'], $meta['manual_payment_request']);

        if (isset($meta['transfer']) && is_array($meta['transfer'])) {
            unset($meta['transfer']['bank_name'], $meta['transfer']['manual_bank_id']);

            if ($meta['transfer'] === []) {
                unset($meta['transfer']);
            }
        }

        return $meta;
    }

    private function resolveManualBankForRequest(array $data): ?ManualBank
    {
        $manualBankId = $this->extractManualBankIdentifier($data);

        if ($manualBankId !== null) {
            $bank = ManualBank::query()->find($manualBankId);

            if ($bank instanceof ManualBank) {
                return $bank;
            }
        }

        $configuredId = config('payments.default_manual_bank_id');

        if ($configuredId !== null && $configuredId !== '') {
            $normalizedId = is_numeric($configuredId) ? (int) $configuredId : null;

            if ($normalizedId && $normalizedId > 0) {
                $bank = ManualBank::query()->find($normalizedId);

                if ($bank instanceof ManualBank) {
                    return $bank;
                }
            }
        }

        $query = ManualBank::query();

        if (ManualBank::supportsColumn('status')) {
            $query->where('status', true);
        } elseif (ManualBank::supportsColumn('is_active')) {
            $query->where('is_active', true);
        }

        if (ManualBank::supportsColumn('display_order')) {
            $query->orderBy('display_order');
        }

        return $query->orderBy('name')->orderBy('id')->first();
    }

    private function extractManualBankIdentifier(array $data): ?int
    {
        $candidates = [
            Arr::get($data, 'manual_bank_id'),
            Arr::get($data, 'bank_id'),
            Arr::get($data, 'transfer.manual_bank_id'),
            Arr::get($data, 'transfer.bank_id'),
            Arr::get($data, 'payment.manual_bank_id'),
            Arr::get($data, 'payment.bank_id'),
        ];

        foreach ($candidates as $candidate) {
            if ($candidate instanceof ManualBank) {
                return $candidate->getKey();
            }

            if (is_string($candidate)) {
                $candidate = trim($candidate);
            }

            if ($candidate === null || $candidate === '' || $candidate === []) {
                continue;
            }

            if (is_int($candidate) && $candidate > 0) {
                return $candidate;
            }

            if (is_numeric($candidate)) {
                $normalized = (int) $candidate;

                if ($normalized > 0) {
                    return $normalized;
                }
            }
        }

        return null;
    }

}
