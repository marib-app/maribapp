<?php

namespace App\Http\Controllers;
use App\Models\Item;
use App\Models\ManualBank;
use App\Http\Controllers\Concerns\ManualPaymentViewHelpers;

use App\Models\ManualPaymentRequest;
use App\Models\ManualPaymentRequestHistory;
use App\Models\Order;
use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Models\WalletTransaction;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\Route;
use Illuminate\Database\Eloquent\Model;
use App\Queries\PaymentRequestTableQuery;
use App\Support\Payments\PaymentLabelService;
use App\Support\ManualPayments\TransferDetailsResolver;

use App\Models\UserFcmToken;
use App\Services\BootstrapTableService;
use App\Services\CachingService;
use App\Services\NotificationService;
use App\Services\Payments\EastYemenBankGateway;

use App\Services\DepartmentReportService;
use App\Models\User;

use App\Services\ResponseService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Database\QueryException;
use App\Services\Payments\ManualPaymentRequestService;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Collection;
use Carbon\CarbonInterface;

use RuntimeException;
use Throwable;

class ManualPaymentRequestController extends Controller
{

    use ManualPaymentViewHelpers;


    public function __construct(
        private readonly DepartmentReportService $departmentReportService,
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly \App\Services\Payments\ManualPaymentDecisionService $manualPaymentDecisionService,
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
            'east_yemen_bank' => trans('East Yemen Bank'),
            'manual_banks' => trans('Bank Transfer'),

            'wallet' => trans('Wallet'),
            'cash' => trans('Cash'),


        ];

