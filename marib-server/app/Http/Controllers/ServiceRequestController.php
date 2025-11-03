<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\ManualPaymentViewHelpers;
use App\Models\Category;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\ServiceRequest;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use App\Services\BootstrapTableService;
use App\Services\ResponseService;
use App\Services\ServiceAuthorizationService;
use App\Support\Payments\PaymentLabelService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * ServiceRequestController
 * -----------------------
 * لوحة إدارة "طلبات الخدمات":
 * - عرض جدول الطلبات مع فلاتر (الفئة / الحالة / البحث)
 * - إظهار تفاصيل الطلب في مودال (payload + ملاحظة + معلومات عامة)
 * - تحديث حالة الطلب (review/approved/rejected) مع سبب الرفض
 * - حذف الطلب نهائياً
 */
class ServiceRequestController extends Controller
{

    use ManualPaymentViewHelpers;


        public function __construct(private ServiceAuthorizationService $serviceAuthorizationService)
    {
    }


    /* =========================================================================
     | إعدادات ثابتة
     |=========================================================================*/

    /** نفس مجموعة فئات الخدمات المعتمدة في المنظومة */
    private const SERVICE_CATEGORY_IDS = [2, 8, 174, 175, 176, 114, 181, 180, 177];

    /* =========================================================================
     | شاشة الطلبات (الفلاتر الأساسية)
     |=========================================================================*/
    public function index(Request $request)
    {
        // نحافظ على نفس الأذونات الحالية
        ResponseService::noAnyPermissionThenRedirect([
            'service-requests-list',
            'service-requests-update',
            'service-requests-delete',
        ]);

        $categoryQuery = Category::query()
            ->whereIn('id', self::SERVICE_CATEGORY_IDS)
            ->orderBy('name');

        $rawCategoryId = $request->input('category_id');
        $selectedCategoryId = null;
        if (is_scalar($rawCategoryId)) {
            $candidateId = (int) $rawCategoryId;
            if ($candidateId > 0) {
                $selectedCategoryId = $candidateId;
            }
        }
        
        $selectedCategory = null;

        $user = Auth::user();
        if ($user && !$this->serviceAuthorizationService->userHasFullAccess($user)) {
            $categoryIds = $this->serviceAuthorizationService->getManagedCategoryIds($user);
            if (empty($categoryIds)) {
                $categoryQuery->whereRaw('1 = 0');
                $selectedCategoryId = null;
            } else {
                $categoryQuery->whereIn('id', $categoryIds);
            }

        }

        if ($selectedCategoryId) {
            $selectedCategory = (clone $categoryQuery)
                ->where('id', $selectedCategoryId)
                ->first(['id', 'name']);


            if (!$selectedCategory) {
                $selectedCategoryId = null;
            }
        }

        if (!$selectedCategory) {
            $fallbackCategory = (clone $categoryQuery)->first(['id', 'name']);
            if ($fallbackCategory) {
                return redirect()->route('service.requests.index', [
                    'category_id' => $fallbackCategory->id,
                ]);
            }
        }

        $statsBaseQuery = ServiceRequest::query()->withTrashed();

        if ($user = Auth::user()) {
            $statsBaseQuery = $this->serviceAuthorizationService->restrictServiceRequestQuery($statsBaseQuery, $user);
        }

        if ($selectedCategory?->id) {
            $statsBaseQuery->whereHas('service', function ($query) use ($selectedCategory) {
                $query->where('category_id', $selectedCategory->id);
            });
        }

        $stats = [
            'total'    => (clone $statsBaseQuery)->count(),
            'review'   => (clone $statsBaseQuery)->where('status', 'review')->count(),
            'approved' => (clone $statsBaseQuery)->where('status', 'approved')->count(),
            'rejected' => (clone $statsBaseQuery)->where('status', 'rejected')->count(),
            'sold_out' => (clone $statsBaseQuery)->where('status', 'sold out')->count(),
        ];

        return view('services.requests.index', [
            'selectedCategory' => $selectedCategory,
            'selectedCategoryId' => $selectedCategory?->id,
            'stats' => $stats,
        ]);
    }

