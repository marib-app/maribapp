<?php

namespace App\Http\Controllers\Api;
use App\Models\PaymentTransaction;
use App\Models\ManualPaymentRequest;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use App\Http\Controllers\Controller;
use App\Models\Service;
use App\Services\LegalNumberingService;
use App\Models\ServiceRequest;
use App\Services\Payments\ServicePaymentService;
use App\Services\ServiceCustomFieldSubmissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use Illuminate\Support\Str;

use JsonException;
use App\Support\Payments\PaymentGatewayCurrencyPolicy;

class ServiceRequestController extends Controller
{
    public function __construct(
        private ServiceCustomFieldSubmissionService $submissionService,
        private ServicePaymentService $servicePaymentService,
        private LegalNumberingService $legalNumberingService,
        
        ) {
    }

    private function transactionMatchesServiceRequest(?PaymentTransaction $transaction, ServiceRequest $serviceRequest, Service $service): bool
    {
        if (! $transaction) {
            return false;
        }

        if ($transaction->payable_type === ServiceRequest::class && (int) $transaction->payable_id === $serviceRequest->getKey()) {
            return true;
        }

        if ($transaction->payable_type === Service::class && (int) $transaction->payable_id === $service->getKey()) {
            return true;
        }

        $metaRequestId = data_get($transaction->meta, 'service.request_id');
        if ($metaRequestId !== null && (int) $metaRequestId === $serviceRequest->getKey()) {
            return true;
        }

        return false;
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user() ?? Auth::user();

        if (!$user) {
            return response()->json([
                'message' => __('Unauthenticated.'),
            ], 401);
        }

        $validated = $request->validate([
            'status' => ['sometimes', 'string', Rule::in(['review', 'approved', 'rejected', 'all'])],
            'category_id' => ['sometimes', 'integer'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = ServiceRequest::query()
            ->with(['service:id,title,category_id'])
            ->where('user_id', $user->getKey())
            ->orderByDesc('created_at');

        $status = $validated['status'] ?? null;
        if ($status && $status !== 'all') {
            $query->where('status', $status);
        }

        if (array_key_exists('category_id', $validated)) {
            $query->whereHas('service', static function ($q) use ($validated): void {
                $q->where('category_id', $validated['category_id']);
            });
        }

        $perPage = $validated['per_page'] ?? 15;

        $paginator = $query->paginate($perPage);

        $items = $paginator->getCollection()
            ->map(fn(ServiceRequest $serviceRequest): array => $this->transformRequest($serviceRequest))
            ->values();

        return response()->json([
            'data' => $items,
            'meta' => [
                'total' => $paginator->total(),
                'per_page' => $paginator->perPage(),
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
            ],
        ]);
    }


    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'service_id' => ['required', 'integer'],
            'service_request_id' => ['sometimes', 'integer'],
            'note' => ['nullable', 'string'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => __('The given data was invalid.'),
                'errors' => $validator->errors()->toArray(),
            ], 422);
        }

        $service = Service::query()
            ->with('serviceCustomFields')
            ->find($request->integer('service_id'));

        if (!$service) {
            return response()->json([
                'message' => __('Service not found.'),
            ], 404);
        }

        if (!$service->status) {
            return response()->json([
                'message' => __('This service is not available.'),
            ], 403);
        }

        $user = $request->user() ?? Auth::user();

        if (!$user) {
            return response()->json([
                'message' => __('Unauthenticated.'),
            ], 401);
        }

        if ($service->direct_to_user && (int) $service->direct_user_id !== (int) $user->id) {
            return response()->json([
                'message' => __('You are not allowed to request this service.'),
            ], 403);
        }

        $serviceRequest = null;
        if ($request->filled('service_request_id')) {
            $serviceRequest = ServiceRequest::query()
                ->withTrashed()
                ->where('user_id', $user->id)
                ->find($request->integer('service_request_id'));

            if (! $serviceRequest || (int) $serviceRequest->service_id !== (int) $service->id) {
                return response()->json([
                    'message' => __('The given data was invalid.'),
                    'errors' => [
                        'service_request_id' => [__('Invalid service request identifier.')],
                    ],
                ], 422);
            }
        }


        $customFields = $request->input('custom_fields', []);

        if (is_string($customFields)) {
            try {
                $customFields = json_decode($customFields, true, 512, JSON_THROW_ON_ERROR);
            } catch (JsonException) {
                return response()->json([
                    'message' => __('The given data was invalid.'),
                    'errors' => [
                        'custom_fields' => [__('Invalid custom_fields payload.')],
                    ],
                ], 422);
            }
        }

        if (!is_array($customFields)) {
            return response()->json([
                'message' => __('The given data was invalid.'),
                'errors' => [
                    'custom_fields' => [__('Custom fields must be an array.')],
                ],
            ], 422);
        }

        $customFieldFiles = $request->file('custom_field_files', []);
        if (!is_array($customFieldFiles)) {
            $customFieldFiles = [];
        }

        try {
            $payload = $this->submissionService->collectRequestPayload($service, $customFields, $customFieldFiles);
        } catch (ValidationException $e) {
            return response()->json([
                'message' => __('The given data was invalid.'),
                'errors' => $e->errors(),
            ], 422);
        }

        if (! $serviceRequest) {
            $serviceRequest = ServiceRequest::query()
                ->where('service_id', $service->id)
                ->where('user_id', $user->id)
                ->whereNull('payment_transaction_id')
                ->where(function ($query) {
                    $query->whereNull('payment_status')
                        ->orWhereNotIn('payment_status', ['paid']);
                })
                ->orderByDesc('id')
                ->first();
        }

        if (! $serviceRequest) {
            $serviceRequest = new ServiceRequest();
            $serviceRequest->service_id = $service->id;
            $serviceRequest->user_id = $user->id;
            $serviceRequest->request_number = $this->generateRequestNumber($serviceRequest);
        } elseif ($serviceRequest->trashed()) {
            $serviceRequest->restore();
        }

        if (! $serviceRequest->request_number) {
            $serviceRequest->request_number = $this->generateRequestNumber($serviceRequest);
        }

        $serviceRequest->status = 'review';
        $serviceRequest->payload = $payload;

        if ($request->has('note')) {
            $serviceRequest->note = $request->filled('note')
                ? (trim((string) $request->input('note')) ?: null)
                : null;
        }

        if (! $serviceRequest->exists) {
            $serviceRequest->payment_status = 'pending';
            $serviceRequest->save();
        }

        $resolvedTransaction = null;

        if ($service->is_paid) {
            $paymentTransactionId = $request->input('payment_transaction_id');

            if ($paymentTransactionId) {
                $resolvedTransaction = PaymentTransaction::query()
                    ->whereKey((int) $paymentTransactionId)
                    ->where('user_id', $user->id)
                    ->first();

                if (! $resolvedTransaction || ! $this->transactionMatchesServiceRequest($resolvedTransaction, $serviceRequest, $service)) {
                    return response()->json([
                        'message' => __('تعذّر العثور على معاملة الدفع المحددة.'),
                        'errors' => [
                            'payment_transaction_id' => [__('معاملة الدفع غير صالحة أو لا تخص هذا الطلب.')],
                        ],
                    ], 422);
                }

                if (mb_strtolower((string) $resolvedTransaction->payment_status) !== 'succeed') {
                    return response()->json([
                        'message' => __('يحتاج الدفع إلى تأكيد قبل إرسال الطلب.'),
                        'code' => 'payment_not_confirmed',
                        'payment_required' => true,
                        'payable_type' => ServiceRequest::class,
                        'payable_id' => $serviceRequest->getKey(),
                    ], 422);
                }
            } else {
                $candidateTransactions = PaymentTransaction::query()
                    ->where('user_id', $user->id)
                    ->where('payment_status', 'succeed')
                    ->orderByDesc('id')
                    ->limit(10)
                    ->get();

                $resolvedTransaction = $candidateTransactions->first(function (PaymentTransaction $transaction) use ($serviceRequest, $service) {
                    return $this->transactionMatchesServiceRequest($transaction, $serviceRequest, $service);
                });
            }

            if (! $resolvedTransaction) {
                if ($serviceRequest->payment_status !== 'paid') {
                    $serviceRequest->payment_status = 'pending';
                    $serviceRequest->payment_transaction_id = null;
                    $serviceRequest->save();
                }

                $manualRequest = ManualPaymentRequest::query()
                    ->with('paymentTransaction')
                    ->where('payable_type', ServiceRequest::class)
                    ->where('payable_id', $serviceRequest->getKey())
                    ->whereIn('status', ManualPaymentRequest::OPEN_STATUSES)
                    ->orderByDesc('id')
                    ->first();

                $latestTransaction = $manualRequest?->paymentTransaction;

                if (! $latestTransaction && $serviceRequest->payment_transaction_id) {
                    $latestTransaction = PaymentTransaction::query()
                        ->whereKey($serviceRequest->payment_transaction_id)
                        ->first();
                }


                try {
                    $quote = $this->servicePaymentService->resolvePaymentQuote($service);
                } catch (ValidationException $exception) {
                    $quote = [
                        'amount' => max(0.0, (float) ($service->price ?? 0.0)),
                        'currency' => strtoupper((string) ($service->currency ?: config('app.currency', 'YER'))),
                    ];

                    Log::warning('service_request.payment_quote_fallback', [
                        'service_id' => $service->getKey(),
                        'service_request_id' => $serviceRequest->getKey(),
                        'user_id' => $user->getKey(),
                        'message' => $exception->getMessage(),
                    ]);
                }

                $availableGateways = $this->servicePaymentService->determineAvailableGateways(
                    $user,
                    $serviceRequest,
                    $service,
                    ['amount' => $quote['amount'], 'currency' => $quote['currency']]
                );

                $manualAllowed = in_array('manual_bank', $availableGateways, true);
                $manualPaymentRequestId = $manualAllowed ? $manualRequest?->getKey() : null;

                if (! $manualAllowed) {
                    $latestTransaction = null;
                }



                return response()->json([
                    'message' => __('Payment is required to request this service.'),
                    'code' => 'payment_required',
                    'payment_required' => true,
                    'payable_type' => ServiceRequest::class,
                    'payable_id' => $serviceRequest->getKey(),
                    'service_request_id' => $serviceRequest->getKey(),
                    'service_id' => $service->id,
                    'service_uid' => $service->service_uid,
                    'service_title' => $service->title,
                    'amount' => $quote['amount'],
                    'currency' => $quote['currency'],
                    'price_note' => $service->price_note,
                    'allowed_gateways' => $availableGateways,
                    'available_gateways' => $availableGateways,
                    'manual_payment_request_id' => $manualPaymentRequestId,
                    'payment_transaction_id' => $latestTransaction?->getKey(),
                    'payment_intent_id' => $latestTransaction?->idempotency_key,
                    'payment_transaction_status' => $latestTransaction?->payment_status,
                    'recommended_idempotency_key' => (string) Str::orderedUuid(),
                ], 402);
            }
        }

        if (! $serviceRequest->exists || $serviceRequest->wasChanged() || $serviceRequest->isDirty()) {
            $serviceRequest->save();
        }

        if ($resolvedTransaction instanceof PaymentTransaction) {
            $serviceRequest->payment_status = 'paid';
            $serviceRequest->payment_transaction_id = $resolvedTransaction->getKey();
            $serviceRequest->save();

            $meta = $resolvedTransaction->meta ?? [];
            if (! is_array($meta)) {
                $meta = [];
            }

            data_set($meta, 'service.request_id', $serviceRequest->getKey());

            $resolvedTransaction->payable_type = ServiceRequest::class;
            $resolvedTransaction->payable_id = $serviceRequest->getKey();
            $resolvedTransaction->meta = $meta;

            if ($resolvedTransaction->isDirty()) {
                $resolvedTransaction->save();
            }

            if ($resolvedTransaction->manualPaymentRequest instanceof ManualPaymentRequest) {
                $manual = $resolvedTransaction->manualPaymentRequest;
                if ($manual->payable_type !== ServiceRequest::class || (int) $manual->payable_id !== $serviceRequest->getKey()) {
                    $manual->payable_type = ServiceRequest::class;
                    $manual->payable_id = $serviceRequest->getKey();
                    $manual->save();
                }
            }
        }


        $deeplink = route('service.requests.review', $serviceRequest->getKey());
        $notificationPayload = [
            'service_request_id' => $serviceRequest->getKey(),
            'status' => $serviceRequest->status,
            'service_id' => $serviceRequest->service_id,
        ];



        try {
            $tokens = UserFcmToken::query()
                ->where('user_id', $user->id)
                ->pluck('fcm_token')
                ->filter()
                ->unique()
                ->values()
                ->all();

            if (!empty($tokens)) {
                $notificationResponse = NotificationService::sendFcmNotification(
                    $tokens,
                    'طلبك قيد المراجعة',
                    'تم إرسال طلبك بنجاح. طلبك الآن قيد المراجعة وسيتم التواصل معك فور مراجعة الطلب .',
                    'service-request-created',
                    [
                        'data' => json_encode($notificationPayload, JSON_UNESCAPED_UNICODE),

                        'deeplink' => $deeplink,
                        'click_action' => $deeplink,
                    ]
                );

                if (is_array($notificationResponse) && ($notificationResponse['error'] ?? false)) {
                    Log::warning('service_requests.create_notification_failed', [
                        'service_request_id' => $serviceRequest->getKey(),
                        'user_id' => $user->id,
                        'response_message' => $notificationResponse['message'] ?? null,
                        'response_details' => $notificationResponse['details'] ?? null,
                        'response_code' => $notificationResponse['code'] ?? null,
                    ]);
                }
            }
        } catch (\Throwable $exception) {
            Log::error('service_requests.create_notification_exception', [
                'service_request_id' => $serviceRequest->getKey(),
                'user_id' => $user->id,
                'error' => $exception->getMessage(),
                'exception_class' => get_class($exception),
            ]);
        }



        $providerIds = null;

        try {
            $providerIds = collect([
                $service->owner_id,
                $service->direct_to_user ? $service->direct_user_id : null,
            ])
                ->filter(fn($id) => $id !== null)
                ->map(fn($id) => (int) $id)
                ->unique()
                ->reject(fn(int $id) => $id === (int) $user->id)
                ->values();

            if ($providerIds->isNotEmpty()) {
                $providerTokens = UserFcmToken::query()
                    ->whereIn('user_id', $providerIds->all())
                    ->pluck('fcm_token')
                    ->filter()
                    ->unique()
                    ->values()
                    ->all();

                if (!empty($providerTokens)) {
                    $providerResponse = NotificationService::sendFcmNotification(
                        $providerTokens,
                        'طلب خدمة جديد',
                        'تم تقديم طلب خدمة جديد وهو قيد المراجعة. يرجى متابعة الطلب والتواصل مع العميل بعد المراجعة.',
                        'service-request-created-provider',
                        [
                            'data' => json_encode(array_merge($notificationPayload, [
                                'submitted_by' => $user->getKey(),
                            ]), JSON_UNESCAPED_UNICODE),
                            'deeplink' => $deeplink,
                            'click_action' => $deeplink,
                        ]
                    );

                    if (is_array($providerResponse) && ($providerResponse['error'] ?? false)) {
                        Log::warning('service_requests.create_provider_notification_failed', [
                            'service_request_id' => $serviceRequest->getKey(),
                            'provider_ids' => $providerIds->all(),
                            'response_message' => $providerResponse['message'] ?? null,
                            'response_details' => $providerResponse['details'] ?? null,
                            'response_code' => $providerResponse['code'] ?? null,
                        ]);
                    }
                }
            }
        } catch (\Throwable $exception) {
            Log::error('service_requests.create_provider_notification_exception', [
                'service_request_id' => $serviceRequest->getKey(),
                'provider_ids' => $providerIds instanceof \Illuminate\Support\Collection ? $providerIds->all() : $providerIds,
                'error' => $exception->getMessage(),
                'exception_class' => get_class($exception),
            ]);
        }

        return response()->json([
            'id' => $serviceRequest->id,
            'status' => $serviceRequest->status,
            'service_id' => $serviceRequest->service_id,
            'payment_status' => $serviceRequest->payment_status,
            'payment_transaction_id' => $serviceRequest->payment_transaction_id,
        ], 201);
    }

