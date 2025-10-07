<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('services', function (Blueprint $t) {
            $t->boolean('is_paid')->default(false);
            $t->decimal('price', 12, 2)->nullable();
            $t->enum('currency', ['YER','USD','SAR'])->nullable();
            $t->text('price_note')->nullable();

            $t->boolean('has_custom_fields')->default(false);

            $t->boolean('direct_to_user')->default(false);
            $t->foreignId('direct_user_id')->nullable()->constrained('users')->nullOnDelete();

            $t->string('service_uid', 26)->unique()->nullable(); // لاستخدامه بالتقييمات لاحقًا
        });
    }

    public function down(): void
    {
        Schema::table('services', function (Blueprint $t) {
            $t->dropColumn(['is_paid','price','currency','price_note','has_custom_fields','direct_to_user']);
            $t->dropConstrainedForeignId('direct_user_id');
            $t->dropColumn('service_uid');
        });
    }
};
