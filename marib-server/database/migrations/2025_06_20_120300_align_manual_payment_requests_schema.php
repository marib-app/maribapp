<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('manual_payment_requests')) {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (!Schema::hasColumn('manual_payment_requests', 'manual_bank_id')) {
                $table->foreignId('manual_bank_id')
                    ->nullable()
                    ->after('user_id')
                    ->constrained('manual_banks')
                    ->restrictOnDelete();
            }

            if (Schema::hasColumn('manual_payment_requests', 'payable_type')) {
                $table->string('payable_type')->nullable()->change();
            }

            if (Schema::hasColumn('manual_payment_requests', 'payable_id')) {
                $table->unsignedBigInteger('payable_id')->nullable()->change();
            }
        });

        if (Schema::hasColumn('manual_payment_requests', 'reference_number') && !Schema::hasColumn('manual_payment_requests', 'reference')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                $table->renameColumn('reference_number', 'reference');
            });
        } elseif (!Schema::hasColumn('manual_payment_requests', 'reference')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                $table->string('reference')->nullable()->after('bank_swift_code');
            });
        }

        if (Schema::hasColumn('manual_payment_requests', 'note') && !Schema::hasColumn('manual_payment_requests', 'user_note')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                $table->renameColumn('note', 'user_note');
            });
        } elseif (!Schema::hasColumn('manual_payment_requests', 'user_note')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                $table->text('user_note')->nullable()->after('reference');
            });
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (Schema::hasColumn('manual_payment_requests', 'receipt_path')) {
                $table->string('receipt_path', 2048)->nullable()->change();
            } else {
                $table->string('receipt_path', 2048)->nullable()->after('user_note');
            }

            if (Schema::hasColumn('manual_payment_requests', 'currency')) {
                $table->string('currency', 8)->nullable()->change();
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('manual_payment_requests')) {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (Schema::hasColumn('manual_payment_requests', 'manual_bank_id')) {
                $table->dropForeign(['manual_bank_id']);
                $table->dropColumn('manual_bank_id');
            }

            if (Schema::hasColumn('manual_payment_requests', 'payable_type')) {
                $table->string('payable_type')->nullable(false)->change();
            }

            if (Schema::hasColumn('manual_payment_requests', 'payable_id')) {
                $table->unsignedBigInteger('payable_id')->nullable(false)->change();
            }
        });

        if (Schema::hasColumn('manual_payment_requests', 'reference') && !Schema::hasColumn('manual_payment_requests', 'reference_number')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                $table->renameColumn('reference', 'reference_number');
            });
        }

        if (Schema::hasColumn('manual_payment_requests', 'user_note') && !Schema::hasColumn('manual_payment_requests', 'note')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                $table->renameColumn('user_note', 'note');
            });
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (Schema::hasColumn('manual_payment_requests', 'receipt_path')) {
                $table->string('receipt_path', 255)->nullable()->change();
            }

            if (Schema::hasColumn('manual_payment_requests', 'currency')) {
                $table->string('currency', 3)->nullable()->change();
            }
        });
    }
};
