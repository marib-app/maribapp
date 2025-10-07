<?php

namespace App\Http\Controllers;

use App\Models\Category;
use App\Models\ServiceRequest;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use App\Services\BootstrapTableService;
use App\Services\ResponseService;
use App\Services\ServiceAuthorizationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
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
    public function index()
    {
        // نحافظ على نفس الأذونات الحالية
        ResponseService::noAnyPermissionThenRedirect([
            'service-requests-list',
            'service-requests-update',
            'service-requests-delete',
        ]);

        // نقرأ فقط id,name لتجنّب أي أعمدة غير موجودة
        $categories = Category::whereIn('id', self::SERVICE_CATEGORY_IDS)
            ->orderBy('name')
            ->get(['id', 'name']);


        $categoryQuery = Category::whereIn('id', self::SERVICE_CATEGORY_IDS)
            ->orderBy('name');

        $user = Auth::user();
        if ($user && !$this->serviceAuthorizationService->userHasFullAccess($user)) {
            $categoryIds = $this->serviceAuthorizationService->getManagedCategoryIds($user);
            if (empty($categoryIds)) {
                $categories = collect();
            } else {
                $categories = $categoryQuery->whereIn('id', $categoryIds)->get(['id', 'name']);
            }
        } else {
            $categories = $categoryQuery->get(['id', 'name']);
        }


        return view('services.requests.index', compact('categories'));
    }

    /* =========================================================================
     | مصدر بيانات الجدول (JSON لـ BootstrapTable)
     | - يعرض الطلبات من جدول service_requests
     | - البحث: id، عنوان الخدمة، اسم المستخدم، الحالة
     | - الفلاتر: الفئة + الحالة
     | - إصلاح حدّ الصفوف: limit افتراضي 50 + دعم limit=all أو limit<=0 لعرض الكل
     |=========================================================================*/
    public function show(Request $request)
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

            $q = ServiceRequest::with([
                    'service:id,title,category_id',
                    'service.category:id,name',
                    'user:id,name',
                ])
                ->withTrashed()


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

                // البحث العام
                ->when(!empty($request->search), function ($qq) use ($request) {
                    $s = trim($request->search);
                    $qq->where(function ($w) use ($s) {
                        $w->where('id', (int) $s)
                          ->orWhere('status', 'like', "%{$s}%")
                          ->orWhereHas('service', fn($t) => $t->where('title', 'like', "%{$s}%"))
                          ->orWhereHas('user', fn($u) => $u->where('name', 'like', "%{$s}%"));
                    });
                });

            // إجمالي السجلات
            $total = (clone $q)->count();

            // حماية أسماء الفرز
            $sortable = ['id', 'status', 'created_at', 'updated_at'];
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
                if (Auth::user()->can('service-requests-list')) {
                    $operate .= BootstrapTableService::button(
                        'fa fa-eye',
                        '#',
                        ['editdata', 'btn-light-danger'],
                        [
                            'title'          => __('View'),
                            'data-bs-target' => '#editModal',
                            'data-bs-toggle' => 'modal',
                            'data-json'      => htmlspecialchars(json_encode([
                                'service_title' => $serviceTitle,
                                'user_name'     => $userName,
                                'status'        => $r->status,
                                'note'          => $r->note,
                                'payload'       => $r->payload, // تُعرض كاملة في المودال
                                'created_at'    => optional($r->created_at)->toDateTimeString(),
                            ], JSON_UNESCAPED_UNICODE), ENT_QUOTES, 'UTF-8'),
                        ]
                    );
                }

                // زر تغيير الحالة
                if (Auth::user()->can('service-requests-update')) {
                    $operate .= BootstrapTableService::editButton(
                        route('service.requests.approval', $r->id),
                        true,
                        '#editStatusModal',
                        'edit-status',
                        $r->id
                    );
                }

                // زر الحذف
                if (Auth::user()->can('service-requests-delete')) {
                    $operate .= BootstrapTableService::deleteButton(
                        route('service.requests.destroy', $r->id)
                    );
                }

                // تشكيل الصف
                $dataRows[] = [
                    'id'              => $r->id,
                    'name'            => $serviceTitle,                // للعمود "Name"
                    'category'        => ['name' => $categoryName],    // يدعم data-field="category.name"
                    'user'            => ['name' => $userName],        // يدعم data-field="user.name"
                    'description'     => $payloadPreview,              // يظهر عبر descriptionFormatter
                    'status'          => $r->status,
                    'rejected_reason' => $r->rejected_reason,
                    'created_at'      => optional($r->created_at)->toDateTimeString(),
                    'updated_at'      => optional($r->updated_at)->toDateTimeString(),
                    'active_status'   => empty($r->deleted_at),         // IF deleted_at is empty => true
                    'operate'         => $operate,
                ];
            }

            return response()->json([
                'total' => $total,
                'rows'  => $dataRows,
            ]);

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "ServiceRequestController --> show");
            ResponseService::errorResponse();
        }
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

                    $deeplink = url(sprintf('/service-requests/show/%d', $r->getKey()));

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
}
