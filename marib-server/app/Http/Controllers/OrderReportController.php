<?php

namespace App\Http\Controllers;

use App\Models\ManualPaymentRequest;
use App\Models\Order;
use App\Models\OrderStatus;
use App\Models\User;
use App\Services\ManualPaymentRequestTableService;
use App\Services\BootstrapTableService;
use App\Services\DepartmentReportService;

use Illuminate\Support\Facades\Auth;
use Carbon\Carbon;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;





class OrderReportController extends Controller
{



        /**
     * @var DepartmentReportService
     */
    protected DepartmentReportService $departmentReportService;


    /**
     * إنشاء مثيل جديد للمتحكم
     */
    public function __construct(DepartmentReportService $departmentReportService)
    {
        // لا حاجة لـ middleware هنا، سيتم فحص الصلاحيات في كل دالة

                $this->departmentReportService = $departmentReportService;

    }

    /**
     * عرض صفحة التقارير الرئيسية
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
        ResponseService::noAnyPermissionThenRedirect(['reports-orders']);

        // إحصائيات عامة

        $stats = $this->departmentReportService->getGeneralOrderStats();

        $departmentSnapshots = collect($this->departmentReportService->availableDepartments())
            ->mapWithKeys(function ($label, $key) {
                $snapshot = $this->departmentReportService->getDepartmentSnapshot($key);

                return [$key => [
                    'label' => $label,
                    'snapshot' => $snapshot,
                    'route' => match ($key) {
                        DepartmentReportService::DEPARTMENT_SHEIN => route('item.shein.reports'),
                        DepartmentReportService::DEPARTMENT_COMPUTER => route('item.computer.reports'),
                        default => route('reports.index'),
                    },
                ]];
            });

        // إحصائيات حسب الحالة
        $ordersByStatus = Order::select('order_status', DB::raw('count(*) as total'))
            ->groupBy('order_status')
            ->get();

        // إحصائيات حسب طريقة الدفع
        $ordersByPaymentMethod = Order::select('payment_method', DB::raw('count(*) as total'))
            ->groupBy('payment_method')
            ->get();

        // إحصائيات الطلبات اليومية (آخر 30 يوم)
        $ordersByDay = Order::select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('count(*) as total'),
                DB::raw('sum(final_amount) as amount')
            )
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        // أكثر العملاء طلبًا
        $topCustomers = DB::table('orders')
            ->join('users', 'orders.user_id', '=', 'users.id')
            ->select('users.id', 'users.name', 'users.email', 'users.mobile', DB::raw('count(*) as total_orders'), DB::raw('sum(orders.final_amount) as total_amount'))
            ->groupBy('users.id', 'users.name', 'users.email', 'users.mobile')
            ->orderByDesc('total_orders')
            ->limit(10)
            ->get();

        return view('reports.index', compact('stats', 'ordersByStatus', 'ordersByPaymentMethod', 'ordersByDay', 'topCustomers', 'departmentSnapshots'));
    }

    public function section(Request $request, string $section)
    {
        ResponseService::noAnyPermissionThenRedirect(['reports-orders']);

        $departments = $this->departmentReportService->availableDepartments();
        $section = strtolower($section);

        if (!array_key_exists($section, $departments)) {
            abort(404);
        }

        $metrics = $this->departmentReportService->getDepartmentMetrics($section);

        return view('reports.sections.overview', [
            'department' => $section,
            'departments' => $departments,
            'metrics' => $metrics,
        ]);


    }

    /**
     * عرض تقرير المبيعات
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function sales(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['reports-sales']);

        // إعداد التواريخ الافتراضية إذا لم يتم تحديدها
        $startDate = $request->filled('start_date') ? $request->start_date : now()->subMonth()->format('Y-m-d');
        $endDate = $request->filled('end_date') ? $request->end_date : now()->format('Y-m-d');

        // إحصائيات المبيعات
        $salesStats = Order::where('order_status', 'delivered')
            ->whereBetween('created_at', [$startDate . ' 00:00:00', $endDate . ' 23:59:59'])
            ->select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('count(*) as total_orders'),
                DB::raw('sum(final_amount) as total_amount')
            )
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        // إجمالي المبيعات للفترة المحددة
        $totalSales = Order::where('order_status', 'delivered')
            ->whereBetween('created_at', [$startDate . ' 00:00:00', $endDate . ' 23:59:59'])
            ->sum('final_amount');

        // عدد الطلبات للفترة المحددة
        $totalOrders = Order::where('order_status', 'delivered')
            ->whereBetween('created_at', [$startDate . ' 00:00:00', $endDate . ' 23:59:59'])
            ->count();

        // متوسط قيمة الطلب
        $averageOrderValue = $totalOrders > 0 ? $totalSales / $totalOrders : 0;

        return view('reports.sales', compact('salesStats', 'totalSales', 'totalOrders', 'averageOrderValue', 'startDate', 'endDate'));
    }

    /**
     * عرض تقرير العملاء
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function customers(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['reports-customers']);

        // إعداد التواريخ الافتراضية إذا لم يتم تحديدها
        $startDate = $request->filled('start_date') ? $request->start_date : now()->subMonth()->format('Y-m-d');
        $endDate = $request->filled('end_date') ? $request->end_date : now()->format('Y-m-d');

        // إعداد الاستعلام
        $query = DB::table('orders')
            ->join('users', 'orders.user_id', '=', 'users.id')
            ->whereBetween('orders.created_at', [$startDate . ' 00:00:00', $endDate . ' 23:59:59']);

        // إضافة فلتر البحث بواسطة رقم الهاتف
        if ($request->filled('mobile')) {
            $query->where('users.mobile', 'like', '%' . $request->mobile . '%');
        }

        // إضافة فلتر البحث بواسطة اسم العميل
        if ($request->filled('name')) {
            $query->where('users.name', 'like', '%' . $request->name . '%');
        }

        // الحصول على النتائج
        $customersQuery = $query->select(
                'users.id',
                'users.name',
                'users.email',
                'users.mobile',
                DB::raw('count(*) as total_orders'),
                DB::raw('sum(orders.final_amount) as total_amount'),
                DB::raw('avg(orders.final_amount) as average_amount')
            )
            ->groupBy('users.id', 'users.name', 'users.email', 'users.mobile')
            ->orderByDesc('total_orders');

        // تصدير البيانات بصيغة Excel إذا تم الطلب
        if ($request->filled('export') && $request->export === 'excel') {
            $customersStream = $customersQuery->cursor();
            return $this->exportCustomersToExcel($customersStream, $startDate, $endDate);
        }

        // عرض الصفحة بشكل عادي مع تقسيم النتائج
        $customers = $customersQuery->paginate(20);

        return view('reports.customers', compact('customers', 'startDate', 'endDate'));
    }



    /**
     * عرض تقرير المدفوعات اليدوية.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function manualPayments(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['reports-orders']);

        [$baseQuery, $startDate, $endDate, $statusFilter] = $this->buildManualPaymentsBaseQuery($request);


        $paginatedQuery = (clone $baseQuery)->with('user')->latest('created_at');
        $payments = $paginatedQuery->paginate(15)->withQueryString();

        $totals = (clone $baseQuery)
            ->selectRaw('COUNT(*) as total_count, COALESCE(SUM(amount), 0) as total_amount')
            ->first();

        $statusBreakdown = (clone $baseQuery)
            ->select('status', DB::raw('COUNT(*) as total_count'), DB::raw('COALESCE(SUM(amount), 0) as total_amount'))
            ->groupBy('status')
            ->orderByDesc('total_count')
            ->get();

        $revenueTrend = (clone $baseQuery)
            ->select(DB::raw('DATE(created_at) as date'), DB::raw('COUNT(*) as total_count'), DB::raw('COALESCE(SUM(amount), 0) as total_amount'))
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        $statusOptions = ManualPaymentRequest::query()
            ->select('status')
            ->distinct()
            ->pluck('status')
            ->filter()
            ->values();

        $timeBucketsConfig = [
            'today' => [now()->startOfDay(), now()->endOfDay()],
            'week' => [now()->startOfWeek(), now()->endOfDay()],
            'month' => [now()->startOfMonth(), now()->endOfDay()],
        ];

        $timeBuckets = [];
        foreach ($timeBucketsConfig as $key => [$from, $to]) {
            $bucketQuery = ManualPaymentRequest::query()
                ->whereBetween('created_at', [$from, $to])
                ->when($statusFilter, static function ($query, $status) {
                    $query->where('status', $status);
                });

            $timeBuckets[$key] = [
                'count' => (clone $bucketQuery)->count(),
                'amount' => (clone $bucketQuery)->sum('amount'),
            ];
        }

        if ($request->filled('export')) {
            $exportCursor = $this->manualPaymentsExportGenerator($baseQuery);

            if ($request->export === 'csv') {
                return $this->exportManualPaymentsToCsv($exportCursor, $startDate, $endDate, $statusFilter);
            }

            if ($request->export === 'excel') {
                return $this->exportManualPaymentsToExcel($exportCursor, $startDate, $endDate, $statusFilter);
            }
        }

        return view('reports.manual-payments', [
            'payments' => $payments,
            'filters' => [
                'start_date' => $startDate->format('Y-m-d'),
                'end_date' => $endDate->format('Y-m-d'),
                'status' => $statusFilter,
            ],
            'statusBreakdown' => $statusBreakdown,
            'revenueTrend' => $revenueTrend,
            'statusOptions' => $statusOptions,
            'timeBuckets' => $timeBuckets,
            'totals' => [
                'count' => $totals->total_count ?? 0,
                'amount' => $totals->total_amount ?? 0,
            ],
        ]);
    }



    /**
     * تصدير المدفوعات اليدوية بصيغة CSV.
     *
     * @param \Illuminate\Support\Collection $payments
     * @param \Carbon\Carbon $startDate
     * @param \Carbon\Carbon $endDate
     * @param string|null $status
     * @return \Symfony\Component\HttpFoundation\StreamedResponse
     */
    private function exportManualPaymentsToCsv(iterable $payments, Carbon $startDate, Carbon $endDate, ?string $status)
    {
        $fileName = 'manual_payments_' . $startDate->format('Ymd') . '_to_' . $endDate->format('Ymd');
        if (!empty($status)) {
            $fileName .= '_' . $status;
        }
        $fileName .= '.csv';

        $headers = [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ];

        $callback = static function () use ($payments) {
            $temp = fopen('php://temp', 'w+');
            $lineBuffer = fopen('php://temp', 'w+');

            $writeRow = static function (array $row, $tempHandle, $lineHandle) {
                ftruncate($lineHandle, 0);
                rewind($lineHandle);
                fputcsv($lineHandle, $row);
                rewind($lineHandle);
                stream_copy_to_stream($lineHandle, $tempHandle);
            };

            $writeRow(['#', 'المستخدم', 'المبلغ', 'الحالة', 'تاريخ الإنشاء', 'آخر تحديث'], $temp, $lineBuffer);

            $rowNumber = 1;
            foreach ($payments as $payment) {
                if (function_exists('connection_aborted') && connection_aborted()) {
                    break;
                }

                $writeRow([
                    $rowNumber,
                    optional($payment->user)->name ?? $payment->user_id,
                    number_format($payment->amount ?? 0, 2, '.', ''),
                    $payment->status ?? 'غير محدد',
                    optional($payment->created_at)->format('Y-m-d H:i'),
                    optional($payment->updated_at)->format('Y-m-d H:i'),
                ], $temp, $lineBuffer);

                ++$rowNumber;
            }

            $bytes = ftell($temp);
            rewind($temp);

            $output = fopen('php://output', 'w');
            header('Content-Length: ' . $bytes);
            stream_copy_to_stream($temp, $output);

            fclose($output);
            fclose($temp);
            fclose($lineBuffer);
        };

        return response()->streamDownload($callback, $fileName, $headers);
    }

