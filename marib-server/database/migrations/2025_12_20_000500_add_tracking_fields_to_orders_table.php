<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'tracking_number')) {
                $table->string('tracking_number')->nullable();
            }

            if (! Schema::hasColumn('orders', 'carrier_name')) {
                $table->string('carrier_name')->nullable();
            }

            if (! Schema::hasColumn('orders', 'tracking_url')) {
                $table->string('tracking_url', 2048)->nullable();
            }

            if (! Schema::hasColumn('orders', 'delivery_proof_image_path')) {
                $table->string('delivery_proof_image_path', 2048)->nullable();
            }

            if (! Schema::hasColumn('orders', 'delivery_proof_signature_path')) {
                $table->string('delivery_proof_signature_path', 2048)->nullable();
            }

            if (! Schema::hasColumn('orders', 'delivery_proof_otp_code')) {
                $table->string('delivery_proof_otp_code', 64)->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'delivery_proof_otp_code')) {
                $table->dropColumn('delivery_proof_otp_code');
            }

            if (Schema::hasColumn('orders', 'delivery_proof_signature_path')) {
                $table->dropColumn('delivery_proof_signature_path');
            }

            if (Schema::hasColumn('orders', 'delivery_proof_image_path')) {
                $table->dropColumn('delivery_proof_image_path');
            }

            if (Schema::hasColumn('orders', 'tracking_url')) {
                $table->dropColumn('tracking_url');
            }

            if (Schema::hasColumn('orders', 'carrier_name')) {
                $table->dropColumn('carrier_name');
            }

            if (Schema::hasColumn('orders', 'tracking_number')) {
                $table->dropColumn('tracking_number');
            }
        });
    }
};