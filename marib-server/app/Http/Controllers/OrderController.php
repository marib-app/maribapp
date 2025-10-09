<?php

namespace App\Http\Controllers;
use App\Events\OrderNoteUpdated;

use App\Models\Order;
use App\Models\ManualPaymentRequest;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderStatus;
use App\Models\OrderPaymentGroup;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Services\DepartmentReportService;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\Route;

class OrderController extends Controller
{




    /**
     * إنشاء مثيل جديد للمتحكم
     */
    public function __construct()
    {
        // لا حاجة لـ middleware هنا، سيتم فحص الصلاحيات في كل دالة
    }

    /**
     * عرض قائمة الطلبات
     *
     * @return \Illuminate\Http\Response
     */
    public function index(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['orders-list']);
        
        $query = Order::with([
            'user' => static fn ($query) => $query->withTrashed(),
            'seller' => static fn ($query) => $query->withTrashed(),
            'items.item.category',
            'latestManualPaymentRequest' => static function ($query) {
                $query->select([
                    'manual_payment_requests.id',
                    'manual_payment_requests.payable_id',
                    'manual_payment_requests.payable_type',
                    'manual_payment_requests.status',
                    'manual_payment_requests.amount',
                    'manual_payment_requests.currency',
                    'manual_payment_requests.created_at',
                    'manual_payment_requests.reviewed_at',
                ]);
            },
        ])
        
