<?php

use App\Models\ManualPaymentRequest;
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

        $charactersToTrim = " \t\n\r\0\x0B\"'";

        $tokens = collect(ManualPaymentRequest::orderPayableTypeTokens())
            ->map(static fn ($token) => strtolower(trim((string) $token, $charactersToTrim)))
            ->filter(static fn ($token) => $token !== '')
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        DB::table('manual_payment_requests')
            ->select(['id', 'payable_type', 'payable_id'])
            ->whereNull('department')
            ->whereNotNull('payable_id')
            ->orderBy('id')
            ->chunkById(200, static function ($rows) use ($tokens, $charactersToTrim): void {
                $orderIds = collect($rows)
                    ->filter(static function ($row) use ($tokens, $charactersToTrim): bool {
                        if (! is_string($row->payable_type)) {
                            return false;
                        }

                        $normalized = strtolower(trim($row->payable_type, $charactersToTrim));

                        return $normalized !== '' && in_array($normalized, $tokens, true);
                    })
                    ->map(static fn ($row) => is_numeric($row->payable_id) ? (int) $row->payable_id : null)
                    ->filter(static fn ($id) => $id !== null)
                    ->unique()
                    ->values()
                    ->all();

                if ($orderIds === []) {
                    return;
                }

                $departments = DB::table('orders')
                    ->whereIn('id', $orderIds)
                    ->pluck('department', 'id');

                foreach ($rows as $row) {
                    if (! is_string($row->payable_type)) {
                        continue;
                    }

                    $normalized = strtolower(trim($row->payable_type, $charactersToTrim));

                    if ($normalized === '' || ! in_array($normalized, $tokens, true)) {
                        continue;
                    }

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