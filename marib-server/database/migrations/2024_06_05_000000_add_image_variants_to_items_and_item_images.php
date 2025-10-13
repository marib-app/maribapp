<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('items', static function (Blueprint $table) {
            $table->string('thumbnail_url', 512)->nullable()->after('image');
            $table->string('detail_image_url', 512)->nullable()->after('thumbnail_url');
        });

        Schema::table('item_images', static function (Blueprint $table) {
            $table->string('thumbnail_url', 512)->nullable()->after('image');
            $table->string('detail_image_url', 512)->nullable()->after('thumbnail_url');
        });
    }

    public function down(): void
    {
        Schema::table('item_images', static function (Blueprint $table) {
            $table->dropColumn(['thumbnail_url', 'detail_image_url']);
        });

        Schema::table('items', static function (Blueprint $table) {
            $table->dropColumn(['thumbnail_url', 'detail_image_url']);
        });
    }
};