<?php

namespace App\Http\Controllers;

use App\Models\Package;
use App\Http\Resources\ManualPaymentRequestResource;
use App\Http\Resources\PaymentTransactionResource;
use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\Wifi\WifiPlan;
use App\Services\Payments\OrderPaymentService;
use App\Services\Payments\PackagePaymentService;
use App\Services\Payments\ServicePaymentService;
use App\Services\Payments\WifiPlanPaymentService;
use Illuminate\Validation\Rule;
use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Services\OrderCheckoutService;
use ReflectionClass;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use App\Services\LegalNumberingService;

use App\Models\PaymentConfiguration;
use App\Models\WalletAccount;
use App\Services\Payments\ManualPaymentRequestService;
use App\Services\WalletService;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Throwable;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;
use App\Support\Payments\PaymentGatewayCurrencyPolicy;




class PaymentController extends Controller
{
    public function __construct(
        private readonly OrderPaymentService $orderPaymentService,
        private readonly PackagePaymentService $packagePaymentService,
        private readonly WifiPlanPaymentService $wifiPlanPaymentService,
        private readonly ServicePaymentService $servicePaymentService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly CreateOrLinkManualPaymentRequest $manualPaymentLinker,
        private readonly LegalNumberingService $legalNumberingService,
        private readonly WalletService $walletService
        
        )
    {
    }

    public function initiate(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        $purpose = $this->normalizePurpose($request->input('purpose', 'order'));
        $request->merge(['purpose' => $purpose]);


        if ($purpose === 'package' && ! $request->filled('package_id') && $request->filled('order_id')) {
            $request->merge(['package_id' => $request->input('order_id')]);
        }

        if ($request->filled('manual_bank_id') && ! $request->filled('bank_id')) {
            $request->merge(['bank_id' => $request->input('manual_bank_id')]);
        }



        $allowedMethods = $this->allowedPaymentMethodTokens($purpose);
        $methodOptionsPayload = $this->paymentMethodOptionsPayload($purpose, $allowedMethods);
        if ($request->filled('payment_method') && is_string($request->input('payment_method'))) {
            $request->merge(['payment_method' => trim((string) $request->input('payment_method'))]);
        }


        $rules = [
            'purpose' => ['required', 'string', Rule::in(['order', 'package', 'service', 'wifi_plan', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP])],
            'payment_method' => ['nullable', 'string', 'max:191', Rule::in($allowedMethods)],
            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'bank_id' => ['nullable', 'integer', 'exists:manual_banks,id'],
            'bank_account_id' => ['nullable', 'string', 'max:191'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
        ];

        if ($purpose === 'order' && $request->filled('order_id')) {
            $candidateRequest = ServiceRequest::query()
                ->whereKey((int) $request->input('order_id'))
                ->where('user_id', $request->user()?->getKey() ?? 0)
                ->first();

            if ($candidateRequest) {
                $purpose = 'service';
                $request->merge([
                    'purpose' => 'service',
                    'service_request_id' => $candidateRequest->getKey(),
                    'service_id' => $candidateRequest->service_id,
                ]);
                $request->request->remove('order_id');
            }
        }

        $messages = [];

        if ($purpose === 'service') {
            $rules['payment_method'] = ['required', 'string', 'max:191', Rule::in($allowedMethods)];
            $rules['currency'] = ['required', 'string', 'size:3', Rule::in(['USD', 'YER'])];
            $rules['service_id'] = ['required', 'integer', 'exists:services,id'];
            $rules['service_request_id'] = ['required', 'integer', 'exists:service_requests,id'];
            $rules['order_id'] = ['prohibited'];
            $messages['order_id.prohibited'] = __('The order_id field is not allowed when initiating a service payment.');
            $messages['currency.required'] = __('gateway_currency_unsupported');
            $messages['currency.in'] = __('gateway_currency_unsupported');
        } elseif ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
        } elseif ($purpose === 'wifi_plan') {
            $rules['wifi_plan_id'] = ['required', 'integer', 'exists:wifi_plans,id'];
        } elseif ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            $rules['amount'] = ['required', 'numeric', 'min:0.01'];
            $rules['currency'] = ['required', 'string', 'size:3'];

        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        try {
            $validated = $request->validate($rules, $messages);
        } catch (ValidationException $exception) {
            Log::warning('payments.initiate.validation_failed', [
                'errors' => $exception->errors(),
                'purpose' => $purpose,
                'payload' => $request->all(),
            ]);

            throw $exception;
        }

        $selectedMethod = null;

        if (isset($validated['currency']) && is_string($validated['currency'])) {
            $validated['currency'] = strtoupper($validated['currency']);
        }

        if (isset($validated['payment_method']) && is_string($validated['payment_method'])) {
            $candidate = trim($validated['payment_method']);
            $selectedMethod = $candidate !== '' ? $candidate : null;
        }

        if ($selectedMethod === null) {
            return response()->json(array_merge(
                $methodOptionsPayload,
                [
                    'message' => __('يرجى اختيار وسيلة الدفع لإكمال العملية.'),
                    'status' => 'requires_payment_method',
                    'requires_payment_method' => true,
                    'selected_payment_method' => null,
                    'payment_method' => null,
                ]
            ));
        }

        $validated['payment_method'] = $this->normalizePaymentMethodForPurpose($selectedMethod, $purpose);

        if (in_array($validated['payment_method'], ['wallet', 'east_yemen_bank'], true)) {
            $validated['currency'] = $this->walletService->getPrimaryCurrency();
        }

        if (($validated['currency'] ?? null) !== null
            && ! PaymentGatewayCurrencyPolicy::supports($validated['payment_method'], $validated['currency'])) {
            return response()->json([
                'message' => __('gateway_currency_unsupported'),
                'errors' => [
                    'currency' => [__('gateway_currency_unsupported')],
                ],
            ], 422);
        }

        $methodResponsePayload = array_merge(
            $methodOptionsPayload,
            [
                'requires_payment_method' => false,
                'payment_method' => $validated['payment_method'],
                'selected_payment_method' => $validated['payment_method'],
                'preferred_payment_method' => $validated['payment_method'],
            ]
        );


        if (!isset($validated['note']) && $request->filled('notes')) {
            $validated['note'] = $request->input('notes');
        }

        if (!isset($validated['metadata']) && $request->has('metadata') && is_array($request->input('metadata'))) {
            $validated['metadata'] = $request->input('metadata');
        }



        if ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            return $this->initiateWalletTopUp($request, $validated, $idempotencyKey);
        }


