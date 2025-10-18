<?php

namespace App\Queries;

use App\Models\ManualPaymentRequest;
use App\Models\WalletTransaction;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Query\JoinClause;

class PaymentRequestTableQuery
{
    private const STATUS_SUCCESS_VALUES = [
        'succeed',
        'success',
        'succeeded',
        'paid',
        'complete',
        'completed',
        'approved',
        'done',
        'settled',
        'confirmed',
    ];

    private const STATUS_FAILED_VALUES = [
        'failed',
        'failure',
        'error',
        'cancelled',
        'canceled',
        'rejected',
        'declined',
        'void',
        'refunded',
    ];

    private const STATUS_PENDING_VALUES = [
        'pending',
        'processing',
        'in_review',
        'in-review',
        'review',
        'reviewing',
        'under_review',
        'under-review',
        'awaiting',
        'waiting',
        'new',
        'initiated',
        'open',
        '',
    ];





    /**
     * Build the unified payment request table query.
     */
    public static function make(): Builder
    {


        $supportsDepartment = Schema::hasTable('manual_payment_requests')
            && Schema::hasColumn('manual_payment_requests', 'department');
        $supportsManualGatewayName = Schema::hasTable('manual_payment_requests')
            && Schema::hasColumn('manual_payment_requests', 'gateway_name');
        $supportsManualBankName = Schema::hasTable('manual_payment_requests')
            && Schema::hasColumn('manual_payment_requests', 'bank_name');
        $supportsManualBankAccountName = Schema::hasTable('manual_payment_requests')
            && Schema::hasColumn('manual_payment_requests', 'bank_account_name');

        $supportsManualBankId = Schema::hasTable('manual_payment_requests')
            && Schema::hasColumn('manual_payment_requests', 'manual_bank_id');
        $supportsManualBankLookupTable = Schema::hasTable('manual_banks');
        $supportsManualBankLookup = $supportsManualBankId && $supportsManualBankLookupTable;
        $supportsManualBankLookupName = $supportsManualBankLookup
            && Schema::hasColumn('manual_banks', 'name');
        $supportsManualBankLookupBeneficiaryName = $supportsManualBankLookup
            && Schema::hasColumn('manual_banks', 'beneficiary_name');


        $supportsPaymentGatewayName = Schema::hasTable('payment_transactions')
            && Schema::hasColumn('payment_transactions', 'payment_gateway_name');


        $supportsOrderLookup = Schema::hasTable('orders');
        $supportsOrderDepartment = $supportsOrderLookup
            && Schema::hasColumn('orders', 'department');
        $orderPayableTypeAliases = ManualPaymentRequest::orderPayableTypeAliases();

        $departmentParts = [];

        if ($supportsOrderDepartment) {
            $departmentParts[] = "NULLIF(order_lookup.department, '')";
        }

        if ($supportsDepartment) {
            $departmentParts[] = "NULLIF(mpr.department, '')";
        }

        $departmentSelect = $departmentParts === []
            ? "NULL as department"
            : 'COALESCE(' . implode(', ', $departmentParts) . ') as department';


        $manualBankNameParts = [];

        if ($supportsManualBankLookupName) {
            $manualBankNameParts[] = "NULLIF(manual_bank_lookup.name, '')";
        }
        if ($supportsManualBankLookupBeneficiaryName) {
            $manualBankNameParts[] = "NULLIF(manual_bank_lookup.beneficiary_name, '')";
        }

        if ($supportsManualBankName) {
            $manualBankNameParts[] = "NULLIF(mpr.bank_name, '')";
        }
        if ($supportsManualBankAccountName) {
            $manualBankNameParts[] = "NULLIF(mpr.bank_account_name, '')";
        }
        $manualBankNameSelect = $manualBankNameParts === []
            ? 'NULL'
            : 'COALESCE(' . implode(', ', $manualBankNameParts) . ')';

        $channelExpression = self::channelExpression('pt');


        $manualBankAliasSqlList = implode(', ', array_map(
            static fn (string $alias): string => "'" . $alias . "'",
            ManualPaymentRequest::manualBankGatewayAliases()
        ));

        $sanitizeManualBankAlias = static function (string $column) use ($manualBankAliasSqlList): string {
            return 'CASE'
                . " WHEN TRIM(COALESCE({$column}, '')) = '' THEN NULL"
                . " WHEN LOWER(TRIM({$column})) IN ({$manualBankAliasSqlList}) THEN NULL"
                . " ELSE {$column}"
                . ' END';
        };


        $paymentGatewayNameParts = [];
        if ($supportsPaymentGatewayName) {
            $paymentGatewayNameParts[] = $sanitizeManualBankAlias('pt.payment_gateway_name');
        }
        $paymentGatewayNameParts[] = $sanitizeManualBankAlias('pt.payment_gateway');


        $manualGatewayNameParts = [];

        if ($supportsManualBankLookupName) {
            $manualGatewayNameParts[] = "NULLIF(manual_bank_lookup.name, '')";
        }
        if ($supportsManualBankLookupBeneficiaryName) {
            $manualGatewayNameParts[] = "NULLIF(manual_bank_lookup.beneficiary_name, '')";
        }

        if ($supportsManualBankName) {
            $manualGatewayNameParts[] = "NULLIF(mpr.bank_name, '')";
        }
        if ($supportsManualBankAccountName) {
            $manualGatewayNameParts[] = "NULLIF(mpr.bank_account_name, '')";
        }
        if ($supportsManualGatewayName) {
            $manualGatewayNameParts[] = $sanitizeManualBankAlias('mpr.gateway_name');
        }

        $manualGatewayNameParts = array_merge($manualGatewayNameParts, $paymentGatewayNameParts);
        $manualGatewayNameParts[] = "'Manual Banks'";
        $manualGatewayNameSelect = 'COALESCE(' . implode(', ', $manualGatewayNameParts) . ')';


        $walletPaymentGatewayNameParts = [];
        if ($supportsPaymentGatewayName) {
            $walletPaymentGatewayNameParts[] = $sanitizeManualBankAlias('pt.payment_gateway_name');
        }
        $walletPaymentGatewayNameParts[] = $sanitizeManualBankAlias('pt.payment_gateway');
        $walletGatewayNameParts = $walletPaymentGatewayNameParts;
        if ($supportsManualGatewayName) {
            array_unshift($walletGatewayNameParts, $sanitizeManualBankAlias('mpr.gateway_name'));
        }
        
        
        
        $walletGatewayNameParts[] = "'Wallet'";
        $paymentTransactionWalletGatewayNameSelect = 'COALESCE(' . implode(', ', $walletGatewayNameParts) . ')';

        $walletTopUpGatewayNameParts = ["'Wallet'"];
        if ($supportsManualGatewayName) {
            array_unshift($walletTopUpGatewayNameParts, $sanitizeManualBankAlias('mpr.gateway_name'));


        }
        $walletGatewayNameSelect = 'COALESCE(' . implode(', ', $walletTopUpGatewayNameParts) . ')';

        $eastGatewayNameParts = [];
        if ($supportsManualGatewayName) {
            $eastGatewayNameParts[] = "NULLIF(mpr.gateway_name, '')";


        }
        $eastGatewayNameParts = array_merge($eastGatewayNameParts, $paymentGatewayNameParts);
        $eastGatewayNameParts[] = "'East Yemen Bank'";
        $eastGatewayNameSelect = 'COALESCE(' . implode(', ', $eastGatewayNameParts) . ')';

        $cashGatewayNameParts = $paymentGatewayNameParts;
        $cashGatewayNameParts[] = "'Cash'";
        $cashGatewayNameSelect = 'COALESCE(' . implode(', ', $cashGatewayNameParts) . ')';

        $defaultGatewayNameParts = $paymentGatewayNameParts;
        $defaultGatewayNameParts[] = "'Manual Banks'";
        $defaultGatewayNameSelect = 'COALESCE(' . implode(', ', $defaultGatewayNameParts) . ')';

        $gatewayNameSelect = 'CASE'
            . " WHEN ({$channelExpression}) = 'manual_banks' THEN {$manualGatewayNameSelect}"
            . " WHEN ({$channelExpression}) = 'east_yemen_bank' THEN {$eastGatewayNameSelect}"
            . " WHEN ({$channelExpression}) = 'wallet' THEN {$paymentTransactionWalletGatewayNameSelect}"
            . " WHEN ({$channelExpression}) = 'cash' THEN {$cashGatewayNameSelect}"
            . " ELSE {$defaultGatewayNameSelect}"
            . ' END';

        $paymentResolvedPayableTypeExpression = "LOWER(COALESCE(NULLIF(pt.payable_type, ''), NULLIF(mpr.payable_type, '')))";
        $paymentResolvedPayableIdExpression = 'COALESCE(pt.payable_id, mpr.payable_id)';


        $paymentTransactions = DB::table('payment_transactions as pt')
            ->selectRaw("CONCAT('pt-', pt.id) as row_key")
            ->selectRaw('pt.id as payment_transaction_id')
            ->selectRaw(
                'CASE WHEN LOWER(pt.payable_type) = ? THEN pt.payable_id ELSE NULL END as wallet_transaction_id',
                [strtolower(WalletTransaction::class)]
            )
            ->selectRaw('pt.manual_payment_request_id')
            ->selectRaw('pt.user_id')
            ->selectRaw('users.name as user_name')
            ->selectRaw('users.mobile as user_mobile')
            ->selectRaw('pt.amount')
            ->selectRaw("COALESCE(NULLIF(pt.currency, ''), '') as currency")
            ->selectRaw(
                "COALESCE(NULLIF(pt.payable_type, ''), NULLIF(mpr.payable_type, '')) as payable_type"
            )
            ->selectRaw('COALESCE(pt.payable_id, mpr.payable_id) as payable_id')
            ->selectRaw(self::gatewayExpression('pt') . ' as gateway_key')
            ->selectRaw(self::channelExpression('pt') . ' as channel')
            ->selectRaw($gatewayNameSelect . ' as gateway_name')
            ->selectRaw(self::categoryExpression('pt') . ' as category')
            ->selectRaw(
                self::statusExpression(
                    "LOWER(COALESCE(NULLIF(pt.payment_status, ''), NULLIF(mpr.status, ''), 'pending'))"
                ) . ' as status'
            )
            ->selectRaw("COALESCE(mpr.reference, CONCAT('TX-', pt.id)) as reference")
            ->selectRaw('pt.created_at')
            ->selectRaw($departmentSelect)
            ->selectRaw($manualBankNameSelect . ' as manual_bank_name')
            ->selectRaw(($supportsManualBankId ? 'mpr.manual_bank_id' : 'NULL') . ' as manual_bank_id')
            ->selectRaw("'payment_transactions' as source")
            ->leftJoin('users', 'users.id', '=', 'pt.user_id')
            ->leftJoin('manual_payment_requests as mpr', 'mpr.id', '=', 'pt.manual_payment_request_id')
            ->when(
                $supportsManualBankLookup,
                static fn (Builder $query) => $query->leftJoin(
                    'manual_banks as manual_bank_lookup',
                    'manual_bank_lookup.id',
                    '=',
                    'mpr.manual_bank_id'
                )


            )
            ->when(
                $supportsOrderLookup,
                static function (Builder $query) use (
                    $paymentResolvedPayableIdExpression,
                    $paymentResolvedPayableTypeExpression,
                    $orderPayableTypeAliases
                ): void {
                    $query->leftJoin(
                        'orders as order_lookup',
                        static function (JoinClause $join) use (
                            $paymentResolvedPayableIdExpression,
                            $paymentResolvedPayableTypeExpression,
                            $orderPayableTypeAliases
                        ): void {
                            $join->on(
                                'order_lookup.id',
                                '=',
                                DB::raw($paymentResolvedPayableIdExpression)
                            )->whereIn(
                                DB::raw($paymentResolvedPayableTypeExpression),
                                $orderPayableTypeAliases
                            );
                        }
                    );
                }


            );

        $walletResolvedPayableIdExpression = 'COALESCE(mpr.payable_id, wt.id)';
        $walletResolvedPayableTypeExpression = "LOWER(NULLIF(mpr.payable_type, ''))";


        $walletTopUps = DB::table('wallet_transactions as wt')
            ->selectRaw("CONCAT('wt-', wt.id) as row_key")
            ->selectRaw('NULL as payment_transaction_id')
            ->selectRaw('wt.id as wallet_transaction_id')
            ->selectRaw('wt.manual_payment_request_id')
            ->selectRaw('wa.user_id')
            ->selectRaw('users.name as user_name')
            ->selectRaw('users.mobile as user_mobile')
            ->selectRaw('wt.amount')
            ->selectRaw("COALESCE(NULLIF(wt.currency, ''), '') as currency")
            ->selectRaw(
                "COALESCE(NULLIF(mpr.payable_type, ''), ?) as payable_type",
                [ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP]
            )
            ->selectRaw('COALESCE(mpr.payable_id, wt.id) as payable_id')
            ->selectRaw("'wallet' as gateway_key")
            ->selectRaw("'wallet' as channel")
            ->selectRaw($walletGatewayNameSelect . ' as gateway_name')
            ->selectRaw("'top_ups' as category")
            ->selectRaw(
                self::statusExpression(
                    "LOWER(COALESCE(NULLIF(mpr.status, ''), 'succeed'))"
                ) . ' as status'
            )
            ->selectRaw("COALESCE(mpr.reference, CONCAT('WT-', wt.id)) as reference")
            ->selectRaw('wt.created_at')
            ->selectRaw($departmentSelect)
            ->selectRaw($manualBankNameSelect . ' as manual_bank_name')
            ->selectRaw(($supportsManualBankId ? 'mpr.manual_bank_id' : 'NULL') . ' as manual_bank_id')
            ->selectRaw("'wallet_transactions' as source")
            ->join('wallet_accounts as wa', 'wa.id', '=', 'wt.wallet_account_id')
            ->leftJoin('users', 'users.id', '=', 'wa.user_id')
            ->leftJoin('manual_payment_requests as mpr', 'mpr.id', '=', 'wt.manual_payment_request_id')

            ->when(
                $supportsManualBankLookup,
                static fn (Builder $query) => $query->leftJoin(
                    'manual_banks as manual_bank_lookup',
                    'manual_bank_lookup.id',
                    '=',
                    'mpr.manual_bank_id'
                )
            )


            ->when(
                $supportsOrderLookup,
                static function (Builder $query) use (
                    $walletResolvedPayableIdExpression,
                    $walletResolvedPayableTypeExpression,
                    $orderPayableTypeAliases
                ): void {
                    $query->leftJoin(
                        'orders as order_lookup',
                        static function (JoinClause $join) use (
                            $walletResolvedPayableIdExpression,
                            $walletResolvedPayableTypeExpression,
                            $orderPayableTypeAliases
                        ): void {
                            $join->on(
                                'order_lookup.id',
                                '=',
                                DB::raw($walletResolvedPayableIdExpression)
                            )->whereIn(
                                DB::raw($walletResolvedPayableTypeExpression),
                                $orderPayableTypeAliases
                            );
                        }
                    );
                }
            )


            ->whereNull('wt.payment_transaction_id')
            ->where('wt.type', 'credit')
            ->where(static function (Builder $query): void {
                $query->where('wt.meta->reason', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                    ->orWhere('wt.meta->reason', 'wallet_top_up')
                    ->orWhere('wt.meta->reason', 'wallet-top-up')
                    ->orWhere('wt.meta->reason', 'wallet_topup')
                    ->orWhere('wt.meta->reason', 'admin_manual_credit');
            });

        return $paymentTransactions->unionAll($walletTopUps);
    }

    private static function gatewayExpression(string $alias): string
    {
        return "LOWER(COALESCE(NULLIF({$alias}.payment_gateway, ''), CASE WHEN {$alias}.manual_payment_request_id IS NOT NULL THEN 'manual_bank' ELSE NULL END))";
    }

    private static function channelExpression(string $alias): string
    {
        $gateway = self::gatewayExpression($alias);

        $eastValues = self::sqlList([
            'east_yemen_bank',
            'east-yemen-bank',
            'east',
            'eastyemenbank',
        ]);

        $manualValues = self::sqlList([
            
            'manual_bank',
            'bank',
            'bank_transfer',
            'banktransfer',
            'bank_alsharq',
            'manual',
            'manual_payment',
            'offline',
            'internal',
        ]);

        $walletValues = self::sqlList([
            'wallet',
            'wallet_balance',
            'wallet-balance',
            'wallet balance',
            'wallet_gateway',
            'wallet-gateway',
            'wallet gateway',
            'wallet_top_up',
            'wallet-top-up',
            'wallet top up',
            'wallettopup',
            'walletpayment',
            'wallet payment',
            'wallet_payment',
            'wallet-payment',
        ]);

        $cashValues = self::sqlList([
            'cash',
            'cod',
            'cash_on_delivery',
            'cashcollection',
            'cash_collect',
        ]);


        return "CASE
            WHEN {$gateway} IN {$eastValues} THEN 'east_yemen_bank'
            WHEN {$gateway} IN {$manualValues} THEN 'manual_banks'
            WHEN {$gateway} IN {$walletValues} THEN 'wallet'
            WHEN {$gateway} IN {$cashValues} THEN 'cash'
            WHEN LOWER({$alias}.payable_type) LIKE '%wallet%' THEN 'wallet'
            ELSE 'manual_banks'
        END";
    }

    private static function categoryExpression(string $alias): string
    {
        return "CASE
            WHEN LOWER({$alias}.payable_type) LIKE '%wallet%' THEN 'top_ups'
            WHEN LOWER({$alias}.payable_type) LIKE '%top_up%' THEN 'top_ups'
            WHEN LOWER({$alias}.payable_type) LIKE '%package%' THEN 'packages'
            WHEN LOWER({$alias}.payable_type) LIKE '%userpurchasedpackage%' THEN 'packages'
            WHEN LOWER({$alias}.payable_type) LIKE '%order%' THEN 'orders'
            WHEN LOWER({$alias}.payable_type) LIKE '%cart%' THEN 'orders'
            ELSE 'orders'
        END";
    }

    private static function statusExpression(string $source): string
    {
        $successValues = self::sqlList(self::STATUS_SUCCESS_VALUES);
        $failedValues = self::sqlList(self::STATUS_FAILED_VALUES);
        $pendingValues = self::sqlList(self::STATUS_PENDING_VALUES);

        return "CASE
            WHEN {$source} IN {$successValues} THEN 'succeed'
            WHEN {$source} IN {$failedValues} THEN 'failed'
            WHEN {$source} IN {$pendingValues} THEN 'pending'
            ELSE 'pending'
        END";
    }

    private static function sqlList(array $values): string
    {
        $escaped = array_map(static function ($value) {
            return "'" . str_replace("'", "''", (string) $value) . "'";
        }, $values);

        return '(' . implode(',', $escaped) . ')';
    }
}
