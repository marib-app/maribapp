<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        if (!Schema::hasTable('manual_payment_requests')) {
            Schema::create('manual_payment_requests', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->foreignId('manual_bank_id')->constrained('manual_banks')->restrictOnDelete();
                $table->decimal('amount', 12, 2);
                $table->string('reference')->nullable();
                $table->text('user_note')->nullable();
                $table->string('receipt_path', 2048);
                $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
                $table->text('admin_note')->nullable();
                $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('reviewed_at')->nullable();
                $table->nullableMorphs('payable');
                $table->timestamps();
                $table->index('status');
            });

            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (Schema::hasColumn('manual_payment_requests', 'payment_transaction_id')) {
                $table->dropConstrainedForeignId('payment_transaction_id');
            }

            $columnsToDrop = array_filter([
                'currency',
                'bank_name',
                'bank_account_name',
                'bank_account_number',
                'bank_iban',
                'bank_swift_code',
                'meta',
            ], static fn (string $column): bool => Schema::hasColumn('manual_payment_requests', $column));

            if ($columnsToDrop !== []) {
                $table->dropColumn($columnsToDrop);
            }
        });

        if (Schema::hasColumn('manual_payment_requests', 'manual_bank_id')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                $table->dropForeign(['manual_bank_id']);
            });

            Schema::table('manual_payment_requests', function (Blueprint $table) {




                $table->unsignedBigInteger('manual_bank_id')->nullable(false)->change();

            });

            Schema::table('manual_payment_requests', function (Blueprint $table) {

                $table->foreign('manual_bank_id')
                    ->references('id')
                    ->on('manual_banks')
                    ->restrictOnDelete();

            });
        } else {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                
                
                $table->foreignId('manual_bank_id')
                    ->after('user_id')
                    ->constrained('manual_banks')
                    ->restrictOnDelete();
            });
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {


            if (!Schema::hasColumn('manual_payment_requests', 'reference')) {
                $table->string('reference')->nullable()->after('amount');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'user_note')) {
                $table->text('user_note')->nullable()->after('reference');
            }

            if (Schema::hasColumn('manual_payment_requests', 'receipt_path')) {
                $table->string('receipt_path', 2048)->nullable(false)->change();
            } else {
                $table->string('receipt_path', 2048)->after('user_note');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'admin_note')) {
                $table->text('admin_note')->nullable()->after('receipt_path');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'reviewed_by')) {
                $table->foreignId('reviewed_by')->nullable()->after('admin_note')->constrained('users')->nullOnDelete();
            }

            if (!Schema::hasColumn('manual_payment_requests', 'reviewed_at')) {
                $table->timestamp('reviewed_at')->nullable()->after('reviewed_by');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'payable_type') || !Schema::hasColumn('manual_payment_requests', 'payable_id')) {
                $table->nullableMorphs('payable');
            } else {
                $table->string('payable_type')->nullable()->change();
                $table->unsignedBigInteger('payable_id')->nullable()->change();
            }

            if (!Schema::hasColumn('manual_payment_requests', 'status')) {
                $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
                $table->index('status');
            }
        });
    }

    public function down(): void {
        if (!Schema::hasTable('manual_payment_requests')) {
            return;
        }

        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (!Schema::hasColumn('manual_payment_requests', 'payment_transaction_id')) {
                $table->foreignId('payment_transaction_id')
                    ->nullable()
                    ->after('manual_bank_id')
                    ->constrained('payment_transactions')
                    ->nullOnDelete();
            }
        });


        if (Schema::hasColumn('manual_payment_requests', 'manual_bank_id')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {

                $table->dropForeign(['manual_bank_id']);

                 });

            Schema::table('manual_payment_requests', function (Blueprint $table) {

                $table->unsignedBigInteger('manual_bank_id')->nullable()->change();

                            });

            Schema::table('manual_payment_requests', function (Blueprint $table) {

                $table->foreign('manual_bank_id')
                    ->references('id')
                    ->on('manual_banks')
                    ->restrictOnDelete();

                  });
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {


            if (Schema::hasColumn('manual_payment_requests', 'receipt_path')) {
                $table->string('receipt_path', 2048)->nullable()->change();
            }

            if (!Schema::hasColumn('manual_payment_requests', 'currency')) {
                $table->string('currency', 8)->nullable()->after('amount');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'bank_name')) {
                $table->string('bank_name')->nullable()->after('currency');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'bank_account_name')) {
                $table->string('bank_account_name')->nullable()->after('bank_name');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'bank_account_number')) {
                $table->string('bank_account_number')->nullable()->after('bank_account_name');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'bank_iban')) {
                $table->string('bank_iban')->nullable()->after('bank_account_number');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'bank_swift_code')) {
                $table->string('bank_swift_code')->nullable()->after('bank_iban');
            }

            if (!Schema::hasColumn('manual_payment_requests', 'meta')) {
                $table->json('meta')->nullable()->after('reviewed_at');
            }
        });
    
    
    }
};