        if ($purpose === 'service') {
            $serviceRequest = ServiceRequest::query()
                ->whereKey($validated['service_request_id'])
                ->where('user_id', $request->user()->getKey())
                ->firstOrFail();

            $serviceRequest->loadMissing('service');

            if (! $serviceRequest->service || (int) $serviceRequest->service_id !== (int) $validated['service_id']) {
                return response()->json([
                    'message' => __('The given data was invalid.'),
                    'errors' => [
                        'service_request_id' => [__('Service request does not match the selected service.')],
                    ],
                ], 422);
            }
            $this->ensureServiceRequestNumber($serviceRequest);


            $service = $serviceRequest->service;

            $availableGateways = $this->servicePaymentService->determineAvailableGateways(
                $request->user(),
                $serviceRequest,
                $service,
                $validated
            );

            $normalizedSelectedMethod = $this->normalizeGatewayToken($validated['payment_method'] ?? null);
            $selectedMethod = $normalizedSelectedMethod ?? ($validated['payment_method'] ?? null);

            $explicitWalletRequest = $normalizedSelectedMethod === 'wallet';
            if (! $explicitWalletRequest && isset($validated['payment_method'])) {
                $explicitWalletRequest = $this->normalizeGatewayToken($validated['payment_method']) === 'wallet';
            }

            if ($availableGateways !== []) {
                $canonicalSelected = $normalizedSelectedMethod;

                if ($canonicalSelected === null || ! in_array($canonicalSelected, $availableGateways, true)) {
                    if ($explicitWalletRequest) {
                        Log::warning('payments.service.wallet_unavailable', [
                            'user_id' => $request->user()->getKey(),
                            'service_request_id' => $serviceRequest->getKey(),
                            'requested_method' => $selectedMethod,
                            'available_gateways' => $availableGateways,
                            'idempotency_key' => $idempotencyKey,
                        ]);

                        return response()->json([
                            'message' => __('الدفع بالمحفظة غير متاح حالياً.'),
                            'errors' => [
                                'payment_method' => [__('الدفع بالمحفظة غير متاح حالياً.')],
                            ],
                        ], 422);
                    }


                    $fallbackMethod = $availableGateways[0];
                    Log::info('payments.service.gateway_overridden', [
                        'user_id' => $request->user()->getKey(),
                        'service_request_id' => $serviceRequest->getKey(),
                        'requested_method' => $selectedMethod,
                        'fallback_method' => $fallbackMethod,
                        'idempotency_key' => $idempotencyKey,
                    ]);
                    $canonicalSelected = $fallbackMethod;
                }

                $selectedMethod = $canonicalSelected;
                $validated['payment_method'] = $selectedMethod;
                $methodResponsePayload = $this->filterPaymentMethodsByAvailability(
                    $methodResponsePayload,
                    $availableGateways,
                    $selectedMethod
                );
            } else {
                $service = $serviceRequest->service;
            }


            if ($conflictResponse = $this->guardServicePaymentIdempotency($serviceRequest, $validated['payment_method'])) {
                return $conflictResponse;
            }

            $transaction = $this->servicePaymentService->initiate(
                $request->user(),
                $serviceRequest,
                $validated['payment_method'],
                $idempotencyKey,
                $validated
            );

            $transaction->loadMissing('manualPaymentRequest.manualBank');

            $freshTransaction = $transaction->fresh();

            $responsePayload = array_merge(
                $methodResponsePayload,
                [
                    'message' => __('تم إنشاء عملية الدفع بنجاح.'),
                    'status' => $freshTransaction?->payment_status,

                        'payment_transaction_id' => $freshTransaction?->getKey(),
                        'payment_intent_id' => $freshTransaction?->idempotency_key,
                        'receipt_no' => $freshTransaction?->receipt_no,
                    'transaction' => $freshTransaction,
                    'payment_transaction' => $freshTransaction,
                    'service_request_id' => $serviceRequest->getKey(),
                    'service' => [
                        'id' => $service->getKey(),
                        'title' => $service->title,
                        'price' => $service->price,
                        'currency' => $service->currency,
                        'service_uid' => $service->service_uid,
                        'price_note' => $service->price_note,
                    ],

                    'available_gateways' => $availableGateways,
                    'allowed_gateways' => $availableGateways,

                ]
            );

            if (
                in_array('manual_bank', $availableGateways, true)
                && $freshTransaction?->manualPaymentRequest instanceof ManualPaymentRequest
            ) {
                $manualPaymentRequest = $freshTransaction->manualPaymentRequest;

                $manualPaymentRequest->loadMissing(
                    $this->manualPaymentRequestRelations($manualPaymentRequest)
                );

                return ManualPaymentRequestResource::make($manualPaymentRequest)
                    ->response()
                    ->setStatusCode(402);
            }

            return response()->json($responsePayload);
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

            $freshTransaction = $transaction->fresh();

            return response()->json(array_merge(
                $methodResponsePayload,
                [
                    'message' => __('تم إنشاء عملية الدفع بنجاح.'),
                    'status' => $freshTransaction?->payment_status,
                    'payment_transaction_id' => $freshTransaction?->getKey(),
                    'payment_intent_id' => $freshTransaction?->idempotency_key,
                    'receipt_no' => $freshTransaction?->receipt_no,
                    'transaction' => $freshTransaction,
                    'payment_transaction' => $freshTransaction,
                ]
            ));
        }


        if ($purpose === 'wifi_plan') {
            $plan = WifiPlan::with('network')->findOrFail($validated['wifi_plan_id']);

            $transaction = $this->wifiPlanPaymentService->initiate(
                $request->user(),
                $plan,
                $validated['payment_method'],
                $idempotencyKey,
                $validated
            );

            $freshTransaction = $transaction->fresh();

            return response()->json(array_merge(
                $methodResponsePayload,
                [
                    'message' => __('تم إنشاء عملية الدفع بنجاح.'),
                    'status' => $freshTransaction?->payment_status,
                    'payment_transaction_id' => $freshTransaction?->getKey(),
                    'payment_intent_id' => $freshTransaction?->idempotency_key,
                    'receipt_no' => $freshTransaction?->receipt_no,
                    'transaction' => $freshTransaction,
                    'payment_transaction' => $freshTransaction,
                ]
            ));
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

        $freshTransaction = $transaction->fresh();

        return response()->json(array_merge(
            $methodResponsePayload,
            [
                'message' => __('تم إنشاء عملية الدفع بنجاح.'),
                'status' => $freshTransaction?->payment_status,
                'payment_transaction_id' => $freshTransaction?->getKey(),
                'payment_intent_id' => $freshTransaction?->idempotency_key,
                'receipt_no' => $freshTransaction?->receipt_no,
                'transaction' => $freshTransaction,
                'payment_transaction' => $freshTransaction,
            ]
        ));
    }

