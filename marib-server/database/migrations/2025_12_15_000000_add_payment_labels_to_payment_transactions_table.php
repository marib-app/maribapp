<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('payment_transactions', static function (Blueprint $table): void {
            if (! Schema::hasColumn('payment_transactions', 'payment_gateway_name')) {
                $table->string('payment_gateway_name')->nullable()->after('payment_gateway');
            }

            if (! Schema::hasColumn('payment_transactions', 'gateway_label')) {
                $afterColumn = Schema::hasColumn('payment_transactions', 'payment_gateway_name')
                    ? 'payment_gateway_name'
                    : 'payment_gateway';

                $table->string('gateway_label')->nullable()->after($afterColumn);
            }

            if (! Schema::hasColumn('payment_transactions', 'channel_label')) {
                $afterColumn = 'payment_gateway';

                if (Schema::hasColumn('payment_transactions', 'gateway_label')) {
                    $afterColumn = 'gateway_label';
                } elseif (Schema::hasColumn('payment_transactions', 'payment_gateway_name')) {
                    $afterColumn = 'payment_gateway_name';
                }

                $table->string('channel_label')->nullable()->after($afterColumn);
            }

            if (! Schema::hasColumn('payment_transactions', 'payment_gateway_label')) {
                $afterColumn = 'payment_gateway';

                if (Schema::hasColumn('payment_transactions', 'channel_label')) {
                    $afterColumn = 'channel_label';
                } elseif (Schema::hasColumn('payment_transactions', 'gateway_label')) {
                    $afterColumn = 'gateway_label';
                } elseif (Schema::hasColumn('payment_transactions', 'payment_gateway_name')) {
                    $afterColumn = 'payment_gateway_name';
                }

                $table->string('payment_gateway_label')->nullable()->after($afterColumn);
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('payment_transactions', static function (Blueprint $table): void {
            if (Schema::hasColumn('payment_transactions', 'payment_gateway_label')) {
                $table->dropColumn('payment_gateway_label');
            }

            if (Schema::hasColumn('payment_transactions', 'channel_label')) {
                $table->dropColumn('channel_label');
            }

            if (Schema::hasColumn('payment_transactions', 'gateway_label')) {
                $table->dropColumn('gateway_label');
            }

            if (Schema::hasColumn('payment_transactions', 'payment_gateway_name')) {
                $table->dropColumn('payment_gateway_name');
            }
        });
    }
}; 