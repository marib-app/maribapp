<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use App\Notifications\SettlementReminderNotification;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Notification;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use Throwable;

class OrderPaymentActionController extends Controller
{

    public function storeManualPayment(Request $request, Order $order): RedirectResponse
    {
        $validated = $request->validate([
            'type' => ['required', 'in:payment,reminder'],
            'amount' => ['nullable', 'numeric', 'min:0', 'required_if:type,payment'],
            'note' => ['nullable', 'string', 'max:1000'],
        ], [
            'type.required' => __('يرجى اختيار نوع الإجراء'),
            'type.in' => __('النوع المحدد غير مدعوم'),
            'amount.required_if' => __('المبلغ مطلوب عند تسجيل دفعة يدوية'),
            'amount.numeric' => __('المبلغ يجب أن يكون رقمياً'),
            'amount.min' => __('المبلغ يجب أن يكون صفراً أو أكبر'),
        ]);

        if ($validated['type'] === 'payment') {
            return redirect()
                ->route('orders.show', $order)
                ->with('error', __('لا يمكن تعديل حالة الدفع من خلال هذه الصفحة. يرجى معالجة الدفعات عبر واجهة طلبات الدفع اليدوية.'));
            
            }

        return $this->handleManualReminder($request, $order, $validated);
    }

    public function sendInstantNotification(Request $request, Order $order): RedirectResponse
    {
        $validated = $request->validate([
            'title' => ['nullable', 'string', 'max:190'],
            'message' => ['required', 'string', 'max:1000'],
        ], [
            'message.required' => __('نص الإشعار مطلوب'),
        ]);

        $tokens = UserFcmToken::where('user_id', $order->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return redirect()
                ->route('orders.show', $order)
                ->with('error', __('لا توجد أجهزة مرتبطة بالعميل لإرسال الإشعار.'));
        }

        $title = $validated['title'] ?? __('إشعار الطلب #:number', ['number' => $order->order_number ?? $order->getKey()]);

        try {
            $result = NotificationService::sendFcmNotification(
                $tokens,
                $title,
                $validated['message'],
                'order',
                [
                    'order_id' => (string) $order->getKey(),
                ]
            );
        } catch (Throwable $throwable) {
            Log::error('OrderPaymentActionController: failed to send instant notification', [
                'order_id' => $order->getKey(),
                'error' => $throwable->getMessage(),
            ]);

            return redirect()
                ->route('orders.show', $order)
                ->with('error', __('تعذّر إرسال الإشعار. الرجاء المحاولة لاحقاً.'));
        }

        if (is_array($result) && Arr::get($result, 'error')) {
            $message = Arr::get($result, 'message') ?? __('تعذّر إرسال الإشعار. الرجاء المحاولة لاحقاً.');

            return redirect()
                ->route('orders.show', $order)
                ->with('error', $message);
        }

        return redirect()
            ->route('orders.show', $order)
            ->with('success', __('تم إرسال الإشعار بنجاح.'));
    }


    private function handleManualReminder(Request $request, Order $order, array $validated): RedirectResponse
    {
        $commentParts = [__('تم إنشاء تذكير للدفعة اليدوية')];

        if (! empty($validated['note'])) {
            $commentParts[] = __('ملاحظة: :note', ['note' => $validated['note']]);
        }

        $order->loadMissing('user');

        if ($order->user === null) {
            $commentParts[] = __('تعذّر إرسال التذكير لعدم وجود عميل مرتبط.');

            OrderHistory::create([
                'order_id' => $order->getKey(),
                'user_id' => $request->user()->getKey(),
                'status_from' => $order->order_status,
                'status_to' => $order->order_status,
                'comment' => implode(' — ', $commentParts),
                'notify_customer' => false,
            ]);

            return redirect()
                ->route('orders.show', $order)
                ->with('error', __('لا يمكن إرسال التذكير لعدم وجود عميل مرتبط بالطلب.'));
        }

        try {
            Notification::send($order->user, new SettlementReminderNotification($order, $this->resolveOrderDueAt($order)));
        } catch (Throwable $throwable) {
            Log::error('OrderPaymentActionController: failed to send manual reminder', [
                'order_id' => $order->getKey(),
                'error' => $throwable->getMessage(),
            ]);

            $failureComment = array_merge($commentParts, [__('تعذّر إرسال التذكير للعميل.')]);

            OrderHistory::create([
                'order_id' => $order->getKey(),
                'user_id' => $request->user()->getKey(),
                'status_from' => $order->order_status,
                'status_to' => $order->order_status,
                'comment' => implode(' — ', $failureComment),
                'notify_customer' => false,
            ]);

            return redirect()
                ->route('orders.show', $order)
                ->with('error', __('تعذّر إرسال التذكير. الرجاء المحاولة لاحقاً.'));
        }

        $successComment = array_merge($commentParts, [__('تم إرسال التذكير للعميل.')]);

        OrderHistory::create([
            'order_id' => $order->getKey(),
            'user_id' => $request->user()->getKey(),
            'status_from' => $order->order_status,
            'status_to' => $order->order_status,
            'comment' => implode(' — ', $successComment),
            'notify_customer' => true,
        ]);

        return redirect()
            ->route('orders.show', $order)
            ->with('success', __('تم حفظ الإجراء على الطلب بنجاح.'));
    }

    private function resolveOrderDueAt(Order $order): CarbonInterface
    {
        $dueAt = $order->payment_due_at;

        if ($dueAt instanceof CarbonInterface) {
            return $dueAt;
        }

        if ($dueAt !== null) {
            return Carbon::parse($dueAt);
        }

        $createdAt = $order->created_at;

        if ($createdAt instanceof CarbonInterface) {
            return $createdAt;
        }

        if ($createdAt !== null) {
            return Carbon::parse($createdAt);
        }

        return Carbon::now();
    }
}
