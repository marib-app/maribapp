<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('currency_rate_hourly_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('currency_rate_id')->constrained()->cascadeOnDelete();
            $table->foreignId('governorate_id')->constrained()->cascadeOnDelete();
            $table->timestamp('hour_start');
            $table->decimal('sell_price', 12, 4);
            $table->decimal('buy_price', 12, 4);
            $table->string('source')->nullable();
            $table->timestamp('captured_at');
            $table->timestamps();

            $table->unique(['currency_rate_id', 'governorate_id', 'hour_start'], 'currency_rate_hour_unique');
            $table->index(['currency_rate_id', 'hour_start']);
            $table->index(['governorate_id', 'hour_start']);
        });

        Schema::create('currency_rate_daily_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('currency_rate_id')->constrained()->cascadeOnDelete();
            $table->foreignId('governorate_id')->constrained()->cascadeOnDelete();
            $table->date('day_start');
            $table->decimal('open_sell', 12, 4);
            $table->decimal('close_sell', 12, 4);
            $table->decimal('high_sell', 12, 4);
            $table->decimal('low_sell', 12, 4);
            $table->decimal('open_buy', 12, 4);
            $table->decimal('close_buy', 12, 4);
            $table->decimal('high_buy', 12, 4);
            $table->decimal('low_buy', 12, 4);
            $table->decimal('change_sell', 12, 4)->default(0);
            $table->decimal('change_sell_percent', 9, 4)->default(0);
            $table->decimal('change_buy', 12, 4)->default(0);
            $table->decimal('change_buy_percent', 9, 4)->default(0);
            $table->unsignedInteger('samples_count')->default(0);
            $table->timestamp('last_sample_at')->nullable();
            $table->timestamps();

            $table->unique(['currency_rate_id', 'governorate_id', 'day_start'], 'currency_rate_day_unique');
            $table->index(['currency_rate_id', 'day_start']);
            $table->index(['governorate_id', 'day_start']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('currency_rate_daily_histories');
        Schema::dropIfExists('currency_rate_hourly_histories');
    }
};