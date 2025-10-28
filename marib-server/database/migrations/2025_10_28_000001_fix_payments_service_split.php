<?php

use App\Models\ServiceRequest;
use Carbon\Carbon;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('payment_transactions')) {
            DB::statement("UPDATE `payment_transactions` SET `payment_status` = NULLIF(TRIM(`payment_status`), '')");

            $activeStatuses = ['pending', 'initiated', 'processing'];

            foreach ($activeStatuses as $status) {
                DB::table('payment_transactions')
                    ->whereNotNull('payment_status')
                    ->whereRaw('LOWER(payment_status) = ?', [$status])
                    ->update(['payment_status' => $status]);
            }

            $activeDuplicateRows = DB::table('payment_transactions')
                ->select('id', 'payable_type', 'payable_id', 'payment_gateway', 'payment_status')
                ->whereIn(DB::raw('LOWER(COALESCE(payment_status, ""))'), $activeStatuses)
                ->orderBy('payable_type')
                ->orderBy('payable_id')
                ->orderBy('payment_gateway')
                ->orderBy('id')
                ->get();

            $seen = [];
            foreach ($activeDuplicateRows as $row) {
                $key = sprintf(
                    '%s|%s|%s|%s',
                    $row->payable_type,
                    $row->payable_id,
                    $row->payment_gateway,
                    strtolower($row->payment_status ?? '')
                );

                if (! array_key_exists($key, $seen)) {
                    $seen[$key] = $row->id;
                    continue;
                }

                $newStatus = sprintf('%s_dup_%d', $row->payment_status, $row->id);

                if (strlen($newStatus) > 191) {
                    $newStatus = substr($newStatus, 0, 191);
                }

                DB::table('payment_transactions')
                    ->where('id', $row->id)
                    ->update(['payment_status' => $newStatus]);
            }

            $duplicateGroups = DB::table('payment_transactions')
                ->select('payable_type', 'payable_id', 'payment_gateway')
                ->selectRaw("COALESCE(payment_status, '__NULL__') AS status_key")
                ->groupBy('payable_type', 'payable_id', 'payment_gateway', 'status_key')
                ->havingRaw('COUNT(*) > 1')
                ->get();

            foreach ($duplicateGroups as $group) {
                $rows = DB::table('payment_transactions')
                    ->select('id', 'payment_status')
                    ->where('payable_type', $group->payable_type)
                    ->where('payable_id', $group->payable_id)
                    ->where('payment_gateway', $group->payment_gateway)
                    ->when(
                        $group->status_key === '__NULL__',
                        static fn ($query) => $query->whereNull('payment_status'),
                        static fn ($query) => $query->where('payment_status', $group->status_key)
                    )
                    ->orderByDesc('id')
                    ->get();

                $rowsToAdjust = $rows->slice(1);

                foreach ($rowsToAdjust as $row) {
                    $fallback = $group->status_key === '__NULL__' ? null : $group->status_key;
                    $newStatusBase = $fallback ?: 'archived';
                    $newStatus = sprintf('%s_dup_%d', $newStatusBase, $row->id);

                    if (strlen($newStatus) > 191) {
                        $newStatus = substr($newStatus, 0, 191);
                    }

                    DB::table('payment_transactions')
                        ->where('id', $row->id)
                        ->update(['payment_status' => $newStatus]);
                }
            }

            $residualDuplicates = DB::table('payment_transactions as pt')
                ->join(DB::raw('(
                    SELECT payable_type, payable_id, payment_gateway,
                        COALESCE(payment_status, "__NULL__") AS status_key,
                        MIN(id) AS keep_id,
                        COUNT(*) AS total
                    FROM payment_transactions
                    GROUP BY payable_type, payable_id, payment_gateway, status_key
                    HAVING COUNT(*) > 1
                ) dup'), function ($join): void {
                    $join->on('pt.payable_type', '=', 'dup.payable_type')
                        ->on('pt.payable_id', '=', 'dup.payable_id')
                        ->on('pt.payment_gateway', '=', 'dup.payment_gateway')
                        ->on(DB::raw('COALESCE(pt.payment_status, "__NULL__")'), '=', 'dup.status_key');
                })
                ->whereColumn('pt.id', '!=', 'dup.keep_id')
                ->select('pt.id', 'pt.payment_status')
                ->get();

            foreach ($residualDuplicates as $row) {
                $base = $row->payment_status;
                if ($base === null || trim($base) === '') {
                    $base = 'archived';
                }

                $newStatus = sprintf('%s_dup_%d', $base, $row->id);
                if (strlen($newStatus) > 191) {
                    $newStatus = substr($newStatus, 0, 191);
                }

                DB::table('payment_transactions')
                    ->where('id', $row->id)
                    ->update(['payment_status' => $newStatus]);
            }

            $nullStatusDuplicates = DB::table('payment_transactions')
                ->select('payable_type', 'payable_id', 'payment_gateway')
                ->whereNull('payment_status')
                ->groupBy('payable_type', 'payable_id', 'payment_gateway')
                ->havingRaw('COUNT(*) > 1')
                ->get();

            foreach ($nullStatusDuplicates as $duplicate) {
                $rows = DB::table('payment_transactions')
                    ->select('id')
                    ->where('payable_type', $duplicate->payable_type)
                    ->where('payable_id', $duplicate->payable_id)
                    ->where('payment_gateway', $duplicate->payment_gateway)
                    ->whereNull('payment_status')
                    ->orderByDesc('id')
                    ->get();

                $rowsToUpdate = $rows->slice(1);

                foreach ($rowsToUpdate as $row) {
                    $newStatus = sprintf('archived_dup_%d', $row->id);
                    DB::table('payment_transactions')
                        ->where('id', $row->id)
                        ->update(['payment_status' => $newStatus]);
                }
            }

            while (true) {
                $duplicate = DB::table('payment_transactions')
                    ->select('payable_type', 'payable_id', 'payment_gateway')
                    ->selectRaw("COALESCE(payment_status, '__NULL__') AS status_key")
                    ->groupBy('payable_type', 'payable_id', 'payment_gateway', 'status_key')
                    ->havingRaw('COUNT(*) > 1')
                    ->first();

                if (! $duplicate) {
                    break;
                }

                $rows = DB::table('payment_transactions')
                    ->select('id', 'payment_status')
                    ->where('payable_type', $duplicate->payable_type)
                    ->where('payable_id', $duplicate->payable_id)
                    ->where('payment_gateway', $duplicate->payment_gateway)
                    ->when(
                        $duplicate->status_key === '__NULL__',
                        static fn ($query) => $query->whereNull('payment_status'),
                        static fn ($query) => $query->where('payment_status', $duplicate->status_key)
                    )
                    ->orderBy('id')
                    ->get();

                if ($rows->count() <= 1) {
                    continue;
                }

                $rows->shift();

                foreach ($rows as $row) {
                    $base = $row->payment_status;
                    if ($base === null || trim((string) $base) === '') {
                        $base = 'archived';
                    }

                    $newStatus = sprintf('%s_dup_%d', $base, $row->id);
                    if (strlen($newStatus) > 191) {
                        $newStatus = substr($newStatus, 0, 191);
                    }

                    DB::table('payment_transactions')
                        ->where('id', $row->id)
                        ->update(['payment_status' => $newStatus]);
                }
            }

            Schema::table('payment_transactions', function (Blueprint $table): void {
                if ($this->indexExists('payment_transactions', 'payment_transactions_payment_gateway_order_id_unique')) {
                    $table->dropUnique('payment_transactions_payment_gateway_order_id_unique');
                }

                if (! Schema::hasColumn('payment_transactions', 'idempotency_key')) {
                    $table->string('idempotency_key', 64)->nullable()->after('payment_signature');
                }

                if (! $this->indexExists('payment_transactions', 'payment_transactions_payable_type_payable_id_index')) {
                    $table->index(['payable_type', 'payable_id'], 'payment_transactions_payable_type_payable_id_index');
                }

                if (! $this->indexExists('payment_transactions', 'payment_transactions_idempotency_key_unique')) {
                    $table->unique('idempotency_key', 'payment_transactions_idempotency_key_unique');
                }

                if (! $this->indexExists('payment_transactions', 'payment_transactions_active_gateway_unique')) {
                    $table->unique(
                        ['payable_type', 'payable_id', 'payment_gateway', 'payment_status'],
                        'payment_transactions_active_gateway_unique'
                    );
                }
            });

            DB::table('payment_transactions')
                ->where('payable_type', '=', ServiceRequest::class)
                ->whereNotNull('order_id')
                ->update(['order_id' => null]);

            DB::table('payment_transactions')
                ->whereNull('idempotency_key')
                ->update([
                    'idempotency_key' => DB::raw("CONCAT('pt_', LPAD(id, 16, '0'))"),
                ]);
        }

        if (Schema::hasTable('service_requests')) {
            Schema::table('service_requests', function (Blueprint $table): void {
                if (! Schema::hasColumn('service_requests', 'request_number')) {
                    $table->string('request_number', 50)->nullable()->after('id');
                }

                if (! $this->indexExists('service_requests', 'service_requests_request_number_unique')) {
                    $table->unique('request_number', 'service_requests_request_number_unique');
                }
            });

            $requests = DB::table('service_requests')
                ->select('id', 'request_number', 'created_at')
                ->orderBy('id')
                ->get();

            foreach ($requests as $request) {
                if (! empty($request->request_number)) {
                    continue;
                }

                $createdAt = $request->created_at ? Carbon::parse($request->created_at) : now();
                $prefix = 'SR-' . $createdAt->format('Ymd');
                $suffix = str_pad((string) $request->id, 6, '0', STR_PAD_LEFT);
                $candidate = $prefix . '-' . $suffix;

                $counter = 0;
                while (
                    DB::table('service_requests')
                        ->where('request_number', $candidate)
                        ->where('id', '!=', $request->id)
                        ->exists()
                ) {
                    $counter++;
                    $candidate = sprintf('%s-%s-%02d', $prefix, $suffix, $counter);
                }

                DB::table('service_requests')
                    ->where('id', $request->id)
                    ->update(['request_number' => $candidate]);
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('payment_transactions')) {
            Schema::table('payment_transactions', function (Blueprint $table): void {
                if ($this->indexExists('payment_transactions', 'payment_transactions_active_gateway_unique')) {
                    $table->dropUnique('payment_transactions_active_gateway_unique');
                }

                if ($this->indexExists('payment_transactions', 'payment_transactions_idempotency_key_unique')) {
                    $table->dropUnique('payment_transactions_idempotency_key_unique');
                }

                if ($this->indexExists('payment_transactions', 'payment_transactions_payable_type_payable_id_index')) {
                    $table->dropIndex('payment_transactions_payable_type_payable_id_index');
                }

                if (Schema::hasColumn('payment_transactions', 'idempotency_key')) {
                    $table->dropColumn('idempotency_key');
                }

                if (! $this->indexExists('payment_transactions', 'payment_transactions_payment_gateway_order_id_unique')) {
                    $table->unique(['payment_gateway', 'order_id'], 'payment_transactions_payment_gateway_order_id_unique');
                }
            });
        }

        if (Schema::hasTable('service_requests')) {
            Schema::table('service_requests', function (Blueprint $table): void {
                if ($this->indexExists('service_requests', 'service_requests_request_number_unique')) {
                    $table->dropUnique('service_requests_request_number_unique');
                }

                if (Schema::hasColumn('service_requests', 'request_number')) {
                    $table->dropColumn('request_number');
                }
            });
        }
    }

    private function indexExists(string $table, string $index): bool
    {
        $connection = config('database.default');
        $database = config("database.connections.{$connection}.database");

        $result = DB::select(
            'SELECT COUNT(*) AS aggregate FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND INDEX_NAME = ?',
            [$database, $table, $index]
        );

        return isset($result[0]) && (int) $result[0]->aggregate > 0;
    }
};
