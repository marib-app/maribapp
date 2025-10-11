<?php

namespace App\Services;

use App\Events\OrderNoteUpdated;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderPaymentGroup;
use App\Notifications\GroupOrderNotification;
use App\Services\DepartmentReportService;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;
use Illuminate\Validation\ValidationException;

class OrderPaymentGroupService
{


    /**
     * الأقسام المسموح بها افتراضيًا للمجموعات.
     *
     * @var array<int, string>
     */
    private const DEFAULT_ALLOWED_DEPARTMENTS = [
        DepartmentReportService::DEPARTMENT_SHEIN,
        DepartmentReportService::DEPARTMENT_COMPUTER,
    ];


    /**
     * يعيد قائمة الأقسام المسموح بها افتراضيًا بعد تطبيعها.
     *
     * @return array<int, string>
     */
    private function defaultAllowedDepartments(): array
    {
        return $this->normalizeDepartments(self::DEFAULT_ALLOWED_DEPARTMENTS);
    }

    /**
     * يطبع مصفوفة الأقسام ويصفّي القيم غير الصالحة.
     *
     * @param  mixed  $departments
     * @param  array<int, string>|null  $scope
     * @return array<int, string>
     */
    private function normalizeDepartments(mixed $departments, ?array $scope = null): array
    {
        if ($departments instanceof Collection) {
            $departments = $departments->all();
        } elseif (is_string($departments)) {
            $decoded = json_decode($departments, true);

            if (is_array($decoded)) {
                $departments = $decoded;
            } else {
                $departments = array_map(static fn ($value) => trim((string) $value), explode(',', $departments));
            }
        }

        $normalized = collect(Arr::wrap($departments))
            ->filter(static fn ($department) => is_string($department) && $department !== '')
            ->map(static fn ($department) => strtolower($department));

        if ($scope !== null) {
            $allowedScope = collect($scope)
                ->filter(static fn ($department) => is_string($department) && $department !== '')
                ->map(static fn ($department) => strtolower($department))
                ->unique()
                ->values()
                ->all();

            $normalized = $normalized->filter(static fn ($department) => in_array($department, $allowedScope, true));
        }

        return $normalized->unique()->values()->all();
    }






    public function createGroup(array $data, ?int $userId = null, ?Order $order = null): OrderPaymentGroup
    {
        return DB::transaction(function () use ($data, $userId, $order) {
            $payload = [
                'name' => trim((string) Arr::get($data, 'name')),
                'note' => Arr::get($data, 'note'),
                'created_by' => $userId,
            ];

            $group = OrderPaymentGroup::create($payload);

            if ($order !== null) {
                $group->orders()->syncWithoutDetaching([$order->getKey()]);
            }

            return $group;
        });
    }

    public function addOrders(OrderPaymentGroup $group, array $orderIds): int
    {
        $ids = $this->sanitizeOrderIds($orderIds);

        if ($ids->isEmpty()) {
            return 0;
        }

        $allowedDepartments = $this->allowedDepartmentsForGroup($group);

        $ordersQuery = Order::query()->whereIn('id', $ids);

        if ($allowedDepartments !== []) {
            $ordersQuery
                ->whereNotNull('department')
                ->whereIn(DB::raw('LOWER(department)'), $allowedDepartments);
            
            }

        $orders = $ordersQuery->get();



        if ($orders->isEmpty()) {
            return 0;
        }

        $group->orders()->syncWithoutDetaching($orders->pluck('id')->all());

        return $orders->count();
    }


    public function allowedDepartmentsForGroup(OrderPaymentGroup $group): array
    {
        $defaultAllowed = $this->defaultAllowedDepartments();
        $configuredAllowed = $this->normalizeDepartments(config('orders.payment_groups.allowed_departments'));
        $validDepartments = $configuredAllowed !== [] ? $configuredAllowed : $defaultAllowed;


        $groupAllowed = $this->normalizeDepartments($group->getAttribute('allowed_departments'), $validDepartments);


        if ($groupAllowed === []) {
            return $validDepartments;


        }

        return $groupAllowed;
    }



