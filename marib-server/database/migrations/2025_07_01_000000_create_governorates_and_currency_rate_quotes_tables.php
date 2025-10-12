<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('governorates', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->string('name');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('currency_rate_quotes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('currency_rate_id')->constrained()->cascadeOnDelete();
            $table->foreignId('governorate_id')->constrained()->cascadeOnDelete();
            $table->decimal('sell_price', 12, 4);
            $table->decimal('buy_price', 12, 4);
            $table->string('source')->nullable();
            $table->timestamp('quoted_at')->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamps();

            $table->unique(['currency_rate_id', 'governorate_id'], 'currency_rate_governorate_unique');
            $table->index(['currency_rate_id', 'is_default']);
        });

        $now = now();
        $defaultGovernorateId = DB::table('governorates')->insertGetId([
            'code' => 'NATL',
            'name' => 'National Market Average',
            'is_active' => true,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $existingCurrencies = DB::table('currency_rates')->select('id', 'sell_price', 'buy_price', 'last_updated_at')->get();

        foreach ($existingCurrencies as $currency) {
            $quotedAt = $currency->last_updated_at ?? $now;

            DB::table('currency_rate_quotes')->insert([
                'currency_rate_id' => $currency->id,
                'governorate_id' => $defaultGovernorateId,
                'sell_price' => $currency->sell_price ?? 0,
                'buy_price' => $currency->buy_price ?? 0,
                'source' => null,
                'quoted_at' => $quotedAt,
                'is_default' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('currency_rate_quotes');
        Schema::dropIfExists('governorates');
    }
};