    /* =========================================================================
     | مصدر بيانات الجدول (JSON لـ BootstrapTable)
     | - يعرض الطلبات من جدول service_requests
     | - البحث: id، عنوان الخدمة، اسم المستخدم، الحالة
     | - الفلاتر: الفئة + الحالة
     | - إصلاح حدّ الصفوف: limit افتراضي 50 + دعم limit=all أو limit<=0 لعرض الكل
     |=========================================================================*/
    public function datatable(Request $request)
    {
        try {

            ResponseService::noPermissionThenSendJson('service-requests-list');


            // مدخلات الجدول
            $offset = (int) $request->input('offset', 0);

            $limitParam = $request->input('limit', 50);
            if (is_string($limitParam) && strtolower($limitParam) === 'all') {
                $limit = -1; // عرض الكل
            } else {
                $limit = (int) $limitParam;
                if ($limit === 0) $limit = 50; // افتراضي
            }

            $sort   = (string) $request->input('sort', 'id');
            $order  = strtoupper((string) $request->input('order', 'DESC')) === 'ASC' ? 'ASC' : 'DESC';


            $categoryFilter = $request->input('category_filter');
            if ($categoryFilter === null || $categoryFilter === '') {
                $categoryFilter = $request->input('category_id');
            }
            $requestNumberFilter = trim((string) $request->input('request_number', ''));

            $q = ServiceRequest::with([
                    'service:id,title,category_id',
                    'service.category:id,name',
                    'user:id,name',
                ])
                ->withTrashed();

            if ($user = Auth::user()) {
                $q = $this->serviceAuthorizationService->restrictServiceRequestQuery($q, $user);
            }

            $q = $q


                // فلتر الفئة (حسب فئة الخدمة المرتبطة)
                ->when($categoryFilter !== null && $categoryFilter !== '', function ($qq) use ($categoryFilter) {
                    $qq->whereHas('service', function ($s) use ($categoryFilter) {
                        $s->where('category_id', $categoryFilter);
                    });
                })

                // فلتر الحالة (review/approved/rejected)
                ->when($request->filled('status_filter'), function ($qq) use ($request) {
                    $qq->where('status', $request->status_filter);
                })


                ->when($requestNumberFilter !== '', function ($qq) use ($requestNumberFilter) {
                    $qq->where(function ($inner) use ($requestNumberFilter) {
                        $inner->where('request_number', 'like', "%{$requestNumberFilter}%")
                            ->orWhere('id', (int) $requestNumberFilter);
                    });
                })



                // البحث العام
                ->when(!empty($request->search), function ($qq) use ($request) {
                    $s = trim($request->search);
                    $qq->where(function ($w) use ($s) {
                        $w->where('id', (int) $s)
                          ->orWhere('request_number', 'like', "%{$s}%")
                          ->orWhere('status', 'like', "%{$s}%")
                          ->orWhereHas('service', fn($t) => $t->where('title', 'like', "%{$s}%"))
                          ->orWhereHas('user', fn($u) => $u->where('name', 'like', "%{$s}%"));
                    });
                });

            // إجمالي السجلات
            $total = (clone $q)->count();

            // حماية أسماء الفرز
            $sortable = ['id', 'request_number', 'status', 'created_at', 'updated_at'];
            if (!in_array($sort, $sortable, true)) {
                $sort = 'id';
            }

            // جلب الدفعة المطلوبة
            if ($limit <= 0) {
                $rows = $q->orderBy($sort, $order)->get();
            } else {
                $rows = $q->orderBy($sort, $order)
                    ->skip($offset)
                    ->take($limit)
                    ->get();
            }

            // تجهيز صفوف الجدول
            $dataRows = [];
            foreach ($rows as $r) {
                // عنوان الخدمة واسم الفئة واسم المستخدم
                $serviceTitle = $r->service?->title ?? '-';
                $categoryName = $r->service?->category?->name ?? '-';
                $userName     = $r->user?->name ?? '-';

                // ملخص payload (ذكي ويتعامل مع شكلين: array of maps أو associative map)
                $payloadPreview = $this->buildPayloadPreview($r->payload, 3);

                // أزرار الإجراءات
                $operate = '';

                // زر "عرض" → يفتح المودال ويملأ #custom_fields من data-json
                if (Auth::user()->can('service-requests-list') || Auth::user()->can('service-requests-update')) {
                    $categoryIdForRow = $r->service?->category_id;
                    $reviewRouteParameters = ['serviceRequest' => $r->id];
                    if (!empty($categoryIdForRow)) {
                        $reviewRouteParameters['category_id'] = $categoryIdForRow;
                    }


                    $operate .= BootstrapTableService::button(
                        'fa fa-eye',
                        route('service.requests.review', $reviewRouteParameters),
                        ['btn-outline-primary', 'btn-sm'],


                        [
                            'title' => __('Review Request'),

                        ],
                        __('Review Request')
                    );
                }

                // زر تغيير الحالة

                $customFields = $this->normalizePayloadEntriesForView($r->payload, false);

                // تشكيل الصف
                $dataRows[] = [
                    'id'              => $r->id,
                    'request_number'  => $r->request_number ?: (string) $r->id,
                    'name'            => $serviceTitle,                // للعمود "Name"
                    'category'        => ['name' => $categoryName],    // يدعم data-field="category.name"
                    'user'            => ['name' => $userName],        // يدعم data-field="user.name"
                    'description'     => $payloadPreview,              // يظهر عبر descriptionFormatter
                    'status'          => $r->status,
                    'rejected_reason' => $r->rejected_reason,
                    'submitted_at'    => optional($r->created_at)->format('Y-m-d H:i'),
                    'created_at'      => optional($r->created_at)->toDateTimeString(),
                    'updated_at'      => optional($r->updated_at)->toDateTimeString(),
                    'operate'         => $operate,
                    'custom_fields'   => array_map(static function (array $entry) {
                        return [
                            'label'      => $entry['label'],
                            'value'      => $entry['display'],
                            'values'     => $entry['value_list'],
                            'display'    => $entry['display'],
                            'is_file'    => $entry['is_file'],
                            'file_url'   => $entry['file_url'],
                            'file_name'  => $entry['file_name'],
                            'note'       => $entry['note'],
                            'value_list' => $entry['value_list'],
                        ];
                    }, $customFields),

                ];
            }

            return response()->json([
                'total' => $total,
                'rows'  => $dataRows,
            ]);

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "ServiceRequestController --> datatable");
            ResponseService::errorResponse();
        }
    }



    public function show(Request $request, $id)
    {
        ResponseService::noAnyPermissionThenRedirect([
            'service-requests-list',
            'service-requests-update',
            'service-requests-delete',
        ]);

        $parameters = ['serviceRequest' => $id];
        $rawCategory = $request->query('category_id');
        if (is_scalar($rawCategory)) {
            $candidate = (int) $rawCategory;
            if ($candidate > 0) {
                $parameters['category_id'] = $candidate;
            }
        }

        return redirect()->route('service.requests.review', $parameters);
    
    }



    public function review($serviceRequest)
    {
        ResponseService::noAnyPermissionThenRedirect([
            'service-requests-list',
            'service-requests-update',
        ]);

        $serviceRequestModel = ServiceRequest::with([
                'service.category',
                'user',
            ])
            ->withTrashed()
            ->findOrFail($serviceRequest);

        $user = Auth::user();
        if (!$user || !$this->serviceAuthorizationService->userCanManageService($user, $serviceRequestModel->service)) {
            abort(403, __('You are not authorized to manage this service.'));
        }

        $transaction = $this->resolveServiceRequestPaymentTransaction($serviceRequestModel);

        $manualPaymentRelations = [
            'user',
            'manualBank',
            'paymentTransaction.order.user',
            'paymentTransaction.order.coupon',
            'paymentTransaction.walletTransaction.walletAccount.user',
            'paymentTransaction.payable',
            'histories.user',
            'reviewer',
            'payable',
        ];

        $manualPaymentRequest = $transaction?->manualPaymentRequest;

        if (! $manualPaymentRequest instanceof ManualPaymentRequest && $transaction instanceof PaymentTransaction) {
            $manualPaymentRequestId = data_get($transaction->meta, 'service.manual_payment_request_id');

            if (is_scalar($manualPaymentRequestId)) {
                $manualPaymentRequestId = trim((string) $manualPaymentRequestId);

                if ($manualPaymentRequestId !== '') {
                    $manualPaymentRequest = ManualPaymentRequest::query()
                        ->with($manualPaymentRelations)
                        ->whereKey($manualPaymentRequestId)
                        ->first();
                }
            }
        }

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualPaymentRequest = ManualPaymentRequest::query()
                ->with($manualPaymentRelations)
                ->where(function ($query) use ($serviceRequestModel) {
                    $id = $serviceRequestModel->getKey();
                    $query->where('meta->service->request_id', $id)
                        ->orWhere('meta->service->request_id', (string) $id);
                })
                ->orderByDesc('id')
                ->first();
        }


        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualPaymentRequest = ManualPaymentRequest::query()
                ->with($manualPaymentRelations)
                ->where('payable_type', ServiceRequest::class)
                ->where('payable_id', $serviceRequestModel->getKey())
                ->orderByDesc('id')
                ->first();
        }



        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);

            if ($manualPaymentRequest->paymentTransaction instanceof PaymentTransaction) {
                $transaction = $manualPaymentRequest->paymentTransaction;
            }
        } elseif ($transaction instanceof PaymentTransaction) {
            $manualPaymentRequest = $this->makeManualPaymentRequestFromTransaction($transaction);
        }

        if ($transaction instanceof PaymentTransaction && $manualPaymentRequest instanceof ManualPaymentRequest) {
            $transaction->setRelation('manualPaymentRequest', $manualPaymentRequest);
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest && $transaction instanceof PaymentTransaction) {
            $manualPaymentRequest->setRelation('paymentTransaction', $transaction);
        }

        $presentation = [];
        $timelineData = [];
        $timelineEndpoint = null;

        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $presentation = $this->manualPaymentRequestPresentationData($manualPaymentRequest);
            $timelineData = $this->manualPaymentTimelinePayload($manualPaymentRequest);

            if ($manualPaymentRequest->exists) {
                $timelineEndpoint = route('payment-requests.timeline', $manualPaymentRequest);
            }
        }

        $canReviewManualPayment = $manualPaymentRequest instanceof ManualPaymentRequest
            && $manualPaymentRequest->isOpen()
            && $user
            && $user->can('manual-payments-review');

        $hasPaymentContext = $manualPaymentRequest instanceof ManualPaymentRequest
            || $transaction instanceof PaymentTransaction;

        $paymentLabels = [];

        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $paymentLabels = PaymentLabelService::forManualPaymentRequest($manualPaymentRequest);
        } elseif ($transaction instanceof PaymentTransaction) {
            $paymentLabels = PaymentLabelService::forPaymentTransaction($transaction);
        }

        $payloadEntries = $this->normalizePayloadEntriesForView($serviceRequestModel->payload);
        $fieldEntries = array_values(array_filter($payloadEntries, static function (array $entry): bool {
            return empty($entry['is_file']);
        }));
        $attachmentEntries = array_values(array_filter($payloadEntries, static function (array $entry): bool {
            return ! empty($entry['is_file']);
        }));

        $expectedAmountRaw = $manualPaymentRequest?->amount
            ?? $transaction?->amount
            ?? optional($serviceRequestModel->service)->price;

        $expectedAmount = is_numeric($expectedAmountRaw) ? (float) $expectedAmountRaw : null;

        $expectedCurrency = $manualPaymentRequest?->currency
            ?? $transaction?->currency
            ?? optional($serviceRequestModel->service)->currency
            ?? config('app.currency', 'SAR');

        if (is_string($expectedCurrency)) {
            $expectedCurrency = strtoupper(trim($expectedCurrency));
        }

        $paymentInstruction = optional($serviceRequestModel->service)->price_note;

        if (is_string($paymentInstruction)) {
            $paymentInstruction = trim($paymentInstruction);
            if ($paymentInstruction === '') {
                $paymentInstruction = null;
            }
        } else {
            $paymentInstruction = null;
        }

        if ($paymentInstruction === null && $manualPaymentRequest instanceof ManualPaymentRequest) {
            $candidateInstruction = $manualPaymentRequest->user_note ?? null;
            if (is_string($candidateInstruction)) {
                $candidateInstruction = trim($candidateInstruction);
                if ($candidateInstruction !== '') {
                    $paymentInstruction = $candidateInstruction;
                }
            }
        }

        $actionFlags = [
            'approve' => ($user?->can('service-requests-update') ?? false)
                && $serviceRequestModel->status === 'review',
            'reject' => ($user?->can('service-requests-update') ?? false)
                && $serviceRequestModel->status === 'review',
            'markPaid' => $canReviewManualPayment,
            'refund' => ($user?->can('manual-payments-review') ?? false)
                && $serviceRequestModel->payment_status === 'paid',
        ];

        $paymentStatusLabel = $serviceRequestModel->payment_status
            ? __($serviceRequestModel->payment_status)
            : __('Not provided');

        return view('services.requests.review', [
            'serviceRequest' => $serviceRequestModel,
            'service' => $serviceRequestModel->service,
            'category' => optional($serviceRequestModel->service)->category,
            'applicant' => $serviceRequestModel->user,
            'manualPaymentRequest' => $manualPaymentRequest,
            'paymentTransaction' => $transaction,
            'presentation' => $presentation,
            'timelineData' => $timelineData,
            'timelineEndpoint' => $timelineEndpoint,
            'canReviewPayment' => $canReviewManualPayment,
            'hasPaymentContext' => $hasPaymentContext,
            'paymentLabels' => $paymentLabels,
            'payloadEntries' => $payloadEntries,
            'fieldEntries' => $fieldEntries,
            'attachmentEntries' => $attachmentEntries,
            'expectedAmount' => $expectedAmount,
            'expectedCurrency' => $expectedCurrency,
            'paymentInstruction' => $paymentInstruction,
            'paymentStatusLabel' => $paymentStatusLabel,
            'actionFlags' => $actionFlags,
        ]);
    }


    /* =========================================================================
     | تحديث حالة الطلب (موافقة/رفض/مراجعة) + (اختياري) إرسال إشعار FCM
     |=========================================================================*/
    public function updateApproval(Request $request, $id)
    {
        try {
            ResponseService::noPermissionThenSendJson('service-requests-update');

            $request->validate([
                'status'          => 'required|in:review,approved,rejected',
                'rejected_reason' => 'nullable|string',
            ]);

            $r = ServiceRequest::with(['service', 'user'])->withTrashed()->findOrFail($id);


            if (!Auth::user() || !$this->serviceAuthorizationService->userCanManageService(Auth::user(), $r->service)) {
                ResponseService::errorResponse('غير مصرح لك بإدارة هذه الخدمة.', null, 403);
            }



            $r->status = $request->status;
            $r->rejected_reason = $request->status === 'rejected'
                ? ($request->rejected_reason ?? '')
                : null;

            $r->save();

            // (اختياري) إشعار للمستخدم صاحب الطلب
            try {
                $tokens = UserFcmToken::where('user_id', $r->user_id)
                    ->pluck('fcm_token')
                    ->filter()
                    ->unique()
                    ->values()
                    ->all();
                    
                    if (!empty($tokens)) {
                    $title = 'تحديث طلب الخدمة';
                    $statusLabel = ucfirst($r->status);
                    $body  = 'تم تحديث حالة طلبك إلى: ' . $statusLabel;

                    $deeplink = route('service.requests.review', $r->getKey());

                    $dataPayload = [
                        'service_request_id' => $r->getKey(),
                        'status'             => $r->status,
                        'status_label'       => $statusLabel,
                        'service_id'         => $r->service_id,
                        'service_title'      => $r->service?->title,
                        'user_id'            => $r->user_id,
                    ];

                    if ($r->status === 'rejected' && filled($r->rejected_reason)) {
                        $dataPayload['rejected_reason'] = $r->rejected_reason;
                    }

                    $notificationResponse = NotificationService::sendFcmNotification(
                        $tokens,
                        $title,
                        $body,
                        'service-request-update',
                        [
                            'data'         => json_encode($dataPayload, JSON_UNESCAPED_UNICODE),
                            'deeplink'     => $deeplink,
                            'click_action' => $deeplink,
                        ]
                    );

                    if (is_array($notificationResponse) && ($notificationResponse['error'] ?? false)) {
                        Log::warning('service_requests.notification_failed', [
                            'service_request_id' => $r->getKey(),
                            'user_id'            => $r->user_id,
                            'response_message'   => $notificationResponse['message'] ?? null,
                            'response_details'   => $notificationResponse['details'] ?? null,
                            'response_code'      => $notificationResponse['code'] ?? null,
                        ]);
                    }


                }
            } catch (\Throwable $e) {
                Log::error('service_requests.notification_exception', [
                    'service_request_id' => $r->getKey(),
                    'user_id'            => $r->user_id,
                    'error'              => $e->getMessage(),
                    'exception_class'    => get_class($e),
                ]);
            
            }

            ResponseService::successResponse('Service Request Status Updated Successfully');

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ServiceRequestController -> updateApproval');
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    /* =========================================================================
     | حذف نهائي لطلب الخدمة
     |=========================================================================*/
    public function destroy($id)
    {
        ResponseService::noPermissionThenSendJson('service-requests-delete');

        try {
            $r = ServiceRequest::with(['service'])->withTrashed()->findOrFail($id);

            if (!Auth::user() || !$this->serviceAuthorizationService->userCanManageService(Auth::user(), $r->service)) {
                ResponseService::errorResponse('غير مصرح لك بإدارة هذه الخدمة.', null, 403);
            }
            
            $r->forceDelete();

            ResponseService::successResponse('Service Request deleted successfully');

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th);
            ResponseService::errorResponse('Something went wrong');
        }
    }

    /* =========================================================================
     | أدوات مساعدة
     |=========================================================================*/


    private function resolveServiceRequestPaymentTransaction(ServiceRequest $serviceRequest): ?PaymentTransaction
    {
        $transactionRelations = [
            'user',
            'order.user',
            'walletTransaction.walletAccount.user',
            'payable',
            'manualPaymentRequest.user',
            'manualPaymentRequest.manualBank',
            'manualPaymentRequest.paymentTransaction.order.user',
            'manualPaymentRequest.paymentTransaction.walletTransaction.walletAccount.user',
            'manualPaymentRequest.payable',
            'manualPaymentRequest.histories.user',
        ];

        $transactionId = $serviceRequest->payment_transaction_id;

        if ($transactionId) {
            $transaction = PaymentTransaction::query()
                ->with($transactionRelations)
                ->find($transactionId);

            if ($transaction instanceof PaymentTransaction) {
                return $transaction;
            }
        }

        return PaymentTransaction::query()
            ->with($transactionRelations)
            ->where(function ($query) use ($serviceRequest) {
                $id = $serviceRequest->getKey();
                $query->where('meta->service->request_id', $id)
                    ->orWhere('meta->service->request_id', (string) $id);
            })
            ->orderByDesc('id')
            ->first();
    }





    /**
     * يبني معاينة مختصرة للـ payload:
     * - يدعم Array of Maps: [{label|title|name|key, value|values|selected|checked}, ...]
     * - أو خريطة Associative: key => scalar/array
     */
    private function buildPayloadPreview($payload, int $limitLines = 3): string
    {
        try {
            $pairs = [];

            // شكل 1: مصفوفة عناصر
            if (is_array($payload) && isset($payload[0]) && is_array($payload[0])) {
                foreach ($payload as $field) {
                    if (!is_array($field)) continue;

                    $label = $field['label'] ?? $field['title'] ?? $field['name'] ?? $field['key'] ?? '';
                    $val   = $field['value'] ?? ($field['values'] ?? ($field['selected'] ?? ($field['checked'] ?? null)));

                    if (is_array($val)) {
                        $val = implode(', ', array_map('strval', $val));
                    }

                    $line = trim(($label ? "{$label}: " : '') . (string) ($val ?? ''));
                    if ($line !== '') $pairs[] = $line;
                    if (count($pairs) >= $limitLines) break;
                }
            }
            // شكل 2: خريطة مفاتيح → قيم
            elseif (is_array($payload)) {
                foreach ($payload as $k => $v) {
                    $val = is_array($v) ? implode(', ', array_map('strval', $v)) : (string) $v;
                    $line = trim("{$k}: {$val}");
                    if ($line !== '') $pairs[] = $line;
                    if (count($pairs) >= $limitLines) break;
                }
            }

            return $pairs ? implode(' | ', $pairs) : '-';
        } catch (\Throwable $e) {
            return '-';
        }
    }





    private function normalizePayloadEntriesForView($payload, bool $resolveFileUrl = true): array
    {
        if (!is_array($payload) || $payload === []) {
            return [];
        }

        $entries = [];

        if ($this->isAssociativeArray($payload)) {
            $index = 0;
            foreach ($payload as $key => $value) {
                $entries[] = $this->buildPayloadEntryForView([
                    'name'  => $key,
                    'label' => $key,
                    'value' => $value,
                ], $index++, $resolveFileUrl);
            }

            return array_values(array_filter($entries));
        }

        foreach ($payload as $index => $entry) {
            $normalized = $this->buildPayloadEntryForView($entry, (int) $index, $resolveFileUrl);
            if ($normalized !== null) {
                $entries[] = $normalized;
            }
        }

        return array_values(array_filter($entries));
    }

    private function buildPayloadEntryForView($entry, int $index, bool $resolveFileUrl): ?array
    {
        $fallbackLabel = __('Field #:number', ['number' => $index + 1]);

        if (!is_array($entry)) {
            $display = $this->stringifyPayloadValue($entry) ?? '-';

            return [
                'label'      => $fallbackLabel,
                'note'       => null,
                'type'       => null,
                'display'    => $display,
                'value_list' => [],
                'is_file'    => false,
                'file_url'   => null,
                'file_path'  => null,
                'file_name'  => null,
            ];
        }

        $label = trim((string) ($entry['label'] ?? $entry['title'] ?? $entry['name'] ?? $entry['key'] ?? ''));
        if ($label === '') {
            $label = $fallbackLabel;
        }

        $note = $entry['note'] ?? null;
        if (is_string($note)) {
            $note = trim($note);
            if ($note === '') {
                $note = null;
            }
        } else {
            $note = null;
        }

        $type = strtolower((string) ($entry['type'] ?? ''));

        $values = [];
        if (isset($entry['values']) && is_array($entry['values'])) {
            $values = array_values(array_filter(array_map(function ($value) {
                return $this->stringifyPayloadValue($value);
            }, $entry['values']), static fn ($value) => $value !== null));
        }

        $value = $entry['display_value'] ?? ($entry['value'] ?? null);
        if (is_array($value) && empty($values)) {
            $values = array_values(array_filter(array_map(function ($value) {
                return $this->stringifyPayloadValue($value);
            }, $value), static fn ($value) => $value !== null));
            $value = null;
        } elseif (!is_array($value)) {
            $value = $this->stringifyPayloadValue($value);
        } else {
            $value = null;
        }

        $isFile = $type === 'fileinput' || isset($entry['file_url']) || isset($entry['file_path']);
        $filePath = isset($entry['file_path']) && is_string($entry['file_path']) ? $entry['file_path'] : null;
        if ($isFile && $filePath === null && isset($entry['value']) && is_string($entry['value'])) {
            $filePath = $entry['value'];
        }

        $fileUrl = isset($entry['file_url']) && is_string($entry['file_url']) ? $entry['file_url'] : null;
        $fileName = null;
        $display = null;

        if ($isFile) {
            if ($resolveFileUrl) {
                $fileUrl = $fileUrl ?: $this->resolveFileUrl($filePath);
            }

            $fileName = $this->resolveFileName($fileUrl, $filePath, $label, $index);
            $display = $fileName ?: '-';
        } else {
            $display = $value ?? (!empty($values) ? implode(', ', $values) : '-');
        }

        if ($display === null || $display === '') {
            $display = '-';
        }

        return [
            'label'      => $label,
            'note'       => $note,
            'type'       => $type ?: null,
            'display'    => $display,
            'value_list' => $values,
            'is_file'    => $isFile,
            'file_url'   => $fileUrl,
            'file_path'  => $filePath,
            'file_name'  => $fileName,
        ];
    }

    private function stringifyPayloadValue($value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_bool($value)) {
            return $value ? __('Yes') : __('No');
        }

        if (is_scalar($value)) {
            $string = trim((string) $value);
            return $string === '' ? null : $string;
        }

        if (is_object($value) && method_exists($value, '__toString')) {
            $string = trim((string) $value);
            return $string === '' ? null : $string;
        }

        if (is_array($value)) {
            $encoded = json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            return $encoded === '[]' ? null : $encoded;
        }

        return null;
    }

    private function resolveFileUrl(?string $pathOrUrl): ?string
    {
        if (!is_string($pathOrUrl) || $pathOrUrl === '') {
            return null;
        }

        if (filter_var($pathOrUrl, FILTER_VALIDATE_URL)) {
            return $pathOrUrl;
        }

        try {
            if (Storage::disk('public')->exists($pathOrUrl)) {
                return Storage::disk('public')->url($pathOrUrl);
            }
        } catch (Throwable) {
            // تجاهل أي أخطاء في الوصول للتخزين واستمر بإرجاع مسار عام
        }

        return url($pathOrUrl);
    }

    private function resolveFileName(?string $fileUrl, ?string $filePath, string $fallbackLabel, int $index): string
    {
        $candidates = [];

        if (is_string($filePath) && $filePath !== '') {
            $candidates[] = $filePath;
        }

        if (is_string($fileUrl) && $fileUrl !== '') {
            $candidates[] = $fileUrl;
        }

        foreach ($candidates as $candidate) {
            $path = parse_url($candidate, PHP_URL_PATH) ?: $candidate;
            $basename = basename($path);
            if ($basename !== '' && $basename !== '/') {
                return $basename;
            }
        }

        $fallback = trim($fallbackLabel);
        if ($fallback !== '') {
            return $fallback;
        }

        return __('Attachment #:number', ['number' => $index + 1]);
    }

    private function isAssociativeArray(array $array): bool
    {
        return array_keys($array) !== range(0, count($array) - 1);
    }



}
