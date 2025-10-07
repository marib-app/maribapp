<?php

namespace App\Services;

use App\Models\SheinOrderBatch;
use Illuminate\Support\Collection;

class SheinOrderBatchReportService
{
    public function summaries(): Collection
    {
        $batches = SheinOrderBatch::query()
            ->with(['orders' => function ($query) {
                $query->select(
                    'id',
                    'shein_batch_id',
                    'final_amount',
                    'delivery_collected_amount'
                );
            }])
            ->orderByDesc('created_at')
            ->get();

        return $batches->map(function (SheinOrderBatch $batch) {
            $totalFinal = (float) $batch->orders->sum('final_amount');
            $totalCollected = (float) $batch->orders->sum('delivery_collected_amount');

            return [
                'batch' => $batch,
                'orders_count' => $batch->orders->count(),
                'total_final_amount' => $totalFinal,
                'total_collected_amount' => $totalCollected,
                'deposit_amount' => (float) $batch->deposit_amount,
                'outstanding_amount' => (float) $batch->outstanding_amount,
                'remaining_balance' => ($totalFinal - $totalCollected) - (float) $batch->deposit_amount,
            ];
        });
    }
}