    public function confirm(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        if ($request->filled('manual_bank_id') && ! $request->filled('bank_id')) {
            $request->merge(['bank_id' => $request->input('manual_bank_id')]);
        }

        if ($request->filled('bank_id') && ! $request->filled('manual_bank_id')) {
            $request->merge(['manual_bank_id' => $request->input('bank_id')]);
        }



        $validated = $request->validate([
            'transaction_id' => ['required', 'integer', 'exists:payment_transactions,id'],
            'reference' => ['nullable', 'string', 'max:191'],


            'note' => ['nullable', 'string'],
            'payment_method' => ['nullable', 'string', 'max:191'],



            'manual_bank_id' => ['nullable', 'integer', 'exists:manual_banks,id'],
            'bank_id' => ['nullable', 'integer', 'exists:manual_banks,id'],
            'bank_account_id' => ['nullable', 'string', 'max:191'],
            'bank_name' => ['nullable', 'string', 'max:191'],
            'bank' => ['nullable', 'array'],
            'bank.name' => ['nullable', 'string', 'max:191'],
            'bank.account_id' => ['nullable', 'string', 'max:191'],
            'bank.beneficiary_name' => ['nullable', 'string', 'max:191'],
            'metadata' => ['nullable', 'array'],
            'attachments' => ['nullable', 'array'],
            'attachments.*' => ['array'],
            'receipt_path' => ['nullable', 'string', 'max:2048'],

        ]);

        $transaction = PaymentTransaction::query()
            ->with('payable')
            ->findOrFail($validated['transaction_id']);
        $wifiDelivery = null;

        if (in_array($transaction->payable_type, [ServiceRequest::class, Service::class], true)) {
            $updated = $this->servicePaymentService->confirm(
                $request->user(),
                $transaction,
                $idempotencyKey,
                $validated
            );
        } elseif ($transaction->payable_type === Package::class) {
            $updated = $this->packagePaymentService->confirm(
                $request->user(),
                $transaction,
                $idempotencyKey,
                $validated
            );

        } elseif ($transaction->payable_type === WifiPlan::class) {
            $result = $this->wifiPlanPaymentService->confirm(
                $request->user(),
                $transaction,
                $idempotencyKey,
                $validated
            );

            $updated = $result['transaction'];
            $wifiDelivery = $result['delivery'] ?? null;

        } else {
            $updated = $this->orderPaymentService->confirm(
                $request->user(),
                $transaction,
                $idempotencyKey,
                $validated
            );
        }

        $freshUpdated = $updated->fresh();

        $response = [
            'message' => __('تم تأكيد عملية الدفع.'),
            'receipt_no' => $freshUpdated?->receipt_no,
            'transaction' => $freshUpdated,
        ];

        if ($wifiDelivery !== null) {
            $response['wifi_delivery'] = $wifiDelivery;
        }

        return response()->json($response);
    }

    /**
     * @return array<int, string>
     */
    private function manualPaymentRequestRelations(ManualPaymentRequest $request): array
    {
        $relations = [
            'manualBank',
            'payable',
            'paymentTransaction.order',
            'paymentTransaction.walletTransaction',
            'paymentTransaction.payable',
            'paymentTransaction.payable.service',
        ];

        foreach (['serviceRequest', 'order', 'attachments'] as $relation) {
            if (method_exists($request, $relation)) {
                $relations[] = $relation;
            }
        }

        return $relations;
    }

    public function manual(Request $request): JsonResponse
    {
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        $purpose = $this->normalizePurpose($request->input('purpose', 'order'));
        $request->merge(['purpose' => $purpose]);


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
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package', 'service', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP])],


            'amount' => ['nullable', 'numeric', 'min:0'],
            'reference' => ['nullable', 'string', 'max:191'],
            'note' => ['nullable', 'string'],
            'manual_bank_id' => ['required', 'integer', 'exists:manual_banks,id'],
            'bank_account_id' => ['nullable', 'string', 'max:191'],
            'metadata' => ['nullable', 'array'],


            'transaction_id' => ['nullable', 'integer', 'exists:payment_transactions,id'],
            'payment_transaction_id' => ['nullable', 'integer', 'exists:payment_transactions,id'],


            'auto_confirm' => ['sometimes', 'boolean'],
            'receipt' => ['nullable', 'file', 'max:10240', 'mimes:jpg,jpeg,png,pdf'],
            'receipt_image' => ['nullable', 'file', 'max:10240', 'mimes:jpg,jpeg,png,pdf'],

        ];

        $messages = [];

