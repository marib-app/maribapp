<?php

namespace App\Http\Controllers;

use App\Models\Package;
use App\Http\Resources\ManualPaymentRequestResource;
use App\Http\Resources\PaymentTransactionResource;
use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\Service;
use App\Services\Payments\OrderPaymentService;
use App\Services\Payments\PackagePaymentService;
use App\Services\Payments\ServicePaymentService;
use Illuminate\Validation\Rule;
use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Services\OrderCheckoutService;
use ReflectionClass;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;

use App\Models\PaymentConfiguration;
use App\Models\WalletAccount;
use App\Services\Payments\ManualPaymentRequestService;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Throwable;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;




class PaymentController extends Controller
{
    public function __construct(
        private readonly OrderPaymentService $orderPaymentService,
        private readonly PackagePaymentService $packagePaymentService,
        private readonly ServicePaymentService $servicePaymentService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly CreateOrLinkManualPaymentRequest $manualPaymentLinker        
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
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package', 'service', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP])],


            'payment_method' => ['nullable', 'string', 'max:191', Rule::in($allowedMethods)],

            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'bank_id' => ['nullable', 'integer', 'exists:manual_banks,id'],
            'bank_account_id' => ['nullable', 'string', 'max:191'],

            'amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
        ];

        if ($purpose === 'service') {
            $rules['service_id'] = ['required', 'integer', 'exists:services,id'];
        } elseif ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
        } elseif ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            $rules['amount'] = ['required', 'numeric', 'min:0.01'];
            $rules['currency'] = ['required', 'string', 'size:3'];

        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        try {
            $validated = $request->validate($rules);
        } catch (ValidationException $exception) {
            Log::warning('payments.initiate.validation_failed', [
                'errors' => $exception->errors(),
                'purpose' => $purpose,
                'payload' => $request->all(),
            ]);

            throw $exception;
        }

        $selectedMethod = null;

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
            $service = Service::findOrFail($validated['service_id']);

            $transaction = $this->servicePaymentService->initiate(
                $request->user(),
                $service,
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
                    'transaction' => $freshTransaction,
                    'payment_transaction' => $freshTransaction,
                    'service' => [
                        'id' => $service->getKey(),
                        'title' => $service->title,
                        'price' => $service->price,
                        'currency' => $service->currency,
                        'service_uid' => $service->service_uid,
                        'price_note' => $service->price_note,
                    ],
                ]
            );

            if ($freshTransaction?->manualPaymentRequest) {
                $responsePayload['manual_payment_request'] = ManualPaymentRequestResource::make(
                    $freshTransaction->manualPaymentRequest->loadMissing('manualBank')
                )->resolve();
            }

            return response()->json($responsePayload);
        }

        if ($purpose === 'service') {
            $service = Service::findOrFail($validated['service_id']);

            $transaction = $this->servicePaymentService->createManual(
                $request->user(),
                $service,
                $idempotencyKey,
                $validated
            );

            $transaction->loadMissing('manualPaymentRequest.manualBank');

            $manualRequest = $transaction->manualPaymentRequest?->loadMissing('paymentTransaction.payable', 'manualBank');

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

        if ($transaction->payable_type === Service::class) {
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

        if ($purpose === 'service') {
            $rules['service_id'] = ['required', 'integer', 'exists:services,id'];
        } elseif ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];

        } elseif ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            $rules['amount'] = ['required', 'numeric', 'min:0.01'];
            $rules['currency'] = ['required', 'string', 'size:3'];

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
            $service = Service::findOrFail($validated['service_id']);

            $transaction = $this->servicePaymentService->createManual(
                $request->user(),
                $service,
                $idempotencyKey,
                $validated
            );

            $transaction->loadMissing('manualPaymentRequest.manualBank');

            $manualRequest = $transaction->manualPaymentRequest?->loadMissing('paymentTransaction.payable', 'manualBank');

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
            $manualRequest = $transaction->manualPaymentRequest?->loadMissing('payable');

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
