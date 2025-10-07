<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('pricing_distance_rules')) {
            return;
        }

        if (! Schema::hasColumn('pricing_distance_rules', 'pricing_policy_id')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->foreignId('pricing_policy_id')
                    ->nullable()
                    ->after('id')
                    ->constrained('pricing_policies')
                    ->cascadeOnDelete();
            });
        }

        if (
            Schema::hasColumn('pricing_distance_rules', 'pricing_policy_id') &&
            Schema::hasColumn('pricing_distance_rules', 'pricing_weight_tier_id') &&
            Schema::hasTable('pricing_weight_tiers') &&
            Schema::hasColumn('pricing_weight_tiers', 'pricing_policy_id')
        ) {
            DB::table('pricing_distance_rules as rules')
                ->leftJoin('pricing_weight_tiers as tiers', 'rules.pricing_weight_tier_id', '=', 'tiers.id')
                ->whereNull('rules.pricing_policy_id')
                ->select([
                    'rules.id',
                    'rules.pricing_weight_tier_id',
                    'tiers.pricing_policy_id',
                ])
                
                ->orderBy('rules.id')
                ->chunk(100, function ($rows) {
                    foreach ($rows as $row) {
                        if ($row->pricing_policy_id === null) {
                            throw new \RuntimeException(
                                sprintf(
                                    'Unable to determine pricing_policy_id for pricing_distance_rules record %d (pricing_weight_tier_id: %s).',
                                    $row->id,
                                    $row->pricing_weight_tier_id === null ? 'null' : (string) $row->pricing_weight_tier_id,
                                ),
                            );
                        
                        
                        }

                        DB::table('pricing_distance_rules')
                            ->where('id', $row->id)
                            ->update([
                                'pricing_policy_id' => $row->pricing_policy_id,
                            ]);
                    }
                    });
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('pricing_distance_rules')) {
            return;
        }

        if (Schema::hasColumn('pricing_distance_rules', 'pricing_policy_id')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->dropForeign(['pricing_policy_id']);
                $table->dropColumn('pricing_policy_id');
            });
        }
    }
};