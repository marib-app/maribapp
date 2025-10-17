<?php

namespace App\Http\Controllers;
use App\Models\Item;

use App\Models\ManualPaymentRequest;
use App\Models\ManualPaymentRequestHistory;
use App\Models\Order;
use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Models\WalletTransaction;
use App\Queries\PaymentRequestTableQuery;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\Route;
use Illuminate\Database\Eloquent\Model;

use App\Models\UserFcmToken;
use App\Services\BootstrapTableService;
use App\Services\CachingService;
use App\Services\NotificationService;
use App\Services\PaymentFulfillmentService;
use App\Services\Payments\EastYemenBankGateway;
use App\Services\WalletService;

use App\Services\DepartmentReportService;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

use App\Services\ResponseService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Schema;

use RuntimeException;
use Throwable;

class ManualPaymentRequestController extends Controller
{

    private array $manualPaymentColumnSupportCache = [];
    private array $manualPaymentOrderIdCache = [];


    public function __construct(
        private readonly PaymentFulfillmentService $paymentFulfillmentService,
        private readonly DepartmentReportService $departmentReportService,
        private readonly WalletService $walletService,
    ) {
    }

    public function index()
    {
        ResponseService::noAnyPermissionThenRedirect(['manual-payments-list', 'manual-payments-review']);

        $statuses = [
            'pending' => trans('Pending'),
            'succeed' => trans('Success'),
            'failed' => trans('Failed'),
        ];

        $payableTypes = [

            'orders' => trans('Orders'),
            'packages' => trans('Packages'),
            'top_ups' => trans('Wallet Top-up'),
        ];

        $paymentGateways = [
            'east_yemen_bank' => trans('East Yemen Bank Gateway'),
            'manual_banks' => trans('Manual Banks'),

            'wallet' => trans('Wallet'),
            'cash' => trans('Cash'),


        ];

        $departments = $this->departmentReportService->availableDepartments();
        $paymentRequestBase = DB::query()->fromSub(PaymentRequestTableQuery::make(), 'requests');

        $summaryData = $this->summarizePaymentRequests($paymentRequestBase);


        $summary = $summaryData['summary'];
        $gatewaySummary = $summaryData['gateway_summary'];
        $categorySummary = $summaryData['category_summary'];
        $departmentSummary = $summaryData['department_summary'];


        return view(
            'payments.manual.index',
            compact(
                'statuses',
                'payableTypes',
                'paymentGateways',
                'summary',
                'gatewaySummary',
                'categorySummary',
                'departments',
                'departmentSummary'
            )
        
        );
    }

    public function list(Request $request)
    {
        ResponseService::noAnyPermissionThenSendJson(['manual-payments-list', 'manual-payments-review']);

        $start = max((int) $request->get('start', 0), 0);
        $offset = max((int) $request->get('offset', $start), 0);

        $rawLimit = $request->get('limit');

        if ($rawLimit === null || (int) $rawLimit <= 0) {
            $rawLimit = $request->get('length', 20);
        }

        $limit = max(min((int) $rawLimit, 200), 1);

        $page = (int) floor($offset / $limit) + 1;

        $sort = $request->get('sort', 'created_at');
        $order = strtolower($request->get('order', 'desc'));
        $order = in_array($order, ['asc', 'desc'], true) ? $order : 'desc';

        $sortable = [
            'id' => 'manual_payment_requests.id',
            'reference' => 'manual_payment_requests.reference',
            'payable_type' => 'manual_payment_requests.payable_type',
            'status' => 'manual_payment_requests.status',
            'submitted_at' => 'manual_payment_requests.created_at',
            'created_at' => 'manual_payment_requests.created_at',
        ];
        $sortColumn = $sortable[$sort] ?? 'manual_payment_requests.created_at';



        $search = trim((string) $request->get('search', ''));

        $payableTypeAliases = $this->expandManualPaymentPayableTypeAliases($request->get('payable_type'));





        $departmentFilter = $request->get('department');
        $departmentFilter = $departmentFilter !== null && $departmentFilter !== '' ? $departmentFilter : null;

        $from = $request->get('from');
        $to = $request->get('to');

        $baseQuery = ManualPaymentRequest::withoutGlobalScopes();

        $overallTotal = (clone $baseQuery)->count();

        $query = (clone $baseQuery)
            ->with([
                'manualBank',
                'user',
                'payable',
                'paymentTransaction.order',
            ])
            ->when($search !== '', fn($q) => $q->search($search))
            ->when($request->filled('status'), fn($q) => $q->status($request->input('status')))
            ->when($payableTypeAliases !== [], fn($q) => $q->whereIn('payable_type', $payableTypeAliases))
            ->when($request->filled('payment_gateway'), fn($q) => $q->paymentGateway($request->input('payment_gateway')))
            ->when($departmentFilter !== null, function ($q) use ($departmentFilter) {
                $q->where(function ($inner) use ($departmentFilter) {
                    $inner->where('department', $departmentFilter)
                        ->orWhereNull('department');
                });
            })
            ->when($from, fn($q) => $q->where('created_at', '>=', $from))
            ->when($to, fn($q) => $q->where('created_at', '<=', $to));

        $filteredTotal = (clone $query)->count();

        $requests = (clone $query)
            ->orderBy($sortColumn, $order)
            ->forPage($page, $limit)
            ->get();

        $rows = [];





        foreach ($requests as $requestRow) {
            $row = $requestRow->toArray();
            $row['user_name'] = $requestRow->user?->name ?? '-';
            $row['user_mobile'] = $requestRow->user?->mobile ?? '-';
            $gateway = $requestRow->paymentTransaction?->payment_gateway;


            $canonicalGateway = ManualPaymentRequest::canonicalGateway($gateway);
            if ($canonicalGateway === 'manual_bank') {
                $canonicalGateway = 'manual_banks';
            }

            $row['payment_gateway_key'] = $canonicalGateway ?? 'manual_banks';
            $row['payment_gateway'] = $this->gatewayLabel($canonicalGateway ?? 'manual_banks');
            $row['payment_gateway_name'] = $this->paymentRequestGatewayName($requestRow);
            $row['manual_bank_name'] = $this->resolveManualBankName($requestRow);

            $row['formatted_amount'] = number_format($requestRow->amount, 2)
                . ($requestRow->currency ? ' ' . $requestRow->currency : '');
            $row['submitted_at'] = $requestRow->created_at?->format('Y-m-d H:i');
            $row['status_badge'] = $this->statusBadge($requestRow->status);
            $row['operate'] = $this->actionsColumn($requestRow);


            $rows[] = $row;
        }

        $lastPage = (int) max(ceil($filteredTotal / $limit), 1);

        return response()->json([
            'total' => $filteredTotal,
            'rows' => $rows,
            'meta' => [
                'total' => $overallTotal,
                'filtered_total' => $filteredTotal,
                'current_page' => min($page, $lastPage),
                'last_page' => $lastPage,
            ],
        ]);


    }




