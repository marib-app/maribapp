<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasTable('wifi_sales')) {
            return;
        }

        Schema::create('wifi_sales', static function (Blueprint $table): void {
            $table->id();
            $table->foreignId('wifi_network_id')->constrained('wifi_networks')->cascadeOnDelete();
            $table->foreignId('wifi_plan_id')->constrained('wifi_plans')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('amount_gross', 14, 4)->default(0);
            $table->decimal('commission_rate', 6, 4)->default(0);
            $table->decimal('commission_amount', 14, 4)->default(0);
            $table->decimal('owner_share_amount', 14, 4)->default(0);
            $table->char('currency', 3)->nullable()->index();
            $table->string('payment_reference')->nullable()->index();
            $table->timestamp('paid_at')->nullable()->index();
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->index(['wifi_network_id', 'paid_at'], 'wifi_sales_network_paid_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wifi_sales');
    }
};