    /**
     * تصدير المدفوعات اليدوية بصيغة Excel.
     *
     * @param \Illuminate\Support\Collection $payments
     * @param \Carbon\Carbon $startDate
     * @param \Carbon\Carbon $endDate
     * @param string|null $status
     * @return \Symfony\Component\HttpFoundation\BinaryFileResponse
     */
    private function exportManualPaymentsToExcel(iterable $payments, Carbon $startDate, Carbon $endDate, ?string $status)
    {
        $fileName = 'manual_payments_' . $startDate->format('Ymd') . '_to_' . $endDate->format('Ymd');
        if (!empty($status)) {
            $fileName .= '_' . $status;
        }
        $fileName .= '.xlsx';

        return response()->streamDownload(static function () use ($payments) {
            \PhpOffice\PhpSpreadsheet\Settings::setCacheStorageMethod(
                \PhpOffice\PhpSpreadsheet\CachedObjectStorageFactory::cache_to_phpTemp,
                ['memoryCacheSize' => '32MB']
            );

            $spreadsheet = new \PhpOffice\PhpSpreadsheet\Spreadsheet();
            $sheet = $spreadsheet->getActiveSheet();

            $sheet->setRightToLeft(true);

            $sheet->fromArray([
                ['#', 'المستخدم', 'المبلغ', 'الحالة', 'تاريخ الإنشاء', 'آخر تحديث'],
            ], null, 'A1');

            $rowIndex = 2;
            foreach ($payments as $payment) {
                if (function_exists('connection_aborted') && connection_aborted()) {
                    break;
                }

                $sheet->fromArray([
                    [
                        $rowIndex - 1,
                        optional($payment->user)->name ?? $payment->user_id,
                        $payment->amount ?? 0,
                        $payment->status ?? 'غير محدد',
                        optional($payment->created_at)->format('Y-m-d H:i'),
                        optional($payment->updated_at)->format('Y-m-d H:i'),
                    ],
                ], null, 'A' . $rowIndex);

                ++$rowIndex;
            }

            $sheet->getStyle('A1:F1')->getFont()->setBold(true);

            foreach (range('A', 'F') as $column) {
                $sheet->getColumnDimension($column)->setAutoSize(true);
            }

            $temp = fopen('php://temp', 'w+');
            $writer = new \PhpOffice\PhpSpreadsheet\Writer\Xlsx($spreadsheet);
            $writer->setPreCalculateFormulas(false);
            $writer->save($temp);

            $bytes = ftell($temp);
            rewind($temp);

            $output = fopen('php://output', 'w');
            header('Content-Length: ' . $bytes);
            stream_copy_to_stream($temp, $output);

            fclose($output);
            fclose($temp);
        }, $fileName, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }



    /**
     * تصدير بيانات العملاء بصيغة Excel
     *
     * @param \Illuminate\Support\Collection $customers
     * @param string $startDate
     * @param string $endDate
     * @return \Symfony\Component\HttpFoundation\BinaryFileResponse
     */
    private function exportCustomersToExcel(iterable $customers, $startDate, $endDate)
    {
        // تحديد اسم الملف
        $fileName = 'تقرير_العملاء_' . $startDate . '_الى_' . $endDate . '.xlsx';

        // إنشاء استجابة التصدير
        return response()->streamDownload(function() use ($customers) {
            \PhpOffice\PhpSpreadsheet\Settings::setCacheStorageMethod(
                \PhpOffice\PhpSpreadsheet\CachedObjectStorageFactory::cache_to_phpTemp,
                ['memoryCacheSize' => '32MB']
            );

            $excel = new \PhpOffice\PhpSpreadsheet\Spreadsheet();
            $sheet = $excel->getActiveSheet();

            // تعيين اتجاه الورقة من اليمين إلى اليسار (RTL)
            $sheet->setRightToLeft(true);

            // إضافة العناوين
            $sheet->fromArray([
                ['#', 'الاسم', 'البريد الإلكتروني', 'رقم الهاتف', 'عدد الطلبات', 'إجمالي المبلغ', 'متوسط قيمة الطلب'],
            ], null, 'A1');

            $rowIndex = 2;
            foreach ($customers as $customer) {
                if (function_exists('connection_aborted') && connection_aborted()) {
                    break;
                }

                $sheet->fromArray([
                    [
                        $rowIndex - 1,
                        $customer->name,
                        $customer->email,
                        $customer->mobile ?? 'غير متوفر',
                        $customer->total_orders,
                        number_format($customer->total_amount, 2),
                        number_format($customer->average_amount, 2),
                    ],
                ], null, 'A' . $rowIndex);

                ++$rowIndex;
            }

            // تنسيق العناوين بخط عريض
            $sheet->getStyle('A1:G1')->getFont()->setBold(true);

            // ضبط عرض الأعمدة
            foreach(range('A', 'G') as $column) {
                $sheet->getColumnDimension($column)->setAutoSize(true);
            }

            // إنشاء ملف Excel المؤقت وكتابته
            $writer = new \PhpOffice\PhpSpreadsheet\Writer\Xlsx($excel);
            $writer->setPreCalculateFormulas(false);

            $temp = fopen('php://temp', 'w+');
            $writer->save($temp);

            $bytes = ftell($temp);
            rewind($temp);

            $output = fopen('php://output', 'w');
            header('Content-Length: ' . $bytes);
            stream_copy_to_stream($temp, $output);

            fclose($output);
            fclose($temp);
        }, $fileName, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }

    private function manualPaymentsExportGenerator($baseQuery): \Generator
    {
        $chunkSize = 500;
        $lastId = 0;

        do {
            $chunk = (clone $baseQuery)
                ->with('user')
                ->where('id', '>', $lastId)
                ->orderBy('id')
                ->limit($chunkSize)
                ->get();

            if ($chunk->isEmpty()) {
                break;
            }

            foreach ($chunk as $payment) {
                $lastId = $payment->id;
                yield $payment;
            }
        } while ($chunk->count() === $chunkSize);
    }

    /**
     * عرض تقرير حالات الطلبات
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function statuses(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['reports-statuses']);

        // إعداد التواريخ الافتراضية إذا لم يتم تحديدها
        $startDate = $request->filled('start_date') ? $request->start_date : now()->subMonth()->format('Y-m-d');
        $endDate = $request->filled('end_date') ? $request->end_date : now()->format('Y-m-d');

        // الحصول على الحالات النشطة فقط
        $orderStatuses = OrderStatus::active()->orderBy('sort_order')->get();

        $statusStats = [];
        $totalOrders = 0;
        $totalAmount = 0;

        foreach ($orderStatuses as $status) {
            $orders = Order::where('order_status', $status->code)
                ->whereBetween('created_at', [$startDate . ' 00:00:00', $endDate . ' 23:59:59']);

            $count = $orders->count();
            $amount = $orders->sum('final_amount');

            $totalOrders += $count;
            $totalAmount += $amount;

            $statusStats[] = [
                'status' => $status,
                'count' => $count,
                'amount' => $amount,
                'orders' => $orders->latest()->limit(5)->get() // آخر 5 طلبات لكل حالة
            ];
        }

        return view('reports.statuses', compact('statusStats', 'startDate', 'endDate', 'totalOrders', 'totalAmount'));
    }

        public function manualPaymentsList(Request $request)
    {
        ResponseService::noPermissionThenSendJson('reports-orders');

        [$baseQuery] = $this->buildManualPaymentsBaseQuery($request);

        $offset = max((int) $request->get('offset', 0), 0);
        $limit = max(min((int) $request->get('limit', 10), 200), 1);
        $sort = $request->get('sort', 'submitted_at');
        $order = strtolower($request->get('order', 'desc')) === 'asc' ? 'asc' : 'desc';

        $sortable = [
            'id' => 'id',
            'reference' => 'reference',
            'payable_type' => 'payable_type',
            'status' => 'status',
            'submitted_at' => 'created_at',
            'created_at' => 'created_at',
        ];

        $sortColumn = $sortable[$sort] ?? 'created_at';



        $searchTerm = $request->has('search') ? trim((string) $request->get('search')) : null;
        if ($searchTerm === '') {
            $searchTerm = null;
        }

        $query = (clone $baseQuery)
            ->with(['user', 'paymentTransaction.order'])
            ->search($searchTerm);

        $total = (clone $query)->count();

        $requests = $query->orderBy($sortColumn, $order)
            ->skip($offset)
            ->take($limit)
            ->get();

        $rows = [];

        foreach ($requests as $requestRow) {
            $row = $requestRow->toArray();
            $row['user_name'] = $requestRow->user?->name ?? '-';
            $row['user_mobile'] = $requestRow->user?->mobile ?? '-';

            $gateway = $requestRow->paymentTransaction?->payment_gateway;
            $row['payment_gateway'] = $gateway ? ucwords(str_replace('_', ' ', $gateway)) : '-';

            $row['formatted_amount'] = number_format($requestRow->amount, 2) . ($requestRow->currency ? ' ' . $requestRow->currency : '');
            $row['submitted_at'] = optional($requestRow->created_at)->format('Y-m-d H:i');
            $row['status_badge'] = $this->manualPaymentStatusBadge($requestRow->status);
            $row['operate'] = $this->manualPaymentActionsColumn($requestRow);

            $rows[] = $row;
        }

        return response()->json([
            'total' => $total,
            'rows' => $rows,
        ]);
    }

    public function manualPaymentsShow(ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noPermissionThenSendJson('reports-orders');

        $manualPaymentRequest->load(['user', 'paymentTransaction.order', 'histories.user', 'reviewer']);
        return view('payments.manual.show', [
            'request' => $manualPaymentRequest,
            'canReview' => Auth::user()->can('manual-payments-review') && $manualPaymentRequest->isPending(),
        ]);
    }

    private function buildManualPaymentsBaseQuery(Request $request): array
    {
        $startInput = $request->get('start_date', $request->get('date_from'));
        $endInput = $request->get('end_date', $request->get('date_to'));

        $startDate = $startInput
            ? Carbon::parse($startInput)->startOfDay()
            : now()->subDays(30)->startOfDay();
        $endDate = $endInput
            ? Carbon::parse($endInput)->endOfDay()
            : now()->endOfDay();

        if ($startDate->greaterThan($endDate)) {
            [$startDate, $endDate] = [$endDate->copy()->startOfDay(), $startDate->copy()->endOfDay()];
        }

        $statusFilter = $request->filled('status') ? $request->status : null;

        $baseQuery = ManualPaymentRequest::query()
            ->whereBetween('created_at', [$startDate, $endDate])
            ->when($statusFilter, static function ($query, $status) {
                $query->where('status', $status);
            });

        return [$baseQuery, $startDate, $endDate, $statusFilter];
    }

    private function manualPaymentStatusBadge(?string $status): string
    {
        return match ($status) {
            ManualPaymentRequest::STATUS_APPROVED => '<span class="badge bg-success">' . trans('Approved') . '</span>',
            ManualPaymentRequest::STATUS_REJECTED => '<span class="badge bg-danger">' . trans('Rejected') . '</span>',
            default => '<span class="badge bg-warning text-dark">' . trans('Pending') . '</span>',
        };
    }

    private function manualPaymentActionsColumn(ManualPaymentRequest $manualPaymentRequest): string
    {
        return BootstrapTableService::button(
            'fa fa-eye',
            route('reports.manual-payments.show', $manualPaymentRequest),
            ['btn-primary', 'view-manual-payment'],
            [
                'data-bs-toggle' => 'modal',
                'data-bs-target' => '#manualPaymentModal',
            ]
        );
    }
}
