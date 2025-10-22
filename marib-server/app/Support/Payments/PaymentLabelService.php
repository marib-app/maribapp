<?php

namespace App\Support\Payments;

use App\Models\PaymentTransaction;
use Illuminate\Support\Facades\Log;


class PaymentLabelService
{
    public static function forPaymentTransaction(PaymentTransaction $pt): array

    {
        $gw = strtolower(trim((string) $pt->payment_gateway));
        // 1) Wallet
        if ($gw === 'wallet') {

            return [
                'channel_label' => trans('المحفظة'),
                'bank_label'    => null,
            ];
        }

        $manualLike = [
            'manual_bank','manual-banks','manual bank','manualbank',
            'bank','bank_transfer','banktransfer','offline','internal',
        ];
        if (in_array($gw, $manualLike, true) || $pt->manual_payment_request_id) {
            $bankName = self::resolveBankNameFromTransaction($pt);

            if (! $bankName) {
                // نعتبرها حالة خطأ بيانات — نسجّل ونرجّع فراغ بصريًا
                Log::warning('Bank name missing for bank-like transaction', [
                    'tx_id' => $pt->id,
                    'gateway' => $pt->payment_gateway,
                    'mpr_id' => $pt->manual_payment_request_id,
                ]);
            }

            return [
                // للعرض: اسم البنك الحقيقي فقط
                'channel_label' => $bankName ?: '—',
                'bank_label'    => $bankName ?: null,
            ];
        }

        return [
            'channel_label' => $pt->payment_gateway ?: '—',
            'bank_label'    => null,
        ];

    }

    public static function forManualPaymentRequest(ManualPaymentRequest $mpr): array
    {
        $bankName = optional($mpr->manualBank)->name;

        if (! $bankName) {
            Log::warning('Bank name missing for manual payment request', ['mpr_id' => $mpr->id]);
        }

        return [
            'channel_label' => $bankName ?: '—',
            'bank_label'    => $bankName ?: null,
        ];
    }


    /** يحاول استخراج اسم البنك من كل المصادر المحتملة دون fallback نصّي */
    private static function resolveBankNameFromTransaction(PaymentTransaction $pt): ?string
    {
        // من الـ meta (عدّة مسارات شائعة)
        $meta = $pt->meta ?? [];
        $candidates = [
            'payload.bank_name',
            'payload.manual_bank_name',
            'bank.name',
            'bank_name',
        ];
        foreach ($candidates as $path) {
            $v = data_get($meta, $path);
            if (is_string($v) && trim($v) !== '') {
                return trim($v);
            }
        }

        // من الربط بـ MPR -> manualBank
        if ($pt->relationLoaded('manualPaymentRequest') && $pt->manualPaymentRequest?->manualBank?->name) {
            return $pt->manualPaymentRequest->manualBank->name;
        }

        // إن وُجد mpr id ولم تُحمّل العلاقة
        if ($pt->manual_payment_request_id && method_exists(ManualPaymentRequest::class, 'find')) {
            $mpr = ManualPaymentRequest::query()
                ->with('manualBank:id,name')
                ->find($pt->manual_payment_request_id);
            if ($mpr?->manualBank?->name) {
                return $mpr->manualBank->name;
            }
        }

        return null;
    }
}
