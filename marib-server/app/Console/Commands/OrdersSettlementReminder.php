<?php

namespace App\Console\Commands;

use App\Models\Order;
use App\Models\OrderHistory;
use App\Notifications\SettlementCanceledNotification;
use App\Notifications\SettlementReminderNotification;
use App\Services\CachingService;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Notification;

class OrdersSettlementReminder extends Command
{
    public const REMINDER_HISTORY_COMMENT = 'تم إرسال تذكير بالدفع بسبب اقتراب موعد الاستحقاق.';
    public const PRE_SHIP_REMINDER_HISTORY_COMMENT = 'تم إرسال تذكير بالدفع قبل شحن الطلب.';
    public const ARRIVAL_REMINDER_HISTORY_COMMENT = 'تم إرسال تذكير بالدفع بعد وصول الشحنة.';
    public const CANCELLATION_HISTORY_COMMENT = 'تم إلغاء الطلب بسبب تجاوز مهلة الدفع وتم تحرير المخزون.';

    private const TARGET_DEPARTMENTS = ['shein', 'computer'];

    private const DEFAULT_REMINDER_HOURS = [
        'shein' => 12.0,
        'computer' => 12.0,
    ];


    private const DEFAULT_PRE_SHIP_REMINDER_HOURS = [
        'shein' => 12.0,
        'computer' => 12.0,
    ];

    private const DEFAULT_ARRIVAL_REMINDER_HOURS = [
        'shein' => 12.0,
        'computer' => 12.0,
    ];


    private const DEFAULT_CANCELLATION_HOURS = [
        'shein' => 48.0,
        'computer' => 48.0,
    ];

    private const SETTLING_PAYMENT_STATUSES = ['paid', 'refunded'];

    private const REMINDER_SETTING_TEMPLATE = 'orders_%s_settlement_reminder_hours';
    private const PRE_SHIP_REMINDER_SETTING_TEMPLATE = 'orders_%s_settlement_reminder_pre_ship_hours';
    private const ARRIVAL_REMINDER_SETTING_TEMPLATE = 'orders_%s_settlement_reminder_arrival_hours';
    private const CANCELLATION_SETTING_TEMPLATE = 'orders_%s_settlement_cancel_hours';

    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'orders:settlement-reminder';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Send settlement reminders and cancel overdue orders for Shein and computer departments.';

    public function handle(): int
    {
        $now = now();
        $settings = $this->loadSettings();

        $summary = [
            'reminders' => 0,
            'cancellations' => 0,
        ];

        Order::query()
            ->with('user')
            ->whereIn('department', self::TARGET_DEPARTMENTS)
            ->where(function ($query) {
                $query
                    ->where(function ($paymentQuery) {
                        $paymentQuery
                            ->whereNull('payment_status')
                            ->orWhereNotIn('payment_status', self::SETTLING_PAYMENT_STATUSES);
                    })
                    ->orWhere(function ($depositQuery) {
                        $depositQuery
                            ->whereNotNull('deposit_remaining_balance')
                            ->where('deposit_remaining_balance', '>', 0);
                    });
            })
            ->orderBy('id')
            ->chunkById(100, function (Collection $orders) use ($settings, $now, &$summary): void {
                foreach ($orders as $order) {
                    $department = $order->department;

                    if (! is_string($department) || $department === '') {
                        continue;
                    }

                    $department = strtolower($department);

                    if (! array_key_exists($department, $settings)) {
                        continue;
                    }

                    $dueAt = $this->resolveDueAt($order);

                    if (! $dueAt instanceof CarbonInterface) {
                        continue;
                    }

                    $departmentSettings = $settings[$department];

                    $reminderLead = $departmentSettings['reminder'];
                    $cancellationGrace = $departmentSettings['cancel'];


                    $reminderWindowStart = $reminderLead > 0
                        ? $dueAt->copy()->subHours($reminderLead)
                        : $dueAt->copy();

                    $cancellationCutoff = $cancellationGrace > 0
                        ? $dueAt->copy()->addHours($cancellationGrace)
                        : $dueAt->copy();

                    if ($now->greaterThanOrEqualTo($cancellationCutoff)) {
                        if ($this->cancelOrder($order, $dueAt, $cancellationCutoff)) {
                            $summary['cancellations']++;
                        }

                        continue;
                    }

                    if ($this->processStageReminders($order, $departmentSettings, $now)) {
                        $summary['reminders']++;

                        continue;
                    }


                    if ($now->lessThan($reminderWindowStart)) {
                        continue;
                    }

                    if ($this->sendReminder($order, $dueAt, self::REMINDER_HISTORY_COMMENT)) {
                        $summary['reminders']++;
                    }
                }
            });

        $this->info(sprintf(
            'Orders settlement reminder complete: %d reminders, %d cancellations.',
            $summary['reminders'],
            $summary['cancellations']
        ));

        return self::SUCCESS;
    }

