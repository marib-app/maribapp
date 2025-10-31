<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
  public function up(): void {
    Schema::table('manual_payment_requests', function (Blueprint $t) {
      if (!Schema::hasColumn('manual_payment_requests','meta')) {
        $t->json('meta')->nullable()->after('payable_id');
      }
    });
  }
  public function down(): void {
    Schema::table('manual_payment_requests', function (Blueprint $t) {
      if (Schema::hasColumn('manual_payment_requests','meta')) {
        $t->dropColumn('meta');
      }
    });
  }
};