    public function table(Request $request)
    {
        ResponseService::noAnyPermissionThenSendJson(['manual-payments-list', 'manual-payments-review']);

        $draw = (int) $request->input('draw', 0);
        $start = max((int) $request->input('start', $request->input('offset', 0)), 0);

        $lengthInput = $request->input('length');
        if ($lengthInput === null || $lengthInput === '') {
            $lengthInput = $request->input('limit', 20);
        }

        $length = is_numeric($lengthInput) ? (int) $lengthInput : 20;

        $length = $length < 0 ? null : max(min($length, 200), 1);

        $searchValue = $request->input('search');
        if (is_array($searchValue)) {
            $searchValue = $searchValue['value'] ?? '';
        }
        $searchValue = is_string($searchValue) ? trim($searchValue) : '';

        $statusFilter = $this->normalizePaymentRequestStatus($request->input('status'));
        $channelFilter = $this->normalizePaymentRequestChannel($request->input('payment_gateway') ?? $request->input('channel'));
        $categoryFilter = $this->normalizePaymentRequestCategory($request->input('payable_type') ?? $request->input('category'));
        $departmentFilter = $this->normalizeManualPaymentDepartment($request->input('department'));
        $from = $this->normalizeManualPaymentDate($request->input('from'), true);
        $to = $this->normalizeManualPaymentDate($request->input('to'), false);

        $baseQuery = DB::query()->fromSub(PaymentRequestTableQuery::make(), 'requests');


        $recordsTotal = (clone $baseQuery)->count();

        $filteredQuery = (clone $baseQuery)
            ->when($searchValue !== '', function (QueryBuilder $query) use ($searchValue) {
                $like = '%' . $searchValue . '%';

                $query->where(function (QueryBuilder $inner) use ($like) {
                    $inner->where('reference', 'LIKE', $like)
                        ->orWhere('user_name', 'LIKE', $like)
                        ->orWhere('user_mobile', 'LIKE', $like)
                        ->orWhere('payment_transaction_id', 'LIKE', $like)
                        ->orWhere('wallet_transaction_id', 'LIKE', $like);
                });
            })
            ->when($statusFilter, static fn (QueryBuilder $query, string $status) => $query->where('status', $status))
            ->when($channelFilter, static fn (QueryBuilder $query, string $channel) => $query->where('channel', $channel))
            ->when($categoryFilter, static fn (QueryBuilder $query, string $category) => $query->where('category', $category))
            ->when($departmentFilter !== null, function (QueryBuilder $query) use ($departmentFilter) {
                $query->where(function (QueryBuilder $inner) use ($departmentFilter) {
                    $inner->where('department', $departmentFilter)
                        ->orWhereNull('department');
                });
            })
            ->when($from, static fn (QueryBuilder $query, Carbon $date) => $query->where('created_at', '>=', $date))
            ->when($to, static fn (QueryBuilder $query, Carbon $date) => $query->where('created_at', '<=', $date));

        $summaryData = $this->summarizePaymentRequests(clone $filteredQuery);



        $recordsFiltered = (clone $filteredQuery)->count();

        [$orderColumn, $orderDirection] = $this->resolvePaymentRequestOrder($request);

        $orderedQuery = (clone $filteredQuery)->orderBy($orderColumn, $orderDirection);

        if ($length !== null) {
            $orderedQuery->skip($start)->take($length);
        }

        $rows = $orderedQuery->get();


        $data = $rows->map(function (object $row) {
            $transactionId = $row->payment_transaction_id
                ? (string) $row->payment_transaction_id
                : ($row->wallet_transaction_id ? 'WT-' . $row->wallet_transaction_id : $row->reference);
                
            $amount = (float) ($row->amount ?? 0);


            $channel = ManualPaymentRequest::canonicalGateway($row->channel ?? null);
            if ($channel === 'manual_bank') {
                $channel = 'manual_banks';
            }
            $manualBankName = $this->resolveManualBankName($row);

            return [
                'transaction_id' => $transactionId,
                'user_name' => $row->user_name ?? '—',
                'user_mobile' => $row->user_mobile ?? '—',
                'amount_fmt' => number_format($amount, 2, '.', ''),
                'currency' => $row->currency ?? '',
                'payment_gateway' => $channel ?? $row->channel,
                'payment_gateway_label' => $this->paymentRequestChannelLabel($channel ?? $row->channel),
                'payment_gateway_name' => $this->paymentRequestGatewayName($row),
                'manual_bank_name' => $manualBankName,
                'category' => $row->category,
                'department' => $row->department ?? null,
                'department_label' => $this->paymentRequestDepartmentLabel($row->department ?? null),
                'payable_type' => $row->payable_type ?? null,
                'payable_id' => $row->payable_id ?? null,
                'payable_label' => $this->paymentRequestPayableLabel($row),
                'status' => $row->status,
                'status_label' => $this->paymentRequestStatusLabel($row->status),
                'created_at_human' => $row->created_at
                    ? Carbon::parse($row->created_at)->format('Y-m-d H:i')
                    : '—',
                'actions' => $this->paymentRequestActionsFromRow($row),
            ];
        })->values();

        return response()->json([
            'draw' => $draw,
            'recordsTotal' => (int) $recordsTotal,
            'recordsFiltered' => (int) $recordsFiltered,
            'data' => $data,
            'summary' => $summaryData['summary'],
            'gateway_summary' => $summaryData['gateway_summary'],
            'category_summary' => $summaryData['category_summary'],
            'department_summary' => $summaryData['department_summary'],

        ]);
    }

    

