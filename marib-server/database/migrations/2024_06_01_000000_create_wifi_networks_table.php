<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private function fkExists(string $table, string $fk): bool
    {
        $db = DB::getDatabaseName();
        $row = DB::selectOne(
            "SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
             WHERE CONSTRAINT_SCHEMA = ? AND TABLE_NAME = ? AND CONSTRAINT_NAME = ?
               AND CONSTRAINT_TYPE = 'FOREIGN KEY' LIMIT 1",
            [$db, $table, $fk]
        );
        return (bool) $row;
    }

    public function up(): void
    {
        // 1) أنشئ الجدول إن لم يكن موجودًا
        if (! Schema::hasTable('wifi_networks')) {
            Schema::create('wifi_networks', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->string('name');
                $table->string('slug')->unique();

                $table->text('description')->nullable();
                $table->string('location_name')->nullable();
                $table->decimal('latitude', 10, 7)->nullable();
                $table->decimal('longitude', 10, 7)->nullable();
                $table->decimal('commission_rate', 5, 2)->default(0);
                $table->decimal('commission_flat', 10, 2)->default(0);
                $table->string('logo_path')->nullable();
                $table->string('login_screenshot_path')->nullable();
                $table->decimal('coverage_radius_km', 6, 2)->nullable();
                $table->json('contacts')->nullable();
                $table->text('notes')->nullable();

                // عمود محفظة + فهرس (بدون FK الآن)
                $table->unsignedBigInteger('wallet_id')->nullable()->index();

                $table->boolean('is_active')->default(true);
                $table->json('meta')->nullable();
                $table->timestamps();

                $table->index(['is_active', 'latitude', 'longitude']);
            });
        } else {
            // 2) في حال الجدول موجود: تأكد من وجود العمود wallet_id
            if (! Schema::hasColumn('wifi_networks', 'wallet_id')) {
                Schema::table('wifi_networks', function (Blueprint $table) {
                    $table->unsignedBigInteger('wallet_id')->nullable()->index();
                });
            }
        }

        // 3) أضِف الـ FK فقط إذا كان جدول المحافظ موجودًا والقيد غير مضاف
        if (Schema::hasTable('wifi_networks') && Schema::hasTable('wallet_accounts')) {
            if (! $this->fkExists('wifi_networks', 'wifi_networks_wallet_id_foreign')) {
                Schema::table('wifi_networks', function (Blueprint $table) {
                    $table->foreign('wallet_id', 'wifi_networks_wallet_id_foreign')
                          ->references('id')->on('wallet_accounts')
                          ->onDelete('set null');
                });
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('wifi_networks')) {
            // إسقاط FK إن وُجد ثم إسقاط الجدول
            if ($this->fkExists('wifi_networks', 'wifi_networks_wallet_id_foreign')) {
                Schema::table('wifi_networks', function (Blueprint $table) {
                    $table->dropForeign('wifi_networks_wallet_id_foreign');
                });
            }
            Schema::drop('wifi_networks');
        }
    }
};
