<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        $defaultCurrency = strtoupper((string) config('app.currency', 'SAR'));

        Schema::table('wallet_accounts', static function (Blueprint $table) {
            if (Schema::hasColumn('wallet_accounts', 'user_id')) {
                $table->dropForeign('wallet_accounts_user_id_foreign');
                $table->dropUnique('wallet_accounts_user_id_unique');
            }

            if (! Schema::hasColumn('wallet_accounts', 'currency')) {
                $table->string('currency', 3)->default('SAR')->after('user_id');
            }
        });

        DB::table('wallet_accounts')->update([
            'currency' => $defaultCurrency,
        ]);

        Schema::table('wallet_accounts', static function (Blueprint $table) use ($defaultCurrency) {
            $table->string('currency', 3)->default($defaultCurrency)->change();
            $table->unique(['user_id', 'currency'], 'wallet_accounts_user_currency_unique');
            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();


        });

        Schema::table('wallet_transactions', static function (Blueprint $table) {
            if (! Schema::hasColumn('wallet_transactions', 'currency')) {
                $table->string('currency', 3)->default('SAR')->after('amount');
            }
        });

        DB::table('wallet_transactions')->chunkById(100, function ($transactions) use ($defaultCurrency) {
            foreach ($transactions as $transaction) {
                $accountCurrency = DB::table('wallet_accounts')
                    ->where('id', $transaction->wallet_account_id)
                    ->value('currency');

                DB::table('wallet_transactions')
                    ->where('id', $transaction->id)
                    ->update([
                        'currency' => strtoupper($accountCurrency ?? $defaultCurrency),
                    ]);
            }
        });

        Schema::table('wallet_transactions', static function (Blueprint $table) use ($defaultCurrency) {
            $table->string('currency', 3)->default($defaultCurrency)->change();
            $table->index('currency', 'wallet_transactions_currency_index');
        });
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('wallet_transactions', static function (Blueprint $table) {
            if (Schema::hasColumn('wallet_transactions', 'currency')) {
                $table->dropIndex('wallet_transactions_currency_index');
                $table->dropColumn('currency');
            }
        });

        Schema::table('wallet_accounts', static function (Blueprint $table) {
            if (Schema::hasColumn('wallet_accounts', 'currency')) {
                $table->dropForeign('wallet_accounts_user_id_foreign');


                $table->dropUnique('wallet_accounts_user_currency_unique');
                $table->dropColumn('currency');
            }

            $table->unique('user_id', 'wallet_accounts_user_id_unique');

            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();

        });
    }
};
