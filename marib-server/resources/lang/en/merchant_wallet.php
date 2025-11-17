<?php

return [
    'page' => [
        'title' => 'Store wallet',
        'subtitle' => 'Track your wallet balance, payouts, and manual withdrawal requests in one place.',
        'back' => 'Back to store dashboard',
        'close' => 'Close',
    ],
    'tabs' => [
        'summary' => 'Overview',
        'transactions' => 'Transactions',
        'withdrawals' => 'Withdrawal history',
        'request' => 'New request',
    ],
    'messages' => [
        'unavailable' => 'Wallet data is currently unavailable.',
        'insufficient' => 'Your wallet balance is not sufficient for this withdrawal.',
        'error' => 'Unable to process the withdrawal request right now. Please try again later.',
        'success' => 'Withdrawal request submitted and awaiting review.',
    ],
    'summary' => [
        'balance_title' => 'Current wallet balance',
        'balance_updated' => 'Last updated: :datetime',
        'pending_title' => 'Pending payouts',
        'pending_caption' => 'Requests awaiting review (:count)',
        'activity_title' => 'Wallet activity',
        'activity_transactions' => 'Transactions',
        'activity_withdrawals' => 'Withdrawal requests',
        'latest_transactions' => 'Latest transactions',
        'latest_withdrawals' => 'Latest withdrawals',
        'view_all' => 'View all',
        'empty' => 'No records to display yet.',
    ],
    'table' => [
        'type' => 'Type',
        'amount' => 'Amount',
        'balance_after' => 'Balance after',
        'date' => 'Date',
        'method' => 'Payout method',
        'status' => 'Status',
    ],
    'transaction_types' => [
        'credit' => 'Credit',
        'debit' => 'Debit',
    ],
    'transactions' => [
        'title' => 'Recent transactions',
        'empty' => 'No recent wallet activity.',
    ],
    'withdrawals' => [
        'title' => 'Latest withdrawal requests',
        'empty' => 'No withdrawal requests yet.',
        'status' => [
            'pending' => 'Pending',
            'approved' => 'Approved',
            'rejected' => 'Rejected',
        ],
    ],
    'form' => [
        'title' => 'New withdrawal request',
        'hint' => 'The minimum per request is :amount :currency.',
        'amount' => 'Withdrawal amount',
        'method' => 'Payout method',
        'notes' => 'Additional notes',
        'submit' => 'Submit request',
    ],
];
