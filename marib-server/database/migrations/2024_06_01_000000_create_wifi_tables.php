<?php

use App\Enums\Wifi\WifiCodeBatchStatus;
use App\Enums\Wifi\WifiCodeStatus;
use App\Enums\Wifi\WifiNetworkStatus;
use App\Enums\Wifi\WifiPlanStatus;
use App\Enums\Wifi\WifiReportStatus;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (! Schema::hasTable('wifi_networks')) {
            Schema::create('wifi_networks', static function (Blueprint $table): void {
                $table->id();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->foreignId('wallet_account_id')->nullable()->constrained()->nullOnDelete();
                $table->string('name');
                $table->string('slug')->nullable()->unique();
                $table->string('status')->default(WifiNetworkStatus::INACTIVE->value)->index();
                $table->string('reference_code')->nullable()->unique();
                $table->decimal('latitude', 10, 7)->nullable();
                $table->decimal('longitude', 10, 7)->nullable();
                $table->decimal('coverage_radius_km', 8, 3)->nullable();
                $table->string('address')->nullable();
                $table->string('icon_path')->nullable();
                $table->string('login_screenshot_path')->nullable();
                $table->text('description')->nullable();
                $table->text('notes')->nullable();
                $table->json('currencies')->nullable();
                $table->json('contacts')->nullable();
                $table->json('meta')->nullable();
                $table->json('settings')->nullable();
                $table->json('statistics')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('wifi_plans')) {
            Schema::create('wifi_plans', static function (Blueprint $table): void {
                $table->id();
                $table->foreignId('wifi_network_id')->constrained('wifi_networks')->cascadeOnDelete();
                $table->string('name');
                $table->string('slug')->nullable()->unique();
                $table->string('status')->default(WifiPlanStatus::UPLOADED->value)->index();
                $table->decimal('price', 12, 4)->default(0);
                $table->char('currency', 3)->nullable()->index();
                $table->unsignedSmallInteger('duration_days')->nullable();
                $table->decimal('data_cap_gb', 10, 3)->nullable();
                $table->boolean('is_unlimited')->default(false);
                $table->unsignedInteger('sort_order')->default(0);
                $table->text('description')->nullable();
                $table->text('notes')->nullable();
                $table->json('benefits')->nullable();
                $table->json('meta')->nullable();
                $table->timestamps();
            });
        }


        if (! Schema::hasTable('wifi_code_batches')) {
            Schema::create('wifi_code_batches', static function (Blueprint $table): void {
                $table->id();
                $table->foreignId('wifi_plan_id')->constrained('wifi_plans')->cascadeOnDelete();
                $table->foreignId('uploaded_by')->constrained('users')->cascadeOnDelete();
                $table->string('label');
                $table->string('source_filename');
                $table->string('checksum', 64)->index();
                $table->string('status')->default(WifiCodeBatchStatus::UPLOADED->value)->index();
                $table->unsignedInteger('total_codes')->default(0);
                $table->unsignedInteger('available_codes')->default(0);
                $table->timestamp('validated_at')->nullable();
                $table->timestamp('activated_at')->nullable();
                $table->text('notes')->nullable();
                $table->json('meta')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('wifi_codes')) {
            Schema::create('wifi_codes', static function (Blueprint $table): void {
                $table->id();
                $table->foreignId('wifi_plan_id')->constrained('wifi_plans')->cascadeOnDelete();
                $table->foreignId('wifi_code_batch_id')->nullable()->constrained('wifi_code_batches')->nullOnDelete();
                $table->string('status')->default(WifiCodeStatus::AVAILABLE->value)->index();
                $table->text('code_encrypted')->nullable();
                $table->string('code_suffix', 32)->nullable();
                $table->string('code_hash', 128)->nullable()->unique();
                $table->text('username_encrypted')->nullable();
                $table->text('password_encrypted')->nullable();
                $table->text('serial_no_encrypted')->nullable();
                $table->date('expiry_date')->nullable();
                $table->timestamp('delivered_at')->nullable();
                $table->timestamp('sold_at')->nullable();
                $table->json('meta')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('wifi_reports')) {
            Schema::create('wifi_reports', static function (Blueprint $table): void {
                $table->id();
                $table->foreignId('wifi_network_id')->constrained('wifi_networks')->cascadeOnDelete();
                $table->foreignId('reported_by')->constrained('users')->cascadeOnDelete();
                $table->foreignId('assigned_to')->nullable()->constrained('users')->nullOnDelete();
                $table->string('status')->default(WifiReportStatus::OPEN->value)->index();
                $table->string('category')->nullable();
                $table->string('priority')->nullable();
                $table->string('title');
                $table->text('description')->nullable();
                $table->text('resolution_notes')->nullable();
                $table->json('attachments')->nullable();
                $table->json('meta')->nullable();
                $table->timestamp('reported_at')->nullable();
                $table->timestamp('resolved_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('wifi_reputation_counters')) {
            Schema::create('wifi_reputation_counters', static function (Blueprint $table): void {
                $table->id();
                $table->foreignId('wifi_network_id')->constrained('wifi_networks')->cascadeOnDelete();
                $table->string('metric');
                $table->decimal('score', 8, 2);
                $table->integer('value');
                $table->date('period_start')->nullable();
                $table->date('period_end')->nullable();
                $table->json('meta')->nullable();
                $table->timestamps();
                $table->unique([
                    'wifi_network_id',
                    'metric',
                    'period_start',
                    'period_end',
                ], 'wifi_reputation_counters_unique_metric');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('wifi_reputation_counters');
        Schema::dropIfExists('wifi_reports');
        Schema::dropIfExists('wifi_codes');
        Schema::dropIfExists('wifi_code_batches');
        Schema::dropIfExists('wifi_plans');
        Schema::dropIfExists('wifi_networks');
    }
};