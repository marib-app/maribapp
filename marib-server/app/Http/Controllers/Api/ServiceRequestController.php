<?php

namespace App\Http\Controllers\Api;
use App\Models\PaymentTransaction;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use App\Http\Controllers\Controller;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Services\ServiceCustomFieldSubmissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

use JsonException;

class ServiceRequestController extends Controller
{
    public function __construct(
        private ServiceCustomFieldSubmissionService $submissionService
    ) {
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


        if ($service->is_paid) {
            $hasSuccessfulPayment = PaymentTransaction::query()
                ->where('user_id', $user->id)
                ->where('payable_type', Service::class)
                ->where('payable_id', $service->id)
                ->where('payment_status', 'succeed')
                ->exists();

            if (!$hasSuccessfulPayment) {
                return response()->json([   
                    'message' => __('Payment is required to request this service.'),
                    'code' => 'payment_required',
                    'payment_required' => true,
                    'payable_type' => Service::class,
                    'payable_id' => $service->id,
                ], 402);
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

        $serviceRequest = new ServiceRequest();
        $serviceRequest->service_id = $service->id;
        $serviceRequest->user_id = $user->id;
        $serviceRequest->status = 'review';
        $serviceRequest->payload = $payload;

        if ($request->filled('note')) {
            $serviceRequest->note = trim((string) $request->input('note')) ?: null;
        }

        $serviceRequest->save();


        try {
            $tokens = UserFcmToken::query()
                ->where('user_id', $user->id)
                ->pluck('fcm_token')
                ->filter()
                ->unique()
                ->values()
                ->all();

            if (!empty($tokens)) {
                $deeplink = url(sprintf('/service-requests/show/%d', $serviceRequest->getKey()));

                $notificationResponse = NotificationService::sendFcmNotification(
                    $tokens,
                    'تم إرسال طلبك',
                    'تم إرسال طلبك بنجاح وهو قيد المراجعة.',
                    'service-request-created',
                    [
                        'data' => json_encode([
                            'service_request_id' => $serviceRequest->getKey(),
                            'status' => $serviceRequest->status,
                            'service_id' => $serviceRequest->service_id,
                        ], JSON_UNESCAPED_UNICODE),
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

        return response()->json([
            'id' => $serviceRequest->id,
            'status' => $serviceRequest->status,
            'service_id' => $serviceRequest->service_id,
        ], 201);
    }
    private function transformRequest(ServiceRequest $serviceRequest): array
    {
        $service = $serviceRequest->service;

        return [
            'id' => $serviceRequest->getKey(),
            'status' => $serviceRequest->status,
            'service_id' => $serviceRequest->service_id,
            'service_title' => $service?->title,
            'service' => $service ? [
                'id' => $service->getKey(),
                'title' => $service->title,
                'category_id' => $service->category_id,
            ] : null,
            'note' => $serviceRequest->note,
            'custom_fields' => $serviceRequest->payload,
            'payload' => $serviceRequest->payload,
            'submitted_at' => optional($serviceRequest->created_at)->toIso8601String(),
            'created_at' => optional($serviceRequest->created_at)->toDateTimeString(),
            'updated_at' => optional($serviceRequest->updated_at)->toDateTimeString(),
        ];
    }
}