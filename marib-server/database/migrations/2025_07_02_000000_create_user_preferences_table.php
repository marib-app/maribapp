<?php

use App\Enums\NotificationFrequency;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('favorite_governorate_id')->nullable()->constrained('governorates')->nullOnDelete();
            $table->json('currency_watchlist')->nullable();
            $table->json('metal_watchlist')->nullable();
            $table->string('notification_frequency')->default(NotificationFrequency::DAILY->value);
            $table->timestamps();

            $table->unique('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_preferences');
    }
};