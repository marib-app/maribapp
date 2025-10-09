<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderPaymentGroup;
use App\Services\OrderPaymentGroupService;
use App\Services\DepartmentReportService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;
use Throwable;

class OrderPaymentGroupController extends Controller
{
    public function __construct(private readonly OrderPaymentGroupService $groupService)
    {
    }

    public function store(Request $request, Order $order): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:190'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        try {
            $group = $this->groupService->createGroup(
                $validated,
                $request->user()?->getKey(),
                $order
            );
        } catch (Throwable $throwable) {
            Log::error('OrderPaymentGroupController@store failed', [
                'order_id' => $order->getKey(),
                'error' => $throwable->getMessage(),
            ]);

            return redirect()
                ->route('orders.show', $order)
                ->with('error', __('تعذّر إنشاء المجموعة. حاول مرة أخرى لاحقاً.'));
        }

        return redirect()
            ->route('orders.payment-groups.show', $group)
            ->with('success', __('تم إنشاء المجموعة وإضافة الطلب الحالي إليها.'));
    }

    public function show(Request $request, OrderPaymentGroup $group): View
    {
        $group->load([
            'orders' => static function ($query) {
                $query->with([
                    'user:id,name',
                    'items' => static function ($itemQuery) {
                        $itemQuery->select('order_items.id', 'order_items.order_id', 'order_items.quantity');
                    },
                ])
                ->withCount(['openManualPaymentRequests as pending_manual_payment_requests_count'])
                ->select('orders.*');
            },
        ]);

        $orders = $group->orders;
        $ordersCount = $orders->count();
        $totalQuantity = $orders->flatMap(static fn ($order) => $order->items)->sum('quantity');
        $totalAmount = $orders->sum('final_amount');

        $orderStatuses = Order::statusValues();
        $statusLabels = Order::statusDisplayMap();
        $paymentStatusLabels = Order::paymentStatusLabels();

        $availableOrders = $this->groupService->availableSheinOrders($group);

        return view('orders.payments.group', [
            'group' => $group,
            'orders' => $orders,
            'ordersCount' => $ordersCount,
            'totalQuantity' => $totalQuantity,
            'totalAmount' => $totalAmount,
            'orderStatuses' => $orderStatuses,
            'statusLabels' => $statusLabels,
            'paymentStatusLabels' => $paymentStatusLabels,
            'availableOrders' => $availableOrders,
        ]);
    }

    public function addOrders(Request $request, OrderPaymentGroup $group): RedirectResponse
    {
        $validated = $request->validate([
            'order_ids' => ['required', 'array'],
            'order_ids.*' => ['integer', 'exists:orders,id'],
        ]);

        $orderIds = collect($validated['order_ids'])
            ->filter(static fn ($id) => is_numeric($id) && (int) $id > 0)
            ->map(static fn ($id) => (int) $id)
            ->unique()
            ->values();
        $orderIdsArray = $orderIds->all();

        $allowedDepartments = $this->groupService->allowedDepartmentsForGroup($group);
        $departmentService = app(DepartmentReportService::class);
        $departmentLabels = $departmentService->availableDepartments();
        $disallowedOrder = null;

        if ($allowedDepartments !== []) {
            $disallowedOrder = Order::query()
                ->whereIn('id', $orderIdsArray)
                ->where(static function ($query) use ($allowedDepartments) {
                    $query
                        ->whereNull('department')
                        ->orWhereNotIn(DB::raw('LOWER(department)'), $allowedDepartments);
                })
                
                ->first();
        }

        if ($disallowedOrder !== null) {
            $orderIdentifier = $disallowedOrder->order_number ?? $disallowedOrder->getKey();
            $departmentKey = $disallowedOrder->department ?? null;
            $normalizedDepartmentKey = is_string($departmentKey) ? strtolower($departmentKey) : null;
            $departmentLabel = $normalizedDepartmentKey !== null
                ? ($departmentLabels[$normalizedDepartmentKey] ?? ucfirst($normalizedDepartmentKey))

                : __('قسم غير محدد');

            $allowedDepartmentLabels = collect($allowedDepartments)
                ->map(static function ($department) use ($departmentLabels) {
                    $normalized = strtolower((string) $department);

                    return $departmentLabels[$normalized] ?? ucfirst($normalized);
                })
                
                ->filter(static fn ($label) => is_string($label) && $label !== '')
                ->unique()
                ->implode('، ');

                
            if ($allowedDepartmentLabels === '') {
                $allowedDepartmentLabels = __('غير محددة');
            }


            $errorMessage = __('لا يمكن إضافة الطلب #:number إلى هذه المجموعة لأنها مخصصة لأقسام :allowed فقط. القسم الحالي للطلب: :department.', [
                'number' => $orderIdentifier,
                'department' => $departmentLabel,
                'allowed' => $allowedDepartmentLabels,
            ]);

            return redirect()
                ->route('orders.payment-groups.show', $group)
                ->with('error', $errorMessage);

        }


        try {
            $added = $this->groupService->addOrders($group, $orderIdsArray);
        } catch (Throwable $throwable) {
            Log::error('OrderPaymentGroupController@addOrders failed', [
                'group_id' => $group->getKey(),
                'error' => $throwable->getMessage(),
            ]);

            return redirect()
                ->route('orders.payment-groups.show', $group)
                ->with('error', __('تعذّر إضافة الطلبات المحددة. حاول مرة أخرى.'));
        }

        if ($added === 0) {
            return redirect()
                ->route('orders.payment-groups.show', $group)
                ->with('error', __('لم يتم العثور على طلبات صالحة لإضافتها.'));
        }

        return redirect()
            ->route('orders.payment-groups.show', $group)
            ->with('success', __('تمت إضافة :count من الطلبات إلى المجموعة.', ['count' => $added]));
    }

    public function bulkUpdate(Request $request, OrderPaymentGroup $group): RedirectResponse
    {
        $validated = $request->validate([
            'order_status' => ['nullable', 'string', Rule::in(Order::statusValues())],
            'notes' => ['nullable', 'string'],
            'comment' => ['nullable', 'string', 'max:1000'],
            'notification_title' => ['nullable', 'string', 'max:190'],
            'notification_message' => ['nullable', 'string', 'max:1000'],
        ]);

        $payload = collect($validated)
            ->mapWithKeys(static function ($value, $key) {
                if (is_string($value)) {
                    $value = trim($value);
                }

                return [$key => $value];
            })
            ->filter(static function ($value) {
                if (is_array($value)) {
                    return $value !== [];
                }

                return $value === null || (is_string($value) && $value === '');
                if (is_string($value)) {
                    return $value !== '';
                }

                return $value !== null;

            })
            ->all();


        $payload['notify_customer'] = $request->boolean('notify_customer');




        try {
            $updated = $this->groupService->bulkUpdate(
                $group,
                $payload,
                $request->user()?->getKey() ?? 0
            );
        } catch (ValidationException $exception) {
            return redirect()
                ->route('orders.payment-groups.show', $group)
                ->withErrors($exception->errors())
                ->withInput();
        } catch (Throwable $throwable) {
            Log::error('OrderPaymentGroupController@bulkUpdate failed', [
                'group_id' => $group->getKey(),
                'error' => $throwable->getMessage(),
            ]);

            return redirect()
                ->route('orders.payment-groups.show', $group)
                ->with('error', __('تعذّر تطبيق التحديث الجماعي. حاول لاحقاً.'));
        }

        if ($updated === 0) {
            return redirect()
                ->route('orders.payment-groups.show', $group)
                ->with('error', __('لا توجد طلبات ضمن المجموعة لتحديثها.'));
        }

        return redirect()
            ->route('orders.payment-groups.show', $group)
            ->with('success', __('تم تحديث :count من الطلبات ضمن المجموعة.', ['count' => $updated]));
    }
}