    public function show(Request $request, ServiceRequest $serviceRequest): JsonResponse
    {
        $user = $request->user() ?? Auth::user();

        if (! $user || (int) $serviceRequest->user_id !== (int) $user->id) {
            return response()->json(['message' => __('Service request not found.')], 404);
        }

        $serviceRequest->loadMissing('service');

        return response()->json([
            'data' => $this->transformRequest($serviceRequest),
        ]);
    }

    public function purchaseOptions(Request $request, ServiceRequest $serviceRequest): JsonResponse
    {
        $user = $request->user() ?? Auth::user();

        if (! $user || (int) $serviceRequest->user_id !== (int) $user->id) {
            return response()->json(['message' => __('Service request not found.')], 404);
        }

        $serviceRequest->loadMissing('service');
        $service = $serviceRequest->service;

        $currency = strtoupper($service?->currency ?? config('app.currency', 'YER'));

        $supportedMethods = ServicePaymentService::SUPPORTED_METHODS;

        $methods = collect($supportedMethods)
            ->unique()
            ->filter(fn (string $method) => PaymentGatewayCurrencyPolicy::supports($method, $currency))
            ->map(static function (string $method) use ($currency): array {
                return [
                    'code' => $method,
                    'currencies' => PaymentGatewayCurrencyPolicy::supportedCurrencies($method),
                    'currency_supported' => PaymentGatewayCurrencyPolicy::supports($method, $currency),
                ];
            })
            ->values()
            ->all();

        $currencyRules = [
            'YER' => collect($supportedMethods)
                ->filter(fn (string $method) => PaymentGatewayCurrencyPolicy::supports($method, 'YER'))
                ->values()
                ->all(),
            'USD' => collect($supportedMethods)
                ->filter(fn (string $method) => PaymentGatewayCurrencyPolicy::supports($method, 'USD'))
                ->values()
                ->all(),
        ];

        return response()->json([
            'service_request_id' => $serviceRequest->getKey(),
            'default_currency' => $currency,
            'methods' => $methods,
            'currency_rules' => $currencyRules,
        ]);
    }

