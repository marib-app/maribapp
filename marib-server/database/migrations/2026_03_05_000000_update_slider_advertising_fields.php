<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('sliders')) {
            return;
        }

        Schema::table('sliders', function (Blueprint $table) {
            if (! Schema::hasColumn('sliders', 'priority')) {
                $table->unsignedInteger('priority')->default(0)->after('sequence');
            }

            if (! Schema::hasColumn('sliders', 'weight')) {
                $table->unsignedInteger('weight')->default(1)->after('priority');
            }

            if (! Schema::hasColumn('sliders', 'share_of_voice')) {
                $table->decimal('share_of_voice', 5, 2)->default(0)->after('weight');
            }

            if (! Schema::hasColumn('sliders', 'status')) {
                $table->string('status', 32)->default('active')->after('share_of_voice');
            }

            if (! Schema::hasColumn('sliders', 'starts_at')) {
                $table->timestamp('starts_at')->nullable()->after('status');
            }

            if (! Schema::hasColumn('sliders', 'ends_at')) {
                $table->timestamp('ends_at')->nullable()->after('starts_at');
            }

            if (! Schema::hasColumn('sliders', 'dayparting_json')) {
                $table->json('dayparting_json')->nullable()->after('ends_at');
            }

            if (! Schema::hasColumn('sliders', 'per_user_per_day_limit')) {
                $table->unsignedInteger('per_user_per_day_limit')->nullable()->after('dayparting_json');
            }

            if (! Schema::hasColumn('sliders', 'per_user_per_session_limit')) {
                $table->unsignedInteger('per_user_per_session_limit')->nullable()->after('per_user_per_day_limit');
            }
        });

        Schema::table('sliders', function (Blueprint $table) {
            if (! $this->hasIndex('sliders', 'sliders_status_priority_index')) {
                $table->index(['status', 'priority'], 'sliders_status_priority_index');
            }

            if (! $this->hasIndex('sliders', 'sliders_starts_at_index')) {
                $table->index('starts_at', 'sliders_starts_at_index');
            }

            if (! $this->hasIndex('sliders', 'sliders_ends_at_index')) {
                $table->index('ends_at', 'sliders_ends_at_index');
            }
        });

        DB::table('sliders')->update([
            'status'    => 'active',
            'priority'  => 0,
            'weight'    => 1,
            'share_of_voice' => 0,
        ]);
    }

    public function down(): void
    {
        if (! Schema::hasTable('sliders')) {
            return;
        }

        Schema::table('sliders', function (Blueprint $table) {
            if ($this->hasIndex('sliders', 'sliders_status_priority_index')) {
                $table->dropIndex('sliders_status_priority_index');
            }

            if ($this->hasIndex('sliders', 'sliders_starts_at_index')) {
                $table->dropIndex('sliders_starts_at_index');
            }

            if ($this->hasIndex('sliders', 'sliders_ends_at_index')) {
                $table->dropIndex('sliders_ends_at_index');
            }

            $columns = [
                'per_user_per_session_limit',
                'per_user_per_day_limit',
                'dayparting_json',
                'ends_at',
                'starts_at',
                'status',
                'share_of_voice',
                'weight',
                'priority',
            ];

            foreach ($columns as $column) {
                if (Schema::hasColumn('sliders', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }

    private function hasIndex(string $table, string $indexName): bool
    {
        try {
            $schemaManager = Schema::getConnection()->getDoctrineSchemaManager();

            return array_key_exists($indexName, $schemaManager->listTableIndexes($table));
        } catch (\Throwable) {
            return false;
        }
    }
};