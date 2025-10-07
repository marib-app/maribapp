<?php

namespace App\Notifications;

use App\Models\Order;
use Carbon\CarbonInterface;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Str;

class SettlementCanceledNotification extends Notification
{
    use Queueable;

    public function __construct(
        private readonly Order $order,
        private readonly CarbonInterface $dueAt,
        private readonly CarbonInterface $cancelledAt
    ) {
    }

    public function via(mixed $notifiable): array
    {
        $channels = ['database'];

        if (filled($notifiable->email)) {
            $channels[] = 'mail';
        }

        return $channels;
    }

    public function toMail(mixed $notifiable): MailMessage
    {
        $orderNumber = $this->order->order_number ?? (string) $this->order->getKey();
        $department = $this->order->department ? Str::title($this->order->department) : __('الطلب');

        return (new MailMessage())
            ->subject(__('إلغاء الطلب #:number بسبب عدم السداد', ['number' => $orderNumber]))
            ->greeting(__('مرحباً :name،', ['name' => $notifiable->name]))
            ->line(__('تم إلغاء طلبك في قسم :department بعد تجاوز مهلة الدفع المحددة.', [
                'department' => $department,
            ]))
            ->line(__('كان موعد الاستحقاق في :due وتجاوز المهلة النهائية عند :cancelled.', [
                'due' => $this->dueAt->toDateTimeString(),
                'cancelled' => $this->cancelledAt->toDateTimeString(),
            ]))
            ->line(__('في حال رغبت بإعادة الطلب يرجى إنشاء طلب جديد.'))
            ->action(__('عرض تفاصيل الطلب'), url(sprintf('orders/%s', $this->order->getKey())))
            ->line(__('نأمل خدمتك مجدداً قريباً.'));
    }

    public function toArray(mixed $notifiable): array
    {
        return [
            'order_id' => $this->order->getKey(),
            'order_number' => $this->order->order_number,
            'department' => $this->order->department,
            'type' => 'settlement_canceled',
            'due_at' => $this->dueAt->toIso8601String(),
            'cancelled_at' => $this->cancelledAt->toIso8601String(),
        ];
    }
}