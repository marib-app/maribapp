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
use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Services\OrderCheckoutService;
use ReflectionClass;

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
class PaymentController extends Controller
{
    public function __construct(
        private readonly OrderPaymentService $orderPaymentService,
        private readonly PackagePaymentService $packagePaymentService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService
        
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

        $rawMethod = $request->input('payment_method', 'manual');
        $normalizedForRequest = OrderCheckoutService::normalizePaymentMethod(is_string($rawMethod) ? $rawMethod : null);
        $sanitizedMethod = is_string($normalizedForRequest) && $normalizedForRequest !== ''
            ? $normalizedForRequest
            : (is_string($rawMethod) ? trim($rawMethod) : 'manual');

        $request->merge(['payment_method' => $sanitizedMethod]);

        $allowedMethods = $this->allowedPaymentMethodTokens($purpose);



        $rules = [
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP])],


            'payment_method' => ['required', 'string', 'max:191', Rule::in($allowedMethods)],

            'notes' => ['nullable', 'string'],
            'metadata' => ['nullable', 'array'],
            'bank_id' => ['nullable', 'integer', 'exists:manual_banks,id'],
            'bank_account_id' => ['nullable', 'string', 'max:191'],

            'amount' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
        ];

        if ($purpose === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
        } elseif ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            $rules['amount'] = ['required', 'numeric', 'min:0.01'];
            $rules['currency'] = ['required', 'string', 'size:3'];

        } else {
            $rules['order_id'] = ['required', 'integer', 'exists:orders,id'];
        }

        $validated = $request->validate($rules);

        $validated['payment_method'] = $this->normalizePaymentMethodForPurpose($validated['payment_method'], $purpose);

        if (!isset($validated['note']) && $request->filled('notes')) {
            $validated['note'] = $request->input('notes');
        }

        if (!isset($validated['metadata']) && $request->has('metadata') && is_array($request->input('metadata'))) {
            $validated['metadata'] = $request->input('metadata');
        }



        if ($purpose === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP) {
            return $this->initiateWalletTopUp($request, $validated, $idempotencyKey);
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
            'purpose' => ['nullable', 'string', Rule::in(['order', 'package', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP])],


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

        if ($purpose === 'package') {
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

            $manualPaymentRequest = $this->manualPaymentRequestService->createOrUpdateForManualTransaction(
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