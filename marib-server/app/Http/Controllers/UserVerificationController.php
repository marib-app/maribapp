<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\UserFcmToken;
use App\Models\VerificationField;
use App\Models\VerificationFieldValue;
use App\Models\VerificationPayment;
use App\Models\VerificationPlan;
use App\Models\VerificationRequest;
use App\Models\Notifications;
use App\Services\BootstrapTableService;
use App\Services\FileService;
use App\Services\NotificationService;
use App\Services\NotificationDispatchService;
use App\Data\Notifications\NotificationIntent;
use App\Enums\NotificationType;
use App\Models\NotificationDelivery;
use App\Services\NotificationInboxService;
use App\Services\ResponseService;
use Illuminate\Support\Facades\Log;

use Auth;
use DB;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Storage;
use Throwable;
use Validator;

class UserVerificationController extends Controller {
    private string $uploadFolder;

    public function __construct() {
        $this->uploadFolder = 'seller_verification';
    }

    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['seller-verification-field-list', 'seller-verification-field-create', 'seller-verification-field-update', 'seller-verification-field-delete']);
        $verificationRequests = VerificationRequest::with('verification_field_values', 'user');
        return view('seller-verification.index', compact('verificationRequests'));
    }

    public function verificationField() {
        return redirect()->route('seller-verification.dashboard', ['tab' => 'fields']);
    }

    public function dashboard() {
        ResponseService::noAnyPermissionThenRedirect(['seller-verification-field-list', 'seller-verification-field-create', 'seller-verification-field-update', 'seller-verification-field-delete']);
        $plans = VerificationPlan::orderByDesc('created_at')->get();
        return view('seller-verification.dashboard', compact('plans'));
    }

    public function create() {
        ResponseService::noPermissionThenRedirect('seller-verification-field-create');
        return view('seller-verification.create');
    }

    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('seller-verification-field-create');
        $validator = Validator::make($request->all(), [
            'name'        => 'required',
            'type'        => 'required|in:number,textbox,fileinput,radio,dropdown,checkbox',
            'status'      => 'nullable',
            'is_verified' => 'nullable|boolean',
            'active'      => 'nullable',
            'values'      => 'required_if:type,radio,dropdown,checkbox|array',
            'min_length'  => 'required_if:number,textbox',
            'max_length'  => 'required_if:number,textbox',
            'account_type'=> 'required|in:individual,commercial,realestate',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            DB::beginTransaction();
            $data = [
                ...$request->all(),
                'image' => $request->hasFile('image') ? FileService::compressAndUpload($request->file('image'), $this->uploadFolder) : '',
            ];

            if (in_array($request->type, ["dropdown", "radio", "checkbox"])) {
                $data['values'] = json_encode($request->values, JSON_THROW_ON_ERROR);
            }
            if ($request->status == 0) {
                $data['deleted_at'] = now();
            }

            VerificationField::create($data);

            DB::commit();
            ResponseService::successResponse('Custom Field Added Successfully');
        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th);
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function show(Request $request) {
        try {
            ResponseService::noPermissionThenSendJson('seller-verification-request-list');

            $offset = $request->input('offset', 0);
            $limit = $request->input('limit', 10);
            $sort = $request->input('sort', 'id');
            $order = $request->input('order', 'DESC');

            $query = VerificationRequest::with('user', 'verification_field_values.verification_field')->orderBy($sort, $order);

            if (!empty($request->filter)) {
                $filters = json_decode($request->filter, true, 512, JSON_THROW_ON_ERROR); // Decode as an associative array
                foreach ($filters as $field => $value) {
                    $query->where($field, $value);
                }
            }

            if (!empty($request->search)) {
                $query->where(function ($q) use ($request) {
                    $q->where('status', 'like', '%' . $request->search . '%')
                        ->orWhereHas('user', function ($q) use ($request) {
                            $q->where('name', 'like', '%' . $request->search . '%');
                        });
                });
            }

            $total = $query->count();
            $result = $query->skip($offset)->take($limit)->get();
            $no = 1;

            $bulkData = [
                'total' => $total,
                'rows'  => []
            ];

            $verificationFieldValues = VerificationFieldValue::whereIn('verification_request_id', $result->pluck('id'))
                ->with('verification_field')
                ->get();
            foreach ($result as $row) {
                $row->verification_fields = collect($row->verification_fields)->map(function ($verification_field) use ($verificationFieldValues, $row) {
                    $fieldValue = $verificationFieldValues->first(function ($data) use ($row, $verification_field) {
                        return $data->verification_field_id == $verification_field->id
                            && $data->verification_request_id == $row->id;
                    });

                    $verification_field['value'] = $fieldValue ? $fieldValue->value : null;

                    if ($verification_field->type == "fileinput" && !empty($verification_field['value'])) {
                        if (!is_array($verification_field->value)) {
                            $verification_field['value'] = [url(Storage::url($verification_field->value))];
                        } else {
                            /*NOTE : Why 123 is given here*/
                            $verification_field['value'] = ['123'];
                        }
                    }
                    return $verification_field;
                });

                $operate = '';

                if (Auth::user()->can('verification_requests-update')) {
                    $operate .= BootstrapTableService::editButton(route('seller_verification.approval', $row->id), true, '#editStatusModal', 'edit-status', $row->id);
                    $operate .= BootstrapTableService::button('fa fa-eye', '#', ['view-verification-fields', 'btn-light-danger  '], ['title' => __("View"), "data-bs-target" => "#editModal", "data-bs-toggle" => "modal",]);
                }
                $tempRow = $row->toArray();
                $tempRow['no'] = $no++;
                $tempRow['operate'] = $operate;
                $tempRow['user_name'] = $row->user->name ?? '';
                $tempRow['verification_field_values'] = $verificationFieldValues
                    ->where('verification_request_id', $row->id)
                    ->values()
                    ->map(static function (VerificationFieldValue $value) {
                        $displayValue = $value->value;
                        $type = $value->verification_field->type ?? null;
                        if ($type === 'fileinput' && !empty($displayValue)) {
                            if (!is_array($displayValue)) {
                                $displayValue = [url(Storage::url($displayValue))];
                            }
                        }
                        return [
                            'verification_field' => [
                                'name' => $value->verification_field->name ?? '',
                            ],
                            'value' => $displayValue,
                        ];
                    });
                $bulkData['rows'][] = $tempRow;
            }
            return response()->json($bulkData);
        } catch (Throwable $e) {
            ResponseService::logErrorResponse($e, "Controller -> show");
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function payments(Request $request) {
        try {
            ResponseService::noPermissionThenSendJson('seller-verification-request-list');

            $offset = (int) $request->input('offset', 0);
            $limit = (int) $request->input('limit', 10);
            $sort = $request->input('sort', 'id');
            $order = $request->input('order', 'DESC');

            $query = VerificationPayment::with(['user', 'plan', 'request'])->orderBy($sort, $order);

            if (!empty($request->search)) {
                $search = $request->search;
                $query->where(function ($q) use ($search) {
                    $q->where('status', 'like', "%{$search}%")
                        ->orWhereHas('user', static function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', "%{$search}%")
                                ->orWhere('email', 'like', "%{$search}%");
                        });
                });
            }

            $total = $query->count();
            $rows = $query->skip($offset)->take($limit)->get();

            $bulkData = [
                'total' => $total,
                'rows'  => [],
            ];

                foreach ($rows as $row) {
                    $bulkData['rows'][] = [
                        'id' => $row->id,
                        'user_name' => $row->user->name ?? '',
                        'status' => $row->status,
                        'amount' => number_format((float) $row->amount, 2) . ' ' . $row->currency,
                        'currency' => $row->currency,
                        'gateway' => data_get($row->meta, 'gateway') ?? data_get($row->meta, 'payment_gateway') ?? '-',
                        'payment_transaction_id' => data_get($row->meta, 'payment_transaction_id'),
                        'plan' => $row->plan->name ?? '-',
                        'expires_at' => optional($row->expires_at)->toDateString(),
                        'created_at' => optional($row->created_at)->toDateTimeString(),
                ];
            }

            return response()->json($bulkData);
        } catch (Throwable $e) {
            ResponseService::logErrorResponse($e, 'UserVerificationController -> payments');
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function requestDetails($id) {
        ResponseService::noAnyPermissionThenRedirect(['seller-verification-request-list','seller-verification-request-update']);

        $request = VerificationRequest::with([
            'user',
            'verification_field_values.verification_field',
        ])->findOrFail($id);

        $payments = VerificationPayment::with('plan')
            ->where('verification_request_id', $id)
            ->orderByDesc('created_at')
            ->get();

        return view('seller-verification.show', [
            'verification' => $request,
            'payments' => $payments,
        ]);
    }

    public function verifiedAccounts(Request $request) {
        try {
            ResponseService::noPermissionThenSendJson('seller-verification-request-list');

            $offset = (int) $request->input('offset', 0);
            $limit = (int) $request->input('limit', 10);
            $search = $request->input('search', '');

            // ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ¬ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ¨ ط·آ·ط¢آ·ط·آ¢ط¢آ¢ط·آ·ط¢آ·ط·آ¢ط¢آ®ط·آ·ط¢آ·ط·آ¢ط¢آ± ط·آ·ط¢آ·ط·آ¢ط¢آ·ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ¨ ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ·ط·آ¢ط¢آ«ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€ک ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط·آ¦أ¢â‚¬â„¢ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع† ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ·ط·آ¢ط¢آ³ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ®ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦
            $requests = VerificationRequest::with('user')
                ->where('status', 'approved')
                ->when(!empty($search), function ($q) use ($search) {
                    $q->whereHas('user', function ($uq) use ($search) {
                        $uq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('mobile', 'like', "%{$search}%");
                    });
                })
                ->orderByDesc('approved_at')
                ->get()
                ->groupBy('user_id')
                ->map(function ($items) {
                    return $items->first(); // ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ£ط·آ·ط¢آ·ط·آ¢ط¢آ­ط·آ·ط¢آ·ط·آ¢ط¢آ¯ط·آ·ط¢آ·ط·آ¢ط¢آ«
                })
                ->values();

            $total = $requests->count();
            $slice = $requests->slice($offset, $limit);

            $rows = $slice->map(static function (VerificationRequest $req) {
                $user = $req->user;
                $expiresAt = $req->expires_at ? Carbon::parse($req->expires_at) : null;
                $remaining = $expiresAt ? $expiresAt->diffInDays(now(), false) * -1 : null;
                $statusType = 'success';
                $labelText = __('ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط·آ«أ¢â‚¬آ ط·آ·ط¢آ·ط·آ¢ط¢آ«ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€ک');
                if ($remaining !== null) {
                    if ($remaining < 0) {
                        $statusType = 'danger';
                        $labelText = __('ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ¦ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط·إ’ط·آ·ط¢آ¸ط·آ¸ط¢آ¹');
                    } elseif ($remaining <= 7) {
                        $statusType = 'warning';
                        $labelText = __('ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¹â€کط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ¨ ط·آ·ط¢آ·ط·آ¢ط¢آ¹ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ° ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط¢آ ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬ط·إ’ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ·ط¥â€™');
                    }
                }

                $statusBadge = sprintf(
                    '<span class="badge bg-%s">%s</span>',
                    $statusType,
                    e($labelText)
                );

                $actions = sprintf(
                    '<a href="%s" class="btn btn-sm btn-outline-primary">%s</a>',
                    route('seller-verification.request.details', $req->id),
                    __('ط·آ·ط¢آ·ط·آ¢ط¢آ¹ط·آ·ط¢آ·ط·آ¢ط¢آ±ط·آ·ط¢آ·ط·آ¢ط¢آ¶ ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†ط·آ·ط¢آ·ط·آ¹ط¢آ¾ط·آ·ط¢آ¸ط·آ¸ط¢آ¾ط·آ·ط¢آ·ط·آ¢ط¢آ§ط·آ·ط¢آ·ط·آ¢ط¢آµط·آ·ط¢آ¸ط·آ¸ط¢آ¹ط·آ·ط¢آ¸ط£آ¢أ¢â€ڑآ¬أ¢â‚¬ع†')
                );

                return [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'mobile' => $user->mobile,
                    'expires_at' => $expiresAt ? $expiresAt->toDateString() : '-',
                    'status_badge' => $statusBadge,
                    'actions' => $actions,
                ];
            });

            return response()->json([
                'total' => $total,
                'rows' => $rows,
            ]);
        } catch (Throwable $e) {
            ResponseService::logErrorResponse($e, 'UserVerificationController -> verifiedAccounts');
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function storePlan(Request $request) {
        ResponseService::noPermissionThenRedirect('seller-verification-field-create');

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:190',
            'account_type' => 'required|in:individual,commercial,realestate',
            'duration_days' => 'nullable|integer|min:0',
            'price' => 'required|numeric|min:0',
            'currency' => 'required|string|max:10',
            'is_active' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return back()->withErrors($validator)->withInput();
        }

        VerificationPlan::create($validator->validated());

        return redirect()->back()->with('success', __('Plan saved successfully'));
    }

    public function updatePlan(Request $request, VerificationPlan $plan) {
        ResponseService::noPermissionThenRedirect('seller-verification-field-update');

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:190',
            'account_type' => 'required|in:individual,commercial,realestate',
            'duration_days' => 'nullable|integer|min:0',
            'price' => 'required|numeric|min:0',
            'currency' => 'required|string|max:10',
            'is_active' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return back()->withErrors($validator)->withInput();
        }

        $plan->update($validator->validated());

        return redirect()->back()->with('success', __('Plan updated successfully'));
    }

    public function destroyPlan(VerificationPlan $plan) {
        ResponseService::noPermissionThenRedirect('seller-verification-field-delete');
        $plan->delete();
        return redirect()->back()->with('success', __('Plan deleted successfully'));
    }

    public function showVerificationFields(Request $request) {
        try {

            ResponseService::noPermissionThenSendJson('seller-verification-field-list');
            $offset = $request->input('offset', 0);
            $limit = $request->input('limit', 10);
            $sort = $request->input('sort', 'id');
            $order = $request->input('order', 'ASC');

            $sql = VerificationField::orderBy($sort, $order)->withTrashed();

            if ($request->filled('account_type')) {
                $sql->where('account_type', $request->input('account_type'));
            }

            if (!empty($_GET['search'])) {
                $sql->search($_GET['search']);
//            $sql->where('id', 'LIKE', "%$search%")->orwhere('question', 'LIKE', "%$search%")->orwhere('answer', 'LIKE', "%$search%");

            }
            $total = $sql->count();
            $sql->skip($offset)->take($limit);
            $result = $sql->get();
            $bulkData = array();
            $bulkData['total'] = $total;
            $rows = array();
            $accountTypeLabels = [
                'individual' => __('فردي'),
                'commercial' => __('تجاري'),
                'realestate' => __('عقاري'),
            ];
            foreach ($result as $row) {
                $tempRow = $row->toArray();
                $tempRow['account_type_label'] = $accountTypeLabels[$row->account_type] ?? $row->account_type;
                $operate = '';
                if (Auth::user()->can('seller-verification.verification-field.update')) {
                    $operate .= BootstrapTableService::editButton(route('seller-verification.verification-field.edit', $row->id));
                }

                if (Auth::user()->can('verification-field-delete')) {
                    $operate .= BootstrapTableService::deleteButton(route('seller-verification.verification-field.delete', $row->id));
                }
                $tempRow['operate'] = $operate;
                $rows[] = $tempRow;
            }

            $bulkData['rows'] = $rows;
            return response()->json($bulkData);

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "UserVerificationController --> show");
            ResponseService::errorResponse();
        }
    }

    public function edit($id) {
        ResponseService::noPermissionThenRedirect('seller-verification-field-update');
        $verification_field = VerificationField::where('id', $id)->withTrashed()->first();
        return view('seller-verification.edit', compact('verification_field'));
    }

    public function update(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('seller-verification-field-update');
        $validator = Validator::make($request->all(), [
            'name'       => 'required',
            'type'       => 'required|in:number,textbox,fileinput,radio,dropdown,checkbox',
            'values'     => 'required_if:type,radio,dropdown,checkbox|array',
            'min_length' => 'required_if:type,number,textbox',
            'max_length' => 'required_if:type,number,textbox',
            'account_type'=> 'required|in:individual,commercial,realestate',
            'status'     => 'nullable|boolean'
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $verification_field = VerificationField::where('id', $id)->withTrashed()->first();
            $data = $request->all();
            if ($request->status == 0) {
                $data['deleted_at'] = now();
            } elseif ($request->status == 1) {
                $data['deleted_at'] = null;
            }

            $verification_field->update($data);
            ResponseService::successResponse('Verification Field Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "UserVerification Controller -> update");
            ResponseService::errorResponse();
        }
    }

    public function destroy($id) {
        try {
            ResponseService::noPermissionThenSendJson('seller-verification-field-delete');
            VerificationField::withTrashed()->find($id)->forceDelete();
            ResponseService::successResponse('seller Verification delete successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Seller Verification Controller -> destroy");
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function getSellerVerificationValues(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('seller-verification-field-update');
        $values = VerificationField::where('id', $id)->withTrashed()->first()->values;

        if (!empty($request->search)) {
            $matchingElements = [];
            foreach ($values as $element) {
                $stringElement = (string)$element;

                // Check if the search term is present in the element
                if (str_contains($stringElement, $request->search)) {
                    // If found, add it to the matching elements array
                    $matchingElements[] = $element;
                }
            }
            $values = $matchingElements;
        }


        $bulkData = array();
        $bulkData['total'] = count($values);
        $rows = array();
        foreach ($values as $key => $row) {
            $tempRow['id'] = $key;
            $tempRow['value'] = $row;
            // if (Auth::user()->can('faq-update')) {
            //     $operate .= BootstrapTableService::editButton(route('faq.update', $row->id), true, '#editModal', 'faqEvents', $row->id);
            // }
            $tempRow['operate'] = BootstrapTableService::button('fa fa-edit',route('seller-verification.value.update', $id), ['edit_btn'],["title"=>"Edit", "data-bs-target" => '#editModal', "data-bs-toggle" => "modal"]);
            $tempRow['operate'] .= BootstrapTableService::deleteButton(route('seller-verification.value.delete', [$id, $row]), true);
            $rows[] = $tempRow;
        }
        $bulkData['rows'] = $rows;


        return response()->json($bulkData);
    }

    public function addSellerVerificationValue(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('seller-verification-field-create');
        $validator = Validator::make($request->all(), [
            'values' => 'required',
        ]);

        if ($validator->fails()) {
            ResponseService::errorResponse($validator->errors()->first());
        }
        try {
            $verification_field = VerificationField::findOrFail($id);
            $newValues = explode(',', $request->values);
            $values = [
                ...$verification_field->values,
                ...$newValues,
            ];

            $verification_field->values = json_encode($values, JSON_THROW_ON_ERROR);
            $verification_field->save();
            ResponseService::successResponse('Seller Verification Value added Successfully');
        } catch (Throwable) {
            ResponseService::errorResponse('Something Went Wrong ');
        }
    }

    public function updateSellerVerificationValue(Request $request, $id) {
        ResponseService::noPermissionThenSendJson('seller-verification-field-update');
        $validator = Validator::make($request->all(), [
            'old_verification_field_value' => 'required',
            'new_verification_field_value' => 'required',
        ]);

        if ($validator->fails()) {
            ResponseService::errorResponse($validator->errors()->first());
        }
        try {
            $verification_field = VerificationField::where('id', $id)->withTrashed()->first();
            $values = $verification_field->values;
            if (is_array($values)) {
                $values[array_search($request->old_verification_field_value, $values, true)] = $request->new_verification_field_value;
            } else {
                $values = $request->new_verification_field_value;
            }
            $verification_field->values = $values;
            $verification_field->save();
            ResponseService::successResponse('Verification Field Value Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'UserVerificationController -> updateSellerVerificationValue');
            ResponseService::errorResponse('Something Went Wrong ');
        }
    }

    public function deleteSellerVerificationValue($id, $deletedValue) {
        try {
            ResponseService::noPermissionThenSendJson('seller-verification-field-delete');
            $verification_field = VerificationField::where('id', $id)->withTrashed()->first();
            $values = $verification_field->values;
            unset($values[array_search($deletedValue, $values, true)]);
            $verification_field->values = json_encode($values, JSON_THROW_ON_ERROR);
            $verification_field->save();
            ResponseService::successResponse('Seller Verification Value Deleted Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th);
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

            public function updateSellerApproval(Request $request, $id) {
        try {
            ResponseService::noPermissionThenSendJson('seller-verification-field-update');
            $verification = VerificationRequest::with('user')->findOrFail($id);
            $newStatus = $request->input('status');
            $rejectionReason = trim((string) $request->input('rejection_reason', ''));
            $durationDays = (int) $request->input('duration_days', 30);
            $priceValue = $request->input('price', $verification->price);
            $currencyValue = $request->input('currency', $verification->currency ?? 'SAR');

            if ($newStatus === 'rejected' && $rejectionReason === '') {
                $rejectionReason = __('لم يتم ذكر سبب الرفض');
            }

            $expiresAt = $newStatus === 'approved'
                ? Carbon::now()->addDays($durationDays)
                : null;

            $verification->update([
                'status'           => $newStatus,
                'rejection_reason' => $newStatus === 'rejected' ? $rejectionReason : null,
                'approved_at'      => $newStatus === 'approved' ? now() : null,
                'expires_at'       => $expiresAt,
                'duration_days'    => $newStatus === 'approved' ? $durationDays : null,
                'price'            => $newStatus === 'approved' ? $priceValue : null,
                'currency'         => $newStatus === 'approved' ? $currencyValue : null,
            ]);

            $verification->user->update([
                'is_verified' => $newStatus === 'approved' ? 1 : 0,
            ]);

            if ($newStatus === 'approved') {
                VerificationPayment::create([
                    'user_id' => $verification->user->id,
                    'verification_request_id' => $verification->id,
                    'amount' => $priceValue ?? 0,
                    'currency' => $currencyValue,
                    'status' => 'paid',
                    'starts_at' => now(),
                    'expires_at' => $expiresAt,
                    'meta' => [
                        'approved_by' => Auth::id(),
                    ],
                ]);
            }

            $title = 'تنبيه التوثيق';
            $expiresText = $expiresAt
                ? $expiresAt->setTimezone(config('app.timezone', 'Asia/Riyadh'))->format('Y-m-d H:i')
                : '-';
            $priceText = $priceValue !== null ? "{$priceValue} {$currencyValue}" : '-';

            if ($newStatus === 'approved') {
                $body = "تهانياً، تم توثيق حسابك!\n"
                    . "الشارة الآن ظاهرة للمستخدمين.\n"
                    . "سينتهي اشتراك التوثيق في {$expiresText}.\n"
                    . "الرسوم: {$priceText}.";
            } elseif ($newStatus === 'rejected') {
                $reason = $rejectionReason ?: 'لم يتم ذكر سبب';
                $body = "تم رفض طلب التوثيق.\n"
                    . "السبب: {$reason}.\n"
                    . "يمكنك التعديل وإعادة الإرسال.";
            } else {
                $statusLabel = match ($newStatus) {
                    'pending', 'in_review' => 'قيد المراجعة',
                    'expired' => 'منتهي',
                    default => $newStatus,
                };
                $body = "تم تحديث حالة طلب التوثيق إلى {$statusLabel}.";
            }

            $collapseKey = sprintf(
                'verification:%s:%s:%s',
                $verification->id,
                $newStatus,
                now()->timestamp
            );

            $payload = [
                'title' => $title,
                'body' => $body,
                'type' => NotificationType::KycRequest->value,
                'deeplink' => 'marib://settings/notifications?category=account',
                'data' => [
                    'category' => 'account',
                    'type' => 'verification',
                    'request_id' => $verification->id,
                    'status' => $newStatus,
                    'expires_at' => $expiresAt?->toIso8601String(),
                    'price' => $priceValue,
                    'currency' => $currencyValue,
                ],
                'meta' => [
                    'category' => 'account',
                    'type' => 'verification',
                    'request_id' => $verification->id,
                    'status' => $newStatus,
                    'expires_at' => $expiresAt?->toIso8601String(),
                    'price' => $priceValue,
                    'currency' => $currencyValue,
                ],
            ];

            NotificationDelivery::create([
                'user_id' => $verification->user->id,
                'type' => NotificationType::KycRequest->value,
                'deeplink' => $payload['deeplink'],
                'status' => NotificationDelivery::STATUS_SENT,
                'delivered_at' => now(),
                'payload' => $payload,
                'meta' => $payload['meta'],
                'collapse_key' => $collapseKey,
                'priority' => 'high',
                'ttl' => 86400,
            ]);
            app(NotificationInboxService::class)->incrementUnreadCount($verification->user->id);

            try {
                $intent = new NotificationIntent(
                    userId: $verification->user->id,
                    type: NotificationType::KycRequest,
                    title: $title,
                    body: $body,
                    deeplink: $payload['deeplink'],
                    entity: 'verification_request',
                    entityId: $verification->id,
                    data: $payload['data'],
                    meta: $payload['meta'],
                );
                app(NotificationDispatchService::class)->dispatch($intent, true);
            } catch (Throwable $notificationException) {
                Log::warning('UserVerificationController: Failed to dispatch inbox notification', [
                    'error' => $notificationException->getMessage(),
                    'user_id' => $verification->user->id,
                    'request_id' => $verification->id,
                ]);
            }

            try {
                $userTokens = UserFcmToken::where('user_id', $verification->user->id)
                    ->pluck('fcm_token')
                    ->filter()
                    ->values()
                    ->all();

                if (!empty($userTokens)) {
                    $fcmPayload = $payload['data'];

                    $legacyResponse = NotificationService::sendFcmNotification(
                        $userTokens,
                        $title,
                        $body,
                        'verification-request-update',
                        $fcmPayload
                    );

                    if (is_array($legacyResponse) && ($legacyResponse['error'] ?? false)) {
                        Log::error('UserVerificationController: Legacy FCM send failed', $legacyResponse);
                    }
                }
            } catch (Throwable $fcmException) {
                Log::warning('UserVerificationController: Fallback FCM send failed', [
                    'error' => $fcmException->getMessage(),
                    'user_id' => $verification->user->id,
                    'request_id' => $verification->id,
                ]);
            }

            try {
                Notifications::create([
                    'title' => $title,
                    'message' => $body,
                    'image' => '',
                    'item_id' => null,
                    'send_to' => 'selected',
                    'user_id' => (string) $verification->user->id,
                    'category' => 'account',
                    'meta' => [
                        'type' => 'verification',
                        'request_id' => $id,
                        'status' => $newStatus,
                        'expires_at' => $expiresAt?->toIso8601String(),
                        'price' => $priceValue,
                        'currency' => $currencyValue,
                    ],
                ]);
            } catch (Throwable $e) {
                Log::error('UserVerificationController: Failed to persist verification notification', ['error' => $e->getMessage()]);
            }

            if ($request->expectsJson() || $request->ajax()) {
                ResponseService::successResponse('Seller status updated successfully');
            } else {
                return redirect()->back()->with('success', __('Seller status updated successfully'));
            }
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'UserVerificationController -> updateSellerApproval');
            ResponseService::errorResponse(
                $th->getMessage(),
                ['error' => true, 'code' => $th->getCode()],
                $th->getCode() ?: null,
                $th
            );
        }
    }
    public function getVerificationDetails($id) {
        $verificationFieldValues = VerificationFieldValue::with('verification_field')->where('verification_request_id', $id)->get();
        if ($verificationFieldValues->isEmpty()) {
            return response()->json(['error' => 'No details found.'], 404);
        }

        $fieldValues = $verificationFieldValues->map(function ($fieldValue) {
            return [
                'name'  => $fieldValue->verification_field->name ?? 'N/A',
                'value' => $fieldValue->value ?? 'No value provided',
            ];
        });

        return response()->json([
            'verification_field_values' => $fieldValues,
        ]);
    }
}





