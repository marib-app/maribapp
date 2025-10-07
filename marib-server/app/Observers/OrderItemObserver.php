<?php

namespace App\Observers;

use App\Models\OrderItem;
use App\Services\OrderDepositRefundService;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class OrderItemObserver
{
    public function __construct(private OrderDepositRefundService $depositRefundService)
    {
    }

    public function updated(OrderItem $orderItem): void
    {
        if ($this->transitionedToOutOfStock($orderItem)) {
            $this->depositRefundService->compensateOrderItem($orderItem, 'out_of_stock');
        }
    }

    public function deleting(OrderItem $orderItem): void
    {
        $this->depositRefundService->compensateOrderItem($orderItem, 'deleted', [
            'update_item' => false,
        ]);
    }

    private function transitionedToOutOfStock(OrderItem $orderItem): bool
    {
        $previous = $this->resolveStatusFromAttributes($orderItem->getOriginal());
        $current = $this->resolveStatusFromAttributes($orderItem->getAttributes());

        return $previous !== 'out_of_stock' && $current === 'out_of_stock';
    }

    /**
     * @param array<string, mixed> $attributes
     */
    private function resolveStatusFromAttributes(array $attributes): ?string
    {
        $candidates = [];

        if (array_key_exists('status', $attributes)) {
            $candidates[] = $attributes['status'];
        }

        if (array_key_exists('options', $attributes)) {
            $candidates[] = $attributes['options'];
        }

        if (array_key_exists('attributes', $attributes)) {
            $candidates[] = $attributes['attributes'];
        }

        foreach ($candidates as $candidate) {
            $status = $this->extractStatus($candidate);

            if ($status !== null) {
                return $status;
            }
        }

        return null;
    }

    private function extractStatus(mixed $value): ?string
    {
        if (is_string($value)) {
            $decoded = json_decode($value, true);

            if (json_last_error() === JSON_ERROR_NONE) {
                $value = $decoded;
            } else {
                return null;
            }
        }

        if (! is_array($value)) {
            return null;
        }

        $status = Arr::get($value, 'status', Arr::get($value, 'state'));

        if (! is_string($status) || $status === '') {
            return null;
        }

        $normalized = Str::of($status)->lower()->trim()->value();

        return $normalized !== '' ? $normalized : null;
    }
}