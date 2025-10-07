<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pricing_policies', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('code')->unique();
            $table->text('description')->nullable();
            $table->string('status', 50)->default('draft');
            $table->string('mode', 50)->default('distance_only');
            $table->boolean('is_default')->default(false);
            $table->string('currency', 3)->default(strtoupper(config('app.currency', 'SAR')));
            $table->boolean('free_shipping_enabled')->default(false);
            $table->decimal('free_shipping_threshold', 10, 2)->nullable();
            $table->string('department')->nullable()->index();

            $table->decimal('min_order_total', 10, 2)->nullable();
            $table->decimal('max_order_total', 10, 2)->nullable();
            $table->text('notes')->nullable();
            
            $table->timestamps();


        });

        Schema::create('pricing_weight_tiers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pricing_policy_id')->constrained('pricing_policies')->cascadeOnDelete();
            $table->string('name');
            $table->decimal('min_weight', 10, 2)->default(0);
            $table->decimal('max_weight', 10, 2)->nullable();
            $table->decimal('base_price', 10, 2)->default(0);
            $table->boolean('status')->default(true);

            $table->decimal('price_per_km', 10, 2)->default(0);
            $table->decimal('flat_fee', 10, 2)->default(0);
            $table->integer('sort_order')->default(0);
            $table->text('notes')->nullable();

            $table->timestamps();
        });

        Schema::create('pricing_distance_rules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pricing_policy_id')->nullable()->constrained('pricing_policies')->cascadeOnDelete();
            $table->foreignId('pricing_weight_tier_id')->nullable()->constrained('pricing_weight_tiers')->cascadeOnDelete();
            
            $table->decimal('min_distance', 10, 2);
            $table->decimal('max_distance', 10, 2)->nullable();
            $table->decimal('price', 10, 2)->default(0);


            $table->string('currency', 3)->default(strtoupper(config('app.currency', 'SAR')));
            $table->boolean('is_free_shipping')->default(false);
            $table->boolean('status')->default(true);

            $table->string('price_type', 50)->default('flat');
            $table->string('applies_to', 50)->default('weight_tier');
            $table->integer('sort_order')->default(0);

            $table->timestamps();
            $table->unique(['pricing_policy_id', 'pricing_weight_tier_id', 'min_distance', 'max_distance'], 'pricing_distance_unique_range');


        });

        Schema::create('pricing_audits', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pricing_policy_id')->nullable()->constrained('pricing_policies')->nullOnDelete();
            $table->foreignId('pricing_weight_tier_id')->nullable()->constrained('pricing_weight_tiers')->nullOnDelete();
            $table->foreignId('pricing_distance_rule_id')->nullable()->constrained('pricing_distance_rules')->nullOnDelete();
            $table->string('action');
            $table->json('old_values')->nullable();
            $table->json('new_values')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('performed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        if (Schema::hasTable('delivery_prices')) {
            $currency = strtoupper(config('app.currency', 'SAR'));
            $now = now();
            $hasDepartment = Schema::hasColumn('delivery_prices', 'department');
            $hasStatus = Schema::hasColumn('delivery_prices', 'status');
            $hasDeletedAt = Schema::hasColumn('delivery_prices', 'deleted_at');

            $policies = [];
            $tiers = [];

            $legacyQuery = DB::table('delivery_prices');

            if ($hasDeletedAt) {
                $legacyQuery->whereNull('deleted_at');
            }

            if ($hasDepartment) {
                $legacyQuery->orderBy('department');
            }

            $legacyQuery->orderBy('size');
            $legacyQuery->orderBy('min_distance');

            $legacyData = $legacyQuery->get();



            foreach ($legacyData as $row) {
                $department = $hasDepartment ? ($row->department ?: null) : null;
                $policyKey = $department ?? 'default';

                if (!array_key_exists($policyKey, $policies)) {
                    $codeBase = $department ? 'legacy-'.$department : 'legacy-default';


                    $code = $codeBase;
                    $suffix = 1;
                    while (DB::table('pricing_policies')->where('code', $code)->exists()) {
                        $code = $codeBase.'-'.$suffix++;
                    }

                    $policyId = DB::table('pricing_policies')->insertGetId([
                        'name' => $department ? 'سياسة التسعير - '.$department : 'سياسة التسعير الافتراضية',

                        'code' => $code,
                        'status' => 'active',
                        'is_default' => true,
                        'currency' => $currency,
                        'free_shipping_enabled' => false,
                        'free_shipping_threshold' => null,
                        'department' => $department,
                        

                        'min_order_total' => null,
                        'max_order_total' => null,
                        'notes' => null,


                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);

                    $policies[$policyKey] = $policyId;
                } else {
                    if (!array_key_exists($policyKey, $policies)) {
                        throw new \RuntimeException('Legacy pricing data inconsistent: missing policy mapping for key ['.$policyKey.']');
                    }

                    $policyId = $policies[$policyKey];
                
                }

                $size = $row->size ?: 'افتراضي';
                $tierKey = $policyKey.'|'.$size;
                
                if (!array_key_exists($tierKey, $tiers)) {


                    $nextTierSortOrder = ((int) DB::table('pricing_weight_tiers')
                        ->where('pricing_policy_id', $policyId)
                        ->max('sort_order')) + 1;



                    $tiers[$tierKey] = DB::table('pricing_weight_tiers')->insertGetId([
                        'pricing_policy_id' => $policyId,
                        'name' => $size,
                        'min_weight' => 0,
                        'max_weight' => null,
                        'base_price' => 0,
                        'status' => true,

                        'price_per_km' => 0,
                        'flat_fee' => 0,
                        'sort_order' => $nextTierSortOrder,
                        'notes' => null,

                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }






                $nextRuleSortOrder = ((int) DB::table('pricing_distance_rules')
                    ->where('pricing_weight_tier_id', $tiers[$tierKey])
                    ->max('sort_order')) + 1;



                DB::table('pricing_distance_rules')->insert([
                    'pricing_policy_id' => $policyId,


                    'pricing_weight_tier_id' => $tiers[$tierKey],
                    'min_distance' => $row->min_distance,
                    'max_distance' => $row->max_distance,
                    'price' => $row->price,
                    'currency' => $currency,
                    'is_free_shipping' => (bool) ($row->price <= 0),
                    'status' => $hasStatus ? (bool) $row->status : true,

                    'price_type' => 'flat',
                    'applies_to' => 'weight_tier',
                    'sort_order' => $nextRuleSortOrder,

                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            Schema::dropIfExists('delivery_prices');
        }
    }

    public function down(): void
    {

        $legacyData = collect();

        if (Schema::hasTable('pricing_distance_rules') && Schema::hasTable('pricing_weight_tiers')) {
            $legacyData = DB::table('pricing_distance_rules as rules')
                ->join('pricing_weight_tiers as tiers', 'tiers.id', '=', 'rules.pricing_weight_tier_id')
                ->leftJoin('pricing_policies as policies', 'policies.id', '=', 'tiers.pricing_policy_id')
                ->select([
                    'tiers.name as tier_name',
                    'policies.department',
                    'rules.min_distance',
                    'rules.max_distance',
                    'rules.price',
                    'rules.is_free_shipping',
                    'rules.status',
                ])
                ->get();
        }

        Schema::dropIfExists('pricing_audits');
        Schema::dropIfExists('pricing_distance_rules');
        Schema::dropIfExists('pricing_weight_tiers');
        Schema::dropIfExists('pricing_policies');



        Schema::create('delivery_prices', function (Blueprint $table) {
            $table->id();
            $table->string('size');
            $table->decimal('min_distance', 10, 2);
            $table->decimal('max_distance', 10, 2)->nullable();
            $table->decimal('price', 10, 2)->default(0);
            $table->boolean('status')->default(true);
            $table->string('department')->nullable()->index();
            $table->timestamps();
            $table->softDeletes();
        });

        if ($legacyData->isNotEmpty()) {
            $now = now();

            foreach ($legacyData as $row) {
                DB::table('delivery_prices')->insert([
                    'size' => $row->tier_name ?? 'افتراضي',
                    'department' => $row->department,
                    'min_distance' => $row->min_distance,
                    'max_distance' => $row->max_distance,
                    'price' => $row->is_free_shipping ? 0 : $row->price,
                    'status' => (bool) $row->status,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

    }
};