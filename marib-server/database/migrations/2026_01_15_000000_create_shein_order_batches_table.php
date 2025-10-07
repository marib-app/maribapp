<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('shein_order_batches', function (Blueprint $table) {
            $table->id();
            $table->string('reference')->unique();
            $table->date('batch_date')->nullable();
            $table->string('status')->default('draft');
            $table->decimal('deposit_amount', 12, 2)->default(0);
            $table->decimal('outstanding_amount', 12, 2)->default(0);
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();
        });

        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'shein_batch_id')) {
                $table->foreignId('shein_batch_id')
                    ->nullable()
                    ->after('department')
                    ->constrained('shein_order_batches')
                    ->nullOnDelete();
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'shein_batch_id')) {
                $table->dropConstrainedForeignId('shein_batch_id');
            }
        });

        Schema::dropIfExists('shein_order_batches');
    }
};