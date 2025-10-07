<?php

namespace App\Support;

use Illuminate\Support\Arr;

class DepositCalculator
{
    /**
     * @return array{
     *     policy: array<string, mixed>|null,
     *     ratio: float,
     *     minimum_total: float,
     *     return_policy_text: string|null,
     * }
     */
    public static function summarizePolicy(?array $policy): array
    {
        $normalized = self::normalizePolicy($policy);

        $returnPolicyText = self::extractPolicyText($policy);

        if ($normalized === null) {
            return [
                'policy' => null,
                'ratio' => 0.0,
                'minimum_total' => 0.0,
                'return_policy_text' => $returnPolicyText,


            ];
        }

        return [

            'policy' => $normalized,
            'ratio' => (float) $normalized['ratio'],
            'minimum_total' => (float) $normalized['minimum_amount'],
            'return_policy_text' => $returnPolicyText,



        ];
    }

    /**
     * @param array<string, mixed>|null $policy
     * @return array<string, mixed>|null
     */
    public static function normalizePolicy(?array $policy): ?array
    {
        if (! is_array($policy) || $policy === []) {
            return null;
        }

        $ratio = Arr::get($policy, 'ratio');

        if ($ratio === null) {
            $ratio = Arr::get($policy, 'percentage', Arr::get($policy, 'percent'));
        }

        if ($ratio !== null) {
            $ratio = (float) $ratio;
            if ($ratio > 1) {
                $ratio = $ratio / 100;
            }
        }

        $ratio = $ratio !== null ? max(min($ratio, 1.0), 0.0) : 0.0;

        $minimumAmount = Arr::get($policy, 'minimum_amount');

        if ($minimumAmount === null) {
            $minimumAmount = Arr::get($policy, 'minimum', Arr::get($policy, 'min'));
        }

        $minimumAmount = $minimumAmount !== null ? max((float) $minimumAmount, 0.0) : 0.0;


        return [
            'ratio' => round($ratio, 4),
            'minimum_amount' => round($minimumAmount, 2),
            'raw' => $policy,
        ];
    }

    private static function extractPolicyText(?array $policy): ?string
    {
        if (! is_array($policy)) {
            return null;
        }

        $text = $policy['return_policy_text'] ?? null;

        if (is_string($text)) {
            $text = trim($text);

            return $text === '' ? null : $text;
        }

        if (is_numeric($text)) {
            return (string) $text;
        }

        return null;
    }


    public static function calculateRequiredAmount(array $summary, float $goodsTotal, float $deliveryTotal): float
    {
        $ratioAmount = round($goodsTotal * (float) ($summary['ratio'] ?? 0.0), 2);

        return max($ratioAmount, 0.0);

    }

    /**
     * @return array{deposit_applied: float, remainder: float}
     */
    public static function allocatePayment(float $amount, float $depositRemaining): array
    {
        $amount = round($amount, 2);
        $depositRemaining = max(round($depositRemaining, 2), 0.0);

        if ($depositRemaining <= 0.0) {
            return [
                'deposit_applied' => 0.0,
                'remainder' => $amount,
            ];
        }

        $depositApplied = min($depositRemaining, $amount);

        return [
            'deposit_applied' => round($depositApplied, 2),
            'remainder' => round($amount - $depositApplied, 2),
        ];
    }



    }