    /**
     * @return array<string, array{reminder: float, pre_ship: float, arrival: float, cancel: float}>
     */
    private function loadSettings(): array
    {
        $settings = CachingService::getSystemSettings();

        if (! is_array($settings)) {
            $settings = $settings instanceof \Traversable ? iterator_to_array($settings) : [];
        }

        $result = [];

        foreach (self::TARGET_DEPARTMENTS as $department) {
            $departmentKey = strtolower($department);

            $reminderKey = sprintf(self::REMINDER_SETTING_TEMPLATE, $departmentKey);
            $preShipKey = sprintf(self::PRE_SHIP_REMINDER_SETTING_TEMPLATE, $departmentKey);
            $arrivalKey = sprintf(self::ARRIVAL_REMINDER_SETTING_TEMPLATE, $departmentKey);
            $cancelKey = sprintf(self::CANCELLATION_SETTING_TEMPLATE, $departmentKey);

            $result[$departmentKey] = [
                'reminder' => $this->parseHours(Arr::get($settings, $reminderKey), self::DEFAULT_REMINDER_HOURS[$departmentKey]),
                'pre_ship' => $this->parseHours(Arr::get($settings, $preShipKey), self::DEFAULT_PRE_SHIP_REMINDER_HOURS[$departmentKey]),
                'arrival' => $this->parseHours(Arr::get($settings, $arrivalKey), self::DEFAULT_ARRIVAL_REMINDER_HOURS[$departmentKey]),
                'cancel' => $this->parseHours(Arr::get($settings, $cancelKey), self::DEFAULT_CANCELLATION_HOURS[$departmentKey]),
            ];
        }

        return $result;
    }

    private function parseHours(mixed $value, float $default): float
    {
        if (is_numeric($value)) {
            $hours = (float) $value;

            if ($hours >= 0) {
                return $hours;
            }
        }

        return $default;
    }

    private function resolveDueAt(Order $order): ?CarbonInterface
    {
        if ($order->payment_due_at instanceof CarbonInterface) {
            return $order->payment_due_at->copy();
        }

        if ($order->created_at instanceof CarbonInterface) {
            return $order->created_at->copy();
        }

        if ($order->created_at) {
            return Carbon::parse($order->created_at);
        }

        if ($order->payment_due_at) {
            return Carbon::parse($order->payment_due_at);
        }

        return null;
    }

    private function processStageReminders(Order $order, array $departmentSettings, CarbonInterface $now): bool
    {
        $historyCache = [];

        $arrivalTriggerAt = $this->arrivalReminderTriggerAt($order, $departmentSettings['arrival'], $now, $historyCache);

        if ($arrivalTriggerAt !== null) {
            return $this->sendReminder($order, $arrivalTriggerAt, self::ARRIVAL_REMINDER_HISTORY_COMMENT);
        }

        $preShipTriggerAt = $this->preShipReminderTriggerAt($order, $departmentSettings['pre_ship'], $now, $historyCache);

        if ($preShipTriggerAt !== null) {
            return $this->sendReminder($order, $preShipTriggerAt, self::PRE_SHIP_REMINDER_HISTORY_COMMENT);
        }

        return false;
    }

    private function sendReminder(Order $order, CarbonInterface $dueAt, string $historyComment): bool
    