    public function bulkUpdate(OrderPaymentGroup $group, array $payload, int $userId): int
    {
        /** @var EloquentCollection<int, Order> $orders */
        $orders = $group->orders()
            ->with(['user', 'manualPaymentRequests', 'paymentTransactions'])
            ->get();

        if ($orders->isEmpty()) {
            return 0;
        }

        $updates = [];
        $fillableUpdates = [];
        $orderStatus = Arr::get($payload, 'order_status');

        if (filled($orderStatus)) {
            $normalizedStatus = (string) $orderStatus;

            $updates['order_status'] = $normalizedStatus;
            $fillableUpdates['order_status'] = $normalizedStatus;
        


            $blockedOrders = $orders->filter(static function (Order $order): bool {
                return $order->latestPendingManualPaymentRequest() !== null;
            });

            if ($blockedOrders->isNotEmpty()) {
                $orderIdentifiers = $blockedOrders
                    ->map(static function (Order $order) {
                        return $order->order_number ?? $order->getKey();
                    })
                    ->unique()
                    ->values()
                    ->implode('، ');

                throw ValidationException::withMessages([
                    'order_status' => __('لا يمكن تحديث حالة الطلب للطلبات التالية بسبب وجود دفعات قيد المراجعة: :orders.', [
                        'orders' => $orderIdentifiers,
                    ]),
                ]);
            }


            $unpaidOrders = $orders->filter(static function (Order $order): bool {
                return ! $order->hasSuccessfulPayment();
            });

            if ($unpaidOrders->isNotEmpty()) {
                $orderIdentifiers = $unpaidOrders
                    ->map(static function (Order $order) {
                        return $order->order_number ?? $order->getKey();
                    })
                    ->unique()
                    ->values()
                    ->implode('، ');

                throw ValidationException::withMessages([
                    'order_status' => __('لا يمكن تحديث حالة الطلب قبل تأكيد الدفع بنجاح للطلبات التالية: :orders.', [
                        'orders' => $orderIdentifiers,
                    ]),
                ]);
            }




            $unpaidOrders = $orders->filter(static function (Order $order): bool {
                return ! $order->hasSuccessfulPayment();
            });

            if ($unpaidOrders->isNotEmpty()) {
                $orderIdentifiers = $unpaidOrders
                    ->map(static function (Order $order) {
                        return $order->order_number ?? $order->getKey();
                    })
                    ->unique()
                    ->values()
                    ->implode('، ');

                throw ValidationException::withMessages([
                    'order_status' => __('لا يمكن تحديث حالة الطلب للطلبات التالية قبل إتمام الدفع بنجاح: :orders.', [
                        'orders' => $orderIdentifiers,
                    ]),
                ]);
            }



        }

        if (array_key_exists('notes', $payload)) {
            $notes = $payload['notes'];


            if (is_string($notes)) {
                $notes = trim($notes);
            }

            if ($notes !== null && ! (is_string($notes) && $notes === '')) {
                if (is_scalar($notes) || (is_object($notes) && method_exists($notes, '__toString'))) {
                    $noteValue = (string) $notes;

                    $updates['notes'] = $noteValue;
                    $fillableUpdates['notes'] = $noteValue;
                }
                
            }
        }





        if ($updates === [] && ! filled(Arr::get($payload, 'comment'))) {
            throw ValidationException::withMessages([
                'order_status' => __('يرجى تحديد تحديث واحد على الأقل لتطبيقه على الطلبات.'),
            ]);
        }

        $comment = Arr::get($payload, 'comment');
        $notifyCustomer = (bool) Arr::get($payload, 'notify_customer', false);
        $notificationTitle = Arr::get($payload, 'notification_title');
        $notificationMessage = Arr::get($payload, 'notification_message');

        DB::transaction(function () use (
            $orders,
            $updates,
            $fillableUpdates,
            $comment,
            $notifyCustomer,
            $notificationTitle,
            $notificationMessage,
            $userId
        ) {
            foreach ($orders as $order) {
                $previousStatus = $order->order_status;

                if (isset($updates['order_status'])) {
                    $order->withStatusContext($userId, $comment);
                }

                $order->fill($fillableUpdates);

                $noteWasUpdated = $order->isDirty('notes');
                $updatedNote = $order->notes;

                if (($updates['order_status'] ?? null) === Order::STATUS_DELIVERED && $order->completed_at === null) {
                    $order->completed_at = now();
                }

                $order->save();

                if ($noteWasUpdated && filled($updatedNote)) {
                    event(new OrderNoteUpdated(
                        $order->fresh('user'),
                        (string) $updatedNote,
                        $userId,
                        'order_note'
                    ));
                }

                if (isset($updates['order_status']) || filled($comment)) {
                    OrderHistory::create([
                        'order_id' => $order->id,
                        'user_id' => $userId,
                        'status_from' => $previousStatus,
                        'status_to' => $updates['order_status'] ?? $previousStatus,
                        'comment' => $comment,
                        'notify_customer' => $notifyCustomer,
                    ]);
                }

                if ($notifyCustomer && $order->user && filled($notificationMessage ?? $comment)) {
                    $title = filled($notificationTitle)
                        ? (string) $notificationTitle
                        : __('تحديث الطلب #:number', ['number' => $order->order_number ?? $order->getKey()]);

                    $messageBody = filled($notificationMessage) ? (string) $notificationMessage : (string) $comment;

                    Notification::send($order->user, new GroupOrderNotification($order, $title, $messageBody));

                    event(new OrderNoteUpdated(
                        $order->fresh('user'),
                        $messageBody,
                        $userId,
                        'history_comment'
                    ));
                }
            }
        });

        return $orders->count();
    }

    public function availableSheinOrders(?OrderPaymentGroup $group = null, int $limit = 50): Collection
    {
        $departmentService = app(DepartmentReportService::class);
        $categoryIds = $departmentService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_SHEIN);

        $query = Order::query()
            ->with('user:id,name')
            ->where(function ($query) use ($categoryIds) {
                $query->where('department', DepartmentReportService::DEPARTMENT_SHEIN);

                if ($categoryIds !== []) {
                    $query->orWhereHas('items.item', static function ($itemQuery) use ($categoryIds) {
                        $itemQuery->whereIn('category_id', $categoryIds);
                    });
                }
            });

        if ($group) {
            $query->whereDoesntHave('paymentGroups', static function ($relation) use ($group) {
                $relation->whereKey($group->getKey());
            });
        }

        return $query
            ->latest('created_at')
            ->limit($limit)
            ->get();
    }

    protected function sanitizeOrderIds(array $orderIds): Collection
    {
        return collect($orderIds)
            ->filter(static fn ($id) => is_numeric($id) && (int) $id > 0)
            ->map(static fn ($id) => (int) $id)
            ->unique();
    }
}