    private function transformRequest(ServiceRequest $serviceRequest): array
    {
        $service = $serviceRequest->service;

        return [
            'id' => $serviceRequest->getKey(),
            'status' => $serviceRequest->status,
            'service_id' => $serviceRequest->service_id,
            'request_number' => $serviceRequest->request_number,
            'service_title' => $service?->title,
            'service' => $service ? [
                'id' => $service->getKey(),
                'title' => $service->title,
                'category_id' => $service->category_id,
            ] : null,
            'note' => $serviceRequest->note,
            'custom_fields' => $serviceRequest->payload,
            'payload' => $serviceRequest->payload,
            'payment_status' => $serviceRequest->payment_status,
            'payment_transaction_id' => $serviceRequest->payment_transaction_id,
            'submitted_at' => optional($serviceRequest->created_at)->toIso8601String(),
            'created_at' => optional($serviceRequest->created_at)->toDateTimeString(),
            'updated_at' => optional($serviceRequest->updated_at)->toDateTimeString(),
        ];
    }

    private function generateRequestNumber(?ServiceRequest $serviceRequest = null): string
    {
        $department = 'services';
        $nextIdentifier = $serviceRequest?->exists
            ? (int) $serviceRequest->getKey()
            : (int) (ServiceRequest::query()->max('id') ?? 0) + 1;

        $candidate = trim((string) $this->legalNumberingService->formatOrderNumber(
            $nextIdentifier,
            $department,
            $serviceRequest?->request_number
        ));

        if ($candidate === '') {
            $candidate = (string) $nextIdentifier;
        }

        if ($this->requestNumberExists($candidate, $serviceRequest)) {
            return $this->fallbackRequestNumber($serviceRequest);
        }

        return $candidate;
    }

    private function requestNumberExists(string $number, ?ServiceRequest $ignore = null): bool
    {
        $query = ServiceRequest::query()->where('request_number', $number);

        if ($ignore?->exists) {
            $query->whereKeyNot($ignore->getKey());
        }

        return $query->exists();
    }

    private function fallbackRequestNumber(?ServiceRequest $ignore = null): string
    {
        $prefix = 'SR-' . now()->format('Ymd');

        do {
            $candidate = $prefix . '-' . Str::padLeft((string) random_int(0, 999999), 6, '0');
        } while ($this->requestNumberExists($candidate, $ignore));

        return $candidate;
    }
}
