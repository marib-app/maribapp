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
                DB::statement(sprintf(
                    "UPDATE `payment_transactions` SET `payment_status` = '%s' WHERE LOWER(`payment_status`) = '%s'",
                    $status,
                    $status
                ));
            }

            DB::statement("
                DELETE pt FROM payment_transactions pt
                JOIN (
                    SELECT
                        MAX(id) AS keep_id,
                        payable_type,
                        payable_id,
                        payment_gateway,
                        COALESCE(payment_status, '') AS status_key,
                        COUNT(*) AS cnt
                    FROM payment_transactions
                    GROUP BY payable_type, payable_id, payment_gateway, status_key
                    HAVING cnt > 1
                ) dup
                ON dup.payable_type = pt.payable_type
                    AND dup.payable_id = pt.payable_id
                    AND dup.payment_gateway = pt.payment_gateway
                    AND dup.status_key = COALESCE(pt.payment_status, '')
                WHERE pt.id <> dup.keep_id
            ");

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
