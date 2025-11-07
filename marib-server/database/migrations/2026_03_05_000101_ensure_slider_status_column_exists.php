<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('sliders')) {
            return;
        }

        Schema::table('sliders', function (Blueprint $table): void {
            if (! Schema::hasColumn('sliders', 'status')) {
                $table->string('status', 32)->default('active');
            }
        });

        if (Schema::hasColumn('sliders', 'status')) {
            DB::table('sliders')
                ->whereNull('status')
                ->update(['status' => 'active']);
        }
    }

    public function down(): void
    {
        // intentionally left blank because the column may pre-exist from earlier migrations
    }
};