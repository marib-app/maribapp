<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (!Schema::hasColumn('manual_payment_requests', 'currency')) {
                $table->string('currency', 8)->nullable()->after('amount');
            }
        });
    }

    public function down(): void
    {
        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (Schema::hasColumn('manual_payment_requests', 'currency')) {
                $table->dropColumn('currency');
            }
        });
    }
};