        if ($purpose === 'service') {
            $rules['service_id'] = ['required', 'integer', 'exists:services,id'];
            $rules['service_request_id'] = ['required', 'integer', 'exists:service_requests,id'];
            $rules['order_id'] = ['prohibited'];
            $messages['order_id.prohibited'] = __('The order_id field is not allowed when creating a manual service payment.');
        } elseif ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];

        } elseif ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            $rules['amount'] = ['required', 'numeric', 'min:0.01'];
            $rules['currency'] = ['required', 'string', 'size:3'];

        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        $validated = $request->validate($rules, $messages);

        if (! isset($validated['note']) && $request->filled('notes')) {
            $validated['note'] = $request->input('notes');
        }

        if (! isset($validated['metadata']) && $request->has('metadata') && is_array($request->input('metadata'))) {
            $validated['metadata'] = $request->input('metadata');
        }

        $receiptFile = $this->resolveReceiptFile($request);

        if ($receiptFile === null) {
            throw ValidationException::withMessages([
                'receipt' => __('يُرجى إرفاق إيصال التحويل.'),
            ]);
        }

        $storedReceiptPath = $this->storeReceiptFile($receiptFile);

        $validated['receipt_path'] = $storedReceiptPath;
        $validated['attachments'] = [[
            'type' => 'receipt',
            'path' => $storedReceiptPath,
            'disk' => 'public',
            'name' => $receiptFile->getClientOriginalName() ?: null,
            'mime_type' => $receiptFile->getClientMimeType() ?: null,
            'size' => $receiptFile->getSize() ?: null,
            'uploaded_at' => now()->toIso8601String(),
            'url' => $this->resolvePublicUrl($storedReceiptPath),
        ]];



        $validated['bank_id'] = $validated['manual_bank_id'];

        if ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            return $this->handleWalletTopUpManual($request, $validated, $idempotencyKey);
        }


        if ($purpose === 'service') {
            $serviceRequest = ServiceRequest::query()
                ->whereKey($validated['service_request_id'])
                ->where('user_id', $request->user()->getKey())
                ->firstOrFail()
                ->loadMissing('service');

            if (! $serviceRequest->service || (int) $serviceRequest->service_id !== (int) $validated['service_id']) {
                return response()->json([
                    'message' => __('The given data was invalid.'),
                    'errors' => [
                        'service_request_id' => [__('Service request does not match the selected service.')],
                    ],
                ], 422);
            }

            $transaction = $this->servicePaymentService->createManual(
                $request->user(),
                $serviceRequest,
                $idempotencyKey,
                $validated
            );

            $transaction->loadMissing('manualPaymentRequest.manualBank');

            $manualRequest = $transaction->manualPaymentRequest;

            if ($manualRequest instanceof ManualPaymentRequest) {
                $manualRequest->loadMissing(
                    $this->manualPaymentRequestRelations($manualRequest)
                );
            } else {
                $manualRequest = null;
            }

            $transactionResource = PaymentTransactionResource::make($transaction)->resolve();
            $manualRequestResource = $manualRequest
                ? ManualPaymentRequestResource::make($manualRequest)->resolve()
                : null;

            return response()->json([
                'message' => __('تم تسجيل الدفع اليدوي.'),
                'transaction' => $transactionResource,
                'payment_transaction' => $transactionResource,
                'manual_payment_request' => $manualRequestResource,
                'service_request_id' => $serviceRequest->getKey(),
            ], $transaction->payment_status === 'succeed' ? 200 : 202);
        }


        if ($purpose === 'package') {
            $package = Package::findOrFail($validated['package_id']);

            $transaction = $this->packagePaymentService->createManual(
                $request->user(),
                $package,
                $idempotencyKey,
                $validated
            );

            $transaction->loadMissing('manualPaymentRequest.manualBank');

            $manualRequest = $transaction->manualPaymentRequest;

            if ($manualRequest instanceof ManualPaymentRequest) {
                $manualRequest->loadMissing(
                    $this->manualPaymentRequestRelations($manualRequest)
                );
            } else {
                $manualRequest = null;
            }

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


        if ($purpose === 'wifi_plan') {
            $plan = WifiPlan::with('network')->findOrFail($validated['wifi_plan_id']);

            $transaction = $this->wifiPlanPaymentService->createManual(
                $request->user(),
                $plan,
                $idempotencyKey,
                $validated
            );

            $transaction->loadMissing('manualPaymentRequest.manualBank');

            $manualRequest = $transaction->manualPaymentRequest;

            if ($manualRequest instanceof ManualPaymentRequest) {
                $manualRequest->loadMissing(
                    $this->manualPaymentRequestRelations($manualRequest)
                );
            } else {
                $manualRequest = null;
            }

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

        $manualRequest = $transaction->manualPaymentRequest;

        if ($manualRequest instanceof ManualPaymentRequest) {
            $manualRequest->loadMissing(
                $this->manualPaymentRequestRelations($manualRequest)
            );
        } else {
            $manualRequest = null;
        }

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


    protected function initiateWalletTopUp(Request $request, array $validated, string $idempotencyKey): JsonResponse
    {
        $user = $request->user();
        $paymentMethod = $validated['payment_method'] ?? 'manual_bank';
        $canonicalMethod = $paymentMethod === 'manual' ? 'manual_bank' : $paymentMethod;
        $amount = (float) $validated['amount'];
        $currency = strtoupper($validated['currency']);

        return DB::transaction(function () use ($user, $canonicalMethod, $amount, $currency, $idempotencyKey) {
            $transaction = PaymentTransaction::query()
                ->where('user_id', $user->getKey())
                ->where('payment_gateway', $canonicalMethod)
                ->where('idempotency_key', $idempotencyKey)
                ->lockForUpdate()
                ->first();

            if (! $transaction) {
                $transaction = PaymentTransaction::create([
                    'user_id' => $user->getKey(),
                    'amount' => $amount,
                    'currency' => $currency,
                    'payment_gateway' => $canonicalMethod,
                    'payment_status' => 'pending',
                    'idempotency_key' => $idempotencyKey,
                    'meta' => [
                        'wallet' => [
                            'purpose' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                        ],
                    ],
                ]);
            } else {
                $transaction->fill([
                    'amount' => $amount,
                    'currency' => $currency,
                    'payment_gateway' => $canonicalMethod,
                ]);

                $meta = $transaction->meta ?? [];
                if (! is_array($meta)) {
                    $meta = [];
                }

                $meta = array_replace_recursive($meta, [
                    'wallet' => [
                        'purpose' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                    ],
                ]);

                $transaction->meta = $meta;
                $transaction->save();
            }

            $banks = ManualBank::query()
                ->active()
                ->orderBy('display_order')
                ->orderBy('name')
                ->get();

            $bankPayload = $banks->map(static fn (ManualBank $bank) => $bank->toArray())->values()->toArray();

            $eastYemenGateway = PaymentConfiguration::query()
                ->where('payment_method', 'east_yemen_bank')
                ->first();

            $eastYemenPayload = [
                'payment_method' => 'east_yemen_bank',
                'enabled' => false,
                'status' => false,
                'display_name' => null,
                'note' => null,
                'logo_url' => null,
                'currency_code' => null,
            ];

            if ($eastYemenGateway) {
                $eastYemenPayload = array_merge($eastYemenPayload, [
                    'enabled' => (bool) $eastYemenGateway->status,
                    'status' => (bool) $eastYemenGateway->status,
                    'display_name' => $eastYemenGateway->display_name,
                    'note' => $eastYemenGateway->note,
                    'logo_url' => $eastYemenGateway->logo_url,
                    'currency_code' => $eastYemenGateway->currency_code,
                ]);
            }

            $transactionPayload = [
                'id' => $transaction->getKey(),
                'status' => $transaction->payment_status,
                'amount' => (float) $transaction->amount,
                'currency' => $transaction->currency,
                'payment_gateway' => $transaction->payment_gateway,
                'user_id' => $transaction->user_id,
                'meta' => $transaction->meta,
            ];

            $intentPayload = [
                'id' => $transaction->idempotency_key,
                'status' => $transaction->payment_status,
                'amount' => (float) $transaction->amount,
                'currency' => $transaction->currency,
                'payment_transaction_id' => $transaction->getKey(),
                'metadata' => [
                    'purpose' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                ],
            ];

            $manualSettings = [
                'banks' => $bankPayload,
                'payment_intent' => $intentPayload,
                'payment_transaction' => $transactionPayload,
                'east_yemen_bank' => $eastYemenPayload,
            ];

            return response()->json([
                'message' => __('تم إنشاء عملية الدفع بنجاح.'),
                'payment_intent_id' => $transaction->idempotency_key,
                'payment_transaction_id' => $transaction->getKey(),
                'payment_intent' => $intentPayload,
                'payment_transaction' => $transactionPayload,
                'banks' => $bankPayload,
                'manual_banks' => $bankPayload,
                'manual_payment' => $manualSettings,
                'manual_payment_settings' => $manualSettings,
                'east_yemen_bank' => $eastYemenPayload,
            ]);
        });
    }

    protected function handleWalletTopUpManual(Request $request, array $validated, string $idempotencyKey): JsonResponse
    {
        $user = $request->user();
        $transactionId = $validated['transaction_id']
            ?? $validated['payment_transaction_id']
            ?? $request->input('payment_transaction_id');

        if (! $transactionId) {
            throw ValidationException::withMessages([
                'transaction_id' => __('المعاملة المطلوبة غير متاحة.'),
            ]);
        }

        return DB::transaction(function () use ($user, $validated, $transactionId, $idempotencyKey) {
            $transaction = PaymentTransaction::query()
                ->where('user_id', $user->getKey())
                ->lockForUpdate()
                ->findOrFail($transactionId);

            $transaction->fill([
                'amount' => (float) $validated['amount'],
                'currency' => strtoupper($validated['currency']),
                'payment_gateway' => 'manual_bank',
                'payment_status' => 'pending',
            ]);

            if (empty($transaction->idempotency_key)) {
                $transaction->idempotency_key = $idempotencyKey;
            }

            $walletAccount = WalletAccount::firstOrCreate([
                'user_id' => $user->getKey(),
            ]);

            if (! isset($validated['bank.name']) && isset($validated['bank_name'])) {
                data_set($validated, 'bank.name', $validated['bank_name']);
            }

            $manualPaymentRequest = $this->manualPaymentLinker->handle(
                
                $user,
                ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                $walletAccount->getKey(),
                $transaction,
                $validated
            );

            $manualMeta = array_filter(
                Arr::only($validated, ['note', 'reference', 'attachments', 'receipt_path']),
                static function ($value) {
                    if (is_array($value)) {
                        return $value !== [];
                    }

                    return $value !== null && $value !== '';
                }
            );

            $bankMeta = [];



            if (! empty($validated['manual_bank_id']) || ! empty($validated['bank_account_id'])) {
                $bankMeta = [

                    'id' => $validated['manual_bank_id'] ?? null,
                    'account_id' => $validated['bank_account_id'] ?? null,
                ];

                $resolvedBankName = $manualPaymentRequest->bank_name
                    ?? $manualPaymentRequest->manualBank?->name;

                if (is_string($resolvedBankName) && trim($resolvedBankName) !== '') {
                    $bankMeta['name'] = trim($resolvedBankName);
                }

                $resolvedBeneficiary = $manualPaymentRequest->bank_account_name
                    ?? $manualPaymentRequest->manualBank?->beneficiary_name;

                if (is_string($resolvedBeneficiary) && trim($resolvedBeneficiary) !== '') {
                    $bankMeta['beneficiary_name'] = trim($resolvedBeneficiary);
                }

                $manualMeta['bank'] = array_filter(
                    $bankMeta,
                    static fn ($value) => $value !== null && $value !== ''
                );
            
            }

            $metadata = $validated['metadata'] ?? null;
            if (is_array($metadata) && ! empty($metadata)) {
                $manualMeta['metadata'] = $metadata;
            }

            $manualMeta['idempotency_key'] = $transaction->idempotency_key;

            $meta = $transaction->meta ?? [];
            if (! is_array($meta)) {
                $meta = [];
            }


            $manualBankId = $manualPaymentRequest->manual_bank_id
                ?? ($manualMeta['bank']['id'] ?? null);

            if (is_string($manualBankId) && trim($manualBankId) === '') {
                $manualBankId = null;
            }

            if ($manualBankId !== null && $manualBankId !== '') {
                $normalizedBankId = is_numeric($manualBankId) ? (int) $manualBankId : null;

                if ($normalizedBankId !== null && $normalizedBankId > 0) {
                    data_set($meta, 'payload.manual_bank_id', $normalizedBankId);
                }
            }

            if (isset($bankMeta['name']) && is_string($bankMeta['name']) && $bankMeta['name'] !== '') {
                data_set($meta, 'payload.bank_name', $bankMeta['name']);
            } elseif (is_string($resolvedBankName) && trim($resolvedBankName) !== '') {
                data_set($meta, 'payload.bank_name', trim($resolvedBankName));
            }



            $meta = array_replace_recursive($meta, [
                'manual' => $manualMeta,
                'manual_payment_request' => [
                    'id' => $manualPaymentRequest->getKey(),
                    'status' => $manualPaymentRequest->status,
                ],
                'wallet' => array_filter([
                    'purpose' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                    'manual_payment_request_id' => $manualPaymentRequest->getKey(),
                ]),
            ]);

            $transaction->manual_payment_request_id = $manualPaymentRequest->getKey();
            $transaction->meta = $meta;
            $transaction->save();

            $transaction->loadMissing('manualPaymentRequest.manualBank');
            $manualRequest = $transaction->manualPaymentRequest;

            if ($manualRequest instanceof ManualPaymentRequest) {
                $manualRequest->loadMissing(
                    $this->manualPaymentRequestRelations($manualRequest)
                );
            } else {
                $manualRequest = null;
            }

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
        });
    }


    /**
     * @param array<int, string> $allowedMethodTokens
     * @return array<string, mixed>
     */
    private function paymentMethodOptionsPayload(string $purpose, array $allowedMethodTokens): array
    {
        $presentable = $this->presentPaymentMethodsForPurpose($purpose);

        $methodIds = array_values(array_filter(array_map(
            static fn (array $option) => $option['id'] ?? null,
            $presentable
        )));

        $defaultMethod = $this->resolveDefaultPaymentMethodToken($methodIds);

                $allowedMethodOptions = $this->formatAllowedPaymentMethodOptions(
            $allowedMethodTokens,
            $presentable,
            $defaultMethod
        );

        if ($defaultMethod !== null) {
            foreach ($presentable as &$option) {
                if (($option['id'] ?? null) === $defaultMethod) {
                    $option['is_default'] = true;
                    break;
                }
            }
            unset($option);
        }

        return [
            'purpose' => $purpose,
            'allowed_payment_methods' => $allowedMethodTokens,
            'payment_method_tokens' => $allowedMethodTokens,
            'allowed_payment_method_options' => $allowedMethodOptions,
            'default_payment_method' => $defaultMethod,
            'preferred_payment_method' => $defaultMethod,
            'available_methods' => $presentable,
            'available_payment_methods' => $presentable,
            'payment_methods' => $presentable,
        ];
    }


    /**
     * @param array<int, string> $allowedMethodTokens
     * @param array<int, array<string, mixed>> $presentableOptions
     * @return array<int, array<string, mixed>>
     */
    private function formatAllowedPaymentMethodOptions(
        array $allowedMethodTokens,
        array $presentableOptions,
        ?string $defaultMethod
    ): array {
        $optionsByToken = [];

        foreach ($presentableOptions as $option) {
            $methodId = $option['id'] ?? null;

            if (! is_string($methodId) || $methodId === '') {
                continue;
            }

            $methodId = (string) $methodId;
            $label = isset($option['label']) && is_string($option['label'])
                ? (string) $option['label']
                : $this->paymentMethodLabel($methodId);
            $gateway = isset($option['gateway']) && is_string($option['gateway'])
                ? (string) $option['gateway']
                : $this->paymentMethodGatewayLabel($methodId);

            $tokens = $option['tokens'] ?? [];

            if (! is_array($tokens)) {
                $tokens = [$tokens];
            }

            $tokens = array_values(array_filter($tokens, static fn ($token) => is_string($token) && $token !== ''));

            foreach ($tokens as $token) {
                if (! is_string($token) || $token === '') {
                    continue;
                }

                $token = (string) $token;
                $optionsByToken[$token] = [
                    'token' => $token,
                    'method' => $methodId,
                    'payment_method' => $methodId,
                    'id' => $methodId,
                    'label' => $label,
                    'gateway' => $gateway,
                    'is_default' => $defaultMethod !== null && $methodId === $defaultMethod,
                    'tokens' => $tokens,
                ];
            }
        }

        foreach ($allowedMethodTokens as $token) {
            if (! is_string($token) || $token === '') {
                continue;
            }

            $token = (string) $token;

            if (isset($optionsByToken[$token])) {
                continue;
            }

            $normalized = OrderCheckoutService::normalizePaymentMethod($token);

            if (! is_string($normalized) || $normalized === '') {
                $normalized = $token;
            }

            $normalized = mb_strtolower($normalized);

            $optionsByToken[$token] = [
                'token' => $token,
                'method' => $normalized,
                'payment_method' => $normalized,
                'id' => $normalized,
                'label' => $this->paymentMethodLabel($normalized),
                'gateway' => $this->paymentMethodGatewayLabel($normalized),
                'is_default' => $defaultMethod !== null && $normalized === $defaultMethod,
                'tokens' => [$token],
            ];
        }

        return array_values(array_map(static function (array $option) {
            $option['is_default'] = (bool) ($option['is_default'] ?? false);

            return $option;
        }, $optionsByToken));
    }



    /**
     * @return array<int, array<string, mixed>>
     */
    private function presentPaymentMethodsForPurpose(string $purpose): array
    {
        $supported = $this->supportedPaymentMethodsForPurpose($purpose);
        $aliasesByCanonical = $this->groupPaymentMethodAliasesByCanonical();

        $presentable = [];

        foreach ($supported as $method) {
            if (! is_string($method) || $method === '') {
                continue;
            }

            $method = (string) $method;
            $aliasTokens = $aliasesByCanonical[$method] ?? [];
            $tokens = array_values(array_unique(array_filter(array_merge([$method], $aliasTokens), static fn ($token) => is_string($token) && $token !== '')));

            $presentable[] = array_filter([
                'id' => $method,
                'label' => $this->paymentMethodLabel($method),
                'gateway' => $this->paymentMethodGatewayLabel($method),
                'is_default' => false,
                'tokens' => $tokens,
            ], static fn ($value) => $value !== null);
        }

        return $presentable;
    }

    /**
     * @param array<int, string> $methodIds
     */
    private function resolveDefaultPaymentMethodToken(array $methodIds): ?string
    {
        $methodIds = array_values(array_filter($methodIds, static fn ($value) => is_string($value) && $value !== ''));

        if ($methodIds === []) {
            return null;
        }

        $preferredOrder = [
            'manual_bank',
            'east_yemen_bank',
            'wallet',
            'cash',
        ];

        foreach ($preferredOrder as $preferred) {
            if (in_array($preferred, $methodIds, true)) {
                return $preferred;
            }
        }

        return $methodIds[0] ?? null;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function groupPaymentMethodAliasesByCanonical(): array
    {
        $aliases = $this->extractPaymentMethodAliases();
        $grouped = [];

        foreach ($aliases as $alias => $canonical) {
            if (! is_string($canonical) || $canonical === '') {
                continue;
            }

            if (! isset($grouped[$canonical])) {
                $grouped[$canonical] = [];
            }

            $grouped[$canonical][] = (string) $alias;
        }

        foreach ($grouped as &$entries) {
            $entries = array_values(array_filter($entries, static fn ($value) => is_string($value) && $value !== ''));
        }
        unset($entries);

        return $grouped;
    }

    private function guardServicePaymentIdempotency(ServiceRequest $serviceRequest, string $paymentMethod): ?JsonResponse
    {
        $normalizedMethod = mb_strtolower($paymentMethod);

        $existingTransaction = PaymentTransaction::query()
            ->where('payable_type', ServiceRequest::class)
            ->where('payable_id', $serviceRequest->getKey())
            ->whereIn('payment_gateway', $this->servicePaymentService->paymentGatewayAliases($normalizedMethod))
            ->orderByDesc('id')
            ->first();

        if ($existingTransaction) {
            $status = strtolower((string) $existingTransaction->payment_status);
            $activeStatuses = ['pending', 'processing', 'requires_action', 'requires_payment_method', 'requires_confirmation', 'under_review', 'initiated'];

            if ($status === 'succeed') {
                return response()->json([
                    'message' => __('service_payment_already_completed'),
                    'code' => 'service_payment_already_completed',
                    'errors' => [
                        'service_request_id' => [__('Service payment already completed for this method.')],
                    ],
                ], 409);
            }

            if (in_array($status, $activeStatuses, true)) {
                return response()->json([
                    'message' => __('service_payment_already_in_progress'),
                    'code' => 'service_payment_in_progress',
                    'errors' => [
                        'service_request_id' => [__('A payment attempt is already in progress for this service request.')],
                    ],
                ], 409);
            }
        }

        if ($normalizedMethod === 'manual_bank') {
            $openRequest = ManualPaymentRequest::query()
                ->where('payable_type', ServiceRequest::class)
                ->where('payable_id', $serviceRequest->getKey())
                ->whereIn('status', ManualPaymentRequest::OPEN_STATUSES)
                ->orderByDesc('id')
                ->first();

            if ($openRequest) {
                return response()->json([
                    'message' => __('service_manual_payment_request_open'),
                    'code' => 'service_manual_payment_request_open',
                    'errors' => [
                        'service_request_id' => [__('A manual payment request already exists for this service request.')],
                    ],
                ], 409);
            }
        }

        return null;
    }


    private function ensureServiceRequestNumber(ServiceRequest $serviceRequest): void
    {
        $current = trim((string) $serviceRequest->request_number);

        if ($current !== '') {
            return;
        }

        $reference = trim((string) $this->legalNumberingService->formatOrderNumber($serviceRequest->getKey(), 'services'));

        if ($reference === '') {
            $reference = (string) $serviceRequest->getKey();
        }

        $serviceRequest->request_number = $reference;
        $serviceRequest->save();
    }



    private function paymentMethodLabel(string $method): string
    {
        return match ($method) {
            'manual_bank' => __('الدفع عبر التحويل البنكي اليدوي'),
            'east_yemen_bank' => __('الدفع عبر بنك الشرق اليمني'),
            'wallet' => __('الدفع عبر المحفظة'),
            'cash' => __('الدفع عند الاستلام'),
            default => Str::headline(str_replace(['_', '-'], ' ', (string) $method)),
        };
    }

    private function paymentMethodGatewayLabel(string $method): ?string
    {
        return match ($method) {
            'manual_bank' => __('التحويل البنكي اليدوي'),
            'east_yemen_bank' => __('بنك الشرق اليمني'),
            'wallet' => __('المحفظة'),
            'cash' => __('الدفع عند الاستلام'),
            default => null,
        };
    }


    /**
     * @param array<string, mixed> $payload
     * @param array<int, string> $availableGateways
     */
    private function filterPaymentMethodsByAvailability(
        array $payload,
        array $availableGateways,
        ?string $selectedMethod
    ): array {
        $normalizedAvailable = array_values(array_unique(array_filter(
            array_map([$this, 'normalizeGatewayToken'], $availableGateways),
            static fn ($value) => is_string($value) && $value !== ''
        )));

        if ($normalizedAvailable === []) {
            return $payload;
        }

        $payload['available_gateways'] = $normalizedAvailable;
        $payload['allowed_gateways'] = $normalizedAvailable;

        foreach (['allowed_payment_methods', 'payment_method_tokens'] as $tokenKey) {
            $tokens = isset($payload[$tokenKey]) && is_array($payload[$tokenKey]) ? $payload[$tokenKey] : [];
            $filteredTokens = $this->filterMethodTokensByAvailability($tokens, $normalizedAvailable);

            if ($filteredTokens === []) {
                $filteredTokens = $normalizedAvailable;
            }

            $payload[$tokenKey] = $filteredTokens;
        }

        $payload['allowed_payment_method_options'] = $this->filterMethodOptionEntries(
            isset($payload['allowed_payment_method_options']) && is_array($payload['allowed_payment_method_options'])
                ? $payload['allowed_payment_method_options']
                : [],
            $normalizedAvailable
        );

        foreach (['available_methods', 'available_payment_methods', 'payment_methods'] as $listKey) {
            $payload[$listKey] = $this->filterMethodListEntries(
                isset($payload[$listKey]) && is_array($payload[$listKey]) ? $payload[$listKey] : [],
                $normalizedAvailable
            );
        }

        if ($payload['allowed_payment_method_options'] === []) {
            $payload['allowed_payment_method_options'] = array_map(function (string $method) {
                return [
                    'token' => $method,
                    'method' => $method,
                    'payment_method' => $method,
                    'id' => $method,
                    'label' => $this->paymentMethodLabel($method),
                    'gateway' => $this->paymentMethodGatewayLabel($method),
                    'is_default' => false,
                    'tokens' => [$method],
                ];
            }, $normalizedAvailable);
        }

        foreach (['available_methods', 'available_payment_methods', 'payment_methods'] as $listKey) {
            if ($payload[$listKey] === []) {
                $payload[$listKey] = array_map(function (string $method) {
                    return array_filter([
                        'id' => $method,
                        'label' => $this->paymentMethodLabel($method),
                        'gateway' => $this->paymentMethodGatewayLabel($method),
                        'is_default' => false,
                        'tokens' => [$method],
                    ], static fn ($value) => $value !== null);
                }, $normalizedAvailable);
            }
        }

        $selectedNormalized = $this->normalizeGatewayToken($selectedMethod);

        if ($selectedNormalized === null || ! in_array($selectedNormalized, $normalizedAvailable, true)) {
            $selectedNormalized = $normalizedAvailable[0];
        }

        foreach ($payload['allowed_payment_method_options'] as &$option) {
            if (! is_array($option)) {
                continue;
            }

            $method = $this->normalizeGatewayToken($option['method'] ?? $option['payment_method'] ?? $option['id'] ?? null);
            $option['is_default'] = $method === $selectedNormalized;
        }
        unset($option);

        foreach (['available_methods', 'available_payment_methods', 'payment_methods'] as $listKey) {
            foreach ($payload[$listKey] as &$entry) {
                if (! is_array($entry)) {
                    continue;
                }

                $method = $this->normalizeGatewayToken($entry['id'] ?? null);
                $entry['is_default'] = $method === $selectedNormalized;
            }
            unset($entry);
        }

        if (! in_array($selectedNormalized, $payload['allowed_payment_methods'], true)) {
            $payload['allowed_payment_methods'][] = $selectedNormalized;
            $payload['allowed_payment_methods'] = array_values(array_unique($payload['allowed_payment_methods']));
        }

        if (! in_array($selectedNormalized, $payload['payment_method_tokens'], true)) {
            $payload['payment_method_tokens'][] = $selectedNormalized;
            $payload['payment_method_tokens'] = array_values(array_unique($payload['payment_method_tokens']));
        }

        $payload['default_payment_method'] = $selectedNormalized;
        $payload['preferred_payment_method'] = $selectedNormalized;
        $payload['payment_method'] = $selectedNormalized;
        $payload['selected_payment_method'] = $selectedNormalized;

        return $payload;
    }

    /**
     * @param array<int, mixed> $tokens
     * @param array<int, string> $availableGateways
     * @return array<int, string>
     */
    private function filterMethodTokensByAvailability(array $tokens, array $availableGateways): array
    {
        $filtered = [];

        foreach ($tokens as $token) {
            if (! is_string($token) || $token === '') {
                continue;
            }

            $normalized = $this->normalizeGatewayToken($token);

            if ($normalized !== null && in_array($normalized, $availableGateways, true)) {
                $filtered[] = (string) $token;
            }
        }

        return array_values(array_unique($filtered));
    }

    /**
     * @param array<int, mixed> $options
     * @param array<int, string> $availableGateways
     * @return array<int, array<string, mixed>>
     */
    private function filterMethodOptionEntries(array $options, array $availableGateways): array
    {
        $filtered = [];

        foreach ($options as $option) {
            if (! is_array($option)) {
                continue;
            }

            $method = $this->normalizeGatewayToken($option['method'] ?? $option['payment_method'] ?? $option['id'] ?? null);

            if ($method === null || ! in_array($method, $availableGateways, true)) {
                continue;
            }

            $filtered[] = $option;
        }

        return array_values($filtered);
    }

    /**
     * @param array<int, mixed> $entries
     * @param array<int, string> $availableGateways
     * @return array<int, array<string, mixed>>
     */
    private function filterMethodListEntries(array $entries, array $availableGateways): array
    {
        $filtered = [];

        foreach ($entries as $entry) {
            if (! is_array($entry)) {
                continue;
            }

            $method = $this->normalizeGatewayToken($entry['id'] ?? null);

            if ($method === null || ! in_array($method, $availableGateways, true)) {
                continue;
            }

            $filtered[] = $entry;
        }

        return array_values($filtered);
    }

    private function normalizeGatewayToken($method): ?string
    {
        if (! is_string($method) || trim($method) === '') {
            return null;
        }

        $normalized = OrderCheckoutService::normalizePaymentMethod($method);

        if (is_string($normalized) && $normalized !== '') {
            return mb_strtolower($normalized);
        }

        return mb_strtolower($method);
    }


    /**
     * @return array<int, string>
     */
    private function allowedPaymentMethodTokens(string $purpose): array
    {
        $supported = $this->supportedPaymentMethodsForPurpose($purpose);
        $aliases = $this->extractPaymentMethodAliases();

        $tokens = $supported;

        foreach ($aliases as $alias => $canonical) {
            if (in_array($canonical, $supported, true)) {
                $tokens[] = $alias;
            }
        }

        $tokens = array_filter($tokens, static fn ($token) => is_string($token) && $token !== '');

        return array_values(array_unique(array_map(static fn ($token) => (string) $token, $tokens)));
    }


    private function normalizePaymentMethodForPurpose(string $method, string $purpose): string
    {
        $normalized = OrderCheckoutService::normalizePaymentMethod($method);

        if (! is_string($normalized) || $normalized === '') {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة.'),
            ]);
        }

        $normalized = mb_strtolower($normalized);

        $supported = $this->supportedPaymentMethodsForPurpose($purpose);

        if (! in_array($normalized, $supported, true)) {
            throw ValidationException::withMessages([
                'payment_method' => __('طريقة الدفع غير مدعومة.'),
            ]);
        }

        return $normalized;
    }


    /**
     * @return array<int, string>
     */
    private function supportedPaymentMethodsForPurpose(string $purpose): array
    {
        if ($purpose === 'service') {
            return $this->extractSupportedMethodsFrom(ServicePaymentService::class);
        }

        if ($purpose === 'package') {
            return $this->extractSupportedMethodsFrom(PackagePaymentService::class);
        }


        if ($purpose === 'wifi_plan') {
            return $this->extractSupportedMethodsFrom(WifiPlanPaymentService::class);
        }

        if ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            return ['manual_bank'];
        }

        return $this->extractSupportedMethodsFrom(OrderPaymentService::class);
    }


    /**
     * @return array<string, string>
     */
    private function extractPaymentMethodAliases(): array
    {
        static $aliases;

        if ($aliases !== null) {
            return $aliases;
        }

        $reflection = new ReflectionClass(OrderCheckoutService::class);
        $constants = $reflection->getConstants();
        $rawAliases = $constants['PAYMENT_METHOD_ALIASES'] ?? [];

        if (! is_array($rawAliases)) {
            return $aliases = [];
        }

        $aliases = [];

        foreach ($rawAliases as $alias => $canonical) {
            if (! is_string($alias) || ! is_string($canonical) || $canonical === '') {
                continue;
            }

            $aliases[$alias] = $canonical;
        }

        return $aliases;
    }


    /**
     * @return array<int, string>
     */
    private function extractSupportedMethodsFrom(string $class): array
    {
        $reflection = new ReflectionClass($class);
        $constants = $reflection->getConstants();
        $methods = $constants['SUPPORTED_METHODS'] ?? [];

        if (! is_array($methods)) {
            return [];
        }

        $canonical = array_filter($methods, static fn ($method) => is_string($method) && $method !== '');

        return array_values(array_unique(array_map(static fn ($method) => mb_strtolower((string) $method), $canonical)));
    }

    

    private function normalizePurpose(?string $purpose): string
    {
        if ($purpose === null) {
            return 'order';
        }

        $normalized = strtolower(trim($purpose));

        if ($normalized === '' || $normalized === 'null') {
            return 'order';
        }

        if (str_contains($normalized, 'wallet')) {
            return ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;
        }

        if ($normalized === 'package') {
            return 'package';
        }

        if ($normalized === 'order') {
            return 'order';
        }


        if ($normalized === 'wifi' || $normalized === 'wifi_plan' || str_contains($normalized, 'wifi-plan')) {
            return 'wifi_plan';
        }

        return $normalized;
    }


    private function resolveIdempotencyKey(Request $request): string
    {
        $key = $request->header('Idempotency-Key');

        if (is_array($key)) {
            $key = reset($key);
        }

        $normalized = is_string($key) ? trim($key) : null;

        if ($normalized === null || $normalized === '') {


            throw ValidationException::withMessages([
                'Idempotency-Key' => __('حقل Idempotency-Key مطلوب في الترويسة.'),
            ]);
        }

        return $normalized;
    }
    private function resolveReceiptFile(Request $request): ?UploadedFile
    {
        $receipt = $request->file('receipt');

        if ($receipt instanceof UploadedFile) {
            return $receipt;
        }

        $receiptImage = $request->file('receipt_image');

        return $receiptImage instanceof UploadedFile ? $receiptImage : null;
    }

    private function storeReceiptFile(UploadedFile $file): string
    {
        $directory = 'manual_payments/' . now()->format('Y/m/d');

        try {
            return $file->store($directory, 'public');
        } catch (Throwable) {
            throw ValidationException::withMessages([
                'receipt' => __('تعذر حفظ إيصال التحويل. يرجى المحاولة مرة أخرى.'),
            ]);
        }
    }

    private function resolvePublicUrl(string $path): ?string
    {
        try {
            return Storage::disk('public')->url($path);
        } catch (Throwable) {
            return null;
        }
    }
}
