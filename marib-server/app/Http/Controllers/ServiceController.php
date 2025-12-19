<?php

namespace App\Http\Controllers;

use App\Models\Category;
use App\Models\Service;
use App\Models\User;
use App\Services\ResponseService;
use App\Services\ServiceAuthorizationService;
use App\Models\ServiceReview;
use App\Models\ServiceCustomFieldValue;
use App\Models\ServiceCustomField;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Support\Arr;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;
use Illuminate\Http\UploadedFile;
use App\Services\DepartmentReportService;
use App\Models\ServiceRequest;
use App\Models\UserReports;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use App\Services\FileService;

use Throwable;



/**
 * ServiceController
 * -----------------
 * لوحة إدارة "الخدمات" (CRUD) مع دعم تدفّق زر المتابعة في التطبيق:
 * - is_paid / price / currency / price_note
 * - has_custom_fields  (+ ربط custom_fields للخدمة عبر Pivot services_custom_fields)
 * - direct_to_user / direct_user_id
 * - service_uid (يُولَّد تلقائيًا في الموديل)
 * - service_fields_schema (JSON اختياري لوصف مخطط الحقول الخاصة بالخدمة)
 */
class ServiceController extends Controller
{


    public function __construct(
        private ServiceAuthorizationService $serviceAuthorizationService,
        private DepartmentReportService $departmentReportService
    ) {
    }

    /* =========================================================================
     | ثوابت
     |=========================================================================*/
    /** فئات الخدمات المسموح بها لواجهة الإنشاء / التعديل */
    private const SERVICE_CATEGORY_IDS = [2, 8, 174, 175, 176, 114, 181, 180, 177];

    /** مجلد رفع أيقونات الحقول المخصصة */
    private const SERVICE_FIELD_ICON_DIR = 'service_field_icons';


    /* =========================================================================
     | شاشة القائمة
     |=========================================================================*/
    public function index()
    {
        ResponseService::noPermissionThenRedirect('service-list');

        $categories = $this->getAccessibleCategories(['id', 'name', 'image']);

        $categorySummaries = collect();

        if ($categories->isNotEmpty()) {
            $stats = $this->baseServiceQuery()
                ->select('category_id')
                ->selectRaw('COUNT(*) as total_services')
                ->selectRaw('SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) as active_services')
                ->selectRaw('SUM(CASE WHEN is_paid = 1 THEN 1 ELSE 0 END) as paid_services')
                ->whereIn('category_id', $categories->pluck('id'))
                ->groupBy('category_id')
                ->get()
                ->keyBy('category_id');

            $categorySummaries = $categories->map(function (Category $category) use ($stats) {
                $stat = $stats->get($category->id);

                return [
                    'id' => $category->id,
                    'name' => $category->name,
                    'image' => $category->image,
                    'total_services' => (int) ($stat->total_services ?? 0),
                    'active_services' => (int) ($stat->active_services ?? 0),
                    'paid_services' => (int) ($stat->paid_services ?? 0),
                ];
            })->values();
        }




        return view('services.index', [
            'categories' => $categorySummaries,
        ]);
    }



    public function category(Category $category)
    {
        ResponseService::noPermissionThenRedirect('service-list');

        if (!in_array($category->id, self::SERVICE_CATEGORY_IDS, true)) {
            abort(404);
        }

        $accessibleCategories = $this->getAccessibleCategories(['id', 'name']);

        if ($accessibleCategories->isNotEmpty() && !$accessibleCategories->contains('id', $category->id)) {
            abort(403, __('You are not authorized to manage this category.'));
        }







        $services = $this->serviceListingQuery()
            ->where('category_id', $category->id)


            ->orderByDesc('services.id')
            ->get()
            ->map(fn(Service $service) => $this->transformService($service))
            ->values()
            ->all();

        $canManageCategoryRequests = false;

        if (Auth::check()) {
            $canManageCategoryRequests = $this->serviceAuthorizationService->userCanManageCategory(
                Auth::user(),
                $category
            );
        }


        $supportsRequests = $this->supportsServiceRequests();
        $categoryDepartmentKey = $this->determineCategoryDepartment($category);
        $categoryDepartmentLabel = $this->departmentLabel($categoryDepartmentKey);
        $categoryRequestsStats = $supportsRequests
            ? $this->buildCategoryRequestsStats($category)
            : null;



        return view('services.category', [
            'category' => $category,
            'initialServices' => $services,
            'supportsServiceRequests' => $supportsRequests,
            'canManageCategoryRequests' => $canManageCategoryRequests,
            'categoryDepartmentKey' => $categoryDepartmentKey,
            'categoryDepartmentLabel' => $categoryDepartmentLabel,
            'categoryRequestsStats' => $categoryRequestsStats,

        ]);
    






   }

