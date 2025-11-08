<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Carbon;

return new class extends Migration {
    public function up(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        if (Schema::hasColumn('manual_payment_requests', 'status')) {
            DB::statement("ALTER TABLE manual_payment_requests MODIFY COLUMN status ENUM('pending','under_review','approved','rejected') NOT NULL DEFAULT 'pending'");
        }

        Schema::table('manual_payment_requests', static function (Blueprint $table): void {
            if (! Schema::hasColumn('manual_payment_requests', 'is_open')) {
                $table->boolean('is_open')
                    ->storedAs("(status in ('pending','under_review'))")
                    ->after('status');
            }

            if (! Schema::hasColumn('manual_payment_requests', 'open_unique_key')) {
                $table->string('open_unique_key', 512)
                    ->storedAs(
                        "case when status in ('pending','under_review') " .
                        "and payable_type is not null and payable_id is not null " .
                        "then concat(payable_type, '#', payable_id) else null end"
                    )
                    ->after('is_open');
            }

        });

        $now = Carbon::now()->toDateTimeString();
        $openStatuses = ['pending', 'under_review'];

        $duplicateGroups = DB::table('manual_payment_requests')
            ->select('payable_type', 'payable_id')
            ->whereIn('status', $openStatuses)
            ->whereNotNull('payable_type')
            ->whereNotNull('payable_id')
            ->groupBy('payable_type', 'payable_id')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($duplicateGroups as $group) {
            $idToKeepOpen = DB::table('manual_payment_requests')

                ->where('payable_type', $group->payable_type)
                ->where('payable_id', $group->payable_id)
                ->whereIn('status', $openStatuses)
                ->orderByDesc('id')
                ->value('id');

            if ($idToKeepOpen === null) {
                continue;
            }

            $idsToClose = DB::table('manual_payment_requests')
                ->where('payable_type', $group->payable_type)
                ->where('payable_id', $group->payable_id)
                ->whereIn('status', $openStatuses)
                ->where('id', '!=', $idToKeepOpen)
                ->pluck('id');

            foreach ($idsToClose as $requestId) {
                $existingNote = DB::table('manual_payment_requests')
                    ->where('id', $requestId)
                    ->value('admin_note');

                $note = trim((string) $existingNote);
                $note = $note !== '' ? ($note . ' — ') : '';
                $note .= sprintf(
                    'Auto-closed on %s due to duplicate open manual payment request enforcement.',
                    $now
                );

                DB::table('manual_payment_requests')
                    ->where('id', $requestId)
                    ->update([
                        'status' => 'rejected',
                        'admin_note' => $note,
                    ]);
            }
        }

        Schema::table('manual_payment_requests', static function (Blueprint $table): void {
            if (! Schema::hasColumn('manual_payment_requests', 'open_unique_key')) {
                return;
            }

            $table->unique(
                'open_unique_key',
                'manual_payment_requests_open_unique_key_unique'
            );
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('manual_payment_requests', static function (Blueprint $table): void {
            if (Schema::hasColumn('manual_payment_requests', 'open_unique_key')) {
                $table->dropUnique('manual_payment_requests_open_unique_key_unique');
                $table->dropColumn('open_unique_key');
            }

            if (Schema::hasColumn('manual_payment_requests', 'is_open')) {
                $table->dropColumn('is_open');
            }
        });

        if (Schema::hasColumn('manual_payment_requests', 'status')) {
            DB::statement("ALTER TABLE manual_payment_requests MODIFY COLUMN status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending'");
        }
    }
};
