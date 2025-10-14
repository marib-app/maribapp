<?php

namespace App\Services;

use App\Models\Order;
use App\Models\RequestDevice;
use App\Models\UserFcmToken;
use Illuminate\Support\Str;
use Throwable;

class DelegateNotificationService
{
    public function __construct(
        private readonly DelegateAuthorizationService $delegateAuthorizationService
    ) {
    }

    public function notifyRequestDevice(RequestDevice $requestDevice): void
    {
        $section = $this->normalizeDepartment($requestDevice->section);

        $tokens = $this->resolveDelegateTokens($section);

        if ($tokens === []) {
            return;
        }

        $departmentLabel = $this->resolveDepartmentLabel($section);
        $orderReference = '#' . $requestDevice->getKey();
        $subject = trim((string) ($requestDevice->subject ?? ''));

        $title = 'طلب شراء جديد يحتاج إلى مراجعة';
        $body = sprintf(
            'لديك طلب شراء في قسم %s رقم الطلب %s يحتاج إلى مراجعة.',
            $departmentLabel,
            $orderReference
        );

        if ($subject !== '') {
            $body .= ' الموضوع: ' . $subject;
        }

        $deeplink = $this->resolveRequestDeviceManagementUrl($section, $requestDevice);

        $payload = [
            'type' => 'request_device',
            'section' => $section,
            'request_device_id' => $requestDevice->getKey(),
            'order_reference' => $orderReference,
            'subject' => $subject,
            'phone' => $requestDevice->phone,
            'deeplink' => $deeplink,
            'click_action' => $deeplink,
            'message_preview' => $body,
        ];

        NotificationService::sendFcmNotification($tokens, $title, $body, 'request_device', $payload);
    }

    public function notifyNewOrder(Order $order): void
    {
        $department = $this->normalizeDepartment($order->department);
        $tokens = $this->resolveDelegateTokens($department);

        if ($tokens === []) {
            return;
        }

        $departmentLabel = $this->resolveDepartmentLabel($department);
        $orderNumber = $order->order_number ?: ('#' . $order->getKey());

        $title = 'طلب جديد يحتاج إلى مراجعة';
        $body = sprintf(
            'لديك طلب جديد في قسم %s رقم الطلب %s يحتاج إلى مراجعة.',
            $departmentLabel,
            $orderNumber
        );

        $deeplink = $this->resolveOrderManagementUrl($order);

        $payload = [
            'type' => 'order',
            'department' => $department,
            'order_id' => $order->getKey(),
            'order_number' => $orderNumber,
            'deeplink' => $deeplink,
            'click_action' => $deeplink,
            'message_preview' => $body,
        ];

        NotificationService::sendFcmNotification($tokens, $title, $body, 'order', $payload);
    }

    /**
     * @return array<int, string>
     */
    private function resolveDelegateTokens(string $department): array
    {
        $delegateIds = $this->delegateAuthorizationService->getDelegatesForSection($department);

        if ($delegateIds === []) {
            return [];
        }

        return UserFcmToken::query()
            ->whereIn('user_id', $delegateIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();
    }

    private function resolveDepartmentLabel(string $department): string
    {
        $label = trans('departments.' . $department, [], 'ar');

        if ($label === 'departments.' . $department) {
            $label = $department;
        }

        return $label;
    }

    private function resolveRequestDeviceManagementUrl(string $section, RequestDevice $requestDevice): ?string
    {
        try {
            return match ($section) {
                DepartmentReportService::DEPARTMENT_SHEIN => route('item.shein.custom-orders.show', ['id' => $requestDevice->getKey()]),
                DepartmentReportService::DEPARTMENT_COMPUTER => route('item.computer.custom-orders.show', ['id' => $requestDevice->getKey()]),
                default => null,
            };
        } catch (Throwable) {
            return null;
        }
    }

    private function resolveOrderManagementUrl(Order $order): ?string
    {
        $orderId = $order->getKey();

        if ($orderId === null) {
            return null;
        }

        try {
            return route('orders.show', ['order' => $orderId]);
        } catch (Throwable) {
            return null;
        }
    }

    private function normalizeDepartment(?string $department): string
    {
        $normalized = Str::of((string) $department)
            ->trim()
            ->lower();

        $value = (string) $normalized;

        if ($value !== '') {
            return $value;
        }

        return DepartmentReportService::DEPARTMENT_COMPUTER;
    }
}