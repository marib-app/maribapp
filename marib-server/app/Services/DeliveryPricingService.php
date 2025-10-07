<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class DeliveryPricingService
{
    public function calculate(array $payload): DeliveryPricingResult
    {
        $payload = $this->normalizePayload($payload);

        $baseUrl = rtrim((string) config('services.delivery_pricing.base_url', ''), '/');
        $appUrl = rtrim((string) config('app.url', ''), '/');

        if ($baseUrl === '' || ($appUrl !== '' && $baseUrl === $appUrl)) {
            return $this->fallbackResult($payload);
        }

        $endpoint = (string) config('services.delivery_pricing.calculate_endpoint', '/api/delivery-prices/calculate');
        $timeout = (int) config('services.delivery_pricing.timeout', 10);
        $url = $baseUrl . (str_starts_with($endpoint, '/') ? $endpoint : '/' . $endpoint);

        try {
            $response = Http::timeout($timeout)
                ->acceptJson()
                ->post($url, $payload);
        } catch (\Throwable $exception) {
            Log::error('delivery_pricing.remote_exception', [
                'error' => $exception->getMessage(),
            ]);

            return $this->fallbackResult($payload);
        }

        if (! $response->successful()) {
            Log::warning('delivery_pricing.remote_failed', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return $this->fallbackResult($payload);
        }

        $raw = $response->json();
        if (! is_array($raw)) {
            Log::warning('delivery_pricing.remote_invalid', [
                'response' => $response->body(),
            ]);

            return $this->fallbackResult($payload);
        }

        $data = $raw['data'] ?? $raw;
        if (! is_array($data)) {
            Log::warning('delivery_pricing.remote_invalid_payload', [
                'payload' => $raw,
            ]);

            return $this->fallbackResult($payload);
        }

        return $this->normalizeResult($data, $payload, $raw);
    }

    private function normalizePayload(array $payload): array
    {
        $orderTotal = $this->toFloatOrNull($payload['order_total'] ?? null) ?? 0.0;
        $distanceKm = $this->toFloatOrNull($payload['distance_km'] ?? null);
        $weightTotal = $this->toFloatOrNull($payload['weight_total'] ?? null);
        $department = is_string($payload['department'] ?? null) ? $payload['department'] : null;
        $currency = (string) ($payload['currency'] ?? config('app.currency', 'YER'));

        $payment = $payload['payment'] ?? [];
        if (! is_array($payment)) {
            $payment = [];
        }

        $timingCodes = $payload['timing_codes'] ?? [];
        if (! is_array($timingCodes)) {
            $timingCodes = [];
        }

        $timing = $this->extractTimingSource($payload) ?? [];
        if (! isset($timing['codes']) && $timingCodes !== []) {
            $timing['codes'] = $timingCodes;
        }

        $suggestedTiming = $payload['suggested_timing'] ?? null;
        if (is_string($suggestedTiming) && $suggestedTiming !== '') {
            $timing['suggested'] = $suggestedTiming;
        }

        return [
            'order_total' => $orderTotal,
            'distance_km' => $distanceKm,
            'weight_total' => $weightTotal,
            'department' => $department,
            'currency' => $currency,
            'payment' => $payment,
            'timing_codes' => $timingCodes,
            'timing' => $timing,
            'policy_id' => $payload['policy_id'] ?? null,
            'rule_id' => $payload['rule_id'] ?? null,
            'tier_id' => $payload['tier_id'] ?? null,
        ];
    }

    private function normalizeResult(array $data, array $payload, array $raw = []): DeliveryPricingResult
    {
        $amount = $this->toFloatOrNull($data['amount'] ?? $data['total'] ?? null) ?? 0.0;
        $currency = (string) ($data['currency'] ?? $payload['currency'] ?? 'YER');

        $merged = array_merge($payload, $data);
        $payment = $this->normalizePaymentOptions($merged['payment'] ?? [], $merged);
        $flatPayment = $this->flattenPaymentOptions($payment);

        $timing = $this->extractTimingSource($merged) ?? [];
        $timingCodes = $this->extractTimingCodes($timing, $merged);
        $suggestedTiming = $this->resolveSuggestedTiming($merged, $timing);

        $result = [
            'amount' => $amount,
            'total' => $amount,
            'currency' => $currency,
            'free_applied' => (bool) ($data['free_applied'] ?? ($amount <= 0.0)),
            'eta' => $data['eta'] ?? null,
            'breakdown' => is_array($data['breakdown'] ?? null) ? $data['breakdown'] : [],
            'policy_id' => $data['policy_id'] ?? ($payload['policy_id'] ?? null),
            'rule_id' => $data['rule_id'] ?? ($payload['rule_id'] ?? null),
            'tier_id' => $data['tier_id'] ?? ($payload['tier_id'] ?? null),
            'distance_km' => $this->toFloatOrNull($data['distance_km'] ?? $payload['distance_km'] ?? null),
            'weight_total' => $this->toFloatOrNull($data['weight_total'] ?? $payload['weight_total'] ?? null),
            'payment' => $payment,
            'timing' => [
                'codes' => $timingCodes,
                'suggested' => $suggestedTiming,
            ],
            'timing_codes' => $timingCodes,
            'suggested_timing' => $suggestedTiming,
        ];

        $normalized = array_merge($result, $flatPayment);

        $rawData = array_merge($merged, $normalized);
        $rawData['provider_response'] = $raw;

        return DeliveryPricingResult::fromArray(array_merge($normalized, [
            'raw_data' => $rawData,
        ]));
    }

    private function fallbackResult(array $payload): DeliveryPricingResult
    {
        $payment = $this->normalizePaymentOptions($payload['payment'] ?? [], $payload);
        $flatPayment = $this->flattenPaymentOptions($payment);

        $timing = $this->extractTimingSource($payload) ?? [];
        $timingCodes = $this->extractTimingCodes($timing, $payload);
        $suggestedTiming = $this->resolveSuggestedTiming($payload, $timing);

        $result = [
            'amount' => 0.0,
            'total' => 0.0,
            'currency' => $payload['currency'] ?? 'YER',
            'free_applied' => true,
            'eta' => null,
            'breakdown' => [],
            'policy_id' => $payload['policy_id'] ?? null,
            'rule_id' => $payload['rule_id'] ?? null,
            'tier_id' => $payload['tier_id'] ?? null,
            'distance_km' => $this->toFloatOrNull($payload['distance_km'] ?? null),
            'weight_total' => $this->toFloatOrNull($payload['weight_total'] ?? null),
            'payment' => $payment,
            'timing' => [
                'codes' => $timingCodes,
                'suggested' => $suggestedTiming,
            ],
            'timing_codes' => $timingCodes,
            'suggested_timing' => $suggestedTiming,
        ];

        $normalized = array_merge($result, $flatPayment);

        $rawData = array_merge($payload, $normalized);
        $rawData['source'] = 'internal';

        return DeliveryPricingResult::fromArray(array_merge($normalized, [
            'raw_data' => $rawData,
        ]));
    }

    private function normalizePaymentOptions(array $payment, array $data): array
    {
        $allowPayNowCandidate = $payment['allow_pay_now']
            ?? $data['allow_pay_now']
            ?? $payment['due_now']
            ?? $data['due_now']
            ?? ! ($payment['prepaid_required'] ?? $data['prepaid_required'] ?? false);

        $allowPayOnDeliveryCandidate = $payment['allow_pay_on_delivery']
            ?? $data['allow_pay_on_delivery']
            ?? $payment['collect_on_delivery']
            ?? $data['collect_on_delivery']
            ?? true;

        $codFeeCandidate = $payment['cod_fee']
            ?? $data['cod_fee']
            ?? $payment['cod_fee_amount']
            ?? $data['cod_fee_amount']
            ?? null;

        $collectOnDeliveryCandidate = $payment['collect_on_delivery']
            ?? $data['collect_on_delivery']
            ?? $allowPayOnDeliveryCandidate;

        $prepaidRequiredCandidate = $payment['prepaid_required']
            ?? $data['prepaid_required']
            ?? ! $allowPayNowCandidate;

        $dueNowCandidate = $payment['due_now']
            ?? $data['due_now']
            ?? $allowPayNowCandidate;

        return [
            'allow_pay_now' => $this->toBool($allowPayNowCandidate),
            'allow_pay_on_delivery' => $this->toBool($allowPayOnDeliveryCandidate),
            'cod_fee' => $this->toFloatOrNull($codFeeCandidate),
            'collect_on_delivery' => $this->toBool($collectOnDeliveryCandidate),
            'prepaid_required' => $this->toBool($prepaidRequiredCandidate),
            'due_now' => $this->toBool($dueNowCandidate),
        ];
    }

    private function flattenPaymentOptions(array $payment): array
    {
        return [
            'allow_pay_now' => $payment['allow_pay_now'] ?? true,
            'allow_pay_on_delivery' => $payment['allow_pay_on_delivery'] ?? true,
            'cod_fee' => $payment['cod_fee'] ?? null,
            'collect_on_delivery' => $payment['collect_on_delivery'] ?? ($payment['allow_pay_on_delivery'] ?? true),
            'prepaid_required' => $payment['prepaid_required'] ?? false,
            'due_now' => $payment['due_now'] ?? true,
        ];
    }

    private function extractTimingSource(array $data): ?array
    {
        foreach (['timing_codes', 'timings', 'timing'] as $key) {
            if (! array_key_exists($key, $data)) {
                continue;
            }

            $value = $data[$key];
            if (is_array($value)) {
                return $value;
            }

            if (is_string($value) && $value !== '') {
                return ['suggested' => $value];
            }
        }

        return null;
    }

    private function extractTimingCodes(array $timing, array $data): array
    {
        $codes = $timing['codes'] ?? [];
        if (! is_array($codes)) {
            $codes = [];
        }

        if ($codes === [] && isset($data['timing_codes']) && is_array($data['timing_codes'])) {
            $codes = $data['timing_codes'];
        }

        return $codes;
    }

    private function resolveSuggestedTiming(array $data, array $timing): ?string
    {
        $candidates = [];

        foreach ([
            $data['suggested_timing'] ?? null,
            $data['suggested_timing_code'] ?? null,
        ] as $value) {
            if (is_string($value) && $value !== '') {
                $candidates[] = $value;
            }
        }

        foreach (['suggested', 'recommended', 'default', 'preferred'] as $key) {
            $value = $timing[$key] ?? null;
            if (is_string($value) && $value !== '') {
                $candidates[] = $value;
            }
        }

        return $candidates[0] ?? null;
    }

    private function toFloatOrNull(mixed $value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_numeric($value)) {
            return (float) $value;
        }

        return null;
    }

    private function toBool(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        if ($value === null) {
            return false;
        }

        if (is_string($value)) {
            $filtered = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            if ($filtered !== null) {
                return $filtered;
            }
        }

        return (bool) $value;
    }
}
