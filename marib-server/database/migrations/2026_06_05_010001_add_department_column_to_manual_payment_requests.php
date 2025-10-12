<?php

use App\Models\Order;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        Schema::table('manual_payment_requests', static function (Blueprint $table): void {
            if (! Schema::hasColumn('manual_payment_requests', 'department')) {
                $table->string('department')->nullable()->after('currency');
                $table->index('department');
            }
        });

        if (! Schema::hasColumn('manual_payment_requests', 'department') || ! Schema::hasTable('orders')) {
            return;
        }

        $allowedTypes = [
            'orders',
            strtolower(Order::class),
        ];

        DB::table('manual_payment_requests')
            ->select(['id', 'payable_type', 'payable_id'])
            ->whereNull('department')
            ->whereNotNull('payable_id')
            ->whereIn(DB::raw('LOWER(payable_type)'), $allowedTypes)
            ->orderBy('id')
            ->chunkById(200, static function ($rows): void {
                $orderIds = collect($rows)
                    ->pluck('payable_id')
                    ->filter(static fn ($id) => is_numeric($id))
                    ->map(static fn ($id) => (int) $id)
                    ->unique()
                    ->values();

                if ($orderIds->isEmpty()) {
                    return;
                }

                $departments = DB::table('orders')
                    ->whereIn('id', $orderIds->all())
                    ->pluck('department', 'id');

                foreach ($rows as $row) {
                    $orderId = is_numeric($row->payable_id) ? (int) $row->payable_id : null;

                    if ($orderId === null) {
                        continue;
                    }

                    $department = $departments[$orderId] ?? null;

                    if (! is_string($department)) {
                        continue;
                    }

                    $trimmed = trim($department);

                    if ($trimmed === '') {
                        continue;
                    }

                    DB::table('manual_payment_requests')
                        ->where('id', $row->id)
                        ->update(['department' => $trimmed]);
                }
            });
    }

    public function down(): void
    {
        if (! Schema::hasTable('manual_payment_requests') || ! Schema::hasColumn('manual_payment_requests', 'department')) {
            return;
        }

        Schema::table('manual_payment_requests', static function (Blueprint $table): void {
            $table->dropIndex(['department']);
            $table->dropColumn('department');
        });
    }
};