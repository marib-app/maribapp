<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (! Schema::hasColumn('manual_payment_requests', 'currency')) {
                $table->string('currency', 8)->nullable()->after('amount');
            }

            if (! Schema::hasColumn('manual_payment_requests', 'bank_name')) {
                $table->string('bank_name')->nullable()->after('currency');
            }

            if (! Schema::hasColumn('manual_payment_requests', 'bank_account_name')) {
                $table->string('bank_account_name')->nullable()->after('bank_name');
            }

            if (! Schema::hasColumn('manual_payment_requests', 'bank_account_number')) {
                $table->string('bank_account_number')->nullable()->after('bank_account_name');
            }

            if (! Schema::hasColumn('manual_payment_requests', 'bank_iban')) {
                $table->string('bank_iban')->nullable()->after('bank_account_number');
            }

            if (! Schema::hasColumn('manual_payment_requests', 'bank_swift_code')) {
                $table->string('bank_swift_code')->nullable()->after('bank_iban');
            }

            if (! Schema::hasColumn('manual_payment_requests', 'meta')) {
                $table->json('meta')->nullable()->after('reviewed_at');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            foreach ([
                'meta',
                'bank_swift_code',
                'bank_iban',
                'bank_account_number',
                'bank_account_name',
                'bank_name',
                'currency',
            ] as $column) {
                if (Schema::hasColumn('manual_payment_requests', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};