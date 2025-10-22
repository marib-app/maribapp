<?php

namespace App\Support\Payments;

use App\Models\PaymentTransaction;
use App\Models\ManualPaymentRequest;


class PaymentLabelService
{
    public static function forPaymentTransaction(PaymentTransaction $pt): array

    {
        $gw = strtolower(trim((string) $pt->payment_gateway));
        $hasMpr = !empty($pt->manual_payment_request_id) || $pt->relationLoaded('manualPaymentRequest');
        if ($gw === 'wallet') {

            return [
                'gateway_label' => trans('المحفظة'),
                'bank_label'    => null,
            ];
        }

        $manualLike = [
            'manual_bank','manual-banks','manual bank','manualbank',
            'bank','bank_transfer','banktransfer','offline','internal',
        ];
        if (in_array($gw, $manualLike, true) || $hasMpr) {
            $bankName = data_get($pt->meta, 'payload.bank_name');

            if (!$bankName && ($pt->relationLoaded('manualPaymentRequest') || $pt->manual_payment_request_id)) {
                $mpr = $pt->manualPaymentRequest ?? null;
                $bankName = optional($mpr?->manualBank)->name;
            }

            return [
                'gateway_label' => trans('تحويل بنكي'),
                'bank_label'    => $bankName ?: trans('تحويل بنكي'),
            ];
        }

        return [
            'gateway_label' => $pt->payment_gateway ?: trans('بوابة غير معروفة'),
            'bank_label'    => null,
        ];

    }

    public static function forManualPaymentRequest(ManualPaymentRequest $mpr): array
    {
        $bankName = optional($mpr->manualBank)->name;
        return [
            'gateway_label' => trans('تحويل بنكي'),
            'bank_label'    => $bankName ?: trans('تحويل بنكي'),
        ];
    }
}