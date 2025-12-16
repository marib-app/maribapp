<?php

namespace App\Http\Controllers;

use App\Models\Item;
use App\Models\ReportReason;
use App\Models\User;
use App\Models\UserReports;
use App\Services\BootstrapTableService;
use App\Services\DepartmentReportService;

use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use JsonException;

use Throwable;

class ReportReasonController extends Controller {

    public function __construct(private DepartmentReportService $departmentReportService)
    {
    }


    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['report-reason-list', 'report-reason-create', 'report-reason-update', 'report-reason-delete']);
        return view('reports.user_feedback');
    }

    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('report-reason-create');
        $validator = Validator::make($request->all(), [
            'reason' => 'required'
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            ReportReason::create($request->all());
            ResponseService::successResponse('Reason Successfully Added');

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "ReportReason Controller -> store");
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function show(Request $request) {
        ResponseService::noPermissionThenSendJson('report-reason-list');
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'DESC';
        $sql = ReportReason::orderBy($sort, $order);
        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }

        $total = $sql->count();
        $sql->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        $no = 1;
        foreach ($result as $key => $row) {
            $tempRow = $row->toArray();
            $tempRow['no'] = $no++;
            $operate = '';
            if (Auth::user()->can('report-reason-update')) {
                $operate .= BootstrapTableService::editButton(route('report-reasons.update', $row->id), true,'#editModal', 'reportReasonEvents', $row->id);
            }

            if (Auth::user()->can('report-reason-delete')) {
                $operate .= BootstrapTableService::deleteButton(route('report-reasons.destroy', $row->id));
            }
            $tempRow['operate'] = $operate;
            $rows[] = $tempRow;
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);
    }

    public function update(Request $request, $id) {
        try {
            ResponseService::noPermissionThenSendJson('report-reason-update');
            ReportReason::findOrFail($id)->update($request->all());
            ResponseService::successResponse('Reason Successfully Updated');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "ReportReason Controller -> store");
            ResponseService::errorResponse('Something Went Wrong');
        }

    }

    public function destroy($id) {
        try {
            ResponseService::noPermissionThenSendJson('report-reason-delete');
            ReportReason::findOrFail($id)->delete();
            ResponseService::successResponse('Reason Deleted Successfully');
        } catch (Throwable) {
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function usersReports() {
        ResponseService::noPermissionThenRedirect('user-reports-list');
        $users = User::select(["id", "name"])->has('user_reports')->get();
        $items = Item::select(["id", "name"])->approved()->has('user_reports')->get();

        $departments = $this->departmentReportService->availableDepartments();

        return view('reports.user_reports', compact('users', 'items', 'departments'));

    }

    public function userReportsShow(Request $request) {
        try {
            ResponseService::noPermissionThenRedirect('user-reports-list');
            $offset = $request->offset ?? 0;
            $limit = $request->limit ?? 10;
            $sort = $request->sort ?? 'id';
            $order = $request->order ?? 'DESC';
            $departments = $this->departmentReportService->availableDepartments();


            $sql = UserReports::with(['user' => fn($q) => $q->select(['id', 'name', 'deleted_at'])->withTrashed(), 'report_reason:id,reason', 'item' => fn($q) => $q->select(['id', 'name', 'deleted_at'])->withTrashed()])->sort($sort, $order);

            if (!empty($request->search)) {
                $sql = $sql->search($request->search);
            }

            if (!empty($request->department)) {
                $sql = $sql->department($request->department);
            }


            if (!empty($request->filter)) {
                try {
                    $filterObject = json_decode($request->filter, false, 512, JSON_THROW_ON_ERROR);
                } catch (JsonException) {
                    $filterObject = null;
                }

                if (!empty($filterObject)) {
                    $sql = $sql->filter($filterObject);
                }
            
            }
            $total = $sql->count();
            $sql->skip($offset)->take($limit);
            $res = $sql->get();
            $bulkData = array();
            $bulkData['total'] = $total;
            $rows = [];
        foreach ($res as $row) {
            $user = $row->user;
            $item = $row->item;
            $reportReason = $row->report_reason;

            $tempRow = $row->toArray();

            $tempRow['user'] = [
                'id' => $user?->id ?? $row->user_id,
                'name' => $user?->name ?? __('User #:id (deleted)', ['id' => $row->user_id]),
            ];

            $tempRow['item'] = [
                'id' => $item?->id ?? $row->item_id,
                'name' => $item?->name ?? __('Item #:id (deleted)', ['id' => $row->item_id]),
            ];

            $tempRow['user_status'] = $user?->deleted_at === null && $user !== null;
            $tempRow['item_status'] = $item?->deleted_at === null && $item !== null;

            $tempRow['reason'] = $reportReason?->reason
                ?? ($row->other_message ?: $row->reason ?: __('N/A'));

            $tempRow['details'] = $row->other_message;
            $tempRow['department_label'] = $departments[$row->department] ?? $row->department;
            $tempRow['reported_at'] = optional($row->created_at)->format('Y-m-d H:i:s');


            $rows[] = $tempRow;
        }

            $bulkData['rows'] = $rows;
            return response()->json($bulkData);

        } catch (Throwable $e) {
            ResponseService::logErrorResponse($e, "ReportReason Controller -> show");
            ResponseService::errorResponse();
        }
    }
}