    {
        if ($order->user === null) {
            return false;
        }

        $alreadyRecorded = $order->history()
            ->where('comment', $historyComment)
            ->exists();

        if ($alreadyRecorded) {
            return false;
        }

        Notification::send($order->user, new SettlementReminderNotification($order, $dueAt));

        OrderHistory::create([
            'order_id' => $order->getKey(),
            'user_id' => null,
            'status_from' => $order->order_status,
            'status_to' => $order->order_status,
            'comment' => $historyComment,
            'notify_customer' => true,
        ]);

        return true;
    }


    private function preShipReminderTriggerAt(
        Order $order,
        float $leadHours,
        CarbonInterface $now,
        array &$historyCache
    ): ?CarbonInterface {
        if ($leadHours < 0) {
            return null;
        }

        $status = $order->order_status;

        if ($status === Order::STATUS_READY_FOR_DELIVERY) {
            $statusChangedAt = $this->statusChangedAt($order, Order::STATUS_READY_FOR_DELIVERY, $historyCache)
                ?? $this->statusChangedAt($order, Order::STATUS_PREPARING, $historyCache);
        } elseif ($status === Order::STATUS_PREPARING) {
            $statusChangedAt = $this->statusChangedAt($order, Order::STATUS_PREPARING, $historyCache);
        } elseif ($status === Order::STATUS_OUT_FOR_DELIVERY) {
            $statusChangedAt = $this->statusChangedAt($order, Order::STATUS_OUT_FOR_DELIVERY, $historyCache)
                ?? $this->statusChangedAt($order, Order::STATUS_READY_FOR_DELIVERY, $historyCache)
                ?? $this->statusChangedAt($order, Order::STATUS_PREPARING, $historyCache);
        } else {
            return null;
        }

        if (! $statusChangedAt instanceof CarbonInterface) {
            return null;
        }

        $triggerAt = $statusChangedAt->copy()->addHours($leadHours);

        if ($now->greaterThanOrEqualTo($triggerAt)) {
            return $triggerAt;
        }

        return null;
    }

    private function arrivalReminderTriggerAt(
        Order $order,
        float $leadHours,
        CarbonInterface $now,
        array &$historyCache
    ): ?CarbonInterface {
        if ($leadHours < 0) {
            return null;
        }

        if (! in_array($order->order_status, [Order::STATUS_DELIVERED, Order::STATUS_FINAL_SETTLEMENT], true)) {
            return null;
        }

        $statusChangedAt = $this->statusChangedAt($order, Order::STATUS_DELIVERED, $historyCache);

        if (! $statusChangedAt instanceof CarbonInterface) {
            return null;
        }

        $triggerAt = $statusChangedAt->copy()->addHours($leadHours);

        if ($now->greaterThanOrEqualTo($triggerAt)) {
            return $triggerAt;
        }

        return null;
    }

    private function statusChangedAt(Order $order, string $status, array &$historyCache): ?CarbonInterface
    {
        if (array_key_exists($status, $historyCache)) {
            return $historyCache[$status];
        }

        $history = $order->history()
            ->where('status_to', $status)
            ->first();

        if ($history === null) {
            return $historyCache[$status] = null;
        }

        $createdAt = $history->created_at;

        if ($createdAt instanceof CarbonInterface) {
            return $historyCache[$status] = $createdAt->copy();
        }

        if ($createdAt !== null) {
            return $historyCache[$status] = Carbon::parse($createdAt);
        }

        return $historyCache[$status] = null;
    }

    private function cancelOrder(Order $order, CarbonInterface $dueAt, CarbonInterface $cancelledAt): bool
    {
        if ($order->order_status === Order::STATUS_CANCELED) {
            return false;
        }

        $originalStatus = $order->order_status;

        $order->withStatusContext(null, self::CANCELLATION_HISTORY_COMMENT);
        $order->order_status = Order::STATUS_CANCELED;
        $order->save();

        if ($order->user !== null) {
            Notification::send($order->user, new SettlementCanceledNotification($order, $dueAt, $cancelledAt));
        }

        OrderHistory::create([
            'order_id' => $order->getKey(),
            'user_id' => null,
            'status_from' => $originalStatus,
            'status_to' => Order::STATUS_CANCELED,
            'comment' => self::CANCELLATION_HISTORY_COMMENT,
            'notify_customer' => true,
        ]);

        return true;
    }
}