        ->withCount(['openManualPaymentRequests as pending_manual_payment_requests_count'])

        
            ->where(function ($query) {
                $query->whereNull('department')
                    ->orWhereNotIn('department', [
                        DepartmentReportService::DEPARTMENT_SHEIN,
                        DepartmentReportService::DEPARTMENT_COMPUTER,
                    ]);
            });
        // 
        if ($request->filled('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        // تطبيق التصفية حسب حالة الطلب
        if ($request->filled('order_status')) {
            $query->where('order_status', $request->order_status);
        }

        // تطبيق التصفية حسب حالة الدفع
        if ($request->filled('payment_status')) {
            $query->where('payment_status', $request->payment_status);

        }

        // تطبيق التصفية حسب التاريخ
        if ($request->filled('date_from')) {
            $query->whereDate('created_at', '>=', $request->date_from);
        }

        if ($request->filled('date_to')) {
            $query->whereDate('created_at', '<=', $request->date_to);
        }

        // تطبيق البحث
        if ($request->filled('search')) {
            $query->search($request->search);
        }

        // ترتيب النتائج
        $query->orderBy('created_at', 'desc');

        // تقسيم النتائج
        $orders = $query->paginate(15);

   
        $orderStatuses = $this->allowedOrderStatuses();

   
        $users = User::customers()->orWhereNull('account_type')->orderBy('name')->get();
        
       
        $sellers = User::sellers()->orderBy('name')->get();

        $statusLabels = $this->buildStatusLabels($orderStatuses);
        $deliveryPaymentTimingLabels = $this->deliveryPaymentTimingLabels();
        $deliveryPaymentStatusLabels = $this->deliveryPaymentStatusLabels();

        return view('orders.index', compact(
            'orders',
            'orderStatuses',
            'users',
            'sellers',
            'statusLabels',
            'deliveryPaymentTimingLabels',
            'deliveryPaymentStatusLabels'
        ));
    
    }



    public function indexShein(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-list']);
        // إعداد الاستعلام مع تحميل العلاقات وتصفية حسب الفئة الأم رقم 4
        $department = DepartmentReportService::DEPARTMENT_SHEIN;
        $categoryIds = app(DepartmentReportService::class)->resolveCategoryIds($department);

        $query = Order::with([
            'user' => static fn ($query) => $query->withTrashed(),
            'seller' => static fn ($query) => $query->withTrashed(),
            'items.item.category',
            'latestManualPaymentRequest' => static function ($query) {
                $query->select([
                    'manual_payment_requests.id',
                    'manual_payment_requests.payable_id',
                    'manual_payment_requests.payable_type',
                    'manual_payment_requests.status',
                    'manual_payment_requests.amount',
                    'manual_payment_requests.currency',
                    'manual_payment_requests.created_at',
                    'manual_payment_requests.reviewed_at',
                ]);
            },
        ])
        
        ->withCount(['openManualPaymentRequests as pending_manual_payment_requests_count'])
            ->where(function ($query) use ($department, $categoryIds) {
                $query->where('department', $department);

                if ($categoryIds !== []) {
                    $query->orWhereHas('items.item', static function ($query) use ($categoryIds) {
                        $query->whereIn('category_id', $categoryIds);
                    });
                }
            });

        // 
        if ($request->filled('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        // تطبيق التصفية حسب التاجر
        if ($request->filled('seller_id')) {
            $query->where('seller_id', $request->seller_id);
        }

        // تطبيق التصفية حسب حالة الطلب
        if ($request->filled('order_status')) {
            $query->where('order_status', $request->order_status);
        }

        // تطبيق التصفية حسب حالة الدفع
        if ($request->filled('payment_status')) {
            $query->where('payment_status', $request->payment_status);

        }

        // تطبيق التصفية حسب التاريخ
        if ($request->filled('date_from')) {
            $query->whereDate('created_at', '>=', $request->date_from);
        }

        if ($request->filled('date_to')) {
            $query->whereDate('created_at', '<=', $request->date_to);
        }

        // تطبيق البحث
        if ($request->filled('search')) {
            $query->search($request->search);
        }

        // ترتيب النتائج
        $query->orderBy('created_at', 'desc');

        // تقسيم النتائج
        $orders = $query->paginate(15);

        // الحصول على حالات الطلبات
        $orderStatuses = $this->allowedOrderStatuses();

        // الحصول على قائمة المستخدمين للفلتر (العملاء)
        $users = User::customers()->orWhereNull('account_type')->orderBy('name')->get();
        


        $sheinOrdersConstraint = static function ($query) use ($department, $categoryIds) {
            $query->where(function ($query) use ($department, $categoryIds) {
                $query->where('department', $department);

                if ($categoryIds !== []) {
                    $query->orWhereHas('items.item', static function ($itemQuery) use ($categoryIds) {
                        $itemQuery->whereIn('category_id', $categoryIds);
                    });
                }
            });
        };

        $paymentGroups = OrderPaymentGroup::query()
            ->withCount(['orders as shein_orders_count' => $sheinOrdersConstraint])
            ->withSum(['orders as shein_orders_total_amount' => $sheinOrdersConstraint], 'final_amount')
            ->orderByDesc('updated_at')
            ->get()
            ->filter(static fn ($group) => (int) ($group->shein_orders_count ?? 0) > 0)
            ->values();

        return view('orders.shein', compact('orders', 'orderStatuses', 'users', 'categoryIds', 'department', 'paymentGroups'));
    
    }



        public function indexComputer(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['computer-orders-list']);

        $department = DepartmentReportService::DEPARTMENT_COMPUTER;
        $categoryIds = app(DepartmentReportService::class)->resolveCategoryIds($department);


        $query = Order::with([
            'user' => static fn ($query) => $query->withTrashed(),
            'seller' => static fn ($query) => $query->withTrashed(),
            'items.item.category',
            'latestManualPaymentRequest' => static function ($query) {
                $query->select([
                    'manual_payment_requests.id',
                    'manual_payment_requests.payable_id',
                    'manual_payment_requests.payable_type',
                    'manual_payment_requests.status',
                    'manual_payment_requests.amount',
                    'manual_payment_requests.currency',
                    'manual_payment_requests.created_at',
                    'manual_payment_requests.reviewed_at',
                ]);
            },
        ])
            ->withCount(['openManualPaymentRequests as pending_manual_payment_requests_count'])
            ->where(function ($query) use ($department, $categoryIds) {

                
                $query->where('department', $department);

                if ($categoryIds !== []) {
                    $query->orWhereHas('items.item', static function ($query) use ($categoryIds) {
                        $query->whereIn('category_id', $categoryIds);
                    });
                }
            });

        if ($request->filled('user_id')) {
            $query->where('user_id', $request->user_id);
        }



        if ($request->filled('order_status')) {
            $query->where('order_status', $request->order_status);
        }

        if ($request->filled('payment_status')) {
            $query->where('payment_status', $request->payment_status);


        }

        if ($request->filled('date_from')) {
            $query->whereDate('created_at', '>=', $request->date_from);
        }

        if ($request->filled('date_to')) {
            $query->whereDate('created_at', '<=', $request->date_to);
        }

        if ($request->filled('search')) {
            $query->search($request->search);
        }

        $query->orderBy('created_at', 'desc');

        $orders = $query->paginate(15);

        $orderStatuses = $this->allowedOrderStatuses();

        $users = User::customers()->orWhereNull('account_type')->orderBy('name')->get();

        return view('orders.computer', compact('orders', 'orderStatuses', 'users', 'categoryIds', 'department'));

    }
    

    /**
     * عرض نموذج إنشاء طلب جديد
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
        ResponseService::noAnyPermissionThenRedirect(['orders-create']);
        
        // الحصول على قائمة المستخدمين (العملاء)
        $users = User::customers()->orWhereNull('account_type')->orderBy('name')->get();
        
        // الحصول على قائمة التجار
        $sellers = User::sellers()->orderBy('name')->get();

        // الحصول على حالات الطلبات
        $orderStatuses = $this->allowedOrderStatuses();

        $paymentMethods = $this->allowedPaymentMethods();

        return view('orders.create', compact('users', 'sellers', 'orderStatuses', 'paymentMethods'));    }

    /**
     * تخزين طلب جديد
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['orders-create']);
        
        // التحقق من البيانات
        $request->validate([
            'user_id' => 'required|exists:users,id',
            'seller_id' => 'nullable|exists:users,id',
            'items' => 'required|array|min:1',
            'items.*.item_id' => 'required|exists:items,id',
            'items.*.price' => 'required|numeric|min:0',
            'items.*.quantity' => 'required|integer|min:1',
            'payment_method' => ['nullable', Rule::in(array_keys($this->allowedPaymentMethods()))],
            'shipping_address' => 'nullable|string',
            'billing_address' => 'nullable|string',
            'notes' => 'nullable|string',
        ]);

        try {
            // بدء المعاملة
            DB::beginTransaction();

            // حساب المبالغ
            $totalAmount = 0;
            foreach ($request->items as $item) {
                $totalAmount += $item['price'] * $item['quantity'];
            }

            $taxAmount = $totalAmount * 0.15; // 15% ضريبة
            $finalAmount = $totalAmount + $taxAmount;

            // إنشاء الطلب
            $order = Order::create([
                'user_id' => $request->user_id,
                'seller_id' => $request->seller_id,
                'order_number' => null,
                'total_amount' => $totalAmount,
                'tax_amount' => $taxAmount,
                'discount_amount' => 0,
                'final_amount' => $finalAmount,
                'payment_method' => $request->payment_method,
                'payment_status' => 'pending',
                'order_status' => Order::STATUS_PROCESSING,
                'shipping_address' => $request->shipping_address,
                'billing_address' => $request->billing_address,
                'notes' => $request->notes,
            ]);

            $order = $order->refreshOrderNumber();


            // إضافة عناصر الطلب
            foreach ($request->items as $itemData) {
                $item = \App\Models\Item::findOrFail($itemData['item_id']);
                $subtotal = $itemData['price'] * $itemData['quantity'];

                OrderItem::create([
                    'order_id' => $order->id,
                    'item_id' => $item->id,
                    'item_name' => $item->name,
                    'price' => $itemData['price'],
                    'quantity' => $itemData['quantity'],
                    'subtotal' => $subtotal,
                    'options' => $itemData['options'] ?? null,
                ]);
            }

            // إضافة سجل الطلب
            OrderHistory::create([
                'order_id' => $order->id,
                'user_id' => Auth::id(),
                'status_to' => Order::STATUS_PROCESSING,
                'comment' => 'تم إنشاء الطلب',
            ]);

            // تأكيد المعاملة
            DB::commit();

            return redirect()->route('orders.show', $order->id)
                ->with('success', 'تم إنشاء الطلب بنجاح');
        } catch (\Exception $e) {
            // التراجع عن المعاملة في حالة حدوث خطأ
            DB::rollBack();
            
            return redirect()->back()
                ->with('error', 'حدث خطأ أثناء إنشاء الطلب: ' . $e->getMessage())
                ->withInput();
        }
    }

    /**
     * عرض تفاصيل الطلب
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        // الحصول على الطلب مع العلاقات
        $order = Order::with([
            'user' => static fn ($query) => $query->withTrashed(),
            'seller' => static fn ($query) => $query->withTrashed(),
            'items',
            'history.user' => static fn ($query) => $query->withTrashed(),
        ])
        
        ->findOrFail($id);

        // الحصول على حالات الطلبات
        $orderStatuses = $this->allowedOrderStatuses();
        $paymentStatusOptions = Order::paymentStatusLabels();

        $statusLabels = $this->buildStatusLabels($orderStatuses);
        $paymentStatusOptions = Order::paymentStatusLabels();
        $deliveryPaymentTimingLabels = $this->deliveryPaymentTimingLabels();
        $deliveryPaymentStatusLabels = $this->deliveryPaymentStatusLabels();






        $cartSnapshot = is_array($order->cart_snapshot) ? $order->cart_snapshot : [];
        $cartItemsSnapshot = collect(data_get($cartSnapshot, 'items', []))
            ->filter(static fn ($item) => is_array($item))
            ->mapWithKeys(static function (array $item): array {
                $itemId = data_get($item, 'item_id');
                $variantId = data_get($item, 'variant_id');

                $key = sprintf('%s:%s', $itemId ?? 'null', $variantId ?? 'null');

                return [$key => $item];
            });

        $normalizeImageUrl = static function ($value): ?string {
            if ($value === null) {
                return null;
            }

            if (is_array($value)) {
                $value = reset($value);
            }

            if (! is_scalar($value)) {
                return null;
            }

            $value = trim((string) $value);

            if ($value === '') {
                return null;
            }

            if (Str::startsWith($value, ['http://', 'https://'])) {
                return $value;
            }

            if (Str::startsWith($value, '//')) {
                return 'https:' . $value;
            }

            return asset(ltrim($value, '/'));
        };

        $orderItemsDisplayData = $order->items->map(function (OrderItem $orderItem) use ($cartItemsSnapshot, $normalizeImageUrl) {
            $itemSnapshot = is_array($orderItem->item_snapshot) ? $orderItem->item_snapshot : [];
            $pricingSnapshot = is_array($orderItem->pricing_snapshot) ? $orderItem->pricing_snapshot : [];

            $snapshotKey = sprintf('%s:%s', $orderItem->item_id ?? 'null', $orderItem->variant_id ?? 'null');
            $cartSnapshotItem = $cartItemsSnapshot->get($snapshotKey, []);

            if (! is_array($cartSnapshotItem)) {
                $cartSnapshotItem = [];
            }

            $options = $orderItem->options ?? $orderItem->attributes ?? data_get($itemSnapshot, 'attributes', []);

            if (is_string($options)) {
                $decoded = json_decode($options, true);

                if (json_last_error() === JSON_ERROR_NONE) {
                    $options = $decoded;
                }
            }

            $options = is_array($options) ? $options : [];

            $optionsDisplay = collect($options)
                ->map(static function ($value, $key) {
                    if (is_array($value)) {
                        $value = collect($value)
                            ->map(static fn ($item) => is_scalar($item) ? trim((string) $item) : null)
                            ->filter()
                            ->implode(', ');
                    } elseif (is_bool($value)) {
                        $value = $value ? 'نعم' : 'لا';
                    }

                    if (is_scalar($value)) {
                        $value = trim((string) $value);
                    } else {
                        $value = json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
                    }

                    if ($value === null || $value === '') {
                        return null;
                    }

                    $label = Str::of((string) $key)
                        ->replace('_', ' ')
                        ->squish()
                        ->title();

                    return [
                        'label' => (string) $label,
                        'value' => $value,
                    ];
                })
                ->filter()
                ->values()
                ->all();

            $advertiserSource = collect([
                data_get($cartSnapshotItem, 'stock_snapshot.department_advertiser'),
                data_get($itemSnapshot, 'stock_snapshot.department_advertiser'),
                data_get($itemSnapshot, 'department_advertiser'),
                data_get($pricingSnapshot, 'department_advertiser'),
                data_get($pricingSnapshot, 'advertisement'),
            ])->first(static fn ($data) => is_array($data) && collect($data)->filter(fn ($value) => filled($value))->isNotEmpty());

            $advertiserFields = [];

            if (is_array($advertiserSource)) {
                $labelOverrides = [
                    'name' => 'الاسم',
                    'contact_number' => 'رقم الاتصال',
                    'message_number' => 'رقم الواتساب',
                    'location' => 'الموقع',
                    'notes' => 'ملاحظات',
                    'reference' => 'المرجع',
                    'id' => 'المعرّف',
                ];

                foreach ($advertiserSource as $field => $value) {
                    if ($value === null || $value === '') {
                        continue;
                    }

                    if (is_array($value)) {
                        $value = collect($value)
                            ->map(static fn ($item) => is_scalar($item) ? trim((string) $item) : null)
                            ->filter()
                            ->implode(', ');
                    } elseif (is_bool($value)) {
                        $value = $value ? 'نعم' : 'لا';
                    }

                    if (is_scalar($value)) {
                        $value = trim((string) $value);
                    } else {
                        $value = json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
                    }

                    if ($value === '') {
                        continue;
                    }

                    $label = $labelOverrides[$field] ?? Str::of((string) $field)
                        ->replace('_', ' ')
                        ->squish()
                        ->title();

                    $advertiserFields[] = [
                        'label' => (string) $label,
                        'value' => $value,
                    ];
                }
            }

            $thumbnailCandidates = [
                $orderItem->item?->image,
                data_get($itemSnapshot, 'image'),
                data_get($itemSnapshot, 'thumbnail'),
                data_get($itemSnapshot, 'stock_snapshot.image'),
                data_get($itemSnapshot, 'stock_snapshot.thumbnail'),
                data_get($itemSnapshot, 'stock_snapshot.images.0'),
                data_get($cartSnapshotItem, 'stock_snapshot.image'),
                data_get($cartSnapshotItem, 'stock_snapshot.images.0'),
                data_get($cartSnapshotItem, 'image'),
            ];

            $thumbnailUrl = collect($thumbnailCandidates)
                ->map($normalizeImageUrl)
                ->filter()
                ->first();

            if (! $thumbnailUrl) {
                $thumbnailUrl = asset('assets/images/no_image_available.png');
            }

            $productUrl = null;

            if ($orderItem->item_id) {
                if (Route::has('item.details')) {
                    $productUrl = route('item.details', ['item' => $orderItem->item_id]);
                } else {
                    $productUrl = url(sprintf('item/%s/details', $orderItem->item_id));
                }
            }

            $variantLabel = data_get($itemSnapshot, 'variant_name')
                ?? data_get($cartSnapshotItem, 'variant_name');

            return [
                'id' => $orderItem->getKey(),
                'item_id' => $orderItem->item_id,
                'variant_id' => $orderItem->variant_id,
                'name' => $orderItem->item_name ?? $orderItem->item?->name,
                'price' => (float) $orderItem->price,
                'quantity' => (float) $orderItem->quantity,
                'subtotal' => (float) $orderItem->subtotal,
                'options' => $optionsDisplay,
                'has_options' => ! empty($optionsDisplay),
                'advertiser' => $advertiserFields,
                'has_advertiser' => ! empty($advertiserFields),
                'thumbnail_url' => $thumbnailUrl,
                'product_url' => $productUrl,
                'variant_label' => $variantLabel,
                'currency' => $orderItem->currency ?? data_get($pricingSnapshot, 'currency') ?? data_get($cartSnapshotItem, 'currency'),


            ];
        })->values();



        $statusHistoryUserIds = collect($order->status_history ?? [])
            ->pluck('user_id')
            ->filter()
            ->unique()
            ->values();

        $statusHistoryUsers = $statusHistoryUserIds->isEmpty()
            ? collect()
            : User::withTrashed()->whereIn('id', $statusHistoryUserIds)->get()->keyBy('id');


        $order->load([
            'paymentGroups.orders' => static function ($query) {
                $query->select('orders.id', 'orders.order_number', 'orders.final_amount')
                    ->with(['items' => static function ($itemQuery) {
                        $itemQuery->select('order_items.id', 'order_items.order_id', 'order_items.quantity');
                    }]);
            },
             'manualPaymentRequests' => static function ($query) {
                $query->orderByDesc('id')
                    ->with('paymentTransaction');
            },
        ]);

        $paymentGroups = $order->paymentGroups;

        $availablePaymentGroups = OrderPaymentGroup::query()
            ->select(['id', 'name', 'note', 'created_at'])
            ->withCount('orders')
            ->whereDoesntHave('orders', static function ($query) use ($order) {
                $query->where('orders.id', $order->getKey());
            })
            ->orderBy('name')
            ->get();


        $pendingManualPaymentRequest = $order->manualPaymentRequests
            ->first(static fn (ManualPaymentRequest $request) => $request->isOpen());



        return view('orders.show', compact(
            'order',
            'orderStatuses',
            'statusLabels',
            'deliveryPaymentTimingLabels',
            'deliveryPaymentStatusLabels',
            'statusHistoryUsers',
            'paymentStatusOptions',
            'orderItemsDisplayData',
            'paymentGroups',
            'availablePaymentGroups',
            'pendingManualPaymentRequest'
        
        ));
    }

    /**
     * عرض نموذج تعديل الطلب
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit($id)
    {
        // الحصول على الطلب مع العلاقات
        $order = Order::with([
                'user' => static fn ($query) => $query->withTrashed(),
                'items',
                'history.user' => static fn ($query) => $query->withTrashed(),
                'manualPaymentRequests.paymentTransaction',
            ])
            
            ->findOrFail($id);

        $pendingManualPaymentRequest = $order->manualPaymentRequests
            ->first(static fn (ManualPaymentRequest $request) => $request->isOpen());


        // الحصول على قائمة المستخدمين
        $users = User::orderBy('name')->get();

        // الحصول على حالات الطلبات
        $orderStatuses = $this->allowedOrderStatuses($order, true);

        $paymentStatusOptions = Order::paymentStatusLabels();

        return view(
            'orders.edit',
            compact('order', 'users', 'orderStatuses', 'paymentStatusOptions', 'pendingManualPaymentRequest')
        );


    
    }

    /**
     * تحديث الطلب
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(Request $request, $id)
    {
        ResponseService::noAnyPermissionThenRedirect(['orders-update']);
        
        // التحقق من البيانات
        $request->validate([
            'order_status' => ['required', 'string', Rule::in(Order::statusValues())],
            'shipping_address' => 'nullable|string',
            'billing_address' => 'nullable|string',
            'notes' => 'nullable|string',
            'comment' => 'nullable|string',
            'notify_customer' => 'nullable|boolean',
            'tracking_number' => ['nullable', 'string', 'max:255'],
            'carrier_name' => ['nullable', 'string', 'max:255'],
            'tracking_url' => ['nullable', 'url', 'max:2048'],
            'delivery_proof_image_path' => ['nullable', 'string', 'max:2048'],
            'delivery_proof_signature_path' => ['nullable', 'string', 'max:2048'],
            'delivery_proof_otp_code' => ['nullable', 'string', 'max:64'],

        ]);

        try {
            // بدء المعاملة
            DB::beginTransaction();

            // الحصول على الطلب
            $order = Order::findOrFail($id);







            $pendingManualPaymentRequest = $order->latestPendingManualPaymentRequest();

            if (
                $pendingManualPaymentRequest
                && $request->order_status !== $order->order_status
            ) {
                DB::rollBack();

                $reviewUrl = route('manual-payments.review', $pendingManualPaymentRequest->getKey());
                $message = sprintf(
                    'لا يمكن تعديل حالة الطلب لوجود طلب دفع يدوي #%d قيد المراجعة. يرجى إتمام المراجعة عبر %s.',
                    $pendingManualPaymentRequest->getKey(),
                    $reviewUrl
                );

                return redirect()->back()
                    ->with('error', $message)
                    ->withInput();
            }

            
            // حفظ الحالة السابقة
            $previousStatus = $order->order_status;
            
            // تحديث بيانات الطلب
            $trackingAttributes = $this->prepareTrackingAttributes($request);

            $order->fill(array_merge([


                'order_status' => $request->order_status,
                'shipping_address' => $request->shipping_address,
                'billing_address' => $request->billing_address,
                'notes' => $request->notes,
            ], $trackingAttributes));

            $noteWasUpdated = $order->isDirty('notes');
            $updatedNote = $order->notes;

            $order->save();



            
            // إضافة سجل للطلب إذا تغيرت الحالة
            if ($previousStatus !== $request->order_status) {
                OrderHistory::create([
                    'order_id' => $order->id,
                    'user_id' => Auth::id(),
                    'status_from' => $previousStatus,
                    'status_to' => $request->order_status,
                    'comment' => $request->comment,
                    'notify_customer' => $request->has('notify_customer'),
                ]);

                // إذا كانت الحالة "مكتمل"، نقوم بتحديث تاريخ الإكمال
                if ($request->order_status === 'delivered') {
                    $order->update(['completed_at' => now()]);
                }

                if ($request->has('notify_customer') && $request->boolean('notify_customer') && filled($request->comment)) {
                    event(new OrderNoteUpdated(
                        $order->fresh('user'),
                        $request->comment,
                        Auth::id(),
                        'history_comment'
                    ));
                }
            }

            if ($noteWasUpdated && filled($updatedNote)) {
                event(new OrderNoteUpdated(
                    $order->fresh('user'),
                    $updatedNote,
                    Auth::id(),
                    'order_note'
                ));

            }

            // تأكيد المعاملة
            DB::commit();

            return redirect()->route('orders.show', $order->id)
                ->with('success', 'تم تحديث الطلب بنجاح');
        } catch (\Exception $e) {
            // التراجع عن المعاملة في حالة حدوث خطأ
            DB::rollBack();
            
            return redirect()->back()
                ->with('error', 'حدث خطأ أثناء تحديث الطلب: ' . $e->getMessage())
                ->withInput();
        }
    }




    /**
     * الحصول على حالات الطلب المسموح بها.
     *
     * @return \Illuminate\Support\Collection<int, \App\Models\OrderStatus>
     */
    private function allowedOrderStatuses(?Order $contextOrder = null, ?bool $includeReserve = null)
    {
        $includeReserve = $includeReserve ?? request()->boolean('include_reserve_statuses');

        $query = OrderStatus::query()
            ->whereIn('code', Order::statusValues());

        if ($includeReserve) {
            $query->where(function ($builder) {
                $builder->where('is_active', true)
                    ->orWhere('is_reserve', true);
            });
        } else {
            $query->where('is_active', true);
        }

        $statuses = $query->orderBy('sort_order')->get();

        if ($contextOrder !== null) {
            $currentStatus = $contextOrder->order_status;

            if (is_string($currentStatus) && $currentStatus !== '') {
                $currentStatusEntry = OrderStatus::where('code', $currentStatus)->get();

                if ($currentStatusEntry->isNotEmpty()) {
                    $statuses = $statuses
                        ->concat($currentStatusEntry)
                        ->unique('code')
                        ->sortBy('sort_order')
                        ->values();
                }
            }
        }

        return $statuses;
    }

    /**
     * @return array<string, mixed>
     */
    private function prepareTrackingAttributes(Request $request): array
    {
        $status = (string) $request->input('order_status', '');

        if (! in_array($status, [Order::STATUS_OUT_FOR_DELIVERY, Order::STATUS_DELIVERED], true)) {
            return [];
        }

        $attributes = [];

        foreach (['tracking_number', 'carrier_name', 'tracking_url'] as $field) {
            if ($request->has($field)) {
                $attributes[$field] = $this->normalizeNullableString($request->input($field));
            }
        }

        if ($status === Order::STATUS_DELIVERED) {
            foreach (['delivery_proof_image_path', 'delivery_proof_signature_path', 'delivery_proof_otp_code'] as $field) {
                if ($request->has($field)) {
                    $attributes[$field] = $this->normalizeNullableString($request->input($field));
                }
            }
        }

        return $attributes;
    }

    private function normalizeNullableString($value): ?string
    {
        if ($value instanceof \Stringable) {
            $value = (string) $value;
        }

        if ($value === null) {
            return null;
        }

        if (is_array($value)) {
            return null;
        }

        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }

    /**
     * @return array<string, string>
     */
    private function allowedPaymentMethods(): array
    {
        return [
            'wallet' => __('Wallet'),
            'east_yemen_bank' => __('East Yemen Bank'),
            'manual_bank' => __('Bank Transfer'),
        ];
    }



    /**
     * حذف الطلب
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        ResponseService::noAnyPermissionThenRedirect(['orders-delete']);
        
        try {
            // الحصول على الطلب
            $order = Order::findOrFail($id);
            
            // حذف الطلب (سيتم حذف العناصر والسجل تلقائيًا بسبب onDelete('cascade'))
            $order->delete();

            return redirect()->route('orders.index')
                ->with('success', 'تم حذف الطلب بنجاح');
        } catch (\Exception $e) {
            return redirect()->back()
                ->with('error', 'حدث خطأ أثناء حذف الطلب: ' . $e->getMessage());
        }
    }


    /**
     * @param  \Illuminate\Support\Collection<int, OrderStatus>  $orderStatuses
     * @return array<string, string>
     */
    private function buildStatusLabels($orderStatuses): array
    {
        $labels = array_merge(Order::getStatusList(), Order::paymentStatusLabels());


        foreach ($orderStatuses as $status) {
            $code = (string) $status->code;

            if ($code === '') {
                continue;
            }

            $labels[$code] = $status->name ?: ($labels[$code] ?? Str::of($code)->replace('_', ' ')->headline());
        }

        return $labels;
    }

    /**
     * @return array<string, string>
     */
    private function deliveryPaymentTimingLabels(): array
    {
        return [
            'pay_now' => 'الدفع الآن',
            'now' => 'الدفع الآن',
            'pay_on_delivery' => 'الدفع عند التسليم',
            'on_delivery' => 'الدفع عند التسليم',
        ];
    }

    /**
     * @return array<string, string>
     */
    private function deliveryPaymentStatusLabels(): array
    {
        return [
            'pending' => 'قيد الدفع',
            'paid' => 'مدفوع',
            'waived' => 'معفى',
            'due_on_delivery' => 'مستحق عند التسليم',
            'due_now' => 'مستحق الآن',
            'partial' => 'مدفوع جزئياً',
            'failed' => 'فشل الدفع',
        ];
    }


}
