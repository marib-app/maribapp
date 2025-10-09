<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('custom_fields', static function (Blueprint $table) {
            if (! Schema::hasColumn('custom_fields', 'required_for_checkout')) {
                $table->boolean('required_for_checkout')->default(false)->after('required');
            }

            if (! Schema::hasColumn('custom_fields', 'allowed_values')) {
                $table->text('allowed_values')->nullable()->after('values');
            }

            if (! Schema::hasColumn('custom_fields', 'affects_stock')) {
                $table->boolean('affects_stock')->default(false)->after('allowed_values');
            }
        });
    }

    public function down(): void
    {
        Schema::table('custom_fields', static function (Blueprint $table) {
            if (Schema::hasColumn('custom_fields', 'affects_stock')) {
                $table->dropColumn('affects_stock');
            }
            if (Schema::hasColumn('custom_fields', 'allowed_values')) {
                $table->dropColumn('allowed_values');
            }
            if (Schema::hasColumn('custom_fields', 'required_for_checkout')) {
                $table->dropColumn('required_for_checkout');
            }
        });
    }
};