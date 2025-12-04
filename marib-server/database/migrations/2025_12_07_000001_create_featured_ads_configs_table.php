<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('featured_ads_configs', function (Blueprint $table) {
            $table->id();
            $table->string('name')->nullable();
            $table->unsignedBigInteger('root_category_id');
            $table->string('interface_type')->nullable();
            $table->string('root_identifier')->nullable();
            $table->string('slug')->nullable();
            $table->boolean('enabled')->default(true);
            $table->boolean('enable_ad_slider')->default(true);
            $table->string('style_key')->nullable();
            $table->string('order_mode')->nullable();
            $table->string('title')->nullable();
            $table->unsignedInteger('position')->default(0);
            $table->timestamps();

            $table->index(['root_category_id', 'interface_type']);
            $table->index(['enabled', 'enable_ad_slider']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('featured_ads_configs');
    }
};
