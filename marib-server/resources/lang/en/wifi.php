<?php

return [
    'notifications' => [
        'network_submitted_title' => 'WiFi network submitted',
        'network_submitted_body' => 'Your network ":name" has been submitted for Wifi Cabin and is now under review.',
        'network_status_title' => 'WiFi network status updated',
        'network_status_body' => 'The status of your network ":name" has been updated to :status.',
        'network_status_reason' => 'Reason: :reason.',
        'status_active' => 'approved',
        'status_inactive' => 'inactive',
        'status_suspended' => 'suspended',
        'commission_updated_title' => 'Commission updated for your network',
        'commission_updated_body' => 'A commission of :rate% is now applied to your sales. Example: for a card worth :amount :currency we deduct :commission :currency and deposit :net :currency into your wallet.',
        'batch_approved_title' => 'WiFi cards batch approved',
        'batch_approved_body' => 'Your batch ":label" for plan ":plan" is now approved and ready for sale.',
        'batch_rejected_title' => 'WiFi cards batch rejected',
        'batch_rejected_body' => 'The batch ":label" for plan ":plan" was rejected.',
        'batch_rejected_reason' => 'Reason: :reason.',
        'purchase_success_title' => 'Your WiFi card is ready',
        'purchase_success_body_with_code' => 'Your WiFi card from ":network" has been issued. Card: :code',
        'purchase_success_body_without_code' => 'Your WiFi card from ":network" has been issued.',
        'owner_sale_title' => 'A new WiFi card was sold',
        'owner_sale_body' => 'A ":plan" card was sold for :amount :currency. Commission :commission% (:commission_value :currency). Net deposit :net :currency. Remaining cards: :remaining.',
        'wallet_credit_title' => 'Wallet credited',
        'wallet_credit_body' => 'An amount of :amount :currency was deposited to your wallet (transaction #:transaction).',
    ],
];