    public function categoryReviews(Category $category, Request $request)
    {
        ResponseService::noPermissionThenSendJson('service-list');

        if (!in_array($category->id, self::SERVICE_CATEGORY_IDS, true)) {
            abort(404);
        }

        $accessibleCategories = $this->getAccessibleCategories(['id']);
        if ($accessibleCategories->isNotEmpty() && !$accessibleCategories->contains('id', $category->id)) {
            abort(403, __('You are not authorized to manage this category.'));
        }

        try {
            $serviceQuery = Service::query()->where('category_id', $category->id);

            if ($user = Auth::user()) {
                $serviceQuery = $this->serviceAuthorizationService->restrictServiceQuery($serviceQuery, $user);
            }

            $serviceIds = $serviceQuery->pluck('id');
            if ($serviceIds->isEmpty()) {
                return response()->json([
                    'total' => 0,
                    'rows' => [],
                ]);
            }

            $offset = (int) $request->input('offset', 0);

            $limitParam = $request->input('limit', 50);
            if (is_string($limitParam) && strtolower($limitParam) === 'all') {
                $limit = -1;
            } else {
                $limit = (int) $limitParam;
                if ($limit === 0) {
                    $limit = 50;
                }
            }

            $sort = (string) $request->input('sort', 'id');
            $order = strtoupper((string) $request->input('order', 'DESC')) === 'ASC' ? 'ASC' : 'DESC';
            $search = trim((string) $request->input('search', ''));

            $reviewsQuery = ServiceReview::with(['service:id,title', 'user:id,name,profile'])
                ->whereIn('service_id', $serviceIds);

            if ($request->filled('status')) {
                $reviewsQuery->where('status', $request->status);
            }

            if ($search !== '') {
                $reviewsQuery->where(function ($q) use ($search) {
                    $q->where('review', 'like', "%{$search}%")
                        ->orWhereHas('service', function ($qs) use ($search) {
                            $qs->where('title', 'like', "%{$search}%");
                        })
                        ->orWhereHas('user', function ($qu) use ($search) {
                            $qu->where('name', 'like', "%{$search}%");
                        });
                });
            }

            $sortable = ['id', 'rating', 'status', 'created_at', 'updated_at'];
            if (!in_array($sort, $sortable, true)) {
                $sort = 'id';
            }

            $reviews = $reviewsQuery->orderBy($sort, $order)->get();

            $serviceTitles = Service::whereIn('id', $serviceIds)
                ->pluck('title', 'id');

            $reportsQuery = UserReports::with(['user:id,name,profile'])
                ->whereIn('item_id', $serviceIds)
                ->department(DepartmentReportService::DEPARTMENT_SERVICES);

            if ($search !== '') {
                $reportsQuery->where(function ($q) use ($search) {
                    $q->where('reason', 'like', "%{$search}%")
                        ->orWhere('other_message', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($qu) use ($search) {
                            $qu->where('name', 'like', "%{$search}%");
                        });
                });
            }

            $reports = $reportsQuery->orderBy('created_at', $order)->get();

            $reviewRows = $reviews->map(function (ServiceReview $review) {
                return [
                    'type' => 'review',
                    'is_report' => false,
                    'id' => $review->id,
                    'rating' => $review->rating,
                    'status' => $review->status,
                    'status_label' => $review->status,
                    'review' => $review->review,
                    'service' => $review->service ? [
                        'id' => $review->service->id,
                        'title' => $review->service->title,
                    ] : null,
                    'user' => $review->user ? [
                        'id' => $review->user->id,
                        'name' => $review->user->name,
                        'profile' => $review->user->profile,
                    ] : null,
                    'created_at' => optional($review->created_at)->toDateTimeString(),
                ];
            });

            $reportRows = $reports->map(function (UserReports $report) use ($serviceTitles) {
                return [
                    'type' => 'report',
                    'is_report' => true,
                    'id' => $report->id,
                    'rating' => '-',
                    'status' => 'report',
                    'status_label' => __('Report'),
                    'review' => trim($report->reason ?? $report->other_message ?? '') !== ''
                        ? ($report->reason ?? $report->other_message ?? '')
                        : __('User report'),
                    'reason' => $report->reason,
                    'other_message' => $report->other_message,
                    'service' => [
                        'id' => $report->item_id,
                        'title' => $serviceTitles[$report->item_id] ?? __('Service #:id', ['id' => $report->item_id]),
                    ],
                    'user' => $report->user ? [
                        'id' => $report->user->id,
                        'name' => $report->user->name,
                        'profile' => $report->user->profile,
                    ] : null,
                    'created_at' => optional($report->created_at)->toDateTimeString(),
                ];
            });

            $combined = $reviewRows->concat($reportRows)
                ->sortByDesc('created_at')
                ->values();

            $total = $combined->count();

            if ($limit > 0) {
                $combined = $combined->slice($offset, $limit)->values();
            }

            return response()->json([
                'total' => $total,
                'rows' => $combined,
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ServiceController -> categoryReviews');
            return ResponseService::errorResponse();
        }








    }

    /* =========================================================================
     | مصدر بيانات الجدول (JSON)
     | يدعم: البحث + فلاتر مبسطة
     | إصلاح حدّ الصفوف: limit افتراضي 50 + دعم limit=all أو limit<=0 لعرض الكل
     |=========================================================================*/
    public function list(Request $request)
    {
        ResponseService::noPermissionThenSendJson('service-list');

        $offset = (int) $request->input('offset', 0);

        $limitParam = $request->input('limit', 50);
        if (is_string($limitParam) && strtolower($limitParam) === 'all') {
            $limit = -1; // لاحقًا نعرض الكل
        } else {
            $limit = (int) $limitParam;
            if ($limit === 0) $limit = 50; // افتراضي
        }

        $sort   = $request->input('sort', 'id');
        $order  = strtoupper($request->input('order', 'DESC')) === 'ASC' ? 'ASC' : 'DESC';
        $search = trim((string) $request->input('search', ''));

        $query = $this->serviceListingQuery()
            ->when($search !== '', function ($q) use ($search) {
                $q->where(function ($qq) use ($search) {
                    $qq->where('title', 'LIKE', "%{$search}%")
                       ->orWhere('description', 'LIKE', "%{$search}%")
                       ->orWhere('service_uid', 'LIKE', "%{$search}%");
                });
            })
            // فلاتر اختيارية من واجهة الإدارة
            ->when($request->filled('category_id'), fn($q) => $q->where('category_id', $request->category_id))
            ->when($request->filled('status'),      fn($q) => $q->where('status', (bool)$request->status))
            ->when($request->filled('is_main'),     fn($q) => $q->where('is_main', (bool)$request->is_main))
            ->when($request->filled('is_paid'),     fn($q) => $q->where('is_paid', (bool)$request->is_paid))
            ->when($request->filled('has_custom_fields'), fn($q) => $q->where('has_custom_fields', (bool)$request->has_custom_fields))
            ->when($request->filled('direct_to_user'),    fn($q) => $q->where('direct_to_user', (bool)$request->direct_to_user));

        $total = (clone $query)->count();

        // حماية أسماء الأعمدة للفرز
        $sortable = ['id', 'title', 'is_main', 'status', 'price', 'currency', 'created_at', 'updated_at', 'views'];
        if (!in_array($sort, $sortable, true)) {
            $sort = 'id';
        }

        // عرض النتائج
        if ($limit <= 0) {
            $rows = $query->orderBy($sort, $order)->get();
        } else {
            $rows = $query->orderBy($sort, $order)
                ->skip($offset)
                ->take($limit)
                ->get();
        }

        $rows = $rows
            ->map(fn(Service $service) => $this->transformService($service))
            ->values()
            ->all();


        return response()->json([
            'total' => $total,
            'rows'  => $rows,
        ]);
    }



        /** بناء الاستعلام الأساسي للبطاقات */
    protected function serviceListingQuery(): Builder
    {
        $query = $this->baseServiceQuery()
            ->with([
                'category:id,name',
                'directUser:id,name',                
                'owner:id,name,email',


            ]);

        if ($this->supportsServiceRequests()) {
            $query->with([
                'latestRequest' => static function ($q) {
                    $q->select([
                        'service_requests.id',
                        DB::raw('service_requests.service_id as latest_request_service_id'),
                        'service_requests.status',
                        'service_requests.created_at',
                        'service_requests.user_id',
                    ])->with(['user:id,name']);


                },
            ])->withCount('requests');
        }


        return $query;
    }

    protected function baseServiceQuery(): Builder
    {
        $query = Service::query();



        if ($user = Auth::user()) {
            $query = $this->serviceAuthorizationService->restrictServiceQuery($query, $user);
        }

        return $query;
    }

    protected function getAccessibleCategories(array $columns = ['id', 'name'])
    {
        $categoryQuery = Category::whereIn('id', self::SERVICE_CATEGORY_IDS)
            ->orderBy('name');




        $user = Auth::user();
        if ($user && !$this->serviceAuthorizationService->userHasFullAccess($user)) {
            $categoryIds = $this->serviceAuthorizationService->getManagedCategoryIds($user);
            if (empty($categoryIds)) {
                return collect();
            }

            $categoryQuery->whereIn('id', $categoryIds);
        }

        return $categoryQuery->get($columns);
    
    }

    /** التحقق من توفر جدول طلبات الخدمات */
    protected function supportsServiceRequests(): bool
    {
        static $cached = null;

        if ($cached === null) {
            $cached = Schema::hasTable('service_requests');
        }

        return $cached;
    }

    /** تحويل نموذج الخدمة إلى مصفوفة مبسطة للواجهة */
    protected function transformService(Service $service): array
    {
        $latestRequest = $service->relationLoaded('latestRequest') ? $service->latestRequest : null;

        $requestsCount = (int) ($service->requests_count ?? 0);

        $latestRequestServiceId = null;
        if ($latestRequest) {
            $latestRequestServiceId = $latestRequest->getAttribute('latest_request_service_id');
            if ($latestRequestServiceId === null) {
                $latestRequestServiceId = $latestRequest->getAttribute('service_id');
            }
            if ($latestRequestServiceId !== null && $latestRequest->getAttribute('service_id') === null) {
                $latestRequest->setAttribute('service_id', $latestRequestServiceId);
            
            }
        }


        $descriptionPlain = $this->sanitizeDescription($service->description);



        return [
            'id' => $service->id,
            'title' => $service->title,
            'description' => $service->description,
            'description_plain' => $descriptionPlain,


            'image' => $service->image,
            'icon' => $service->icon,
            'status' => (bool) $service->status,
            'is_main' => (bool) $service->is_main,
            'is_paid' => (bool) $service->is_paid,
            'has_custom_fields' => (bool) $service->has_custom_fields,
            'direct_to_user' => (bool) $service->direct_to_user,
            'price' => $service->price !== null ? (float) $service->price : null,
            'currency' => $service->currency,
            'views' => (int) $service->views,
            'service_uid' => $service->service_uid,
            'expiry_date' => $service->expiry_date ? (string) $service->expiry_date : null,


            'created_at' => optional($service->created_at)->toDateTimeString(),
            'updated_at' => optional($service->updated_at)->toDateTimeString(),
            'category' => $service->category ? [
                'id' => $service->category->id,
                'name' => $service->category->name,
            ] : null,
            'direct_user' => $service->directUser ? [
                'id' => $service->directUser->id,
                'name' => $service->directUser->name,
            ] : null,
            'owner' => $service->owner ? [
                'id' => $service->owner->id,
                'name' => $service->owner->name,
                'email' => $service->owner->email,
            ] : null,

            'requests_count' => $this->supportsServiceRequests() ? $requestsCount : 0,
            'latest_request' => $this->supportsServiceRequests() && $latestRequest ? [
                'id' => $latestRequest->id,
                'service_id' => $latestRequestServiceId,


                'status' => $latestRequest->status,
                'created_at' => optional($latestRequest->created_at)->toDateTimeString(),
                'user' => $latestRequest->relationLoaded('user') && $latestRequest->user ? [
                    'id' => $latestRequest->user->id,
                    'name' => $latestRequest->user->name,
                ] : null,
            ] : null,
        ];
    }


    
    



    /**
     * تنقية الوصف من الوسوم والتعليقات وتحويل الكيانات إلى نص عادي
     */
    protected function sanitizeDescription(?string $description): ?string
    {
        if ($description === null) {
            return null;
        }

        $withoutComments = preg_replace('/<!--.*?-->/s', '', $description) ?? $description;
        $stripped = strip_tags($withoutComments);
        $decoded = html_entity_decode($stripped, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $normalizedWhitespace = preg_replace('/\s+/u', ' ', $decoded) ?? $decoded;

        return trim($normalizedWhitespace);
    }


    private function determineCategoryDepartment(Category $category): ?string
    {
        foreach (array_keys($this->departmentReportService->availableDepartments()) as $department) {
            $categoryIds = $this->departmentReportService->resolveCategoryIds($department);

            if (in_array($category->id, $categoryIds, true)) {
                return $department;
            }
        }

        return null;
    }

    private function departmentLabel(?string $department): string
    {
        return match ($department) {
            DepartmentReportService::DEPARTMENT_SHEIN => trans('departments.shein'),
            DepartmentReportService::DEPARTMENT_COMPUTER => trans('departments.computer'),
            DepartmentReportService::DEPARTMENT_STORE => trans('departments.store'),
            default => trans('Unknown Department'),
        };
    }

    private function buildCategoryRequestsStats(Category $category): array
    {
        $query = ServiceRequest::query()
            ->whereHas('service', static function (Builder $builder) use ($category) {
                $builder->where('category_id', $category->id);
            });

        if ($user = Auth::user()) {
            $query = $this->serviceAuthorizationService->restrictServiceRequestQuery($query, $user);
        }

        $total = (clone $query)->count();

        $statusCounts = (clone $query)
            ->select('status', DB::raw('COUNT(*) as aggregate_total'))
            ->groupBy('status')
            ->pluck('aggregate_total', 'status');

        $soldOutTotal = (int) (($statusCounts['sold out'] ?? 0)
            + ($statusCounts['sold_out'] ?? 0)
            + ($statusCounts['sold-out'] ?? 0));

        return [
            'total' => (int) $total,
            'review' => (int) ($statusCounts['review'] ?? 0),
            'approved' => (int) ($statusCounts['approved'] ?? 0),
            'rejected' => (int) ($statusCounts['rejected'] ?? 0),
            'sold_out' => $soldOutTotal,
        ];
    }





    /* =========================================================================
     | شاشة الإنشاء
     |=========================================================================*/
    public function create(Request $request)
    {
        ResponseService::noPermissionThenRedirect('service-create');

        $accessibleCategories = $this->getAccessibleCategories(['id', 'name']);

        if ($accessibleCategories->isEmpty()) {
            abort(403, __('You are not authorized to manage any categories.'));
        }

        $requestedCategoryId = $request->input('category_id', $request->input('category'));

        $category = null;

        if ($requestedCategoryId !== null) {
            $categoryId = (int) $requestedCategoryId;
            $category = $accessibleCategories->firstWhere('id', $categoryId);

            if (!$category) {
                abort(403, __('You are not authorized to manage this category.'));
            }
        } elseif ($accessibleCategories->count() === 1) {
            $category = $accessibleCategories->first();
        } else {
            return ResponseService::errorRedirectResponse(
                __('Please select a category before creating a service.'),
                route('services.index')
            );
        }

        $owners = User::customers()
            ->orderBy('name')
            ->get(['id', 'name']);

        // نستخدم نفس القائمة كخيارات للمستخدم الموجّه للدردشة
        $users = $owners;

        return view('services.create', compact('category', 'users', 'owners'));
    }

/* =========================================================================
 | الحفظ (إنشاء)
 |=========================================================================*/
public function store(Request $request)
{
    ResponseService::noPermissionThenSendJson('service-create');

    $rules = [
        'category_id'       => 'required|exists:categories,id',
        'title'             => 'required|string|max:255',
        'description'       => 'nullable|string',
        'is_main'           => 'required|boolean',
        'status'            => 'required|boolean',

        // تحكم التدفّق
        'is_paid'           => 'required|boolean',
        'price'             => 'required_if:is_paid,1|nullable|numeric|min:0',
        'currency'          => 'required_if:is_paid,1|nullable|in:YER,USD,SAR',
        'price_note'        => 'nullable|string',

        'has_custom_fields' => 'required|boolean', // سنحسبها فعليًا من السكيمة

        'direct_to_user'    => 'required|boolean',
        'direct_user_id'    => 'required_if:direct_to_user,1|nullable|exists:users,id',
        'owner_id'          => [
            'nullable',
            'integer',
            Rule::exists('users', 'id')->where(fn($q) => $q->where('account_type', User::ACCOUNT_TYPE_CUSTOMER)),
        ],
        'expiry_date'       => 'nullable|date',

        // مخطط الحقول (JSON كسلسلة؛ سنفكّه لاحقًا)
        'service_fields_schema' => 'nullable|string',

        // ملفات اختيارية
        'image'                 => 'nullable|image|max:5120',
        'icon'                  => 'nullable|image|max:2048',
        'service_field_icons'   => 'nullable|array',
        'service_field_icons.*' => 'nullable|image|max:2048',
    ];

    $data = $request->validate($rules);

    $category = Category::whereIn('id', self::SERVICE_CATEGORY_IDS)
        ->where('id', $data['category_id'])
        ->first();

    if (!$category) {
        ResponseService::validationError(__('Invalid category selected.'));
    }

    if ($user = $request->user()) {
        if (!$this->serviceAuthorizationService->userCanManageCategory($user, $category)) {
            ResponseService::validationError(__('You are not authorized to create services in this category.'));
        }
    }

    $data['category_id'] = $category->id;

    // فكّ السكيمة القادمة من النموذج ثم احسب has_custom_fields من الواقع
    $schemaPayload                 = $this->decodeSchemaOrNull($request->input('service_fields_schema'));
    $iconUploads                   = $request->file('service_field_icons', []);

    if ($request->boolean('has_custom_fields') && empty($schemaPayload)) {
        ResponseService::validationError(__('The custom fields schema is required when custom fields are enabled.'));
    }


    $data['service_fields_schema'] = $schemaPayload ?? [];
    $data['has_custom_fields']     = is_array($schemaPayload) && count($schemaPayload) > 0;
    $this->validateServiceCustomFieldInputs($request, $schemaPayload ?? []);

    // تطبيع القيم البوليانية وبقية الحقول
    $data['status']         = $request->boolean('status');
    $data['is_main']        = $request->boolean('is_main');
    $data['is_paid']        = $request->boolean('is_paid');
    $data['direct_to_user'] = $request->boolean('direct_to_user');
    $data['owner_id']       = $request->filled('owner_id') ? (int) $request->input('owner_id') : null;
    $data['expiry_date']    = $request->input('expiry_date') ?: null;

    if (!$data['is_paid']) {
        $data['price']    = null;
        $data['currency'] = null;
    }
    if (!$data['direct_to_user']) {
        $data['direct_user_id'] = null;
    }

    DB::beginTransaction();
    try {
        $service = new Service();
        $service->fill($data);

        // رفع الملفات
        $service->image = $this->handleUpload($request, 'image');
        $service->icon  = $this->handleUpload($request, 'icon');

        // منشئ/مُحدّث (اختياري)
        if ($service->isFillable('created_by')) {
            $service->created_by = Auth::id();
        }
        if ($service->isFillable('updated_by')) {
            $service->updated_by = Auth::id();
        }

        $service->save();

        // مزامنة حقول الخدمة المخصّصة مع الجدول المخصص (أساسي لظهورها في الـAPI ولوحة التحرير)
        $this->syncServiceCustomFields($service, $schemaPayload, $iconUploads);
        $this->syncServiceCustomFieldValues($service, $request);

        DB::commit();
        ResponseService::successResponse('تم إنشاء الخدمة بنجاح');
    } catch (QueryException $e) {
        DB::rollBack();
        ResponseService::logErrorResponse($e);
        ResponseService::errorResponse('فشل إنشاء الخدمة');
    } catch (Throwable $th) {
        DB::rollBack();
        ResponseService::logErrorResponse($th);
        ResponseService::errorResponse('حدث خطأ غير متوقع');
    }
}

    /* =========================================================================
     | شاشة التعديل
     |=========================================================================*/
    public function edit(Service $service)
    {
        ResponseService::noPermissionThenRedirect('service-edit');

        $this->ensureServiceAccessible($service);

        $service->load(['customFields', 'serviceCustomFields.value']);


        $categories = Category::whereIn('id', self::SERVICE_CATEGORY_IDS)
            ->orderBy('name')
            ->get(['id', 'name']);

        $owners = User::customers()
            ->orderBy('name')
            ->get(['id', 'name']);

        $users = $owners;


        // ✨ الحقول المخصّصة المحفوظة مسبقًا عبر علاقة الـ pivot (لا حاجة لـ ServiceFieldMap)
        $selectedServiceCF = [];
        foreach ($service->customFields as $cf) {
            $selectedServiceCF[$cf->id] = [
                'custom_field_id' => $cf->id,
                'is_required'     => (bool) ($cf->pivot->is_required ?? false),
                'sequence'        => (int)  ($cf->pivot->sequence ?? 1),
            ];
        }

        return view('services.edit', compact('service', 'categories', 'users', 'owners', 'selectedServiceCF'));
    }

/* =========================================================================
 | الحفظ (تعديل)
 |=========================================================================*/
public function update(Request $request, Service $service)
{
    ResponseService::noPermissionThenSendJson('service-edit');
    $this->ensureServiceAccessible($service);

    $rules = [
        'category_id'       => 'required|exists:categories,id',
        'title'             => 'required|string|max:255',
        'description'       => 'nullable|string',
        'is_main'           => 'required|boolean',
        'status'            => 'required|boolean',

        // تحكم التدفّق
        'is_paid'           => 'required|boolean',
        'price'             => 'required_if:is_paid,1|nullable|numeric|min:0',
        'currency'          => 'required_if:is_paid,1|nullable|in:YER,USD,SAR',
        'price_note'        => 'nullable|string',

        'has_custom_fields' => 'required|boolean',

        'direct_to_user'    => 'required|boolean',
        'direct_user_id'    => 'required_if:direct_to_user,1|nullable|exists:users,id',
        'owner_id'          => [
            'nullable',
            'integer',
            Rule::exists('users', 'id')->where(fn($q) => $q->where('account_type', User::ACCOUNT_TYPE_CUSTOMER)),
        ],
        'expiry_date'       => 'nullable|date',

        // السكيمة كسلسلة JSON (اختيارية)
        'service_fields_schema' => 'nullable|string',

        // ملفات اختيارية
        'image'                 => 'nullable|image|max:5120',
        'icon'                  => 'nullable|image|max:2048',
        'service_field_icons'   => 'nullable|array',
        'service_field_icons.*' => 'nullable|image|max:2048',
    ];

    $data = $request->validate($rules);

    // تطبيع القيم التابعة
    $data['status']         = $request->boolean('status');
    $data['is_main']        = $request->boolean('is_main');
    $data['is_paid']        = $request->boolean('is_paid');
    $data['direct_to_user'] = $request->boolean('direct_to_user');
    $data['owner_id']       = $request->filled('owner_id') ? (int) $request->input('owner_id') : null;
    $data['expiry_date']    = $request->input('expiry_date') ?: null;

    if (!$data['is_paid']) {
        $data['price']    = null;
        $data['currency'] = null;
    }
    if (!$data['direct_to_user']) {
        $data['direct_user_id'] = null;
    }

    // فك JSON للسكيمة القادمة (قد تكون null إذا لم تتغير)
    $schemaPayload = $this->decodeSchemaOrNull($request->input('service_fields_schema'));


    $iconUploads   = $request->file('service_field_icons', []);
    $existingSchema  = is_array($service->service_fields_schema) ? $service->service_fields_schema : [];

    if ($request->boolean('has_custom_fields') && empty($schemaPayload) && empty($existingSchema)) {
        ResponseService::validationError(__('The custom fields schema is required when custom fields are enabled.'));
    }


    if ($schemaPayload === null) {
        if ($request->boolean('has_custom_fields')) {
            // لم تُرسل سكيمة جديدة ونُبقي الحالية
            unset($data['service_fields_schema']);
        } else {
            // تعطيل الحقول المخصّصة
            $data['service_fields_schema'] = [];
        }
    } else {
        $data['service_fields_schema'] = $schemaPayload;
    }

    // احسب السكيمة الفعّالة لتحديد has_custom_fields ولمزامنة الجدول الفرعي
    $effectiveSchema = $schemaPayload !== null
        ? $schemaPayload
        : ($request->boolean('has_custom_fields') ? $existingSchema : []);

    // احسب العلم من الواقع بدل الاعتماد على المُدخل
    $data['has_custom_fields'] = is_array($effectiveSchema) && count($effectiveSchema) > 0;

    $existingFieldValues = $this->buildExistingFieldValueIndex($service);
    $this->validateServiceCustomFieldInputs($request, $effectiveSchema, $existingFieldValues);


    DB::beginTransaction();
    try {
        $service->fill($data);

        // استبدال الملفات عند الرفع الجديد + حذف القديم
        $service->image = $this->handleUpload($request, 'image', $service->image);
        $service->icon  = $this->handleUpload($request, 'icon',  $service->icon);

        if ($service->isFillable('updated_by')) {
            $service->updated_by = Auth::id();
        }

        $service->save();

        // مهم: المزامنة باستخدام السكيمة الفعّالة (حتى لو لم تُرسل في الطلب)
        $this->syncServiceCustomFields($service, $effectiveSchema, $iconUploads);


        $this->syncServiceCustomFieldValues($service, $request);



        DB::commit();
        ResponseService::successResponse('تم تحديث الخدمة بنجاح');
    } catch (QueryException $e) {
        DB::rollBack();
        ResponseService::logErrorResponse($e);
        ResponseService::errorResponse('فشل تحديث الخدمة');
    } catch (Throwable $th) {
        DB::rollBack();
        ResponseService::logErrorResponse($th);
        ResponseService::errorResponse('حدث خطأ غير متوقع');
    }
}


    /* =========================================================================
     | عرض التفاصيل (اختياري)
     |=========================================================================*/
    public function show(Service $service)
    {
        ResponseService::noPermissionThenRedirect('service-list');

        $this->ensureServiceAccessible($service);

        $service->load(['category', 'directUser', 'customFields', 'owner']);


        return view('services.show', compact('service'));
    }

    /* =========================================================================
     | الحذف
     |=========================================================================*/
    public function destroy(Service $service)
    {
        ResponseService::noPermissionThenSendJson('service-delete');

                $this->ensureServiceAccessible($service);


        DB::beginTransaction();
        try {

            $service->load('customFields');

            // فصل الحقول المخصّصة أولًا (لو فيه قيود FK)
            $service->customFields()->detach();

            // حذف الملفات من قرص public
            $this->deleteFromPublic($service->image);
            $this->deleteFromPublic($service->icon);

            $service->delete();

            DB::commit();
            ResponseService::successResponse('تم حذف الخدمة بنجاح');
        } catch (QueryException $e) {
            DB::rollBack();
            ResponseService::logErrorResponse($e);
            ResponseService::errorResponse('فشل حذف الخدمة (قد تكون مرتبطة بسجلات أخرى)');
        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th);
            ResponseService::errorResponse('حدث خطأ غير متوقع');
        }
    }



    /* =========================================================================
     | أدوات مساعدة خاصة
     |=========================================================================*/




        private function ensureServiceAccessible(Service $service): void
    {
        if ($user = Auth::user()) {
            $this->serviceAuthorizationService->ensureUserCanManageService($user, $service);
        }
    }


    /**
     * رفع ملف واحد إلى قرص public داخل مجلد services_images
     * يعيد المسار النسبي (بدون storage/) لتخزينه في قاعدة البيانات.
     * عند تمرير $oldPath سيتم حذف الملف القديم بعد نجاح الرفع.
     */
    private function handleUpload(Request $request, string $field, ?string $oldPath = null): ?string
    {
        if (!$request->hasFile($field)) {
            return $oldPath; // لا تغيير
        }

        $file = $request->file($field);
        $path = $file->store('services_images', 'public'); // مثال: services_images/abc.jpg

        // حذف القديم بأمان
        if ($oldPath && $oldPath !== $path) {
            $this->deleteFromPublic($oldPath);
        }

        return $path;
    }

    /**
     * حذف ملف من قرص public، يدعم مسارات تبدأ بـ "storage/" أو بدونه.
     */
    private function deleteFromPublic(?string $path): void
    {
        if (!$path) return;

        // تطبيع: لو تم تخزين "storage/services_images/xx" نحذف الـ prefix
        $normalized = preg_replace('#^storage/#', '', $path);

        if ($normalized && Storage::disk('public')->exists($normalized)) {
            Storage::disk('public')->delete($normalized);
        }
    }


    private function normalizeServiceFieldIconValue($value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_array($value)) {
            $value = Arr::first($value);
        }

        $value = trim((string) $value);

        if ($value === '' || strtolower($value) === 'null') {
            return null;
        }

        if (preg_match('#^https?://#i', $value)) {
            $parsed = parse_url($value, PHP_URL_PATH);
            if (is_string($parsed) && $parsed !== '') {
                $value = $parsed;
            }
        }

        $value = ltrim($value, '/');

        if (Str::startsWith($value, 'storage/')) {
            $value = substr($value, strlen('storage/'));
        }

        return $value !== '' ? $value : null;
    }

    private function deleteServiceFieldIcon($path, array &$deletedPaths): void
    {
        $normalized = $this->normalizeServiceFieldIconValue($path);

        if ($normalized === null || isset($deletedPaths[$normalized])) {
            return;
        }

        FileService::delete($normalized);
        $deletedPaths[$normalized] = true;
    }


    /**
     * يفك JSON string إلى مصفوفة، وإلا يعيد null (للاستخدام مع service_fields_schema)
     */
    private function decodeSchemaOrNull(?string $json): ?array
    {
        if ($json === null || trim($json) === '') {
            return null;
        }
        $decoded = json_decode($json, true);
        return (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) ? $decoded : null;
    }








    private function sanitizeFormKey(?string $value): string
    {
        return ServiceCustomField::normalizeKey($value);

    }

    private function normalizeFieldTypeName(?string $type): string
    {
        $type = strtolower((string) $type);

        return match ($type) {
            'select'   => 'dropdown',
            'file', 'image' => 'fileinput',
            'textarea' => 'textbox',
            default    => in_array($type, ['number', 'textbox', 'fileinput', 'radio', 'dropdown', 'checkbox', 'color'], true)
                ? $type
                : 'textbox',
        };
    }

    private function extractFieldOptionValues(array $field, string $type): array
    {
        $values = Arr::get($field, 'values');
        if (!is_array($values) || $values === []) {
            $values = Arr::get($field, 'options');
        }
        if (!is_array($values) || $values === []) {
            $values = Arr::get($field, 'choices');
        }
        if (!is_array($values)) {
            $values = [];
        }

        $values = array_map(function ($value) use ($type) {
            if (is_scalar($value) || (is_object($value) && method_exists($value, '__toString'))) {
                $value = (string) $value;
            } else {
                return null;
            }

            if ($type === 'color') {
                $value = strtoupper(ltrim($value, '#'));
            }

            return trim($value) !== '' ? $value : null;
        }, $values);

        $values = array_values(array_filter($values, static fn($v) => $v !== null && $v !== ''));

        if ($type === 'color') {
            $values = array_values(array_unique(array_map(static fn($v) => strtoupper($v), $values)));
        }

        return $values;
    }

    private function schemaFieldPrimaryKey(array $field, int $position): string
    {
        $candidates = [
            Arr::get($field, 'form_key'),
            Arr::get($field, 'meta.form_key'),
            Arr::get($field, 'name'),
            Arr::get($field, 'handle'),
            Arr::get($field, 'key'),
            Arr::get($field, 'label'),
            Arr::get($field, 'title'),
        ];

        foreach ($candidates as $candidate) {
            $candidate = $this->sanitizeFormKey($candidate);
            if ($candidate !== '') {
                return $candidate;
            }
        }

        if (isset($field['id'])) {
            return (string) $field['id'];
        }

        return 'field_' . $position;
    }

    private function schemaFieldAliases(array $field, int $position): array
    {
        $aliases = [];

        $primary = $this->schemaFieldPrimaryKey($field, $position);
        if ($primary !== '') {
            $aliases[] = $primary;
        }

        $metaKey = $this->sanitizeFormKey(Arr::get($field, 'meta.form_key'));
        if ($metaKey !== '' && !in_array($metaKey, $aliases, true)) {
            $aliases[] = $metaKey;
        }

        foreach (['form_key', 'name', 'handle', 'key', 'label', 'title'] as $attribute) {
            $candidate = $this->sanitizeFormKey(Arr::get($field, $attribute));
            if ($candidate !== '' && !in_array($candidate, $aliases, true)) {
                $aliases[] = $candidate;
            }
        }

        if (isset($field['id'])) {
            $aliases[] = (string) $field['id'];
        }

        return array_values(array_unique(array_filter($aliases, static fn($value) => $value !== '')));
    }

    private function fieldKeyAliases(ServiceCustomField $field): array
    {
        $aliases = [];

        $formKey = $this->sanitizeFormKey($field->form_key);
        if ($formKey !== '') {
            $aliases[] = $formKey;
        }

        $handle = $this->sanitizeFormKey($field->handle);
        if ($handle !== '' && !in_array($handle, $aliases, true)) {
            $aliases[] = $handle;
        }

        $name = $this->sanitizeFormKey($field->name);
        if ($name !== '' && !in_array($name, $aliases, true)) {
            $aliases[] = $name;
        }

        $aliases[] = (string) $field->id;

        return array_values(array_unique($aliases));
    }

    private function buildExistingFieldValueIndex(Service $service): array
    {
        $service->loadMissing(['serviceCustomFields.value']);

        $index = [];

        foreach ($service->serviceCustomFields as $field) {
            $valueModel = $field->value;
            $info = [
                'has_file' => $valueModel && $field->normalizedType() === 'fileinput' && $valueModel->getRawOriginal('value'),
                'model'    => $valueModel,
            ];

            foreach ($this->fieldKeyAliases($field) as $alias) {
                $index[$alias] = $info;
            }
        }

        return $index;
    }

    private function validateServiceCustomFieldInputs(Request $request, array $schema, array $existingValues = []): void
    {
        if (empty($schema)) {
            return;
        }

        $rules = [];
        $attributes = [];
        $requiredFileChecks = [];

        foreach ($schema as $position => $field) {
            if (!is_array($field)) {
                continue;
            }

            $type      = $this->normalizeFieldTypeName($field['type'] ?? $field['field_type'] ?? $field['input_type'] ?? 'textbox');
            $formKey   = $this->schemaFieldPrimaryKey($field, $position + 1);
            $aliases   = $this->schemaFieldAliases($field, $position + 1);
            $label     = trim((string) ($field['title'] ?? $field['label'] ?? $field['name'] ?? Str::title(str_replace('_', ' ', $formKey))));
            $required  = (bool) ($field['required'] ?? false);
            $options   = $this->extractFieldOptionValues($field, $type);

            $attributes["custom_fields.$formKey"] = $label;
            $attributes["custom_field_files.$formKey"] = $label;

            switch ($type) {
                case 'textbox':
                    $rule = [$required ? 'required' : 'nullable', 'string'];
                    if (isset($field['min_length']) && $field['min_length'] !== null && $field['min_length'] !== '') {
                        $rule[] = 'min:' . (int) $field['min_length'];
                    } elseif (isset($field['min']) && $field['min'] !== null && $field['min'] !== '') {
                        $rule[] = 'min:' . (int) $field['min'];
                    }
                    if (isset($field['max_length']) && $field['max_length'] !== null && $field['max_length'] !== '') {
                        $rule[] = 'max:' . (int) $field['max_length'];
                    } elseif (isset($field['max']) && $field['max'] !== null && $field['max'] !== '') {
                        $rule[] = 'max:' . (int) $field['max'];
                    }
                    $rules["custom_fields.$formKey"] = $rule;
                    break;
                case 'number':
                    $rule = [$required ? 'required' : 'nullable', 'numeric'];
                    $min = $field['min'] ?? $field['min_value'] ?? null;
                    $max = $field['max'] ?? $field['max_value'] ?? null;
                    if ($min !== null && $min !== '') {
                        $rule[] = 'min:' . (float) $min;
                    }
                    if ($max !== null && $max !== '') {
                        $rule[] = 'max:' . (float) $max;
                    }
                    $rules["custom_fields.$formKey"] = $rule;
                    break;
                case 'dropdown':
                case 'radio':
                case 'color':
                    $rule = [$required ? 'required' : 'nullable', 'string'];
                    if (!empty($options)) {
                        $rule[] = Rule::in($options);
                    }
                    $rules["custom_fields.$formKey"] = $rule;
                    break;
                case 'checkbox':
                    $rule = [$required ? 'required' : 'nullable', 'array'];
                    if ($required) {
                        $rule[] = 'min:1';
                    }
                    $rules["custom_fields.$formKey"] = $rule;
                    if (!empty($options)) {
                        $rules["custom_fields.$formKey.*"] = [Rule::in($options)];
                    }
                    break;
                case 'fileinput':
                    $rules["custom_field_files.$formKey"] = [$required ? 'nullable' : 'nullable', 'file', 'max:10240'];
                    if ($required) {
                        $requiredFileChecks[] = [
                            'form_key' => $formKey,
                            'label'    => $label,
                            'aliases'  => $aliases,
                        ];
                    }
                    break;
                default:
                    $rules["custom_fields.$formKey"] = [$required ? 'required' : 'nullable'];
            }
        }

        if (empty($rules)) {
            return;
        }

        $validator = Validator::make($request->all(), $rules, [], $attributes);

        if (!empty($requiredFileChecks)) {
            $validator->after(function ($validator) use ($requiredFileChecks, $existingValues, $request) {
                foreach ($requiredFileChecks as $check) {
                    $hasUpload = false;
                    foreach ($check['aliases'] as $alias) {
                        if ($request->hasFile('custom_field_files.' . $alias)) {
                            $hasUpload = true;
                            break;
                        }
                    }

                    if ($hasUpload) {
                        continue;
                    }

                    $hasExisting = false;
                    foreach ($check['aliases'] as $alias) {
                        if (!empty($existingValues[$alias]['has_file'])) {
                            $hasExisting = true;
                            break;
                        }
                    }

                    if (!$hasExisting) {
                        $validator->errors()->add('custom_field_files.' . $check['form_key'], __('The :attribute field is required.', ['attribute' => $check['label']]));
                    }
                }
            });
        }

        $validator->validate();
    }

    private function normalizeSubmittedCustomFieldValue(ServiceCustomField $field, $value)
    {
        $type = $field->normalizedType();

        if ($type === 'checkbox') {
            $values = is_array($value) ? $value : (isset($value) ? [$value] : []);
            $values = array_map(static fn($v) => is_scalar($v) || (is_object($v) && method_exists($v, '__toString')) ? trim((string) $v) : null, $values);
            $values = array_values(array_filter($values, static fn($v) => $v !== null && $v !== ''));

            $allowed = array_map(static fn($v) => (string) $v, $field->values);
            if (!empty($allowed)) {
                $values = array_values(array_intersect($values, $allowed));
            }

            return $values === [] ? null : $values;
        }

        if (is_array($value)) {
            $value = Arr::first($value);
        }

        if ($type === 'number') {
            if ($value === null || $value === '') {
                return null;
            }
            return is_numeric($value) ? (string) $value : null;
        }

        if (in_array($type, ['dropdown', 'radio', 'color'], true)) {
            if ($value === null || $value === '') {
                return null;
            }

            $value = (string) $value;
            if ($type === 'color') {
                $value = strtoupper(ltrim($value, '#'));
            }

            $allowed = array_map(static fn($v) => (string) $v, $field->values);
            if (!empty($allowed) && !in_array($value, $allowed, true)) {
                return null;
            }

            return $value;
        }

        if ($type === 'textbox') {
            return ($value === null || $value === '') ? null : (string) $value;
        }

        return ($value === null || $value === '') ? null : (string) $value;
    }

    private function syncServiceCustomFieldValues(Service $service, Request $request): void
    {
        $service->loadMissing('serviceCustomFields');
        $fields = $service->serviceCustomFields;

        if ($fields->isEmpty()) {
            $service->serviceCustomFieldValues()->delete();
            return;
        }

        $inputValues = $request->input('custom_fields', []);
        if (!is_array($inputValues)) {
            $inputValues = [];
        }

        $fileInputs = $request->file('custom_field_files', []);
        if (!is_array($fileInputs)) {
            $fileInputs = [];
        }

        $existing = $service->serviceCustomFieldValues()->get()->keyBy('service_custom_field_id');
        $upserts = [];
        $now = now();

        foreach ($fields as $field) {
            $aliases = $this->fieldKeyAliases($field);

            $value = null;
            foreach ($aliases as $alias) {
                if (array_key_exists($alias, $inputValues)) {
                    $value = $inputValues[$alias];
                    break;
                }
            }

            $file = null;
            foreach ($aliases as $alias) {
                if (isset($fileInputs[$alias])) {
                    $file = $fileInputs[$alias];
                    break;
                }
            }

            $existingValue = $existing->get($field->id);
            $type = $field->normalizedType();

            if ($file) {
                $path = $existingValue && $existingValue->getRawOriginal('value')
                    ? FileService::replace($file, 'services/custom_fields', $existingValue->getRawOriginal('value'))
                    : FileService::upload($file, 'services/custom_fields');

                $upserts[] = [
                    'service_id' => $service->id,
                    'service_custom_field_id' => $field->id,
                    'value' => $path,
                    'created_at' => $existingValue?->created_at ?? $now,
                    'updated_at' => $now,
                ];
                continue;
            }

            if ($type === 'fileinput') {
                continue;
            }

            $normalized = $this->normalizeSubmittedCustomFieldValue($field, $value);

            if ($normalized === null) {
                if ($existingValue) {
                    $existingValue->delete();
                }
                continue;
            }

            $upserts[] = [
                'service_id' => $service->id,
                'service_custom_field_id' => $field->id,
                'value' => is_array($normalized)
                    ? json_encode($normalized, JSON_UNESCAPED_UNICODE)
                    : (string) $normalized,
                'created_at' => $existingValue?->created_at ?? $now,
                'updated_at' => $now,
            ];
        }

        if (!empty($upserts)) {
            ServiceCustomFieldValue::upsert($upserts, ['service_id', 'service_custom_field_id'], ['value', 'updated_at']);
        }
    }





    /**
     * Sync the JSON schema stored on the service with the "service_custom_fields" table.
     *
     * The mobile application reads custom fields from this table; previously we only
     * stored the schema JSON so nothing was persisted for the API consumers. By
     * materialising the schema here we guarantee that:
     *   - the API returns the expected custom fields after publishing a service; and
     *   - re-opening the edit form shows the fields that were configured earlier.
     */



    public function syncServiceCustomFields(Service $service, ?array $schema = null, array $iconUploads = []): void
    {
        $schema = $schema ?? $service->service_fields_schema ?? null;

        if ($schema === null || !is_array($schema)) {
            return;
        }

        $relation = $service->serviceCustomFields();
        $existingFields = $relation->orderBy('sequence')->orderBy('id')->get();

        $normalizedUploads = [];
        foreach ($iconUploads as $key => $file) {
            if (!$file instanceof UploadedFile) {
                continue;
            }

            $stringKey = is_string($key) ? $key : (string) $key;
            $normalizedKey = $this->sanitizeFormKey($stringKey);
            if ($normalizedKey === '') {
                $normalizedKey = $stringKey;
            }

            $normalizedUploads[$normalizedKey] = $file;
        }

        $deletedIconPaths = [];

        
        if ($schema === []) {
            foreach ($existingFields as $field) {
                $this->deleteServiceFieldIcon($field->image, $deletedIconPaths);
            }

            $relation->delete();
            $service->setRelation('serviceCustomFields', $relation->getModel()->newCollection());

            $service->forceFill([
                'service_fields_schema' => [],
                'has_custom_fields'     => false,
            ])->save();


            return;
        }

        $existingFieldsById = $existingFields->keyBy('id');
        $existingFieldAliases = [];
        foreach ($existingFields as $existingField) {
            foreach ($this->fieldKeyAliases($existingField) as $alias) {
                if ($alias !== '' && !isset($existingFieldAliases[$alias])) {
                    $existingFieldAliases[$alias] = $existingField;
                }
            }
        }


        $payload = [];
        $sequenceFallback = 1;
        $matchedExistingIds = [];

        foreach ($schema as $index => $field) {
            if (!is_array($field)) {
                continue;
            }

            $title = trim((string)($field['title'] ?? $field['label'] ?? $field['name'] ?? ''));
            if ($title === '') {
                $title = 'Field ' . $sequenceFallback;
            }

            $type    = $this->normalizeFieldTypeName($field['type'] ?? $field['field_type'] ?? $field['input_type'] ?? 'textbox');
            $formKey = $this->schemaFieldPrimaryKey($field, $sequenceFallback);
            $aliases = $this->schemaFieldAliases($field, $sequenceFallback);


            $values  = $this->extractFieldOptionValues($field, $type);


            $existingField = null;
            if (isset($field['id'])) {
                $candidateId = (int) $field['id'];
                if ($existingFieldsById->has($candidateId)) {
                    $existingField = $existingFieldsById->get($candidateId);
                }
            }

            if (!$existingField) {
                foreach ($aliases as $alias) {
                    if (isset($existingFieldAliases[$alias])) {
                        $existingField = $existingFieldAliases[$alias];
                        break;
                    }
                }
            }

            if ($existingField) {
                $matchedExistingIds[$existingField->id] = true;
                foreach ($this->fieldKeyAliases($existingField) as $alias) {
                    unset($existingFieldAliases[$alias]);
                }
            }


            $minLength = $field['min_length'] ?? $field['min'] ?? null;
            $maxLength = $field['max_length'] ?? $field['max'] ?? null;
            $minValue  = $field['min'] ?? $field['min_value'] ?? null;
            $maxValue  = $field['max'] ?? $field['max_value'] ?? null;

            $sequence  = (int)($field['sequence'] ?? $sequenceFallback);
            $note      = isset($field['note']) ? trim((string)$field['note']) : '';


            $handleSource = $formKey !== ''
                ? $formKey
                : (string)($field['handle'] ?? $field['name'] ?? $field['key'] ?? $title);

                        $handle = $this->sanitizeFormKey($handleSource);

            if ($handle === '') {
                $handle = $this->sanitizeFormKey($title);
            }

            if ($handle === '' && $formKey !== '') {
                $handle = $formKey;
            }

            if ($handle === '') {
                $handle = 'field_' . $sequenceFallback;
            }

            $meta = is_array($field['meta'] ?? null) ? $field['meta'] : [];
            $meta['source'] = 'service_fields_schema';
            if ($handle !== '') {
                $meta['form_key'] = $handle;
            }


            $iconUpload = null;
            foreach ($aliases as $alias) {
                if (isset($normalizedUploads[$alias])) {
                    $iconUpload = $normalizedUploads[$alias];
                    unset($normalizedUploads[$alias]);
                    break;
                }
            }

            $existingIconPath = $existingField ? $this->normalizeServiceFieldIconValue($existingField->image) : null;
            $finalIconPath    = $existingIconPath;

            if ($iconUpload instanceof UploadedFile) {
                $finalIconPath = $existingIconPath
                    ? FileService::replace($iconUpload, self::SERVICE_FIELD_ICON_DIR, $existingIconPath)
                    : FileService::upload($iconUpload, self::SERVICE_FIELD_ICON_DIR);
            } else {
                if (array_key_exists('image', $field)) {
                    $normalizedSchemaIcon = $this->normalizeServiceFieldIconValue($field['image'] ?? null);
                    if ($normalizedSchemaIcon === null) {
                        if ($existingIconPath) {
                            $this->deleteServiceFieldIcon($existingIconPath, $deletedIconPaths);
                        }
                        $finalIconPath = null;
                    } else {
                        $finalIconPath = $normalizedSchemaIcon;
                    }
                }
            }




            $payload[] = [
                'name'        => $title,
                'handle'      => $handle,
                'type'        => $type,
                'is_required' => (bool)($field['required'] ?? false),
                'note'        => $note !== '' ? $note : null,
                'values'      => $values,
                'min_length'  => $type === 'textbox' && $minLength !== null ? (int) $minLength : null,
                'max_length'  => $type === 'textbox' && $maxLength !== null ? (int) $maxLength : null,
                'min_value'   => $type === 'number' && $minValue !== null ? (float) $minValue : null,
                'max_value'   => $type === 'number' && $maxValue !== null ? (float) $maxValue : null,
                'sequence'    => $sequence,
                'status'      => (bool)($field['status'] ?? $field['active'] ?? true),
                'meta'        => $meta,
                'image'       => $finalIconPath ?: null,
            ];

            $sequenceFallback++;
        }

        $removedFields = $existingFields->filter(static function (ServiceCustomField $field) use ($matchedExistingIds) {
            return !isset($matchedExistingIds[$field->id]);
        });
        
        foreach ($removedFields as $removedField) {
            $this->deleteServiceFieldIcon($removedField->image, $deletedIconPaths);

        }


        $relation->delete();
        if (!empty($payload)) {
            $relation->createMany($payload);
        }

        $fields = $relation
            ->orderBy('sequence')
            ->orderBy('id')
            ->get();


        $service->setRelation('serviceCustomFields', $fields);


        $canonicalSchema = $fields
            ->map(function (ServiceCustomField $field) {
                $payload = $field->toSchemaPayload();
                $meta = is_array($payload['meta'] ?? null) ? $payload['meta'] : [];
                if (!isset($meta['form_key']) || $meta['form_key'] === null || $meta['form_key'] === '') {
                    $meta['form_key'] = $field->form_key;
                }
                $payload['meta'] = $meta;
                $payload['name'] = $field->form_key;

                $displayName = is_string($field->name) && trim($field->name) !== ''
                    ? trim($field->name)
                    : (is_string($payload['title'] ?? null) ? trim((string) $payload['title']) : null);

                $displayName = trim((string) ($field->name ?? ''));
                if ($displayName === '') {
                    $displayName = is_string($payload['title'] ?? null)
                        ? trim((string) $payload['title'])
                        : '';
                }


                if ($displayName !== '') {
                    $payload['title'] = $displayName;
                    $payload['label'] = $displayName;
                } elseif (!isset($payload['label']) || trim((string) $payload['label']) === '') {
                    $fallback = $payload['title'] ?? $payload['name'];
                    $payload['title'] = $fallback;
                    $payload['label'] = $fallback;
                }

                return $payload;
            })
            
            
            ->values()
            ->all();

        $service->forceFill([
            'service_fields_schema' => $canonicalSchema,
            'has_custom_fields'     => $fields->isNotEmpty(),
        ])->save();
    }


}