        $departments = $this->departmentReportService->availableDepartments();
        $paymentRequestBase = DB::query()
            ->fromSub(PaymentRequestTableQuery::make(), 'requests');



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
            'id' => 'id',
            'reference' => 'reference',
            'payable_type' => 'payable_type',
            'status' => 'status_group',
            'submitted_at' => 'created_at',
            'created_at' => 'created_at',
        ];
        $sortColumn = $sortable[$sort] ?? 'created_at';



        $search = trim((string) $request->get('search', ''));

        $payableTypeAliases = $this->expandManualPaymentPayableTypeAliases($request->get('payable_type'));





        $departmentFilter = $request->get('department');
        $departmentFilter = $departmentFilter !== null && $departmentFilter !== '' ? $departmentFilter : null;

        $from = $request->get('from');
        $to = $request->get('to');

        $baseQuery = $this->buildUnifiedManualPaymentsBaseQuery($request);

        $overallTotal = (clone $baseQuery)->count();

        $query = (clone $baseQuery)
            ->when($search !== '', function ($q) use ($search) {
                $like = '%' . $search . '%';
                $q->where(function ($inner) use ($like) {
                    $inner->where('reference', 'LIKE', $like)
                        ->orWhere('user_name', 'LIKE', $like)
                        ->orWhere('user_mobile', 'LIKE', $like)
                        ->orWhere('payment_transaction_id', 'LIKE', $like)
                        ->orWhere('manual_payment_request_id', 'LIKE', $like);
                });
            })
            ->when($payableTypeAliases !== [], function ($q) use ($payableTypeAliases) {
                $normalized = array_map(static fn ($alias) => strtolower((string) $alias), $payableTypeAliases);
                $q->whereIn(DB::raw("LOWER(COALESCE(NULLIF(payable_type, ''), ''))"), $normalized);
            })
            ->when($request->filled('payment_gateway'), function ($q) use ($request) {
                $channel = $this->normalizePaymentRequestChannel($request->input('payment_gateway'));
                if ($channel !== null) {
                    $q->where('channel', $channel);
                }
            })
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

        $this->prefetchManualPaymentRequestsForRows($requests);
        $this->hydrateMissingManualPaymentRequestIds($requests);

        $transactionIds = $requests->pluck('payment_transaction_id')
            ->filter(static fn ($id) => $id !== null && $id !== '')
            ->map(static fn ($id) => is_numeric($id) ? (int) $id : null)
            ->filter()
            ->unique()
            ->values();

        $transactions = $transactionIds->isEmpty()
            ? collect()
            : PaymentTransaction::query()
                ->with(['manualPaymentRequest.manualBank'])
                ->whereIn('id', $transactionIds)
                ->get()
                ->keyBy('id');


        $rows = [];





        foreach ($requests as $requestRow) {


            $rowData = (array) $requestRow;
            $manualBankName = $this->resolveManualBankName($requestRow);
            $gatewayKey = $requestRow->channel ?? 'manual_banks';
            if ($gatewayKey === 'manual_bank') {
                $gatewayKey = 'manual_banks';
            }

            $manualPaymentRequestId = $this->normalizeManualPaymentIdentifier(
                $requestRow->manual_payment_request_id ?? null
            );



            $manualPaymentRequest = null;
            if ($manualPaymentRequestId !== null) {
                $manualPaymentRequest = $this->getManualPaymentRequestById($manualPaymentRequestId);
            }





            $rowData['id'] = $manualPaymentRequestId ?? $requestRow->payment_transaction_id;
            $rowData['user_name'] = $requestRow->user_name ?? '-';
            $rowData['user_mobile'] = $requestRow->user_mobile ?? '-';
            $canonicalGateway = ManualPaymentRequest::canonicalGateway($gatewayKey) ?? $gatewayKey;
            if ($canonicalGateway === 'manual_bank') {
                $canonicalGateway = 'manual_banks';
            }

            $rowData['payment_gateway_key'] = $canonicalGateway;
            
            $rowData['manual_bank_name'] = $manualBankName;
            $rowData['payment_gateway_name'] = $manualBankName


                ?? $this->paymentRequestGatewayName($requestRow);
            $rowData['gateway_code'] = $canonicalGateway;

            $labels = null;
            if ($requestRow->payment_transaction_id && $transactions->has((int) $requestRow->payment_transaction_id)) {
                $labels = PaymentLabelService::forPaymentTransaction($transactions->get((int) $requestRow->payment_transaction_id));
            } elseif ($manualPaymentRequest instanceof ManualPaymentRequest) {
                $labels = PaymentLabelService::forManualPaymentRequest($manualPaymentRequest);
            }

            if ($labels === null) {
                $labels = [
                    'gateway_key' => null,
                    'gateway_label' => null,
                    'bank_name' => null,
                    'channel_label' => null,
                    'bank_label' => null,
                ];
            }

            $channelLabel = $labels['gateway_label'];
            $bankLabel = $labels['bank_name'];
            $gatewayKeyFromLabels = $labels['gateway_key'];

            if ($gatewayKeyFromLabels) {
                $rowData['payment_gateway_key'] = $gatewayKeyFromLabels;
                $rowData['gateway_code'] = $gatewayKeyFromLabels;
            }

            $rowData['gateway_label'] = $channelLabel;
            $rowData['channel_label'] = $channelLabel;
            $rowData['gateway_key'] = $gatewayKeyFromLabels ?? $canonicalGateway;
            $rowData['payment_gateway'] = $gatewayKeyFromLabels ?? $canonicalGateway;
            $rowData['bank_label'] = $bankLabel;
            $rowData['bank_name'] = $bankLabel;
            $rowData['manual_bank_name'] = $bankLabel;

            $rowData['formatted_amount'] = number_format((float) ($requestRow->amount ?? 0), 2)



                . ($requestRow->currency ? ' ' . $requestRow->currency : '');

            $rowData['submitted_at'] = $requestRow->created_at
                ? Carbon::parse($requestRow->created_at)->format('Y-m-d H:i')
                : null;
            $rowData['status_badge'] = $this->statusBadge($requestRow->status_group ?? null);
            $rowData['status_group'] = $requestRow->status_group ?? null;
            if ($manualPaymentRequest instanceof ManualPaymentRequest) {
                $rowData['operate'] = $this->actionsColumn($manualPaymentRequest);
            } elseif ($manualPaymentRequestId !== null) {
                $rowData['operate'] = $this->renderManualPaymentReviewButton($manualPaymentRequestId);
            } else {
                $rowData['operate'] = '';
            }

            

            $rows[] = $rowData;

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

        $allowedColumnAliases = [
            'reference',
            'user_name',
            'user_mobile',
            'amount',
            'currency',
            'gateway_label',
            'bank_label',
            'gateway_code',
            'status',
            'channel',
            'created_at',
            'department',
            'manual_bank_name',
            'source',
            'category',
        ];




        $columnAliasMap = [
            'transaction_id' => 'reference',
            'reference' => 'reference',
            'user_name' => 'user_name',
            'user_mobile' => 'user_mobile',
            'amount_fmt' => 'amount',
            'amount_formatted' => 'amount',
            'amount' => 'amount',
            'currency' => 'currency',
            'payment_gateway_label' => 'gateway_label',
            'gateway_label' => 'gateway_label',
            'bank_label' => 'manual_bank_name',
            'payment_gateway_name' => 'channel',
            'payment_gateway' => 'channel',
            'channel_label' => 'channel',
            'channel_name' => 'channel',
            'channel' => 'channel',
            'gateway_code' => 'channel',
            'department_label' => 'department',
            'department' => 'department',
            'payable_label' => 'category',
            'category_label' => 'category',
            'payable_type' => 'category',
            'category' => 'category',
            'status_label' => 'status',
            'status' => 'status',
            'status_group' => 'status',
            'created_at_human' => 'created_at',
            'created_at' => 'created_at',
            'manual_bank_name' => 'manual_bank_name',
            'source' => 'source',
        ];

        $columnsInput = collect($request->input('columns', []))
            ->map(function ($column) use ($columnAliasMap, $allowedColumnAliases) {


                if (! is_array($column)) {
                    return $column;
                }

                foreach (['data', 'name'] as $key) {
                    if (! isset($column[$key]) || ! is_string($column[$key])) {
                        continue;
                    }

                    $normalized = trim($column[$key]);

                    if ($normalized === '') {
                        $column[$key] = null;
                        continue;
                    }

                    $normalized = trim($normalized, "`\"[]");

                    if (Str::contains($normalized, '.')) {
                        $normalized = Str::afterLast($normalized, '.');
                    }

                    $normalized = $columnAliasMap[$normalized] ?? $normalized;

                    if (! in_array($normalized, $allowedColumnAliases, true)) {
                        $column[$key] = null;
                        continue;
                    }


                    $column[$key] = $normalized;
                }

                return $column;
            })
            ->values();

        if ($columnsInput->isNotEmpty()) {
            $request->merge(['columns' => $columnsInput->toArray()]);
        }



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

        $baseQuery = $this->buildUnifiedManualPaymentsBaseQuery($request);



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
            ->when($statusFilter, static fn (QueryBuilder $query, string $status) => $query->where('status_group', $status))
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

        [$orderColumn, $orderDirection, $useRawOrder] = $this->resolvePaymentRequestOrder($request);

        $orderedQuery = clone $filteredQuery;

        if ($useRawOrder) {
            $orderedQuery->orderByRaw($orderColumn . ' ' . $orderDirection);
        } else {
            $orderedQuery->orderBy($orderColumn, $orderDirection);
        }


        if ($length !== null) {
            $orderedQuery->skip($start)->take($length);
        }

        $rows = $orderedQuery->get();
        $this->prefetchManualPaymentRequestsForRows($rows);
        $this->hydrateMissingManualPaymentRequestIds($rows);


        $data = $rows->map(function (object $row) {
            $transactionId = $row->payment_transaction_id
                ? (string) $row->payment_transaction_id
                : ($row->wallet_transaction_id ? 'WT-' . $row->wallet_transaction_id : $row->reference);
                
            $amount = (float) ($row->amount ?? 0);


            $gatewayKey = data_get($row, 'gateway_key', $row->channel ?? null);
            $gatewayCode = ManualPaymentRequest::canonicalGateway(is_string($gatewayKey) ? $gatewayKey : null);
            if ($gatewayCode === 'manual_bank') {
                $gatewayCode = 'manual_banks';
            }

            $channel = $gatewayCode ?? ManualPaymentRequest::canonicalGateway($row->channel ?? null);
            
            
            if ($channel === 'manual_bank') {
                $channel = 'manual_banks';
            }
            $manualBankName = $this->resolveManualBankName($row);
            $gatewayLabelValue = data_get($row, 'gateway_label');

            if (is_string($gatewayLabelValue)) {
                $gatewayLabelValue = trim($gatewayLabelValue);

                if ($gatewayLabelValue === '') {
                    $gatewayLabelValue = null;
                }
            } else {
                $gatewayLabelValue = null;
            }


            $createdAt = $row->created_at ? Carbon::parse($row->created_at) : null;

            $categoryLabel = $this->paymentRequestPayableLabel($row);

            $resolvedChannel = $channel ?? $row->channel;
            $gatewayLabel = $gatewayLabelValue
                ?? $this->paymentRequestChannelLabel($resolvedChannel, $manualBankName);

            return [
                'reference' => $row->reference ?? $transactionId,
                'transaction_id' => $transactionId,
                'user_name' => $row->user_name ?? '—',
                'user_mobile' => $row->user_mobile ?? '—',
                'amount' => $amount,
                'amount_fmt' => number_format($amount, 2, '.', ''),
                'currency' => $row->currency ?? '',
                'manual_payment_request_id' => $row->manual_payment_request_id,
                'payment_transaction_id' => $row->payment_transaction_id,
                'channel' => $resolvedChannel,
                'gateway_code' => $gatewayCode ?? $resolvedChannel,
                'channel_label' => $gatewayLabel,
                'channel_name' => $gatewayLabelValue
                    ?? $manualBankName


                    ?? $this->paymentRequestGatewayName($row),


                'manual_bank_name' => $manualBankName,
                'category' => $row->category,
                'category_label' => $categoryLabel,
                'department' => $row->department ?? null,
                'department_label' => $this->paymentRequestDepartmentLabel($row->department ?? null),
                'payable_type' => $row->payable_type ?? null,
                'payable_id' => $row->payable_id ?? null,
                'payable_label' => $categoryLabel,
                'gateway_label' => $gatewayLabel,
                'payment_gateway_label' => $gatewayLabel,
                'bank_label' => null,
                'status' => $row->status ?? $row->status_group,
                'status_group' => $row->status_group,
                'status_label' => $this->paymentRequestStatusLabel($row->status_group),
                'created_at' => $createdAt?->toDateTimeString(),
                'created_at_human' => $createdAt?->format('Y-m-d H:i') ?? '—',
                'source' => $row->source ?? null,
                'actions' => $this->paymentRequestActionsFromRow($row),
            ];
        })->values();
        $data = $this->applyPaymentLabelsToRowData($data)->values();

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

    



    private function applyPaymentLabelsToRowData(Collection $rows): Collection
    {
        if ($rows->isEmpty()) {
            return $rows;
        }

        $transactionIds = $rows->pluck('payment_transaction_id')
            ->filter(static fn ($id) => $id !== null && $id !== '')
            ->map(static fn ($id) => is_numeric($id) ? (int) $id : null)
            ->filter()
            ->unique()
            ->values();

        $manualRequestIds = $rows->pluck('manual_payment_request_id')
            ->map(fn ($id) => $this->normalizeManualPaymentIdentifier($id))
            ->filter()
            ->unique()
            ->values();

        $transactions = $transactionIds->isEmpty()
            ? collect()
            : PaymentTransaction::query()
                ->with(['manualPaymentRequest.manualBank'])
                ->whereIn('id', $transactionIds)
                ->get()
                ->keyBy('id');

        $manualRequests = $manualRequestIds->isEmpty()
            ? collect()
            : ManualPaymentRequest::query()
                ->with(['manualBank'])
                ->whereIn('id', $manualRequestIds)
                ->get()
                ->keyBy('id');

        return $rows->map(function ($row) use ($transactions, $manualRequests) {
            $rowArray = is_array($row) ? $row : (array) $row;

            $transactionId = $rowArray['payment_transaction_id'] ?? null;
            $manualRequestId = $this->normalizeManualPaymentIdentifier($rowArray['manual_payment_request_id'] ?? null);

            $labels = [
                'gateway_key' => $rowArray['gateway_key'] ?? null,
                'gateway_label' => $rowArray['gateway_label'] ?? null,
                'bank_name' => $rowArray['bank_label'] ?? null,
                'channel_label' => $rowArray['gateway_label'] ?? null,
                'bank_label' => $rowArray['bank_label'] ?? null,
            ];

            if ($transactionId !== null) {
                $transactionKey = is_numeric($transactionId) ? (int) $transactionId : null;

                if ($transactionKey !== null && $transactions->has($transactionKey)) {
                    $labels = PaymentLabelService::forPaymentTransaction($transactions->get($transactionKey));
                }
            }

            if (($labels['gateway_label'] ?? null) === null && $manualRequestId !== null && $manualRequests->has($manualRequestId)) {
                $labels = PaymentLabelService::forManualPaymentRequest($manualRequests->get($manualRequestId));
            }

            if ($transactionId === null && $manualRequestId !== null && $manualRequests->has($manualRequestId)) {
                $labels = PaymentLabelService::forManualPaymentRequest($manualRequests->get($manualRequestId));
            }

            $channelLabel = $labels['gateway_label'];
            $bankLabel = $labels['bank_name'];
            $gatewayKey = $labels['gateway_key'];

            $rowArray['gateway_label'] = $channelLabel;
            $rowArray['payment_gateway_label'] = $channelLabel;
            $rowArray['channel_label'] = $channelLabel;
            $rowArray['bank_label'] = $bankLabel;
            $rowArray['manual_bank_name'] = $bankLabel;
            $rowArray['gateway_key'] = $gatewayKey ?? ($rowArray['gateway_key'] ?? null);


            if ($rowArray['gateway_label'] === trans('المحفظة')) {
                $rowArray['bank_label'] = null;
                $rowArray['manual_bank_name'] = null;
            }

            return $rowArray;
        });
    }


    public function show(ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noAnyPermissionThenSendJson(['manual-payments-list', 'manual-payments-review']);



        $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);

        return view('payments.manual.show', array_merge([
            'request' => $manualPaymentRequest,
            'canReview' => Auth::user()->can('manual-payments-review') && $manualPaymentRequest->isOpen(),
            'timelineData' => $this->manualPaymentTimelinePayload($manualPaymentRequest),
        ], $this->manualPaymentRequestPresentationData($manualPaymentRequest)));
    }


    public function review(ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noAnyPermissionThenRedirect(['manual-payments-list', 'manual-payments-review']);

        $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);

        return view('payments.manual.review', array_merge([
            'request' => $manualPaymentRequest,
            'canReview' => Auth::user()->can('manual-payments-review') && $manualPaymentRequest->isOpen(),
            'timelineData' => $this->manualPaymentTimelinePayload($manualPaymentRequest),
        ], $this->manualPaymentRequestPresentationData($manualPaymentRequest)));
    }


    public function reviewTransaction(PaymentTransaction $paymentTransaction)
    {
        ResponseService::noAnyPermissionThenRedirect(['manual-payments-review']);

        $paymentTransaction->load([
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
        ]);

        $manualPaymentRequest = $paymentTransaction->manualPaymentRequest;

        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);
        } else {
            $manualPaymentRequest = $this->makeManualPaymentRequestFromTransaction($paymentTransaction);
        }

        $presentation = $this->manualPaymentRequestPresentationData($manualPaymentRequest);
        if (! isset($presentation['transferDetails'])) {
            $presentation['transferDetails'] = TransferDetailsResolver::forRow($paymentTransaction)->toArray();
        }


        return view(
            'payments.manual.review-transaction',
            array_merge(
                [
                    'transaction' => $paymentTransaction,
                    'request' => $manualPaymentRequest,
                    'canReview' => false,
                    'timelineData' => [],
                ],
                $presentation
            )
        );
    }





    public function timeline(ManualPaymentRequest $manualPaymentRequest)
    {
        ResponseService::noAnyPermissionThenSendJson(['manual-payments-list', 'manual-payments-review']);

        $manualPaymentRequest = $this->loadManualPaymentRequestRelations($manualPaymentRequest);

        return response()->json([
            'data' => $this->manualPaymentTimelinePayload($manualPaymentRequest),

        ]);
    }



    private function summarizePaymentRequests(QueryBuilder $query): array
    {
        $summaryRow = (clone $query)
            ->selectRaw('COUNT(*) as total_requests, COALESCE(SUM(amount), 0) as total_amount')
            ->first();

        $statusTotals = (clone $query)
            ->select('status_group', DB::raw('COUNT(*) as aggregate_total'))
            ->groupBy('status_group')
            ->pluck('aggregate_total', 'status_group');

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
                    ->select('department', 'status_group')
                    ->selectRaw('COUNT(*) as aggregate_total')
                    ->groupBy('department', 'status_group')
                    ->get();

                foreach ($departmentStats as $stat) {
                    $departmentKey = $stat->department;

                    if (!isset($departmentSummary[$departmentKey])) {
                        continue;
                    }

                    $total = (int) ($stat->aggregate_total ?? 0);
                    $status = is_string($stat->status_group) ? strtolower($stat->status_group) : '';

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







        try {
            $history = $this->manualPaymentDecisionService->decide($manualPaymentRequest, $status, [
                'note' => $note,
                'notify' => $shouldNotify,
                'attachment_path' => $attachmentPath,
                'attachment_name' => $attachmentOriginalName,
                'document_valid_until' => $documentValidUntil?->toDateString(),
                'actor_id' => Auth::id(),
            ]);
        } catch (Throwable $throwable) {
            return ResponseService::errorResponse($throwable->getMessage());
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
        $normalized = $this->normalizePaymentRequestStatus($status) ?? 'pending';

        return match ($normalized) {

            'succeed' => '<span class="badge bg-success">' . trans('Success') . '</span>',
            'failed' => '<span class="badge bg-danger">' . trans('Failed') . '</span>',
            default => '<span class="badge bg-warning text-dark">' . trans('Pending') . '</span>',

        };
    }

    protected function actionsColumn(?ManualPaymentRequest $manualPaymentRequest): string
    {

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            return '';
        }

        return $this->renderManualPaymentReviewButton($manualPaymentRequest);

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
        if ($value instanceof CarbonInterface) {
            $date = $value->copy();
        } elseif ($value instanceof \DateTimeInterface) {
            $date = Carbon::instance($value);
        } elseif (is_string($value)) {
            $trimmed = trim($value);



            if ($trimmed === '' || strtolower($trimmed) === 'null') {
                return null;
            }

            try {
                $date = Carbon::parse($trimmed);
            } catch (Throwable) {
                return null;
            }
        } else {


            return null;
        }

        return $startOfDay ? $date->startOfDay() : $date->endOfDay();
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


    private function paymentRequestCategoryLabel(?string $category): string
    {
        return match ($this->normalizePaymentRequestCategory($category) ?? '') {
            'orders' => trans('Orders'),
            'packages' => trans('Packages'),
            'top_ups' => trans('Wallet Top-up'),
            default => '—',
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
        $manualPaymentRequestId = $this->normalizeManualPaymentIdentifier(
            data_get($row, 'manual_payment_request_id')
        );

        $manualPaymentRequest = $manualPaymentRequestId !== null
            ? $this->getManualPaymentRequestById($manualPaymentRequestId)
            : null;

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualPaymentRequest = $this->resolveManualPaymentRequestForRow($row);


            if ($manualPaymentRequest instanceof ManualPaymentRequest) {
                $manualPaymentRequestId = $manualPaymentRequest->getKey();
                $row->manual_payment_request_id = $manualPaymentRequestId;
            }
        }

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $reference = data_get($row, 'reference');

            if (is_string($reference) && trim($reference) !== '') {
                $manualPaymentRequest = ManualPaymentRequest::query()
                    ->where('reference', trim($reference))
                    ->orderByDesc('id')
                    ->first();

                if ($manualPaymentRequest instanceof ManualPaymentRequest) {
                    $manualPaymentRequestId = $manualPaymentRequest->getKey();
                    $row->manual_payment_request_id = $manualPaymentRequestId;
                    $this->manualPaymentRequestLookupCache[$manualPaymentRequestId] = $manualPaymentRequest;
                }
            }
        }


        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $walletTransactionId = $this->normalizeManualPaymentIdentifier(
                data_get($row, 'wallet_transaction_id')
            );

            if ($walletTransactionId !== null) {
                $manualPaymentRequest = ManualPaymentRequest::query()
                    ->where(function ($query) use ($walletTransactionId) {
                        $query->where(function ($inner) use ($walletTransactionId) {
                            $inner->where('payable_type', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                                ->where('payable_id', $walletTransactionId);
                        })->orWhere(function ($inner) use ($walletTransactionId) {
                            $inner->whereRaw(
                                "JSON_UNQUOTE(JSON_EXTRACT(meta, '$.wallet.transaction_id')) IN (?, ?)",
                                [$walletTransactionId, (string) $walletTransactionId]
                            );
                        });
                    })
                    ->orderByDesc('id')
                    ->first();

                if ($manualPaymentRequest instanceof ManualPaymentRequest) {
                    $manualPaymentRequestId = $manualPaymentRequest->getKey();
                    $row->manual_payment_request_id = $manualPaymentRequestId;
                    $this->manualPaymentRequestLookupCache[$manualPaymentRequestId] = $manualPaymentRequest;
                }
            }
        }



        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            return $this->actionsColumn($manualPaymentRequest);
        }


        if ($manualPaymentRequestId !== null) {
            return $this->renderManualPaymentReviewButton($manualPaymentRequestId);
        }


        $transactionId = $this->normalizeManualPaymentIdentifier(
            data_get($row, 'payment_transaction_id') ?? data_get($row, 'id')
        );

        if ($transactionId === null) {
            return '';
        }


        $channel = $this->normalizePaymentRequestChannel(
            data_get($row, 'channel') ?? data_get($row, 'payment_gateway')
        );

        if ($channel === 'wallet') {
            $walletReviewButton = $this->renderPaymentTransactionReviewButton($transactionId);

            if ($walletReviewButton !== '') {
                return $walletReviewButton;
            }
        }



        $transaction = PaymentTransaction::query()
            ->with('manualPaymentRequest')
            ->find($transactionId);

        if (! $transaction instanceof PaymentTransaction) {
            return '';
        }

        $manualPaymentRequest = $transaction->manualPaymentRequest;

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualPaymentRequest = $this->manualPaymentRequestService
                ->ensureManualPaymentRequestForTransaction($transaction);
        }

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $transactionManualRequestId = $this->normalizeManualPaymentIdentifier(
                $transaction->manual_payment_request_id
            );

            if ($transactionManualRequestId !== null) {
                $manualPaymentRequestId = $transactionManualRequestId;
                $manualPaymentRequest = $this->getManualPaymentRequestById($transactionManualRequestId);
            }
        }

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            return $manualPaymentRequestId !== null
                ? $this->renderManualPaymentReviewButton($manualPaymentRequestId)
                : '';
        }

        $manualPaymentRequestId = $manualPaymentRequest->getKey();
        $row->manual_payment_request_id = $manualPaymentRequestId;
        $this->manualPaymentRequestLookupCache[$manualPaymentRequestId] = $manualPaymentRequest;

        return $this->actionsColumn($manualPaymentRequest);
    }

    private function renderManualPaymentReviewButton(ManualPaymentRequest|int $manualPaymentRequest): string
    {
        if (! Route::has('payment-requests.review')) {
            return '';

        
        }

        $manualPaymentRequestId = $manualPaymentRequest instanceof ManualPaymentRequest
            ? $manualPaymentRequest->getKey()
            : $manualPaymentRequest;

        if (! is_int($manualPaymentRequestId) || $manualPaymentRequestId <= 0) {
            return '';



        }

        $manualPaymentInstance = $manualPaymentRequest instanceof ManualPaymentRequest
            ? $manualPaymentRequest
            : $this->getManualPaymentRequestById($manualPaymentRequestId);

        $user = Auth::user();
        $canReview = $user?->can('manual-payments-review') ?? false;
        $shouldOpenReview = $manualPaymentInstance instanceof ManualPaymentRequest
            ? ($canReview && $manualPaymentInstance->isOpen())
            : $canReview;

        $url = route('payment-requests.review', ['manualPaymentRequest' => $manualPaymentRequestId]);

        $label = $shouldOpenReview ? trans('Review request') : trans('View request');
        $buttonClasses = $shouldOpenReview
            ? ['btn-primary']
            : ['btn-outline-primary'];

        return BootstrapTableService::button(
            'fa fa-eye',
            $url,
            array_merge($buttonClasses, ['view-payment-request']),
            [
                'target' => '_blank',
                'rel' => 'noopener noreferrer',
                'title' => $label,
            ],
            $label
        );
    }


    private function renderPaymentTransactionReviewButton(int $paymentTransactionId): string
    {
        if (! Route::has('payment-requests.review-transaction')) {
            return '';
        }

        if ($paymentTransactionId <= 0) {
            return '';
        }

        $user = Auth::user();

        if (! ($user?->can('manual-payments-review') ?? false)) {
            return '';
        }

        $url = route('payment-requests.review-transaction', ['paymentTransaction' => $paymentTransactionId]);

        return BootstrapTableService::button(
            'fa fa-eye',
            $url,
            ['btn-outline-primary', 'view-payment-transaction'],
            [
                'target' => '_blank',
                'rel' => 'noopener noreferrer',
                'title' => trans('Review transaction'),
            ],
            trans('Review transaction')
        );
    }

    private function resolveManualPaymentRequestForRow(object $row): ?ManualPaymentRequest
    {

        $manualPaymentRequest = null;


        $transactionId = $this->normalizeManualPaymentIdentifier(
            data_get($row, 'payment_transaction_id')
        );

        if ($transactionId !== null) {
            $transaction = PaymentTransaction::query()
                ->with('manualPaymentRequest')
                ->find($transactionId);

            if ($transaction) {
                $manualPaymentRequest = $transaction->manualPaymentRequest;

                if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                    $manualPaymentRequestId = $this->normalizeManualPaymentIdentifier(
                        $transaction->manual_payment_request_id
                    );

                    if ($manualPaymentRequestId !== null) {
                        $manualPaymentRequest = $this->getManualPaymentRequestById($manualPaymentRequestId);
                    }
                }
                if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                    $manualPaymentRequest = ManualPaymentRequest::query()
                        ->where('payment_transaction_id', $transaction->getKey())
                        ->orderByDesc('id')
                        ->first();
                }

                if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                    $manualPaymentRequest = $this->manualPaymentRequestService
                        ->ensureManualPaymentRequestForTransaction($transaction);
                }
            }
        }

        if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
            $payableId = $this->normalizeManualPaymentIdentifier(data_get($row, 'payable_id'));


            if ($payableId !== null) {
                $query = ManualPaymentRequest::query()
                    ->where('payable_id', $payableId)
                    ->orderByDesc('id');

                $payableType = data_get($row, 'payable_type');
                $category = $this->normalizePaymentRequestCategory(data_get($row, 'category'));

                if (
                    (is_string($payableType) && ManualPaymentRequest::isOrderPayableType($payableType))
                    || $category === 'orders'
                ) {
                    $query->whereIn('payable_type', ManualPaymentRequest::orderPayableTypeAliases());
                }

                $manualPaymentRequest = $query->first();
            }
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $this->manualPaymentRequestLookupCache[$manualPaymentRequest->id] = $manualPaymentRequest;

            return $manualPaymentRequest;
        }

        return null;
    }

    private function hydrateMissingManualPaymentRequestIds(Collection $rows): void
    {
        if ($rows->isEmpty()) {
            return;
        }

        $transactionIds = $rows
            ->map(function (object $row) {
                if ($this->normalizeManualPaymentIdentifier(data_get($row, 'manual_payment_request_id')) !== null) {
                    return null;
                }

                return $this->normalizeManualPaymentIdentifier(data_get($row, 'payment_transaction_id'));
            })
            ->filter()
            ->unique()
            ->values();

        if ($transactionIds->isEmpty()) {
            return;
        }

        $transactions = PaymentTransaction::query()
            ->with('manualPaymentRequest')
            ->whereIn('id', $transactionIds->all())
            ->get()
            ->keyBy('id');

        foreach ($rows as $row) {
            $manualPaymentRequestId = $this->normalizeManualPaymentIdentifier(
                data_get($row, 'manual_payment_request_id')
            );

            if ($manualPaymentRequestId !== null) {
                continue;
            }

            $transactionId = $this->normalizeManualPaymentIdentifier(
                data_get($row, 'payment_transaction_id')
            );

            if ($transactionId === null) {
                continue;
            }

            $transaction = $transactions->get($transactionId);

            if (! $transaction) {
                continue;
            }

            $manualPaymentRequest = $transaction->manualPaymentRequest;

            if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                $manualPaymentRequestId = $this->normalizeManualPaymentIdentifier(
                    $transaction->manual_payment_request_id
                );

                if ($manualPaymentRequestId !== null) {
                    $manualPaymentRequest = $this->getManualPaymentRequestById($manualPaymentRequestId);
                }
            }

            if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                $manualPaymentRequest = ManualPaymentRequest::query()
                    ->where('payment_transaction_id', $transaction->getKey())
                    ->orderByDesc('id')
                    ->first();
            }

            if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                try {
                    $manualPaymentRequest = $this->manualPaymentRequestService
                        ->ensureManualPaymentRequestForTransaction($transaction);
                } catch (QueryException $exception) {
                    if ((string) $exception->getCode() === '23000') {
                        Log::warning('Skipped hydrating manual payment request for transaction due to unique constraint violation.', [
                            'payment_transaction_id' => $transaction->getKey(),
                            'error' => $exception->getMessage(),
                        ]);

                        continue;
                    }

                    throw $exception;
                }
            }

            if (! $manualPaymentRequest instanceof ManualPaymentRequest) {
                continue;
            }

            $linkedTransactionId = $manualPaymentRequest->payment_transaction_id;

            if ($linkedTransactionId !== null && (int) $linkedTransactionId !== $transaction->getKey()) {
                Log::info('Manual payment request already linked to a different transaction. Skipping hydration.', [
                    'manual_payment_request_id' => $manualPaymentRequest->getKey(),
                    'payment_transaction_id' => $transaction->getKey(),
                    'existing_payment_transaction_id' => $linkedTransactionId,
                ]);

                continue;
            }

            $row->manual_payment_request_id = $manualPaymentRequest->getKey();
            $this->manualPaymentRequestLookupCache[$manualPaymentRequest->id] = $manualPaymentRequest;
        }
    }

    private function normalizeManualPaymentIdentifier($value): ?int
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $value = trim($value);

            if ($value === '') {
                return null;
            }
        }

        if (! is_numeric($value)) {
            return null;
        }

        $id = (int) $value;

        return $id > 0 ? $id : null;
    }



    private function paymentRequestGatewayName(object $row): string
    {

        $channelValue = data_get($row, 'channel', data_get($row, 'payment_gateway'));
        $normalizedChannel = $this->normalizePaymentRequestChannel($channelValue);
        $manualBankAliases = $this->resolveGenericGatewayAliases();

        $propertyNames = ['payment_gateway_name'];

        $manualBankName = null;


        if ($normalizedChannel === 'manual_banks' || $normalizedChannel === null) {
            $propertyNames[] = 'gateway_label';
            $propertyNames[] = 'manual_bank_name';
            $propertyNames[] = 'bank_name';
            $propertyNames[] = 'gateway_name';
            $propertyNames[] = 'gateway_display_name';
        } else {
            $propertyNames[] = 'gateway_label';
            $propertyNames[] = 'gateway_name';
            $propertyNames[] = 'gateway_display_name';

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

            if (in_array(strtolower($trimmed), $manualBankAliases, true)) {
                continue;
            }

            $candidates[] = $trimmed;


        }

        if ($normalizedChannel === 'manual_banks' || $normalizedChannel === null) {
            $manualBankName = $this->resolveManualBankName($row);

            if ($manualBankName !== null) {
                array_unshift($candidates, $manualBankName);


            }
        }

        foreach ($candidates as $candidate) {
            if ($candidate === '') {
                continue;
            }

            if (in_array(strtolower($candidate), $manualBankAliases, true)) {
                continue;
            }

            return $candidate;

        }

        if (is_string($channelValue) && trim($channelValue) !== '') {
            return Str::of($channelValue)
                ->replace(['_', '-'], ' ')
                ->trim()
                ->title()
                ->value();
        }

        return $this->paymentRequestChannelLabel(data_get($row, 'channel'), $manualBankName);
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
            'user_mobile' => 'user_mobile',
            'amount_fmt' => 'amount',
            'amount_formatted' => 'amount',
            'amount' => 'amount',
            'currency' => 'currency',
            'payment_gateway_label' => 'gateway_label',
            'gateway_label' => 'gateway_label',
            'payment_gateway_name' => 'channel',
            'payment_gateway' => 'channel',
            'channel_label' => 'channel',
            'channel_name' => 'channel',
            'channel' => 'channel',
            'gateway_code' => 'channel',
            'department_label' => 'department',
            'department' => 'department',
            'payable_label' => 'category',
            'category_label' => 'category',
            'payable_type' => 'category',
            'category' => 'category',
            'status_label' => 'status',
            'status' => 'status',
            'status_group' => 'status',
            'created_at_human' => 'created_at',
            'created_at' => 'created_at',
            'manual_bank_name' => 'manual_bank_name',
            'source' => 'source',
        ];

        $columnKey = null;

        if (isset($columnDefinitions[$columnIndex]) && is_array($columnDefinitions[$columnIndex])) {
            $columnDefinition = $columnDefinitions[$columnIndex];

            $resolveColumn = static function ($value) use ($columnMap) {
                if (! is_string($value)) {
                    return null;
                }

                $normalized = trim($value);

                if ($normalized === '') {
                    return null;
                }

                $normalized = trim($normalized, "`\"[]");

                if (str_contains($normalized, '.')) {
                    $parts = explode('.', $normalized);
                    $normalized = end($parts) ?: $normalized;
                }

                if (isset($columnMap[$normalized])) {
                    return $columnMap[$normalized];
                }

                $allowedColumns = [
                    'reference',
                    'user_name',
                    'user_mobile',
                    'amount',
                    'currency',
                    'channel',
                    'department',
                    'category',
                    'status',
                    'created_at',
                    'manual_bank_name',
                    'source',
                ];

                return in_array($normalized, $allowedColumns, true) ? $normalized : null;
            };

            $columnKey = $resolveColumn($columnDefinition['data'] ?? null)
                ?? $resolveColumn($columnDefinition['name'] ?? null);
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
                9 => 'reference',
            ];

            $columnKey = $fallbackColumns[$columnIndex] ?? 'created_at';
        }

        $allowedOrderColumns = [
            'reference' => ['column' => 'reference', 'raw' => false],
            'user_name' => ['column' => 'user_name', 'raw' => false],
            'user_mobile' => ['column' => 'user_mobile', 'raw' => false],
            'amount' => ['column' => 'amount', 'raw' => false],
            'currency' => ['column' => 'currency', 'raw' => false],
            'channel' => ['column' => 'channel', 'raw' => false],
            'department' => ['column' => 'department', 'raw' => false],
            'category' => ['column' => 'category', 'raw' => true],
            'status' => ['column' => 'status', 'raw' => true],
            'created_at' => ['column' => 'created_at', 'raw' => false],
            'manual_bank_name' => ['column' => 'manual_bank_name', 'raw' => false],
            'source' => ['column' => 'source', 'raw' => false],
        ];

        if (! isset($allowedOrderColumns[$columnKey])) {
            $columnKey = 'created_at';
        }

        $orderColumn = $allowedOrderColumns[$columnKey];

        return [$orderColumn['column'], $direction, (bool) $orderColumn['raw']];

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
            $attributes = [
                'user_id' => $manualPaymentRequest->user_id,
                'amount' => $manualPaymentRequest->amount,
                'payment_gateway' => $transactionGateway,
                'order_id' => $resolvedOrderId,
                'payable_type' => $isOrderRequest ? Order::class : $manualPaymentRequest->payable_type,
                'payable_id' => $manualPaymentRequest->payable_id,
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'payment_status' => 'pending',
            ];

            if ($transactionGateway === 'east_yemen_bank') {
                $attributes['meta'] = [
                    'provider' => 'alsharq',
                    'channel' => 'alsharq',
                ];
            }

            $transaction = PaymentTransaction::create($attributes);


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


            if ($transactionGateway === 'east_yemen_bank') {
                $currentMeta = $transaction->meta;

                if (!is_array($currentMeta)) {
                    $currentMeta = [];
                }

                $needsProvider = ($currentMeta['provider'] ?? null) !== 'alsharq';
                $needsChannel = ($currentMeta['channel'] ?? null) !== 'alsharq';

                if ($needsProvider || $needsChannel) {
                    $currentMeta['provider'] = 'alsharq';
                    $currentMeta['channel'] = 'alsharq';

                    $updates['meta'] = $currentMeta;
                }
            }



            if (!empty($updates)) {
                $transaction->fill($updates);
                $transaction->save();
            }

 
        }

        return $transaction;
    }

    public function buildUnifiedManualPaymentsBaseQuery(Request $request): QueryBuilder
    {
        $startDate = $this->normalizeManualPaymentDate($request->get('start_date'), true)
            ?? $this->normalizeManualPaymentDate($request->get('date_from'), true)
            ?? $this->normalizeManualPaymentDate($request->get('from'), true);
        $endDate = $this->normalizeManualPaymentDate($request->get('end_date'), false)
            ?? $this->normalizeManualPaymentDate($request->get('date_to'), false)
            ?? $this->normalizeManualPaymentDate($request->get('to'), false);

        if ($startDate !== null && $endDate !== null && $startDate->greaterThan($endDate)) {
            [$startDate, $endDate] = [$endDate->copy()->startOfDay(), $startDate->copy()->endOfDay()];
        }

        $query = DB::query()->fromSub(PaymentRequestTableQuery::make(), 'requests');


        if ($startDate !== null) {
            $query->where('created_at', '>=', $startDate);
        }
        if ($endDate !== null) {
            $query->where('created_at', '<=', $endDate);
        }
        $statusGroups = $this->statusGroupsForFilter($request->input('status'));


        if ($statusGroups !== []) {
            $query->whereIn('status_group', $statusGroups);
        }

        return $query;
    }

    private function statusGroupsForFilter($status): array
    {
        if (! is_string($status)) {
            return [];
        }

        $normalized = strtolower(trim($status));

        if ($normalized === '' || $normalized === 'null') {
            return [];
        }

        return match ($normalized) {
            'succeed', 'success', 'approved', 'accept', 'accepted' => ['succeed'],
            'failed', 'failure', 'rejected', 'declined', 'canceled', 'cancelled', 'void' => ['failed'],
            'pending', 'processing', 'in_review', 'in-review', 'under_review', 'under-review', 'waiting', 'awaiting', 'open', 'new', 'initiated' => ['pending'],
            default => [],
        };
    }

    private function quoteSqlList(array $values): string
    {
        $normalized = array_values(array_filter(array_map(function ($value) {
            if (! is_string($value)) {
                return null;
            }

            return "'" . str_replace("'", "''", strtolower(trim($value))) . "'";
        }, $values), static fn ($value) => $value !== null));

        return $normalized === [] ? "''" : implode(', ', array_unique($normalized));
    }



    private function gatewayLabel(string $gateway, ?string $manualBankName = null): string

    {

        $manualBankName = is_string($manualBankName) ? trim($manualBankName) : null;

        if ($manualBankName !== null && $manualBankName !== '') {
            $aliases = $this->resolveGenericGatewayAliases();

            if (! in_array(strtolower($manualBankName), $aliases, true)) {
                return $manualBankName;
            }
        }


        $canonical = ManualPaymentRequest::canonicalGateway($gateway);

        if ($canonical === 'manual_bank') {
            $canonical = 'manual_banks';
        }

        return match ($canonical) {
            'east_yemen_bank' => trans('East Yemen Bank'),
            'manual_banks' => trans('Bank Transfer'),

            'wallet' => trans('Wallet'),
            'cash' => trans('Cash'),


            default => ucwords(str_replace('_', ' ', $gateway)),
        };
    }


}
