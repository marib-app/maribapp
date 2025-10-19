<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('metal_rate_quotes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('metal_rate_id')->constrained()->cascadeOnDelete();
            $table->foreignId('governorate_id')->constrained()->cascadeOnDelete();
            $table->decimal('sell_price', 12, 3);
            $table->decimal('buy_price', 12, 3);
            $table->string('source')->nullable();
            $table->timestamp('quoted_at')->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamps();

            $table->unique(['metal_rate_id', 'governorate_id'], 'metal_rate_governorate_unique');
            $table->index(['metal_rate_id', 'is_default']);
        });

        Schema::create('metal_rate_change_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('metal_rate_id')->constrained()->cascadeOnDelete();
            $table->foreignId('governorate_id')->nullable()->constrained()->nullOnDelete();
            $table->string('change_type', 20);
            $table->json('previous_values')->nullable();
            $table->json('new_values')->nullable();
            $table->foreignId('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('changed_at')->useCurrent();
            $table->timestamps();

            $table->index(['metal_rate_id', 'governorate_id']);
            $table->index('changed_at');
            $table->index('change_type');
        });

        $now = now();

        $defaultGovernorateId = DB::table('governorates')
            ->where('code', 'NATL')
            ->value('id');

        if (!$defaultGovernorateId) {
            $defaultGovernorateId = DB::table('governorates')->insertGetId([
                'code' => 'NATL',
                'name' => 'National Market Average',
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $existingRates = DB::table('metal_rates')
            ->select('id', 'sell_price', 'buy_price', 'source', 'quoted_at', 'created_at', 'updated_at')
            ->get();

        foreach ($existingRates as $rate) {
            DB::table('metal_rate_quotes')->insert([
                'metal_rate_id' => $rate->id,
                'governorate_id' => $defaultGovernorateId,
                'sell_price' => $rate->sell_price ?? 0,
                'buy_price' => $rate->buy_price ?? 0,
                'source' => $rate->source,
                'quoted_at' => $rate->quoted_at ?? $rate->updated_at ?? $now,
                'is_default' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('metal_rate_change_logs');
        Schema::dropIfExists('metal_rate_quotes');
    }
};