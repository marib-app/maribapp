<?php

namespace App\Http\Controllers;

use App\Models\Category;
use App\Models\ManualPaymentRequest;
use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Queries\PaymentRequestTableQuery;
use App\Support\ManualPayments\ManualPaymentPresentationHelpers;
use App\Models\UserPurchasedPackage;
use App\Services\BootstrapTableService;
use App\Support\Currency;
use App\Services\CachingService;
use App\Services\FileService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Collection;
use App\Support\Payments\PaymentLabelService;
use Throwable;

class PackageController extends Controller {


    use ManualPaymentPresentationHelpers;


    private string $uploadFolder;

    public function __construct() {
        $this->uploadFolder = 'packages';
    }

    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['item-listing-package-list', 'item-listing-package-create', 'item-listing-package-update', 'item-listing-package-delete']);
        $category = Category::select(['id', 'name'])->where('status', 1)->get();
        $currencySymbolSetting = CachingService::getSystemSettings('currency_symbol');
        $currencyCodeSetting = CachingService::getSystemSettings('currency_code');
        $currency_symbol = Currency::preferredSymbol($currencySymbolSetting, $currencyCodeSetting ?: config('app.currency'));
        
        return view('packages.item-listing', compact('category', 'currency_symbol'));
    }

    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('item-listing-package-create');
        $validator = Validator::make($request->all(), [
            'name'                   => 'required',
            'price'                  => 'required|numeric',
            'discount_in_percentage' => 'required|numeric',
            'final_price'            => 'required|numeric',
            'duration_type'          => 'required|in:limited,unlimited',
            'duration'               => 'required_if:duration_type,limited',
            'item_limit_type'        => 'required|in:limited,unlimited',
            'item_limit'             => 'required_if:limit_type,limited',
            'icon'                   => 'required|mimes:jpeg,jpg,png|max:2048',
            'description'            => 'required',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $data = [
                ...$request->all(),
                'duration'   => ($request->duration_type == "limited") ? $request->duration : "unlimited",
                'item_limit' => ($request->item_limit_type == "limited") ? $request->item_limit : "unlimited",
                'type'       => 'item_listing'
            ];
            if ($request->hasFile('icon')) {
                $data['icon'] = FileService::compressAndUpload($request->file('icon'), $this->uploadFolder);
            }
            Package::create($data);
            ResponseService::successResponse('Package Successfully Added', $data);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "PackageController -> store method");
            ResponseService::errorResponse();
        }

    }

    public function show(Request $request) {
        ResponseService::noPermissionThenSendJson('item-listing-package-list');
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'DESC';

        $sql = Package::where('type', 'item_listing');
        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }
        $total = $sql->count();
        $sql->orderBy($sort, $order)->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        foreach ($result as $key => $row) {
            $tempRow = $row->toArray();
            if (Auth::user()->can('item-listing-package-update')) {
                $tempRow['operate'] = BootstrapTableService::editButton(route('package.update', $row->id), true);
            }
            $rows[] = $tempRow;
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);
    }

    public function update(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('item-listing-package-update');
        $validator = Validator::make($request->all(), [
            'name'                   => 'required',
            'price'                  => 'required|numeric',
            'discount_in_percentage' => 'required|numeric',
            'final_price'            => 'required|numeric',
            'duration_type'          => 'required|in:limited,unlimited',
            'duration'               => 'required_if:duration_type,limited',
            'item_limit_type'        => 'required|in:limited,unlimited',
            'item_limit'             => 'required_if:limit_type,limited',
            'icon'                   => 'nullable|mimes:jpeg,jpg,png|max:2048',
            'description'            => 'required',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $package = Package::findOrFail($id);

            $data = [
                //Type should not be updated
                ...$request->except('type'),
                'duration'   => ($request->duration_type == "limited") ? $request->duration : "unlimited",
                'item_limit' => ($request->item_limit_type == "limited") ? $request->item_limit : "unlimited"
            ];

            if ($request->hasFile('icon')) {
                $data['icon'] = FileService::compressAndReplace($request->file('icon'), $this->uploadFolder, $package->getRawOriginal('icon'));
            }

            $package->update($data);

            ResponseService::successResponse("Package Successfully Update");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "PackageController ->  update");
            ResponseService::errorResponse();
        }
    }

    /* Advertisement Package */
    public function advertisementIndex() {
        ResponseService::noAnyPermissionThenRedirect(['advertisement-package-list', 'advertisement-package-create', 'advertisement-package-update', 'advertisement-package-delete']);
        $category = Category::select(['id', 'name'])->where('status', 1)->get();
        $currencySymbolSetting = CachingService::getSystemSettings('currency_symbol');
        $currencyCodeSetting = CachingService::getSystemSettings('currency_code');
        $currency_symbol = Currency::preferredSymbol($currencySymbolSetting, $currencyCodeSetting ?: config('app.currency'));
        
        return view('packages.advertisement', compact('category', 'currency_symbol'));
    }

    public function advertisementShow(Request $request) {
        ResponseService::noPermissionThenSendJson('advertisement-package-list');
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'DESC';

        $sql = Package::where('type', 'advertisement');
        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }
        $total = $sql->count();
        $sql->orderBy($sort, $order)->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        foreach ($result as $key => $row) {
            $tempRow = $row->toArray();
            $operate = '';
//            $operate = '&nbsp;&nbsp;<a  id="' . $row->id . '"  class="btn icon btn-primary btn-sm rounded-pill mt-2 edit_btn editdata"  data-bs-toggle="modal" data-bs-target="#editModal"   title="Edit"><i class="fa fa-edit edit_icon"></i></a>';
            if (Auth::user()->can('advertisement-package-update')) {
                $operate .= BootstrapTableService::editButton(route('package.advertisement.update', $row->id), true);
            }

            $tempRow['operate'] = $operate;
            $rows[] = $tempRow;
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);
    }

    public function advertisementStore(Request $request) {
        ResponseService::noPermissionThenSendJson('advertisement-package-create');
        $validator = Validator::make($request->all(), [
            'name'                   => 'required',
            'price'                  => 'required|numeric',
            'discount_in_percentage' => 'required|numeric',
            'final_price'            => 'required|numeric',
            'duration'               => 'nullable',
            'item_limit'             => 'nullable',
            'icon'                   => 'required|mimes:jpeg,jpg,png|max:2048',
            'description'            => 'required',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $data = [
                ...$request->all(),
                'duration'   => !empty($request->duration) ? $request->duration : "unlimited",
                'item_limit' => !empty($request->item_limit) ? $request->item_limit : "unlimited",
                'type'       => 'advertisement'
            ];
            if ($request->hasFile('icon')) {
                $data['icon'] = FileService::compressAndUpload($request->file('icon'), $this->uploadFolder);
            }
            Package::create($data);
            ResponseService::successResponse('Package Successfully Added');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "PackageController -> store method");
            ResponseService::errorResponse();
        }
    }


    public function advertisementUpdate(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('advertisement-package-update');
        $validator = Validator::make($request->all(), [
            'name'                   => 'nullable',
            'price'                  => 'required|numeric',
            'discount_in_percentage' => 'required|numeric',
            'final_price'            => 'required|numeric',
            'duration'               => 'nullable',
            'item_limit'             => 'nullable',
            'icon'                   => 'nullable|mimes:jpeg,jpg,png|max:2048',
            'description'            => 'nullable',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $package = Package::findOrFail($id);

            $data = [
                //Type should not be updated
                ...$request->except('type'),
                'duration'   => !empty($request->duration) ? $request->duration : "unlimited",
                'item_limit' => !empty($request->item_limit) ? $request->item_limit : "unlimited"
            ];

            if ($request->hasFile('icon')) {
                $data['icon'] = FileService::compressAndReplace($request->file('icon'), $this->uploadFolder, $package->getRawOriginal('icon'));
            }
            $package->update($data);

            ResponseService::successResponse("Package Successfully Update");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "PackageController ->  update");
            ResponseService::errorResponse();
        }
    }

    public function userPackagesIndex() {
        ResponseService::noPermissionThenRedirect('user-package-list');
        return view('packages.user');
    }

    public function userPackagesShow(Request $request) {
        ResponseService::noPermissionThenSendJson('payment-transactions-list');
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'DESC';

        $sql = UserPurchasedPackage::with('user:id,name', 'package:id,name');
        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }
        $total = $sql->count();
        $sql->orderBy($sort, $order)->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        foreach ($result as $key => $row) {
            $rows[] = $row->toArray();
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);
    }

    public function paymentTransactionIndex() {
        ResponseService::noPermissionThenRedirect('payment-transactions-list');
        return view('packages.payment-transactions');
    }

    public function paymentTransactionShow(Request $request) {
        ResponseService::noPermissionThenSendJson('user-package-list');
        $offset = max((int) ($request->offset ?? 0), 0);
        $limit = (int) ($request->limit ?? 10);
        $limit = $limit > 0 ? $limit : 10;

        $sort = (string) ($request->sort ?? 'id');
        $order = strtolower((string) ($request->order ?? 'desc'));
        $order = in_array($order, ['asc', 'desc'], true) ? $order : 'desc';

        $sortableColumns = [
            'id'                    => 'payment_transaction_id',
            'payment_status'        => 'status_group',
            'status_group'          => 'status_group',
            'created_at'            => 'created_at',
            'amount'                => 'amount',
            'gateway_label'         => 'gateway_label',
            'normalized_channel'    => 'channel',
            'normalized_channel_label' => 'channel',
        ];

        $sortColumn = $sortableColumns[$sort] ?? 'created_at';

        $baseQuery = DB::query()
            ->fromSub(PaymentRequestTableQuery::make(), 'requests')
            ->where('category', 'packages');

        $search = trim((string) ($request->search ?? ''));

        if ($search !== '') {
            $like = '%' . $search . '%';
            $baseQuery->where(function ($query) use ($like) {
                $query->where('reference', 'LIKE', $like)
                    ->orWhere('payment_transaction_id', 'LIKE', $like)
                    ->orWhere('manual_payment_request_id', 'LIKE', $like)
                    ->orWhere('wallet_transaction_id', 'LIKE', $like)
                    ->orWhere('user_name', 'LIKE', $like)
                    ->orWhere('user_mobile', 'LIKE', $like)
                    ->orWhere('gateway_label', 'LIKE', $like)
                    ->orWhere('manual_bank_name', 'LIKE', $like);
            });
        }
        $total = (clone $baseQuery)->count();

        $recordsQuery = (clone $baseQuery);

        $orderDirection = strtoupper($order);

        if ($sort === 'id') {
            $recordsQuery->orderByRaw('COALESCE(payment_transaction_id, manual_payment_request_id, wallet_transaction_id, 0) ' . $orderDirection);
        } else {
            $recordsQuery->orderBy($sortColumn, $orderDirection === 'ASC' ? 'asc' : 'desc');
        }

        $records = $recordsQuery
            ->skip($offset)
            ->take($limit)
            ->get();

        $transactionIds = $records->pluck('payment_transaction_id')
            ->filter(static fn ($id) => $id !== null && $id !== '')
            ->map(static fn ($id) => is_numeric($id) ? (int) $id : null)
            ->filter()
            ->unique()
            ->values();

        $manualRequestIds = $records->pluck('manual_payment_request_id')
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

        $manualRequests = $manualRequestIds->isEmpty()
            ? collect()
            : ManualPaymentRequest::query()
                ->with(['manualBank'])
                ->whereIn('id', $manualRequestIds)
                ->get()
                ->keyBy('id');

        $rows = $records->map(function ($row) use ($transactions, $manualRequests) {
            return $this->formatPaymentTransactionRow((array) $row, $transactions, $manualRequests);


        })->all();

        return response()->json([
            'total' => $total,
            'rows'  => $rows,
        ]);
    }

    private function formatPaymentTransactionRow(array $row, Collection $transactions, Collection $manualRequests): array
    {
        $rawChannel = $row['channel'] ?? null;
        $gatewayKey = $row['gateway_key'] ?? null;
        $normalizedChannel = $this->normalizePaymentRequestChannel($rawChannel)
            ?? $this->normalizePaymentRequestChannel($gatewayKey)
            ?? 'manual_banks';
        $channel = $rawChannel ?? $gatewayKey ?? $normalizedChannel;

        $transactionId = isset($row['payment_transaction_id']) && is_numeric($row['payment_transaction_id'])
            ? (int) $row['payment_transaction_id']

            : null;

        $manualRequestId = isset($row['manual_payment_request_id']) && is_numeric($row['manual_payment_request_id'])
            ? (int) $row['manual_payment_request_id']
            : null;

        $transaction = $transactionId !== null ? $transactions->get($transactionId) : null;
        $manualRequest = $manualRequestId !== null ? $manualRequests->get($manualRequestId) : null;

        if ($transaction instanceof PaymentTransaction) {
            $transaction->loadMissing(['manualPaymentRequest.manualBank']);
        }

        if ($manualRequest instanceof ManualPaymentRequest) {
            $manualRequest->loadMissing('manualBank');
        }

        if ($transaction instanceof PaymentTransaction) {
            $labels = PaymentLabelService::forPaymentTransaction($transaction);
        } elseif ($manualRequest instanceof ManualPaymentRequest) {
            $labels = PaymentLabelService::forManualPaymentRequest($manualRequest);
        } else {
            $labels = [
                'gateway_key' => $row['gateway_key'] ?? null,
                'gateway_label' => $row['gateway_label'] ?? null,
                'bank_name' => $row['manual_bank_name'] ?? null,
                'channel_label' => $row['gateway_label'] ?? null,
                'bank_label' => $row['manual_bank_name'] ?? null,
            ];
        }

        $gatewayLabel = $labels['gateway_label'];
        $bankLabel = $labels['bank_name'];
        $gatewayKey = $labels['gateway_key'] ?? ($row['gateway_key'] ?? null);

        $manualBankName = $gatewayLabel === trans('المحفظة') ? null : $bankLabel;



        $createdAt = $this->parseDateOrNull($row['created_at'] ?? null);
        $formattedCreatedAt = $createdAt?->format('d-m-y H:i:s');
        $updatedAt = $this->parseDateOrNull($row['updated_at'] ?? null);
        $formattedUpdatedAt = $updatedAt?->format('d-m-y H:i:s');

        $amount = $row['amount'] ?? null;

        $id = $row['payment_transaction_id']
            ?? $row['manual_payment_request_id']
            ?? $row['wallet_transaction_id']
            ?? $row['row_key']
            ?? null;

        return [
            'id'                         => $id,
            'row_key'                    => $row['row_key'] ?? null,
            'payment_transaction_id'     => $row['payment_transaction_id'] ?? null,
            'wallet_transaction_id'      => $row['wallet_transaction_id'] ?? null,
            'manual_payment_request_id'  => $row['manual_payment_request_id'] ?? null,
            'user_id'                    => $row['user_id'] ?? null,
            'amount'                     => $amount,
            'currency'                   => $row['currency'] ?? null,
            'reference'                  => $row['reference'] ?? null,
            'payment_status'             => $row['status_group'] ?? null,
            'status_group'               => $row['status_group'] ?? null,
            'gateway_key'                => $gatewayKey,
            'gateway_label'              => $gatewayLabel,
            'gateway_name'               => $row['gateway_name'] ?? null,
            'payment_gateway'            => $gatewayLabel,
            'channel_label'              => $gatewayLabel,
            'manual_bank_name'           => $manualBankName,
            'bank_label'                 => $bankLabel,
            'bank_name'                  => $bankLabel,
            'manual_bank_id'             => $row['manual_bank_id'] ?? null,
            'normalized_channel'         => $normalizedChannel,
            'normalized_channel_label'   => $this->paymentRequestChannelLabel($normalizedChannel),
            'channel'                    => $channel,
            'category'                   => $row['category'] ?? null,
            'department'                 => $row['department'] ?? null,
            'user'                       => [
                'name' => $row['user_name'] ?? '',
            ],
            'user_name'                  => $row['user_name'] ?? null,
            'user_mobile'                => $row['user_mobile'] ?? null,
            'created_at'                 => $formattedCreatedAt,
            'created_at_raw'             => $createdAt?->toDateTimeString(),
            'updated_at'                 => $formattedUpdatedAt,
            'updated_at_raw'             => $updatedAt?->toDateTimeString(),
            'source'                     => $row['source'] ?? null,
        ];
        
    }
}
