<?php

namespace App\Notifications;

use App\Models\Order;
use Carbon\CarbonInterface;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Str;

class SettlementReminderNotification extends Notification
{
    use Queueable;

    public function __construct(private readonly Order $order, private readonly CarbonInterface $dueAt)
    {
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
            ->subject(__('تذكير بتسوية الطلب #:number', ['number' => $orderNumber]))
            ->greeting(__('مرحباً :name،', ['name' => $notifiable->name]))
            ->line(__('نذكرك بإتمام تسوية طلب قسم :department قبل :date.', [
                'department' => $department,
                'date' => $this->dueAt->toDateTimeString(),
            ]))
            ->line(__('في حال تم السداد يرجى تجاهل هذه الرسالة.'))
            ->action(__('عرض الطلب'), url(sprintf('orders/%s', $this->order->getKey())))
            ->line(__('شكراً لاختيارك لنا.'));
    }

    public function toArray(mixed $notifiable): array
    {
        return [
            'order_id' => $this->order->getKey(),
            'order_number' => $this->order->order_number,
            'department' => $this->order->department,
            'type' => 'settlement_reminder',
            'due_at' => $this->dueAt->toIso8601String(),
        ];
    }
}