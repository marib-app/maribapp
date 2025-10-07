<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\SheinOrderBatch;
use App\Services\ResponseService;
use App\Services\SheinOrderBatchReportService;
use App\Services\SheinOrderBatchService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class SheinOrderBatchController extends Controller
{
    public function __construct(private readonly SheinOrderBatchService $batchService)
    {
    }

    public function index(Request $request): View
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-list']);

        $batches = SheinOrderBatch::query()
            ->withCount('orders')
            ->withSum('orders as total_final_amount', 'final_amount')
            ->withSum('orders as total_collected_amount', 'delivery_collected_amount')
            ->orderByDesc('created_at')
            ->paginate(15)
            ->withQueryString();

        return view('orders.shein_batches.index', [
            'batches' => $batches,
        ]);
    }

    public function create(): View
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-update']);

        return view('orders.shein_batches.create', [
            'statuses' => SheinOrderBatch::statuses(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-update']);

        $data = $request->validate([
            'reference' => ['required', 'string', 'max:191', 'unique:shein_order_batches,reference'],
            'batch_date' => ['nullable', 'date'],
            'status' => ['required', Rule::in(SheinOrderBatch::statuses())],
            'deposit_amount' => ['nullable', 'numeric', 'min:0'],
            'outstanding_amount' => ['nullable', 'numeric'],
            'notes' => ['nullable', 'string'],
            'closed_at' => ['nullable', 'date'],
        ]);

        $batch = $this->batchService->createBatch($data, $request->user()->id);

        return redirect()
            ->route('item.shein.batches.show', $batch)
            ->with('success', __('تم إنشاء الدفعة بنجاح.'));
    }

    public function show(Request $request, SheinOrderBatch $batch): View
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-list']);

        $orders = $batch->orders()
            ->with('user:id,name')
            ->orderByDesc('created_at')
            ->paginate(25)
            ->withQueryString();

        $availableOrders = Order::query()
            ->whereNull('shein_batch_id')
            ->where('department', 'shein')
            ->orderByDesc('created_at')
            ->limit(50)
            ->get(['id', 'order_number', 'final_amount', 'user_id']);

        $availableOrders->loadMissing('user:id,name');

        return view('orders.shein_batches.show', [
            'batch' => $batch,
            'orders' => $orders,
            'availableOrders' => $availableOrders,
            'orderStatuses' => Order::statusValues(),
            'statusLabels' => Order::statusDisplayMap(),
        ]);
    }

    public function update(Request $request, SheinOrderBatch $batch): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-update']);

        $data = $request->validate([
            'batch_date' => ['nullable', 'date'],
            'status' => ['required', Rule::in(SheinOrderBatch::statuses())],
            'deposit_amount' => ['nullable', 'numeric', 'min:0'],
            'outstanding_amount' => ['nullable', 'numeric'],
            'notes' => ['nullable', 'string'],
            'closed_at' => ['nullable', 'date'],
        ]);

        $batch->update($data);

        return redirect()
            ->route('item.shein.batches.show', $batch)
            ->with('success', __('تم تحديث بيانات الدفعة بنجاح.'));
    }

    public function assignOrders(Request $request, SheinOrderBatch $batch): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-update']);

        $data = $request->validate([
            'order_ids' => ['required', 'array'],
            'order_ids.*' => ['integer', 'exists:orders,id'],
        ]);

        $updated = $this->batchService->assignOrders($batch, $data['order_ids']);

        return redirect()
            ->route('item.shein.batches.show', $batch)
            ->with('success', __('تمت إضافة :count طلب(ات) إلى الدفعة.', ['count' => $updated]));
    }

    public function bulkUpdate(Request $request, SheinOrderBatch $batch): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-update']);

        $data = $request->validate([
            'order_ids' => ['required', 'array'],
            'order_ids.*' => ['integer', 'exists:orders,id'],
            'order_status' => ['nullable', Rule::in(Order::statusValues())],
            'notes' => ['nullable', 'string'],
            'comment' => ['nullable', 'string'],
            'notify_customer' => ['nullable', 'boolean'],
        ]);

        $updated = $this->batchService->bulkUpdateOrders(
            $batch,
            $data['order_ids'],
            $data,
            $request->user()->id,
            (bool) ($data['notify_customer'] ?? false)
        );

        return redirect()
            ->route('item.shein.batches.show', $batch)
            ->with('success', __('تم تحديث :count طلب(ات) داخل الدفعة.', ['count' => $updated]));
    }

    public function report(SheinOrderBatchReportService $reportService): View
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-orders-list']);

        $summaries = $reportService->summaries();

        $totals = [
            'deposit' => $summaries->sum('deposit_amount'),
            'outstanding' => $summaries->sum('outstanding_amount'),
            'collected' => $summaries->sum('total_collected_amount'),
        ];

        return view('orders.shein_batches.report', [
            'summaries' => $summaries,
            'totals' => $totals,
        ]);
    }
}