    public function show(ManualPaymentRequest $manualPaymentRequest) 
    {
        ResponseService::noAnyPermissionThenSendJson(['manual-payments-list', 'manual-payments-review']);

        $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);
        return view('payments.manual.show', [
            'request' => $manualPaymentRequest,
            'canReview' => Auth::user()->can('manual-payments-review') && $manualPaymentRequest->isOpen(),
            'timelineData' => $this->manualPaymentTimelinePayload($manualPaymentRequest),



            

        ]);
    }
      

    public function review(ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noAnyPermissionThenRedirect(['manual-payments-list', 'manual-payments-review']);

        $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);

        return view('payments.manual.review', [
            'request' => $manualPaymentRequest,
            'canReview' => Auth::user()->can('manual-payments-review') && $manualPaymentRequest->isOpen(),

            'timelineData' => $this->manualPaymentTimelinePayload($manualPaymentRequest),
        ]);
    }

    public function timeline(ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noAnyPermissionThenSendJson(['manual-payments-list', 'manual-payments-review']);

        $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);

        return response()->json([
            'data' => $this->manualPaymentTimelinePayload($manualPaymentRequest),

        ]);
    }


    private function loadManualPaymentRequestRelations(ManualPaymentRequest $manualPaymentRequest): ManualPaymentRequest
    {
        $manualPaymentRequest->load([
            'user',
            'paymentTransaction.order.user',
            'paymentTransaction.walletTransaction.walletAccount.user',
            'paymentTransaction.payable',
            'histories.user',
            'reviewer',
            'payable',
        ]);
        $paymentTransaction = $manualPaymentRequest->paymentTransaction;

        $payable = $manualPaymentRequest->payable;

        if ($payable === null && $paymentTransaction) {
            if ($paymentTransaction->order) {
                $manualPaymentRequest->setRelation('payable', $paymentTransaction->order);
                $payable = $paymentTransaction->order;
            } elseif ($paymentTransaction->payable instanceof Model) {
                $manualPaymentRequest->setRelation('payable', $paymentTransaction->payable);
                $payable = $paymentTransaction->payable;
            }
        }

        if ($payable instanceof Order) {
            $payable->loadMissing(['user', 'seller']);
        } elseif ($payable instanceof Item) {
            $payable->loadMissing(['user', 'category']);
        } elseif ($payable instanceof WalletTransaction) {
            $payable->loadMissing(['walletAccount.user']);

        }

        return $manualPaymentRequest;
    }






    private function manualPaymentTimelinePayload(ManualPaymentRequest $manualPaymentRequest): array
    {
        $manualPaymentRequest->loadMissing(['histories.user', 'user']);

        $iconMap = $this->manualPaymentStatusIconMap();
        $timeline = [];

        $submissionDocumentValidUntil = data_get($manualPaymentRequest->meta, 'document.valid_until');
        $submissionDocumentDate = $this->parseDateOrNull($submissionDocumentValidUntil);

        $timeline[] = [
            'id' => 'submission-' . $manualPaymentRequest->id,
            'status' => ManualPaymentRequest::STATUS_PENDING,
            'status_label' => trans('Awaiting review'),
            'icon' => $iconMap['submitted'] ?? $iconMap[ManualPaymentRequest::STATUS_PENDING],
            'note' => $manualPaymentRequest->user_note,
            'document_valid_until' => $submissionDocumentDate?->toDateString(),
            'document_valid_until_human' => $submissionDocumentDate?->format('Y-m-d'),
            'document_valid_label' => $submissionDocumentDate
                ? trans('Document valid until :date', ['date' => $submissionDocumentDate->format('Y-m-d')])
                : null,
            'created_at' => $manualPaymentRequest->created_at?->toIso8601String(),
            'created_at_human' => $manualPaymentRequest->created_at?->format('Y-m-d H:i'),
            'actor' => $manualPaymentRequest->user?->name ?? trans('Requester'),
            'attachment_url' => null,
            'attachment_name' => null,
            'attachment_label' => null,
            'notification_sent' => false,
            'notification_label' => null,
            'is_current' => false,
        ];

        $manualPaymentRequest->histories
            ->sortBy('created_at')
            ->each(function (ManualPaymentRequestHistory $history) use (&$timeline, $iconMap) {
                $normalizedStatus = $this->normalizeManualPaymentStatus($history->status) ?? $history->status;
                $documentValidUntil = data_get($history->meta, 'document_valid_until');
                $documentDate = $this->parseDateOrNull($documentValidUntil);
                $attachmentUrl = $history->attachment_url;
                $attachmentName = data_get($history->meta, 'attachment_name');
                $notificationSent = (bool) data_get($history->meta, 'notification_sent');

                $timeline[] = [
                    'id' => 'history-' . $history->id,
                    'status' => $normalizedStatus,
                    'status_label' => $this->manualPaymentStatusLabel($normalizedStatus),
                    'icon' => $iconMap[$normalizedStatus] ?? $iconMap['default'],
                    'note' => $history->note,
                    'document_valid_until' => $documentDate?->toDateString(),
                    'document_valid_until_human' => $documentDate?->format('Y-m-d'),
                    'document_valid_label' => $documentDate
                        ? trans('Document valid until :date', ['date' => $documentDate->format('Y-m-d')])
                        : null,
                    'created_at' => $history->created_at?->toIso8601String(),
                    'created_at_human' => $history->created_at?->format('Y-m-d H:i'),
                    'actor' => $history->user?->name ?? trans('System'),
                    'attachment_url' => $attachmentUrl,
                    'attachment_name' => $attachmentName,
                    'attachment_label' => $attachmentUrl
                        ? ($attachmentName ? Str::limit($attachmentName, 40) : trans('View attachment'))
                        : null,
                    'notification_sent' => $notificationSent,
                    'notification_label' => $notificationSent ? trans('Notification sent') : null,
                    'is_current' => false,
                ];
            });

        $currentStatus = $this->normalizeManualPaymentStatus($manualPaymentRequest->status)
            ?? ManualPaymentRequest::STATUS_PENDING;
        $lastMatchingIndex = null;

        foreach ($timeline as $index => $entry) {
            if (($entry['status'] ?? null) === $currentStatus) {
                $lastMatchingIndex = $index;
            }
        }

        if ($lastMatchingIndex === null && $currentStatus === ManualPaymentRequest::STATUS_PENDING) {
            $lastMatchingIndex = 0;
        }

        if ($lastMatchingIndex !== null) {
            $timeline[$lastMatchingIndex]['is_current'] = true;
        }

        $lastUpdatedAt = collect([
            $manualPaymentRequest->created_at,
            ...$manualPaymentRequest->histories->pluck('created_at')->all(),
        ])->filter()->sortDesc()->first();

        return [
            'request_id' => $manualPaymentRequest->id,
            'current_status' => $currentStatus,
            'current_status_label' => $this->manualPaymentStatusLabel($currentStatus),
            'current_status_icon' => $this->manualPaymentStatusIcon($currentStatus),
            'current_status_badge' => $this->manualPaymentStatusBadge($currentStatus),
            'timeline' => array_values($timeline),
            'last_updated_at' => $lastUpdatedAt?->toIso8601String(),
            'last_updated_at_human' => $lastUpdatedAt?->format('Y-m-d H:i'),
            'empty_message' => trans('No status updates yet.'),
            'poll_interval' => config('manual-payments.timeline.poll_interval', 8000),
            'error_message' => trans('Unable to refresh the status timeline right now.'),
        ];
    }


    private function summarizePaymentRequests(QueryBuilder $query): array
    {
        $summaryRow = (clone $query)
            ->selectRaw('COUNT(*) as total_requests, COALESCE(SUM(amount), 0) as total_amount')
            ->first();

        $statusTotals = (clone $query)
            ->select('status', DB::raw('COUNT(*) as aggregate_total'))
            ->groupBy('status')
            ->pluck('aggregate_total', 'status');

        $gatewayTotals = (clone $query)
            ->select('channel', DB::raw('COUNT(*) as aggregate_total'))
            ->groupBy('channel')
            ->pluck('aggregate_total', 'channel');

        $categoryTotals = (clone $query)
            ->select('category', DB::raw('COUNT(*) as aggregate_total'))
            ->groupBy('category')
            ->pluck('aggregate_total', 'category');

        $departments = $this->departmentReportService->availableDepartments();

        $summary = [
            'total' => (int) ($summaryRow->total_requests ?? 0),
            'pending' => (int) ($statusTotals['pending'] ?? 0),
            'succeed' => (int) ($statusTotals['succeed'] ?? 0),
            'failed' => (int) ($statusTotals['failed'] ?? 0),
            'amount' => (float) ($summaryRow->total_amount ?? 0),
        ];

        $gatewaySummary = [
            'east_yemen_bank' => (int) ($gatewayTotals['east_yemen_bank'] ?? 0),
            'manual_banks' => (int) ($gatewayTotals['manual_banks'] ?? 0),
            'wallet' => (int) ($gatewayTotals['wallet'] ?? 0),
            'cash' => (int) ($gatewayTotals['cash'] ?? 0),
        ];

        $categorySummary = [
            'orders' => (int) ($categoryTotals['orders'] ?? 0),
            'packages' => (int) ($categoryTotals['packages'] ?? 0),
            'top_ups' => (int) ($categoryTotals['top_ups'] ?? 0),
        ];

        $departmentSummary = [];

        if (
            $departments !== []
            && $this->manualPaymentRequestsSupportsColumn('department')
        ) {
            $departmentSummary = collect($departments)
                ->mapWithKeys(static function (string $label, string $key) {
                    return [$key => [
                        'key' => $key,
                        'label' => $label,
                        'total' => 0,
                        'pending' => 0,
                        'succeed' => 0,
                        'failed' => 0,
                    ]];
                })
                ->all();

            if ($departmentSummary !== []) {
                $departmentStats = (clone $query)
                    ->whereIn('department', array_keys($departmentSummary))
                    ->select('department', 'status')
                    ->selectRaw('COUNT(*) as aggregate_total')
                    ->groupBy('department', 'status')
                    ->get();

                foreach ($departmentStats as $stat) {
                    $departmentKey = $stat->department;

                    if (!isset($departmentSummary[$departmentKey])) {
                        continue;
                    }

                    $total = (int) ($stat->aggregate_total ?? 0);
                    $status = is_string($stat->status) ? strtolower($stat->status) : '';

                    $departmentSummary[$departmentKey]['total'] += $total;

                    if ($status === 'succeed') {
                        $departmentSummary[$departmentKey]['succeed'] += $total;
                    } elseif ($status === 'failed') {
                        $departmentSummary[$departmentKey]['failed'] += $total;
                    } else {
                        $departmentSummary[$departmentKey]['pending'] += $total;
                    }
                }

                $departmentSummary = array_values($departmentSummary);
            }
        }

        return [
            'summary' => $summary,
            'gateway_summary' => $gatewaySummary,
            'category_summary' => $categorySummary,
            'department_summary' => $departmentSummary,
        ];
    }



    private function parseDateOrNull($value): ?Carbon
    {
        if (empty($value)) {
            return null;
        }

        try {
            return Carbon::parse($value);
        } catch (Throwable) {
            return null;
        }
    }

    private function manualPaymentStatusIcon(?string $status): string
    {
        return match ($this->normalizeManualPaymentStatus($status)) {
            ManualPaymentRequest::STATUS_APPROVED => 'fa-solid fa-circle-check',
            ManualPaymentRequest::STATUS_REJECTED => 'fa-solid fa-circle-xmark',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'fa-solid fa-magnifying-glass',
            default => 'fa-solid fa-hourglass-half',
        };
    }

    private function manualPaymentStatusBadge(?string $status): string
    {
        return match ($this->normalizeManualPaymentStatus($status)) {
            ManualPaymentRequest::STATUS_APPROVED => 'bg-success',
            ManualPaymentRequest::STATUS_REJECTED => 'bg-danger',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'bg-info text-dark',
            default => 'bg-warning text-dark',
        };
    }

    private function manualPaymentStatusIconMap(): array
    {
        return [
            ManualPaymentRequest::STATUS_PENDING => 'fa-solid fa-clock text-warning',            
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'fa-solid fa-magnifying-glass text-primary',
            ManualPaymentRequest::STATUS_APPROVED => 'fa-solid fa-circle-check text-success',
            ManualPaymentRequest::STATUS_REJECTED => 'fa-solid fa-circle-xmark text-danger',
            'submitted' => 'fa-solid fa-file-circle-plus text-primary',
            'default' => 'fa-solid fa-circle text-secondary',
        ];
    }








        public function notify(Request $request, ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noPermissionThenSendJson('manual-payments-review');

        $validator = Validator::make($request->all(), [
            'message' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return ResponseService::validationError($validator->errors()->first());
        }

        if (!$manualPaymentRequest->user_id) {
            return ResponseService::errorResponse('The requester is no longer associated with this manual payment.');
        }

        $tokens = UserFcmToken::where('user_id', $manualPaymentRequest->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if (empty($tokens)) {
            return ResponseService::errorResponse('No active notification tokens were found for this requester.');
        }

        try {
            $result = NotificationService::sendFcmNotification(
                $tokens,
                trans('Manual payment request update'),
                $validator->validated()['message'],
                'manual-payment-message',
                [
                    'manual_payment_request_id' => $manualPaymentRequest->id,
                    'status' => $manualPaymentRequest->status,
                    'reference' => $manualPaymentRequest->reference ?? $manualPaymentRequest->id,
                ]
            );
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'ManualPaymentRequestController -> notify');

            return ResponseService::errorResponse(
                $throwable->getMessage(),
                ['error' => true, 'code' => $throwable->getCode()],
                $throwable->getCode() ?: null,
                $throwable
            );
        
        }

        if (is_array($result) && ($result['error'] ?? false)) {
            Log::error('ManualPaymentRequestController: Notification service returned an error', $result);

            return ResponseService::errorResponse(
                $result['message'] ?? 'Failed to send notification.',
                $result,
                $result['code'] ?? null
            );
        
        }

        return ResponseService::successResponse('Notification sent successfully.');
    }




    public function decide(Request $request, ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noPermissionThenSendJson('manual-payments-review');

        if (!$manualPaymentRequest->isOpen()) {

            return ResponseService::errorResponse(trans('manual_payment.decide.only_pending'));
        }

        $validator = Validator::make($request->all(), [
            'decision' => 'required|in:' . implode(',', [ManualPaymentRequest::STATUS_APPROVED, ManualPaymentRequest::STATUS_REJECTED]),






            'admin_note' => 'nullable|string|max:2000',

            'document_valid_until' => 'nullable|date',
            'attachment' => 'nullable|image|max:5120',
            'notify_user' => 'nullable|boolean',


        ]);




        if ($validator->fails()) {
            return ResponseService::validationError($validator->errors()->first());
        }

        $data = $validator->validated();
        $status = $data['decision'];
        $note = $data['admin_note'] ?? null;
        $shouldNotify = (bool) ($data['notify_user'] ?? false);

        $attachmentPath = null;
        $attachmentOriginalName = null;
        $documentValidUntil = null;

        if (!empty($data['document_valid_until'])) {
            try {
                $documentValidUntil = Carbon::parse($data['document_valid_until'])->startOfDay();
            } catch (Throwable $throwable) {
                Log::warning('Manual payment decision: invalid document_valid_until value', [
                    'value' => $data['document_valid_until'],
                    'error' => $throwable->getMessage(),
                ]);
                $documentValidUntil = null;
            }
        }
        if ($request->hasFile('attachment')) {
            $attachment = $request->file('attachment');
            $attachmentPath = $attachment->store('manual_payment_decisions', 'public');
            $attachmentOriginalName = $attachment->getClientOriginalName();
        }







        DB::beginTransaction();

        try {
            $transaction = $this->resolveTransaction($manualPaymentRequest);

            if (!$transaction) {
                throw new RuntimeException(trans('manual_payment.decide.unable_to_resolve_transaction'));
            }

            $manualPaymentRequest->update([
                'status' => $status,
                'admin_note' => $note,
                'reviewed_by' => Auth::id(),
                'reviewed_at' => Carbon::now(),
            ]);


            $historyMeta = array_filter([
                'attachment_path' => $attachmentPath,
                'attachment_disk' => $attachmentPath ? 'public' : null,
                'attachment_name' => $attachmentOriginalName,
                'notification_sent' => $shouldNotify,
                'document_valid_until' => $documentValidUntil?->toDateString(),

            ], static fn($value) => $value !== null && $value !== '' && $value !== false);




            $history = ManualPaymentRequestHistory::create([
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'user_id' => Auth::id(),
                'status' => $status,
                'note' => $note,
                'meta' => empty($historyMeta) ? null : $historyMeta,

            ]);

            if ($status === ManualPaymentRequest::STATUS_APPROVED) {
                if ($manualPaymentRequest->isWalletTopUp()) {
                    $manualPaymentRequest->loadMissing('user');

                    if (!$manualPaymentRequest->user) {
                        throw new RuntimeException('The requester is no longer associated with this wallet top-up.');
                    }

                    $walletTransaction = $this->walletService->credit(
                        $manualPaymentRequest->user,
                        $this->walletIdempotencyKey($manualPaymentRequest),
                        (float) $manualPaymentRequest->amount,
                        [
                            'manual_payment_request' => $manualPaymentRequest,
                            'payment_transaction' => $transaction,
                            'meta' => [
                                'reason' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                            ],
                        ]
                    );

                    $transactionMeta = $transaction->meta ?? [];
                    data_set($transactionMeta, 'wallet.transaction_id', $walletTransaction->getKey());
                    data_set($transactionMeta, 'wallet.account_id', $walletTransaction->wallet_account_id);

                    $transaction->fill([
                        'payment_status' => 'succeed',
                        'payable_type' => WalletTransaction::class,
                        'payable_id' => $walletTransaction->getKey(),



                        'manual_payment_request_id' => $manualPaymentRequest->id,
                        'meta' => $transactionMeta,
                    ])->save();



                    $requestMeta = $manualPaymentRequest->meta ?? [];
                    data_set($requestMeta, 'wallet.purpose', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP);
                    data_set($requestMeta, 'wallet.transaction_id', $walletTransaction->getKey());
                    data_set($requestMeta, 'wallet.idempotency_key', $walletTransaction->idempotency_key);




                    $manualPaymentRequest->forceFill([
                        'payable_id' => $walletTransaction->wallet_account_id,
                        'meta' => $requestMeta,
                    ])->save();

                    $transaction->refresh();
                } else {
                    $fulfillment = $this->paymentFulfillmentService->fulfill(
                        $transaction,
                        $manualPaymentRequest->payable_type,
                        $manualPaymentRequest->payable_id,
                        $manualPaymentRequest->user_id,
                        [
                            'manual_payment_request_id' => $manualPaymentRequest->id,
                            'notify' => false,
                        ]
                    );

                    if ($fulfillment['error']) {
                        throw new RuntimeException($fulfillment['message']);
                    }

                    $transaction->refresh();
                }
            
            
            } else {
                $transaction->update([
                    'payment_status' => 'failed',



                    
                    'manual_payment_request_id' => $manualPaymentRequest->id,
                             ]);




                $transaction->refresh();

            }


            DB::commit();

            $manualPaymentRequest->refresh();

        } catch (Throwable $throwable) {
            DB::rollBack();


            if ($attachmentPath) {
                Storage::disk('public')->delete($attachmentPath);
            }

            Log::error('Manual payment decision error: ' . $throwable->getMessage(), [
                
                'request_id' => $manualPaymentRequest->id,
            ]);
            return ResponseService::errorResponse(trans('manual_payment.decide.unable_to_process'));

        }

        $attachmentUrl = $attachmentPath ? Storage::disk('public')->url($attachmentPath) : null;


        if ($shouldNotify) {
            $this->sendDecisionNotification($manualPaymentRequest, $transaction, $status, $note, $attachmentUrl);
        }

        $message = $status === ManualPaymentRequest::STATUS_APPROVED
            ? trans('manual_payment.decide.approved')
            : trans('manual_payment.decide.rejected');

        return ResponseService::successResponse($message, [
            'history_id' => $history->id,
            'status' => $status,
        ]);
    }

    public function approve(Request $request, ManualPaymentRequest $manualPaymentRequest)
    {
        $request->merge([
            'decision' => ManualPaymentRequest::STATUS_APPROVED,
            'notify_user' => $request->boolean('notify_user', true),
        ]);





        return $this->decide($request, $manualPaymentRequest);
    }



    public function reject(Request $request, ManualPaymentRequest $manualPaymentRequest)
    {
        $request->merge([
            'decision' => ManualPaymentRequest::STATUS_REJECTED,
            'notify_user' => $request->boolean('notify_user', true),
        ]);


        return $this->decide($request, $manualPaymentRequest);

    }



    public function eastYemenRequestPayment(Request $request, ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noPermissionThenSendJson('manual-payments-review');

        $transaction = $this->ensureEastYemenTransaction($manualPaymentRequest);

        $validator = Validator::make($request->all(), [
            'customer_identifier' => 'required|string|max:255',
            'description' => 'nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            return ResponseService::validationError($validator->errors()->first());
        }

        $data = $validator->validated();

        try {
            $gateway = EastYemenBankGateway::fromConfig();

            $payload = array_filter([
                'customer_identifier' => $data['customer_identifier'],
                'amount' => $manualPaymentRequest->amount ? (float) $manualPaymentRequest->amount : null,
                'currency' => $manualPaymentRequest->currency,
                'reference' => $manualPaymentRequest->reference ?? (string) $manualPaymentRequest->id,
                'description' => $data['description'] ?? null,
            ], static fn ($value) => $value !== null && $value !== '');

            $response = $gateway->requestPayment($payload);

            $this->recordEastYemenActivity($manualPaymentRequest, 'request_payment', $payload, $response);

            if (!empty($response['voucher_number'])) {
                $transaction->update(['order_id' => $response['voucher_number']]);
            }

            return ResponseService::successResponse('East Yemen Bank payment request sent successfully.', [
                'response' => $response,
            ]);
        } catch (Throwable $throwable) {
            Log::error('East Yemen Bank request payment error: ' . $throwable->getMessage(), [
                'request_id' => $manualPaymentRequest->id,
            ]);

            return ResponseService::errorResponse('Unable to initiate payment with East Yemen Bank.');
        }
    }

    public function eastYemenConfirmPayment(Request $request, ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noPermissionThenSendJson('manual-payments-review');

        $transaction = $this->ensureEastYemenTransaction($manualPaymentRequest);

        $validator = Validator::make($request->all(), [
            'voucher_number' => 'required|string|max:255',
            'otp' => 'nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            return ResponseService::validationError($validator->errors()->first());
        }

        $data = $validator->validated();

        try {
            $gateway = EastYemenBankGateway::fromConfig();

            $additionalPayload = array_filter([
                'amount' => $manualPaymentRequest->amount ? (float) $manualPaymentRequest->amount : null,
                'currency' => $manualPaymentRequest->currency,
                'otp' => $data['otp'] ?? null,
            ], static fn ($value) => $value !== null && $value !== '');

            $response = $gateway->confirmPayment($data['voucher_number'], $additionalPayload);

            $this->recordEastYemenActivity($manualPaymentRequest, 'confirm_payment', array_merge([
                'voucher_number' => $data['voucher_number'],
            ], $additionalPayload), $response);

            if (!empty($response['status'])) {
                $transaction->meta = array_merge($transaction->meta ?? [], ['east_yemen_bank_status' => $response['status']]);
                $transaction->save();
            }

            return ResponseService::successResponse('East Yemen Bank payment confirmation submitted successfully.', [
                'response' => $response,
            ]);
        } catch (Throwable $throwable) {
            Log::error('East Yemen Bank confirm payment error: ' . $throwable->getMessage(), [
                'request_id' => $manualPaymentRequest->id,
            ]);

            return ResponseService::errorResponse('Unable to confirm payment with East Yemen Bank.');
        }
    }

    public function eastYemenCheckVoucher(Request $request, ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noPermissionThenSendJson('manual-payments-review');

        $this->ensureEastYemenTransaction($manualPaymentRequest);

        $validator = Validator::make($request->all(), [
            'voucher_number' => 'required|string|max:255',
        ]);

        if ($validator->fails()) {
            return ResponseService::validationError($validator->errors()->first());
        }

        $data = $validator->validated();

        try {
            $gateway = EastYemenBankGateway::fromConfig();

            $payload = array_filter([
                'currency' => $manualPaymentRequest->currency,
            ], static fn ($value) => $value !== null && $value !== '');

            $response = $gateway->checkVoucher($data['voucher_number'], $payload);

            $this->recordEastYemenActivity($manualPaymentRequest, 'check_voucher', array_merge([
                'voucher_number' => $data['voucher_number'],
            ], $payload), $response);

            return ResponseService::successResponse('East Yemen Bank voucher status fetched successfully.', [
                'response' => $response,
            ]);
        } catch (Throwable $throwable) {
            Log::error('East Yemen Bank check voucher error: ' . $throwable->getMessage(), [
                'request_id' => $manualPaymentRequest->id,
            ]);

            return ResponseService::errorResponse('Unable to check voucher with East Yemen Bank.');
        }
    }

    public function deepLink(PaymentTransaction $paymentTransaction)
    {
        $appStoreLink = CachingService::getSystemSettings('app_store_link');
        $playStoreLink = CachingService::getSystemSettings('play_store_link');
        $appName = CachingService::getSystemSettings('company_name');

        $deeplinkPath = 'transactions/' . $paymentTransaction->id;

        return view('payments.manual.deep-link', compact('appStoreLink', 'playStoreLink', 'appName', 'deeplinkPath', 'paymentTransaction'));
    }

    protected function statusBadge(?string $status): string
    {
        $normalized = $this->normalizeManualPaymentStatus($status) ?? $status;

        return match ($normalized) {

            ManualPaymentRequest::STATUS_APPROVED => '<span class="badge bg-success">' . trans('Approved') . '</span>',
            ManualPaymentRequest::STATUS_REJECTED => '<span class="badge bg-danger">' . trans('Rejected') . '</span>',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => '<span class="badge bg-info text-dark">' . trans('Under Review') . '</span>',
            default => '<span class="badge bg-warning text-dark">' . trans('Pending') . '</span>',

        };
    }

    protected function actionsColumn(ManualPaymentRequest $manualPaymentRequest): string
    {
        $buttons = '';

        $buttons .= BootstrapTableService::button(
            'fa fa-eye',
            route('manual-payments.review', $manualPaymentRequest),
            ['btn-primary', 'view-manual-payment'],
            [
                'target' => '_blank',
                'rel' => 'noopener noreferrer',
                'title' => trans('View'),
            ],
            trans('View')
        
        );

        return $buttons;
    }




    private function normalizeManualPaymentStatus($status): ?string
    {
        if (!is_string($status)) {
            return null;
        }

        $normalized = strtolower(trim($status));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }


        $canonical = ManualPaymentRequest::normalizeStatus($normalized);

        if ($canonical !== null) {
            return $canonical;
        }


        return in_array($normalized, [
            ManualPaymentRequest::STATUS_PENDING,
            ManualPaymentRequest::STATUS_APPROVED,
            ManualPaymentRequest::STATUS_REJECTED,
            ManualPaymentRequest::STATUS_UNDER_REVIEW,
        ], true) ? $normalized : null;
    }

    private function normalizeManualPaymentGateway($gateway): ?string
    {
        if (!is_string($gateway)) {
            return null;
        }

        $normalized = strtolower(trim($gateway));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        $canonical = ManualPaymentRequest::canonicalGateway($normalized);

        if ($canonical === null) {
            return null;
        }

        return $canonical === 'manual_bank' ? 'manual_banks' : $canonical;
    }

    private function normalizeManualPaymentPayableType($type): ?string
    {
        if (!is_string($type)) {
            return null;
        }

        $normalized = strtolower(trim($type));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        return match ($normalized) {
            'package', 'packages', 'app\\package', 'app\\models\\package' => Package::class,
            'item', 'items', 'advertisement', 'advertisements', 'app\\item', 'app\\models\\item' => Item::class,
            ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
            'wallet',
            'wallet-top-up',
            'wallet_top_up',
            'wallettopup' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
            default => $type,
        };
    }


    private function expandManualPaymentPayableTypeAliases($type): array
    {
        $canonical = $this->normalizeManualPaymentPayableType($type);

        if ($canonical === null) {
            return [];
        }


        if (ManualPaymentRequest::isOrderPayableType($canonical)) {
            return ManualPaymentRequest::orderPayableTypeAliases();
        }


        return match ($canonical) {

            Package::class => [
                Package::class,
                'package',
                'packages',
                'App\\Models\\Package',
                'App\\Package',
            ],
            Item::class => [
                Item::class,
                'item',
                'items',
                'advertisement',
                'advertisements',
                'App\\Models\\Item',
                'App\\Item',
            ],
            ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP => [
                ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                'wallet_top_up',
                'wallet-top-up',
                'wallettopup',
                'wallet',
            ],
            default => [$canonical, $type],
        };
    }

    private function normalizeManualPaymentDepartment($department): ?string
    {
        if (!is_string($department)) {
            return null;
        }

        $normalized = trim($department);

        if ($normalized === '' || strtolower($normalized) === 'null') {
            return null;
        }

        return $normalized;
    }

    private function normalizeManualPaymentDate($value, bool $startOfDay): ?Carbon
    {
        if (!is_string($value) || trim($value) === '') {
            return null;
        }

        try {
            $date = Carbon::parse($value);
        } catch (Throwable $throwable) {
            return null;
        }

        return $startOfDay ? $date->startOfDay() : $date->endOfDay();
    }

    private function normalizePaymentRequestStatus($status): ?string
    {
        if (!is_string($status)) {
            return null;
        }

        $normalized = strtolower(trim($status));


        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        return match ($normalized) {
            'succeed', 'success', 'succeeded', 'paid', 'approved', 'complete', 'completed', 'done', 'settled', 'confirmed' => 'succeed',
            'failed', 'failure', 'error', 'cancelled', 'canceled', 'rejected', 'declined', 'void', 'refunded' => 'failed',
            'pending', 'processing', 'in_review', 'in-review', 'review', 'reviewing', 'under_review', 'under-review', 'awaiting', 'waiting', 'new', 'initiated', 'open' => 'pending',
            default => in_array($normalized, ['pending', 'succeed', 'failed'], true) ? $normalized : null,
        };
    
    }

    private function normalizePaymentRequestChannel($channel): ?string
    {

        if (!is_string($channel)) {
            return null;
        }

        $normalized = strtolower(trim($channel));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }



        $canonical = ManualPaymentRequest::canonicalGateway($normalized);

        if ($canonical === null) {
            return null;
        }

        return match ($canonical) {
            'manual_bank' => 'manual_banks',
            'east_yemen_bank', 'manual_banks', 'wallet', 'cash' => $canonical,
            default => in_array($canonical, ['manual_banks', 'east_yemen_bank', 'wallet', 'cash'], true)
                ? $canonical
                : null,
        };
    }

   private function normalizePaymentRequestCategory($category): ?string
    {
        if (!is_string($category)) {
            return null;

        }
        $normalized = strtolower(trim($category));


        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        return match ($normalized) {
            'order', 'orders', 'cart', 'cart_order', 'cart-order', 'cartorder' => 'orders',
            'package', 'packages', 'user_purchased_package', 'userpurchasedpackage', 'user_purchased_packages', 'userpurchasedpackages' => 'packages',
            'wallet', 'wallet_top_up', 'wallet-top-up', 'wallettopup', 'topup', 'top-ups', 'top_ups', 'topups' => 'top_ups',
            default => in_array($normalized, ['orders', 'packages', 'top_ups'], true) ? $normalized : null,
        };
    }

    private function paymentRequestStatusLabel(?string $status): string
    {
        return match ($this->normalizePaymentRequestStatus($status) ?? 'pending') {
            'succeed' => trans('Success'),
            'failed' => trans('Failed'),
            default => trans('Pending'),
        };
    }

    private function paymentRequestChannelLabel(?string $channel): string
    {
        $normalized = $this->normalizePaymentRequestChannel($channel);

        if ($normalized !== null) {
            return match ($normalized) {
                'east_yemen_bank' => trans('East Yemen Bank Gateway'),
                'manual_banks' => trans('Manual Banks'),
                'wallet' => trans('Wallet'),
                'cash' => trans('Cash'),
                default => trans('Manual Banks'),
            };
        }

        if (is_string($channel) && $channel !== '') {
            return Str::of($channel)
                ->replace(['_', '-'], ' ')
                ->trim()
                ->title()
                ->value();
        }

        return trans('Manual Banks');
    }

    private function paymentRequestCategoryLabel(?string $category): string
    {
        return match ($this->normalizePaymentRequestCategory($category) ?? '') {
            'orders' => trans('Orders'),
            'packages' => trans('Packages'),
            'top_ups' => trans('Wallet Top-up'),
            default => '—',
        };
    }


    private function paymentRequestDepartmentLabel(?string $department): string
    {
        if (! is_string($department) || $department === '') {
            return trans('Unknown Department');
        }

        return match ($department) {
            DepartmentReportService::DEPARTMENT_SHEIN => trans('departments.shein'),
            DepartmentReportService::DEPARTMENT_COMPUTER => trans('departments.computer'),
            DepartmentReportService::DEPARTMENT_STORE => trans('departments.store'),
            default => $department,
        };
    }


    private function paymentRequestPayableLabel(object $row): string
    {
        $category = $this->normalizePaymentRequestCategory($row->category ?? null);

        if ($category === null) {
            return '—';
        }

        $payableId = $row->payable_id ?? null;
        $walletTransactionId = $row->wallet_transaction_id ?? null;
        $hasPayableId = $payableId !== null && $payableId !== '';
        $hasWalletTransactionId = $walletTransactionId !== null && $walletTransactionId !== '';

        return match ($category) {
            'orders' => $hasPayableId ? __('Order #:id', ['id' => $payableId]) : trans('Orders'),
            'packages' => $hasPayableId ? __('Package #:id', ['id' => $payableId]) : trans('Packages'),
            'top_ups' => $hasWalletTransactionId
                ? __('Wallet Top-up #:id', ['id' => $walletTransactionId])
                : trans('Wallet Top-up'),
            default => $this->paymentRequestCategoryLabel($category),
        };
    }

    private function paymentRequestActionsFromRow(object $row): string
    {

        $category = $this->normalizePaymentRequestCategory($row->category ?? null);
        $payableId = $row->payable_id ?? null;
        $hasPayableId = $payableId !== null && $payableId !== '';

        if ($category === 'orders' && $hasPayableId) {
            $orderId = $this->resolveOrderIdFromPayableId($payableId);

            if ($orderId === null || ! Route::has('orders.show')) {
                return '';
            }

            $url = route('orders.show', ['order' => $orderId]);

            return BootstrapTableService::button(
                'fa fa-external-link-alt',
                $url,
                ['btn-primary', 'view-order-details'],
                [
                    'title' => trans('View'),
                ],
                trans('View')
            );
        }

        if (
            !empty($row->manual_payment_request_id)
            && Route::has('manual-payments.review')
        ) {
            return BootstrapTableService::button(
                'fa fa-eye',
                route('manual-payments.review', ['manualPaymentRequest' => $row->manual_payment_request_id]),
                ['btn-outline-primary', 'view-manual-payment'],
                [
                    'target' => '_blank',
                    'rel' => 'noopener noreferrer',
                    'title' => trans('View'),
                ],
                trans('View')
            
            );
        }

        if (
            !empty($row->payment_transaction_id)
            && Route::has('manual-payments.deep-link')
        ) {
            return BootstrapTableService::button(
                'fa fa-receipt',
                route('manual-payments.deep-link', ['paymentTransaction' => $row->payment_transaction_id]),
                ['btn-outline-secondary'],
                [
                    'target' => '_blank',
                    'rel' => 'noopener noreferrer',
                    'title' => trans('View'),
                ]
            );
        }



        if (
            $category === 'orders'
            && $hasPayableId
            && Route::has('orders.show')
        ) {
            return BootstrapTableService::button(
                'fa fa-shopping-cart',
                route('orders.show', ['order' => $payableId]),
                ['btn-outline-primary'],
                [
                    'target' => '_blank',
                    'rel' => 'noopener noreferrer',
                    'title' => trans('View'),
                ]
            );
        }

        return '';
    }


    private function resolveOrderIdFromPayableId(mixed $payableId): ?int
    {
        if (! is_scalar($payableId)) {
            return null;
        }

        $normalized = trim((string) $payableId);

        if ($normalized === '') {
            return null;
        }

        if (array_key_exists($normalized, $this->manualPaymentOrderIdCache)) {
            return $this->manualPaymentOrderIdCache[$normalized];
        }

        $numericId = ctype_digit($normalized) ? (int) $normalized : null;

        $orderId = Order::withTrashed()
            ->select('id')
            ->when(
                $numericId !== null,
                static function (Builder $builder) use ($numericId, $normalized) {
                    $builder->where(static function (Builder $query) use ($numericId, $normalized) {
                        $query
                            ->where('id', $numericId)
                            ->orWhere('order_number', $normalized);
                    });
                },
                static function (Builder $builder) use ($normalized) {
                    $builder->where('order_number', $normalized);
                }
            )
            ->value('id');

        if ($orderId === null) {
            $orderId = $numericId;
        }

        return $this->manualPaymentOrderIdCache[$normalized] = $orderId !== null
            ? (int) $orderId
            : null;
    }


    private function resolveManualBankName(mixed $row): ?string
    {
        $candidates = [
            data_get($row, 'manual_bank_name'),
            data_get($row, 'manualBank.name'),
            data_get($row, 'manualBank.beneficiary_name'),
            data_get($row, 'bank_name'),
            data_get($row, 'bank_account_name'),
        ];

        foreach ($candidates as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }

            $trimmed = trim($candidate);

            if ($trimmed !== '') {
                return $trimmed;
            }
        }

        return null;
    }

    private function paymentRequestGatewayName(object $row): string
    {

        $channelValue = data_get($row, 'channel', data_get($row, 'payment_gateway'));
        $normalizedChannel = $this->normalizePaymentRequestChannel($channelValue);

        $propertyNames = [
            'payment_gateway_name',
            'gateway_name',
            'gateway_display_name',
        ];


        if ($normalizedChannel === 'manual_banks' || $normalizedChannel === null) {
            $propertyNames[] = 'manual_bank_name';
            $propertyNames[] = 'bank_name';
        }


        $candidates = [];

        foreach ($propertyNames as $property) {

            $value = data_get($row, $property);

            if (! is_string($value)) {
                continue;
            }


            $trimmed = trim($value);

            if ($trimmed === '') {
                continue;
            }
            $candidates[] = $trimmed;


        }

        if ($normalizedChannel === 'manual_banks' || $normalizedChannel === null) {
            $manualBankName = $this->resolveManualBankName($row);

            if ($manualBankName !== null) {
                $candidates[] = $manualBankName;


            }
        }

        foreach ($candidates as $candidate) {
            if ($candidate !== '') {
                return $candidate;
            }
        }

        if (is_string($channelValue) && trim($channelValue) !== '') {
            return Str::of($channelValue)
                ->replace(['_', '-'], ' ')
                ->trim()
                ->title()
                ->value();
        }

        return $this->paymentRequestChannelLabel(data_get($row, 'channel'));
    }


    private function resolvePaymentRequestOrder(Request $request): array
    {
        $orderInput = $request->input('order', []);
        $order = is_array($orderInput) ? $orderInput : [];

        $firstOrder = $order[0] ?? [];
        $columnIndex = (int) ($firstOrder['column'] ?? 8);
        $directionInput = strtolower((string) ($firstOrder['dir'] ?? 'desc'));
        $direction = in_array($directionInput, ['asc', 'desc'], true) ? $directionInput : 'desc';

        $columnDefinitions = $request->input('columns', []);
        $columnDefinitions = is_array($columnDefinitions) ? $columnDefinitions : [];

        $columnMap = [
            'transaction_id' => 'reference',
            'reference' => 'reference',
            'user_name' => 'user_name',
            'amount_fmt' => 'amount',
            'amount' => 'amount',
            'currency' => 'currency',
            'payment_gateway_label' => 'channel',
            'payment_gateway_name' => 'channel',
            'payment_gateway' => 'channel',
            'department_label' => 'department',
            'department' => 'department',
            'payable_label' => 'category',
            'payable_type' => 'category',
            'category' => 'category',
            'status_label' => 'status',
            'status' => 'status',
            'created_at_human' => 'created_at',
            'created_at' => 'created_at',
        ];

        $columnKey = null;

        if (isset($columnDefinitions[$columnIndex]) && is_array($columnDefinitions[$columnIndex])) {
            $dataKey = $columnDefinitions[$columnIndex]['data'] ?? null;
            if (is_string($dataKey) && $dataKey !== '') {
                $columnKey = $columnMap[$dataKey] ?? null;
            }
        }

        if ($columnKey === null) {
            $fallbackColumns = [
                0 => 'reference',
                1 => 'user_name',
                2 => 'amount',
                3 => 'currency',
                4 => 'channel',
                5 => 'department',
                6 => 'category',
                7 => 'status',
                8 => 'created_at',
            ];

            $columnKey = $fallbackColumns[$columnIndex] ?? 'created_at';
        }

        return [$columnKey, $direction];
    
    }

    private function resolveManualPaymentGatewayKey(ManualPaymentRequest $manualPaymentRequest): string
    {
        $gateway = $manualPaymentRequest->paymentTransaction?->payment_gateway;
        $normalized = ManualPaymentRequest::canonicalGateway($gateway);

        if ($normalized !== null) {
            return $normalized === 'manual_bank' ? 'manual_banks' : $normalized;

        }

        $metaGateway = ManualPaymentRequest::canonicalGateway(data_get($manualPaymentRequest->meta, 'gateway'));

        if ($metaGateway !== null) {
            return $metaGateway === 'manual_bank' ? 'manual_banks' : $metaGateway;

        }

        if (
            $manualPaymentRequest->isWalletTopUp()
            || data_get($manualPaymentRequest->meta, 'wallet.transaction_id')
        ) {
            return 'wallet';
        }

        return 'manual_banks';

        
    }

    private function manualPaymentStatusLabel(?string $status): string
    {
        return match ($this->normalizeManualPaymentStatus($status)) {
            ManualPaymentRequest::STATUS_APPROVED => trans('Approved'),
            ManualPaymentRequest::STATUS_REJECTED => trans('Rejected'),
            ManualPaymentRequest::STATUS_UNDER_REVIEW => trans('Under Review'),
            default => trans('Pending'),
        };
    }


    private function manualPaymentRequestsSupportsColumn(string $column): bool
    {
        if (!array_key_exists($column, $this->manualPaymentColumnSupportCache)) {
            $this->manualPaymentColumnSupportCache[$column] = Schema::hasTable('manual_payment_requests')
                && Schema::hasColumn('manual_payment_requests', $column);
        }

        return $this->manualPaymentColumnSupportCache[$column];
    }


    private function manualPaymentPayableLabel(ManualPaymentRequest $manualPaymentRequest): string
    {
        if ($manualPaymentRequest->isWalletTopUp()) {
            return trans('Wallet Top-up');
        }


        $typeLabel = $this->manualPaymentPayableTypeLabel($manualPaymentRequest->payable_type);
        $payable = $manualPaymentRequest->payable;

        if ($payable instanceof Order) {
            return trim($typeLabel . ' #' . $payable->id);
        }

        if ($payable instanceof Package) {
            $name = $payable->title ?? $payable->name ?? null;
            return $name ? $typeLabel . ' - ' . $name : $typeLabel;
        }

        if ($payable instanceof Item) {
            $title = $payable->title ?? $payable->name ?? null;
            return $title ? $typeLabel . ' - ' . $title : $typeLabel;
        }

        return $typeLabel ?: '—';
    }

    private function manualPaymentPayableTypeLabel(?string $type): string
    {
        $canonical = $this->normalizeManualPaymentPayableType($type);

        return match ($canonical) {
            Order::class => trans('Orders'),
            Package::class => trans('Packages'),
            Item::class => trans('Advertisements'),

            ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP => trans('Wallet Top-up'),


            default => $type
                ? Str::of(class_basename((string) $type))
                    ->replace('_', ' ')
                    ->headline()
                    ->value()
                : '—',
        };
    }





    private function ensureEastYemenTransaction(ManualPaymentRequest $manualPaymentRequest): PaymentTransaction
    {
        $transaction = $this->resolveTransaction($manualPaymentRequest);

        if (!$transaction) {
            ResponseService::errorResponse('Unable to locate the payment transaction for this request.');
        }

        if ($transaction->payment_gateway !== 'east_yemen_bank') {
            ResponseService::errorResponse('The associated payment transaction is not using East Yemen Bank gateway.');
        }

        return $transaction;
    }

    private function recordEastYemenActivity(ManualPaymentRequest $manualPaymentRequest, string $action, array $payload, array $response): ManualPaymentRequestHistory
    {
        return ManualPaymentRequestHistory::create([
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'user_id' => Auth::id(),
            'status' => $manualPaymentRequest->status,
            'meta' => [
                'action' => $action,
                'payload' => $payload,
                'response' => $response,
            ],
        ]);
    }


    protected function resolveTransaction(ManualPaymentRequest $manualPaymentRequest, bool $required = true): ?PaymentTransaction
    {
        $transaction = $manualPaymentRequest->paymentTransaction;


        $isOrderRequest = ManualPaymentRequest::isOrderPayableType((string) $manualPaymentRequest->payable_type);
        $resolvedOrderId = $isOrderRequest && $manualPaymentRequest->payable_id
            ? (int) $manualPaymentRequest->payable_id
            : null;

        $gatewayKey = $this->resolveManualPaymentGatewayKey($manualPaymentRequest);
        $transactionGateway = $gatewayKey === 'manual_banks' ? 'manual_bank' : $gatewayKey;



        if (!$transaction && $required) {
            $transaction = PaymentTransaction::create([
                'user_id' => $manualPaymentRequest->user_id,
                'amount' => $manualPaymentRequest->amount,
                'payment_gateway' => $transactionGateway,
                'order_id' => $resolvedOrderId,
                'payable_type' => $isOrderRequest ? Order::class : $manualPaymentRequest->payable_type,
                'payable_id' => $manualPaymentRequest->payable_id,
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'payment_status' => 'pending',
            ]);


        }

        if ($transaction) {
            $updates = [];

            if (empty($transaction->manual_payment_request_id)) {
                $updates['manual_payment_request_id'] = $manualPaymentRequest->id;
            }

            if (empty($transaction->payment_gateway) && $transactionGateway) {
                $updates['payment_gateway'] = $transactionGateway;
            }

            if ($resolvedOrderId !== null && empty($transaction->order_id)) {
                $updates['order_id'] = $resolvedOrderId;
            }

            $transactionPayableType = $transaction->payable_type;
            if (empty($transactionPayableType)) {
                $updates['payable_type'] = $isOrderRequest ? Order::class : $manualPaymentRequest->payable_type;
            } elseif (
                $isOrderRequest
                && ! ManualPaymentRequest::isOrderPayableType((string) $transactionPayableType)
            ) {
                $updates['payable_type'] = Order::class;

                
            }

            if (empty($transaction->payable_id) && !empty($manualPaymentRequest->payable_id)) {
                $updates['payable_id'] = $manualPaymentRequest->payable_id;
            }

            if (!empty($updates)) {
                $transaction->fill($updates);
                $transaction->save();
            }

 
        }

        return $transaction;
    }

    private function walletIdempotencyKey(ManualPaymentRequest $manualPaymentRequest): string
    {
        return sprintf('manual-payment-request:%d:wallet-credit', $manualPaymentRequest->getKey());
    }

    protected function sendDecisionNotification(ManualPaymentRequest $manualPaymentRequest, PaymentTransaction $transaction, string $status, ?string $note = null, ?string $attachmentUrl = null): void

    {
        $tokens = UserFcmToken::where('user_id', $manualPaymentRequest->user_id)->pluck('fcm_token')->filter()->values()->all();

        if (empty($tokens)) {
            return;
        }

        $title = $status === ManualPaymentRequest::STATUS_APPROVED
            ? trans('Manual payment approved')
            : trans('Manual payment rejected');

        $body = trans('Reference #:ref - Amount: :amount', [
            'ref' => $manualPaymentRequest->reference ?? $manualPaymentRequest->id,
            'amount' => number_format($manualPaymentRequest->amount, 2) . ($manualPaymentRequest->currency ? ' ' . $manualPaymentRequest->currency : ''),
        ]);

        $deepLink = route('manual-payments.deep-link', $transaction);


        $data = [
            'transaction_id' => $transaction->id,
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'status' => $status,
            'deep_link' => $deepLink,
        ];

        if ($note) {
            $data['note'] = $note;
        }

        if ($attachmentUrl) {
            $data['attachment'] = $attachmentUrl;
        }



        $response = NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'payment-transaction',
            
            $data

        );

        if (is_array($response) && ($response['error'] ?? false)) {
            Log::warning('ManualPaymentRequestController: Failed to send decision notification', [
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'message' => $response['message'] ?? null,
                'code' => $response['code'] ?? null,
            ]);
        }

    }


    private function gatewayLabel(string $gateway): string

    {
        $canonical = ManualPaymentRequest::canonicalGateway($gateway);

        if ($canonical === 'manual_bank') {
            $canonical = 'manual_banks';
        }

        return match ($canonical) {
            'east_yemen_bank' => trans('East Yemen Bank Gateway'),
            'manual_banks' => trans('Manual Banks'),

            'wallet' => trans('Wallet'),
            'cash' => trans('Cash'),


            default => ucwords(str_replace('_', ' ', $gateway)),
        };
    }


}