<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('department_number_settings')) {
            return;
        }

        Schema::table('department_number_settings', static function (Blueprint $table): void {
            if (! Schema::hasColumn('department_number_settings', 'payment_prefix')) {
                $table->string('payment_prefix')->nullable()->after('invoice_prefix');
            }

            if (! Schema::hasColumn('department_number_settings', 'next_payment_number')) {
                $table->unsignedBigInteger('next_payment_number')->default(1)->after('next_invoice_number');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('department_number_settings')) {
            return;
        }

        Schema::table('department_number_settings', static function (Blueprint $table): void {
            if (Schema::hasColumn('department_number_settings', 'next_payment_number')) {
                $table->dropColumn('next_payment_number');
            }

            if (Schema::hasColumn('department_number_settings', 'payment_prefix')) {
                $table->dropColumn('payment_prefix');
            }
        });
    }
};