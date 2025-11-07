<?php

namespace App\Http\Controllers;
use App\Enums\OrderStatus as OrderStatusEnum;
use App\Exceptions\CheckoutValidationException;
use App\Services\DepartmentSupportService;
use Illuminate\Support\Str;
use App\Services\DepartmentPolicyService;
use App\Services\OrderCancellationService;
use Illuminate\Support\Facades\URL;
use App\Support\Payments\PaymentLabelService;

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
use Illuminate\Support\Facades\Storage;
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
            ->with([
                'items',
                'latestManualPaymentRequest.manualBank',
                'latestPaymentTransaction.manualPaymentRequest.manualBank',
            ])
            
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
                'payment' => ['nullable'],
                'manual_transfer' => ['nullable'],
                'manual_transfer_receipt' => ['nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],

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

        $paymentPayload = $this->normalizePaymentPayload(
            $this->coerceJsonObject($request->input('payment'))
        );

        if ($paymentPayload !== null) {
            $validated['payment'] = $paymentPayload;
        } else {
            unset($validated['payment']);
        }

        $manualTransferPayload = $this->sanitizeManualTransferPayload($request);
        $manualTransferUploads = [];

        if ($manualTransferPayload !== null) {
            if (array_key_exists('_uploaded_files', $manualTransferPayload)) {
                $manualTransferUploads = $manualTransferPayload['_uploaded_files'] ?? [];
                unset($manualTransferPayload['_uploaded_files']);
            }

            $validated['manual_transfer'] = $manualTransferPayload;
            $validated['payment_method'] = $validated['payment_method'] ?? 'manual_bank';
        } else {
            unset($validated['manual_transfer']);
        }


        $user = $request->user();
        $idempotencyKey = $this->resolveIdempotencyKey($request);

        return DB::transaction(function () use (
            $user,
            $validated,
            $idempotencyKey,
            $paymentPayload,
            $manualTransferPayload,
            $manualTransferUploads
        ) {

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

                $paymentIntent = $this->createDefaultPaymentIntent(
                    $user,
                    $order,
                    $idempotencyKey,
                    [
                        'payment' => $paymentPayload,
                        'manual_transfer' => $manualTransferPayload,
                    ]
                );


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

                $orderPaymentPayload = is_array($order->payment_payload ?? null) ? $order->payment_payload : [];
                $enrichedPayment = data_get($orderPaymentPayload, 'payment');
                if (is_array($enrichedPayment) && $enrichedPayment !== []) {
                    $paymentPayload = $enrichedPayment;
                }

                $enrichedManualTransfer = data_get($orderPaymentPayload, 'manual_transfer');
                if (is_array($enrichedManualTransfer) && $enrichedManualTransfer !== []) {
                    $manualTransferPayload = $enrichedManualTransfer;
                }

            } catch (ValidationException $exception) {
                if ($this->isAddressRequiredException($exception)) {
                    $this->cleanupManualTransferUploads($manualTransferUploads);
                    return $this->addressValidationErrorResponse($exception);
                }

                $this->cleanupManualTransferUploads($manualTransferUploads);
                throw $exception;



            } catch (CheckoutValidationException $exception) {
                $this->cleanupManualTransferUploads($manualTransferUploads);
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

            $paymentIntent = $this->createDefaultPaymentIntent(
                $user,
                $order,
                $idempotencyKey,
                [
                    'payment' => $paymentPayload,
                    'manual_transfer' => $manualTransferPayload,
                ]
            );


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
            'paymentTransactions.manualPaymentRequest.manualBank',
            'latestManualPaymentRequest.manualBank',
            'latestPaymentTransaction.manualPaymentRequest.manualBank',
        
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



    public function invoice(Request $request, int $orderId): Response|JsonResponse
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


        $document = $this->invoicePdfService->renderDocument($order);


        if ($document->hasPdf()) {
            return response($document->pdf, 200, [
                'Content-Type' => 'application/pdf',
                'Content-Disposition' => 'inline; filename="' . $document->fileName . '"',
            ]);
        }

        return response()->json([
            'invoice_url' => $this->buildInvoicePreviewUrl($order, $request),
            'format' => 'html',
            'file_name' => $document->fileName,

        ]);
    }



    private function buildInvoicePreviewUrl(Order $order, Request $request): string
    {
        $parameters = [
            'order' => $order->getKey(),
            'user' => $request->user()->getKey(),
            'issued_at' => now()->timestamp,
        ];

        return URL::temporarySignedRoute(
            'orders.invoice.preview',
            now()->addMinutes(30),
            $parameters
        );
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

    /**
     * @param mixed $value
     */
    private function coerceJsonObject($value): ?array
    {
        if ($value === null || $value === '') {
            return null;
        }

        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if (is_array($value)) {
            return $value;
        }

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '') {
            return null;
        }

        $decoded = json_decode($trimmed, true);

        if (json_last_error() !== JSON_ERROR_NONE || ! is_array($decoded)) {
            return null;
        }

        return $decoded;
    }

    /**
     * @param mixed $value
     */
    private function normalizePaymentPayload($value): ?array
    {
        if ($value === null) {
            return null;
        }

        if (! is_array($value)) {
            return null;
        }

        $method = $this->normalizeNullableString($value['method'] ?? $value['payment_method'] ?? null);
        $bankId = $this->normalizeNullableInt($value['bank_id'] ?? $value['manual_bank_id'] ?? null);
        $bankName = $this->normalizeNullableString($value['bank_name'] ?? null);
        $accountNumber = $this->normalizeNullableString($value['account_number'] ?? null);

        $normalized = array_filter([
            'method' => $method,
            'bank_id' => $bankId,
            'manual_bank_id' => $bankId,
            'bank_name' => $bankName,
            'account_number' => $accountNumber,
        ], static fn ($entry) => $entry !== null && $entry !== '');

        if ($normalized === []) {
            return null;
        }

        if ($bankId === null) {
            unset($normalized['manual_bank_id']);
        }

        return $normalized;
    }

    /**
     * @param mixed $value
     */
    private function sanitizeManualTransferPayload(Request $request): ?array
    {
        $raw = $request->input('manual_transfer');

        if (is_string($raw)) {
            $decoded = json_decode($raw, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $raw = $decoded;
            }
        }

        if (! is_array($raw)) {
            $raw = [];
        }

        $payload = [];

        $senderName = $this->normalizeNullableString(
            $raw['sender_name'] ?? $request->input('manual_transfer_sender_name')
        );
        if ($senderName !== null) {
            $payload['sender_name'] = $senderName;
        }

        $transferReference = $this->normalizeNullableString(
            $raw['transfer_reference']
                ?? $raw['transfer_code']
                ?? $request->input('manual_transfer_transfer_reference')
                ?? $request->input('manual_transfer_transfer_code')
        );
        if ($transferReference !== null) {
            $payload['transfer_reference'] = $transferReference;
        }

        $note = $this->normalizeNullableMultiline(
            $raw['note'] ?? $request->input('manual_transfer_note')
        );
        if ($note !== null) {
            $payload['note'] = $note;
        }

        $storeAccountId = $this->normalizeNullableInt(
            $raw['store_gateway_account_id']
                ?? $raw['store_bank_id']
                ?? $request->input('manual_transfer_store_gateway_account_id')
        );
        if ($storeAccountId !== null) {
            $payload['store_gateway_account_id'] = $storeAccountId;
        }

        $receiptUrl = $this->normalizeNullableString(
            $raw['receipt_url']
                ?? Arr::get($raw, 'receipt.url')
                ?? $request->input('manual_transfer_receipt_url')
        );
        $receiptPath = $this->normalizeNullableString(
            $raw['receipt_path']
                ?? Arr::get($raw, 'receipt.path')
        );
        $receiptDisk = $this->normalizeNullableString(
            $raw['receipt_disk']
                ?? Arr::get($raw, 'receipt.disk')
        );

        $attachments = $this->normalizeManualTransferAttachments($raw['attachments'] ?? null);
        $storedFiles = [];

        foreach (['manual_transfer_receipt', 'manual_transfer_receipt_file'] as $field) {
            if (! $request->hasFile($field)) {
                continue;
            }

            $file = $request->file($field);

            if (! $file || ! $file->isValid()) {
                continue;
            }

            $path = $file->store('manual-transfer-receipts', 'public');
            $url = null;

            try {
                $url = Storage::disk('public')->url($path);
            } catch (\Throwable) {
                $url = null;
            }

            $attachments[] = array_filter([
                'name' => $file->getClientOriginalName(),
                'mime_type' => $file->getClientMimeType(),
                'size' => $file->getSize(),
                'path' => $path,
                'disk' => 'public',
                'url' => $url,
                'uploaded_at' => now()->toIso8601String(),
            ], static fn ($value) => $value !== null && $value !== '');

            $storedFiles[] = [
                'disk' => 'public',
                'path' => $path,
            ];

            $receiptPath ??= $path;
            $receiptDisk ??= 'public';
            $receiptUrl ??= $url;
        }

        if ($attachments !== []) {
            $payload['attachments'] = $attachments;
        }

        if ($receiptUrl !== null) {
            $payload['receipt_url'] = $receiptUrl;
        }

        if ($receiptPath !== null) {
            $payload['receipt_path'] = $receiptPath;
        }

        if ($receiptDisk !== null) {
            $payload['receipt_disk'] = $receiptDisk;
        }

        if ($receiptPath !== null || $receiptUrl !== null) {
            $payload['receipt'] = array_filter([
                'path' => $receiptPath,
                'disk' => $receiptDisk ?? 'public',
                'url' => $receiptUrl,
            ], static fn ($value) => $value !== null && $value !== '');
        }

        if ($storedFiles !== []) {
            $payload['_uploaded_files'] = $storedFiles;
        }

        return $payload === [] ? null : $payload;
    }

    /**
     * @param array<int, array<string, mixed>> $uploads
     */
    private function cleanupManualTransferUploads(array $uploads): void
    {
        foreach ($uploads as $upload) {
            $path = $this->normalizeNullableString($upload['path'] ?? null);
            $disk = $this->normalizeNullableString($upload['disk'] ?? null) ?? 'public';

            if ($path === null) {
                continue;
            }

            try {
                Storage::disk($disk)->delete($path);
            } catch (\Throwable) {
                // ignore cleanup failures
            }
        }
    }

    private function normalizeManualTransferPayload($value): ?array
    {
        if ($value === null) {
            return null;
        }

        if (! is_array($value)) {
            return null;
        }

        $senderName = $this->normalizeNullableString($value['sender_name'] ?? null);
        $transferReference = $this->normalizeNullableString(
            $value['transfer_reference']
                ?? $value['transfer_code']
                ?? $value['reference']
        );
        $note = $this->normalizeNullableMultiline($value['note'] ?? null);

        $normalized = [];


        if ($senderName !== null) {
            $normalized['sender_name'] = $senderName;
        }

        if ($transferReference !== null) {
            $normalized['transfer_reference'] = $transferReference;
        }

        if ($note !== null) {
            $normalized['note'] = $note;
        }

        $receiptData = $value['receipt'] ?? null;
        $receiptUrl = null;
        $receiptPath = $this->normalizeNullableString($value['receipt_path'] ?? null);
        $receiptDisk = $this->normalizeNullableString($value['receipt_disk'] ?? null);
        $providedUrl = $this->normalizeNullableString($value['url'] ?? null);

        if (is_array($receiptData)) {
            $sanitizedReceipt = $this->normalizeManualTransferArrayValue($receiptData);

            if ($sanitizedReceipt !== []) {
                $normalized['receipt'] = $sanitizedReceipt;
                $receiptUrl = $this->normalizeNullableString($sanitizedReceipt['receipt_url'] ?? $sanitizedReceipt['url'] ?? null);

                $receiptPathFromReceipt = $this->normalizeNullableString($sanitizedReceipt['receipt_path'] ?? $sanitizedReceipt['path'] ?? null);
                if ($receiptPathFromReceipt !== null) {
                    $receiptPath = $receiptPathFromReceipt;
                }

                $receiptDiskFromReceipt = $this->normalizeNullableString($sanitizedReceipt['receipt_disk'] ?? $sanitizedReceipt['disk'] ?? null);
                if ($receiptDiskFromReceipt !== null) {
                    $receiptDisk = $receiptDiskFromReceipt;
                }

                if (! isset($normalized['attachments']) && isset($sanitizedReceipt['attachments'])) {
                    $receiptAttachments = $this->normalizeManualTransferAttachments($sanitizedReceipt['attachments']);
                    if ($receiptAttachments !== []) {
                        $normalized['attachments'] = $receiptAttachments;
                    }
                }
            }
        } else {
            $receiptString = $this->normalizeNullableString($receiptData);
            if ($receiptString !== null) {
                $normalized['receipt'] = $receiptString;
                $receiptUrl = $receiptString;
            }
        }

        $directAttachments = $this->normalizeManualTransferAttachments($value['attachments'] ?? null);
        if ($directAttachments !== []) {
            $normalized['attachments'] = $directAttachments;
        }

        $explicitReceiptUrl = $this->normalizeNullableString(
            $value['receipt_url']
                ?? Arr::get($value, 'receipt.url')
                ?? Arr::get($value, 'receipt.receipt_url')
        );

        if ($explicitReceiptUrl !== null) {
            $receiptUrl = $explicitReceiptUrl;
        }

        if ($receiptUrl !== null) {
            $normalized['receipt_url'] = $receiptUrl;

            if (! isset($normalized['url'])) {
                $normalized['url'] = $receiptUrl;
            }

            if (! isset($normalized['receipt']) || $normalized['receipt'] === []) {
                $normalized['receipt'] = $receiptUrl;
            }
        }

        if ($providedUrl !== null) {
            $normalized['url'] = $providedUrl;

            if (! isset($normalized['receipt_url'])) {
                $normalized['receipt_url'] = $providedUrl;
            }

            if (! isset($normalized['receipt'])) {
                $normalized['receipt'] = $providedUrl;
            }
        }

        if ($receiptPath !== null) {
            $normalized['receipt_path'] = $receiptPath;
        }

        if ($receiptDisk !== null) {
            $normalized['receipt_disk'] = $receiptDisk;
        }

        foreach ($value as $rawKey => $rawEntry) {
            if (! is_int($rawKey) && ! is_string($rawKey)) {
                continue;
            }

            $key = is_int($rawKey) ? (string) $rawKey : $rawKey;

            if (in_array($key, ['sender_name', 'transfer_reference', 'transfer_code', 'note', 'receipt', 'receipt_url', 'url', 'receipt_path', 'receipt_disk', 'attachments'], true)) {
                continue;
            }

            if (array_key_exists($key, $normalized)) {
                continue;
            }

            if ($rawEntry === null) {
                continue;
            }

            if (is_string($rawEntry)) {
                $trimmed = trim($rawEntry);
                if ($trimmed === '') {
                    continue;
                }

                $normalized[$key] = $trimmed;
                continue;
            }

            if (is_array($rawEntry)) {
                $sanitized = $this->normalizeManualTransferArrayValue($rawEntry);
                if ($sanitized !== []) {
                    $normalized[$key] = $sanitized;
                }

                continue;
            }

            if (is_scalar($rawEntry)) {
                $normalized[$key] = $rawEntry;
            }

        }

        if ($transferReference !== null) {
            $normalized['transfer_code'] = $transferReference;
        }

        return $normalized === [] ? null : $normalized;
    }

    /**
     * @param mixed $value
     * @return array<int, array<int|string, mixed>>
     */
    private function normalizeManualTransferAttachments($value): array
    {
        if ($value === null) {
            return [];
        }

        if (is_array($value) && Arr::isAssoc($value)) {
            $value = [$value];
        }

        if (! is_iterable($value)) {
            return [];
        }

        $normalized = [];

        foreach ($value as $attachment) {
            if (! is_array($attachment)) {
                continue;
            }

            $sanitized = [];

            foreach ($attachment as $rawKey => $rawEntry) {
                if (! is_int($rawKey) && ! is_string($rawKey)) {
                    continue;
                }

                $key = is_int($rawKey) ? (string) $rawKey : $rawKey;

                if ($rawEntry === null) {
                    continue;
                }

                if (is_string($rawEntry)) {
                    $trimmed = trim($rawEntry);
                    if ($trimmed === '') {
                        continue;
                    }

                    $sanitized[$key] = $trimmed;
                    continue;
                }

                if (is_scalar($rawEntry) || is_array($rawEntry)) {
                    $sanitized[$key] = $rawEntry;
                }
            }

            if ($sanitized !== []) {
                $normalized[] = $sanitized;
            }
        }

        return $normalized;
    }

    /**
     * @param mixed $value
     * @return array<int|string, mixed>
     */
    private function normalizeManualTransferArrayValue($value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $normalized = [];

        foreach ($value as $rawKey => $rawEntry) {
            if (! is_int($rawKey) && ! is_string($rawKey)) {
                continue;
            }

            $key = is_int($rawKey) ? (string) $rawKey : $rawKey;

            if ($rawEntry === null) {
                continue;
            }

            if (is_string($rawEntry)) {
                $trimmed = trim($rawEntry);
                if ($trimmed === '') {
                    continue;
                }

                $normalized[$key] = $trimmed;
                continue;
            }

            if (is_array($rawEntry)) {
                if ($key === 'attachments') {
                    $attachments = $this->normalizeManualTransferAttachments($rawEntry);
                    if ($attachments !== []) {
                        $normalized[$key] = $attachments;
                    }

                    continue;
                }

                $nested = $this->normalizeManualTransferArrayValue($rawEntry);
                if ($nested !== []) {
                    $normalized[$key] = $nested;
                }

                continue;
            }

            if (is_scalar($rawEntry)) {
                $normalized[$key] = $rawEntry;
            }
        }

        return $normalized;
    }

    private function buildDefaultPaymentInitiationContext(
        Order $order,
        array $paymentContext,
        array $manualTransferContext,
        string $idempotencyKey
    ): array {
        $context = [];

        if ($paymentContext !== []) {
            $context['payment'] = $paymentContext;
        }

        if ($manualTransferContext !== []) {
            $context['manual_transfer'] = $manualTransferContext;
        }

        $bankId = $paymentContext['bank_id'] ?? $paymentContext['manual_bank_id'] ?? null;

        if ($bankId !== null) {
            $context['bank_id'] = $bankId;
            $context['manual_bank_id'] = $bankId;
        }

        if (isset($paymentContext['bank_name'])) {
            $context['bank_name'] = $paymentContext['bank_name'];
        }

        if (isset($paymentContext['account_number'])) {
            $context['account_number'] = $paymentContext['account_number'];
        }

        if (isset($manualTransferContext['sender_name'])) {
            $context['sender_name'] = $manualTransferContext['sender_name'];
        }

        if (isset($manualTransferContext['transfer_reference'])) {
            $reference = $manualTransferContext['transfer_reference'];
            $context['reference'] = $reference;
            $context['transfer_reference'] = $reference;
            $context['transfer_code'] = $reference;
        }

        if (isset($manualTransferContext['note'])) {
            $context['note'] = $manualTransferContext['note'];
        }

        if ($manualTransferContext !== []) {
            $context['metadata'] = array_filter([
                'manual_transfer' => $manualTransferContext,
                'transfer' => $manualTransferContext,
            ]);
        }

        $context['idempotency_key'] = $idempotencyKey;

        return $context;
    }

    /**
     * @param mixed $value
     */
    private function normalizeNullableString($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if ($value === null) {
            return null;
        }

        if (is_bool($value) || is_array($value)) {
            return null;
        }

        if (! is_string($value)) {
            if (is_numeric($value)) {
                $value = (string) $value;
            } else {
                return null;
            }
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    /**
     * @param mixed $value
     */
    private function normalizeNullableMultiline($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if ($value === null) {
            return null;
        }

        if (is_bool($value) || is_array($value)) {
            return null;
        }

        if (! is_string($value)) {
            if (is_numeric($value)) {
                return (string) $value;
            }

            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $value;
    }

    /**
     * @param mixed $value
     */
    private function normalizeNullableInt($value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_int($value)) {
            return $value > 0 ? $value : null;
        }

        if (is_numeric($value) && ! is_bool($value)) {
            $intValue = (int) $value;

            return $intValue > 0 ? $intValue : null;
        }

        return null;
    }
    private function createDefaultPaymentIntent(
        User $user,
        Order $order,
        string $idempotencyKey,
        array $context = []
    ): ?PaymentTransaction
    
    
    {
        $defaultIntent = $order->payment_payload['default_intent'] ?? [];
        $existingTransactionId = data_get($defaultIntent, 'transaction_id');
        $intentIdempotencyKey = data_get($defaultIntent, 'idempotency_key');
        $existingTransaction = null;
        $shouldForceUniqueIdempotencyKey = false;
        $existingTransactionIsReusable = false;
        $logMethod = null;


        $paymentContext = $this->normalizePaymentPayload($context['payment'] ?? null) ?? [];
        $manualTransferContext = $this->normalizeManualTransferPayload($context['manual_transfer'] ?? null) ?? [];
        $initiationContext = $this->buildDefaultPaymentInitiationContext(
            $order,
            $paymentContext,
            $manualTransferContext,
            $idempotencyKey
        );


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


                $existingTransactionIsReusable = true;
            }

        }

        $transaction = null;

        try {
            if ($existingTransactionIsReusable && $existingTransaction !== null) {
                $logMethod = $existingTransaction->payment_gateway;

                if ($existingTransaction->payment_gateway === 'wallet'




                    && $existingTransaction->payment_status !== 'succeed') {
                    $intentIdempotencyKey = $intentIdempotencyKey
                        ?: (string) ($existingTransaction->idempotency_key ?? $idempotencyKey);


                    $existingTransaction = $this->confirmDefaultWalletPaymentIntent(
                        $user,
                        $order,
                        $existingTransaction,
                        $intentIdempotencyKey
                    );



                }

                return $existingTransaction;
            }
        


        $method = $this->resolveDefaultPaymentMethod($order);

            if (! is_string($method) || $method === '') {
                return null;
            }

            $logMethod = $method;

            $idempotencySuffix = $shouldForceUniqueIdempotencyKey ? Str::uuid()->toString() : null;
            $intentIdempotencyKey = $this->buildDefaultPaymentIdempotencyKey(
                $order,
                $idempotencyKey,
                $method,
                $idempotencySuffix
            );


            $initiationContext['idempotency_key'] = $intentIdempotencyKey;


            $transaction = $this->orderPaymentService->initiate(
                $user,
                $order,
                $method,
                $intentIdempotencyKey,
                $initiationContext
            );

            if ($transaction->payment_gateway === 'wallet') {
                $logMethod = $transaction->payment_gateway;


                $transaction = $this->confirmDefaultWalletPaymentIntent(
                    $user,
                    $order,
                    $transaction,
                    $intentIdempotencyKey
                );
            }

        } catch (ValidationException $exception) {
            Log::info('orders.default_payment_intent.skipped', [
                'order_id' => $order->getKey(),
                'user_id' => $user->getKey(),
                'method' => $logMethod,
                'message' => $exception->getMessage(),
            ]);

            return null;
        } catch (Throwable $throwable) {
            Log::warning('orders.default_payment_intent.failed', [
                'order_id' => $order->getKey(),
                'user_id' => $user->getKey(),
                'method' => $logMethod,
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


    private function confirmDefaultWalletPaymentIntent(
        User $user,
        Order $order,
        PaymentTransaction $transaction,
        string $intentIdempotencyKey
    ): PaymentTransaction {
        $confirmationData = [
            'payment_method' => $transaction->payment_gateway,
            'currency' => strtoupper((string) ($transaction->currency ?? config('app.currency', 'SAR'))),
        ];

        try {
            return $this->orderPaymentService->confirm(
                $user,
                $transaction,
                $intentIdempotencyKey,
                $confirmationData
            );
        } catch (Throwable $throwable) {
            $this->handleWalletIntentFailure($order, $transaction, $throwable);
        }
    }

    private function handleWalletIntentFailure(
        Order $order,
        PaymentTransaction $transaction,
        Throwable $throwable
    ): never {
        $this->cancelDefaultPaymentIntent($order, $transaction);

        Log::warning('orders.default_payment_intent.wallet_confirm_failed', [
            'order_id' => $order->getKey(),
            'transaction_id' => $transaction->getKey(),
            'user_id' => $transaction->user_id,
            'message' => $throwable->getMessage(),
        ]);

        if ($throwable instanceof ValidationException) {
            throw $throwable;
        }

        throw ValidationException::withMessages([
            'payment' => __('تعذر خصم مبلغ المحفظة.'),
        ]);
    }

    private function cancelDefaultPaymentIntent(Order $order, PaymentTransaction $transaction): void
    {
        if ($transaction->payment_status === 'pending') {
            $transaction->forceFill([
                'payment_status' => 'cancelled',
            ])->save();
        }

        $payload = $order->payment_payload ?? [];

        if (
            isset($payload['default_intent']['transaction_id'])
            && (int) $payload['default_intent']['transaction_id'] === $transaction->getKey()
        ) {
            unset($payload['default_intent']);

            $order->forceFill([
                'payment_payload' => $payload,
            ])->save();
        }
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
                $transaction = $this->createDefaultPaymentIntent(
                    $user,
                    $order,
                    $refreshIdempotencyKey,
                    [
                        'payment' => data_get($order->payment_payload, 'payment'),
                        'manual_transfer' => data_get($order->payment_payload, 'manual_transfer'),
                    ]
                );
                
                
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

        $labelDefaults = [
            'gateway_key' => null,
            'gateway_label' => null,
            'bank_name' => null,
            'channel_label' => null,
            'bank_label' => null,
        ];

        if ($transaction instanceof PaymentTransaction) {
            $transaction->loadMissing('manualPaymentRequest.manualBank');
            $labels = array_merge($labelDefaults, PaymentLabelService::forPaymentTransaction($transaction));
        } else {
            $labels = array_merge($labelDefaults, $order->resolvePaymentGatewayLabels());
        }


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

            'gateway_key' => $labels['gateway_key'],
            'gateway_label' => $labels['gateway_label'],
            'channel_label' => $labels['channel_label'] ?? $labels['gateway_label'],
            'bank_name' => $labels['bank_name'],
            'bank_label' => $labels['bank_name'],



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
