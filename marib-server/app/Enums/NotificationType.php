<?php

namespace App\Enums;

enum NotificationType: string
{
    case PaymentRequest = 'payment.request';
    case KycRequest = 'kyc.request';
    case OrderStatus = 'order.status';
    case WalletAlert = 'wallet.alert';
    case BroadcastMarketing = 'broadcast.marketing';
    case ActionRequest = 'action.request';
    case ChatMessage = 'chat.message';
}
