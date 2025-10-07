<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('custom_fields', function (Blueprint $table) {
            $table->boolean('is_customer_option')->default(false)->after('required')
                ->comment('If true, this field will be shown as an option for customers to select');
            $table->boolean('show_in_filter')->default(false)->after('is_customer_option')
                ->comment('If true, this field will be shown in filters on product listing');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('custom_fields', function (Blueprint $table) {
            $table->dropColumn('is_customer_option');
            $table->dropColumn('show_in_filter');
        });
    }
}; 