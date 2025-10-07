<?php

namespace App\Services;

use ArrayAccess;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;

class DepartmentPolicyService
{
    private const DEPARTMENT_CONFIG = [
        DepartmentReportService::DEPARTMENT_SHEIN => [
            'deposit' => [
                'ratio' => 'orders_deposit_shein_ratio',
                'minimum_amount' => 'orders_deposit_shein_minimum',
            ],
            'return_policy' => 'return_policy_shein',
            'return_policy_fallback' => 'department_return_policy_shein',
            'whatsapp' => [
                'enabled' => 'whatsapp_enabled_shein',
                'number' => 'whatsapp_number_shein',
            ],
        ],
        DepartmentReportService::DEPARTMENT_COMPUTER => [
            'deposit' => [
                'ratio' => 'orders_deposit_computer_ratio',
                'minimum_amount' => 'orders_deposit_computer_minimum',
            ],
            'return_policy' => 'return_policy_computer',
            'return_policy_fallback' => 'department_return_policy_computer',
            'whatsapp' => [
                'enabled' => 'whatsapp_enabled_computer',
                'number' => 'whatsapp_number_computer',
            ],
        ],
    ];

    private const DEFAULT_WHATSAPP_KEY = 'whatsapp_number';

    private ?array $settings = null;

    public function policyFor(?string $department): array
    {
        $settings = $this->settings();

        $policy = [
            'department' => $department,
            'return_policy_text' => null,
            'deposit' => null,
            'whatsapp' => [
                'department' => $department,
                'enabled' => false,
                'number' => null,
                'default_number' => $this->defaultWhatsappNumber(),
            ],
        ];

        if (! $this->isSupported($department)) {
            return $policy;
        }

        $config = self::DEPARTMENT_CONFIG[$department];

        $returnPolicyText = $this->normalizeReturnPolicy(
            Arr::get($settings, $config['return_policy'])
        );

        if ($returnPolicyText === null && isset($config['return_policy_fallback'])) {
            $returnPolicyText = $this->normalizeReturnPolicy(
                Arr::get($settings, $config['return_policy_fallback'])
            );
        }

        $policy['return_policy_text'] = $returnPolicyText;

        $policy['deposit'] = $this->buildDepositPolicy($department, $settings, $config['deposit'] ?? []);
        $policy['whatsapp'] = $this->buildWhatsappPolicy($department, $settings, $config['whatsapp'] ?? []);

        return $policy;
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    public function policies(): array
    {
        $policies = [];

        foreach (array_keys(self::DEPARTMENT_CONFIG) as $department) {
            $policies[$department] = $this->policyFor($department);
        }

        return $policies;
    }

    public function isSupported(?string $department): bool
    {
        return is_string($department) && array_key_exists($department, self::DEPARTMENT_CONFIG);
    }

    public function defaultWhatsappNumber(): ?string
    {
        return $this->normalizeString(Arr::get($this->settings(), self::DEFAULT_WHATSAPP_KEY));
    }

    private function buildDepositPolicy(string $department, array $settings, array $keys): ?array
    {


        $ratioKey = $keys['ratio'] ?? null;
        $ratioValue = null;

        if ($ratioKey && array_key_exists($ratioKey, $settings)) {
            $rawRatio = $settings[$ratioKey];

            if (is_string($rawRatio)) {
                $rawRatio = trim($rawRatio);
            }

            if ($rawRatio !== '' && $rawRatio !== null && is_numeric($rawRatio)) {
                $ratioValue = (float) $rawRatio;
            }
        }

        if ($ratioValue === null) {
            return null;
        }

        $policy = config("orders.deposit.departments.$department", []);

        if (! is_array($policy)) {
            $policy = [];
        }

        $policy['ratio'] = $ratioValue;


        unset($policy['minimum_amount'], $policy['minimum']);



        if (! array_key_exists('department', $policy)) {
            $policy['department'] = $department;
        }

        if ($this->depositPolicyIsEmpty($policy)) {
            return null;
        }

        return $policy;
    }

    private function depositPolicyIsEmpty(array $policy): bool
    {
        $ratio = (float) ($policy['ratio'] ?? 0.0);
        return $ratio <= 0.0;


    }

    private function buildWhatsappPolicy(string $department, array $settings, array $keys): array
    {
        $enabledKey = $keys['enabled'] ?? null;
        $numberKey = $keys['number'] ?? null;

        $enabled = $enabledKey ? $this->toBoolean($settings[$enabledKey] ?? null) : false;
        $number = $numberKey ? $this->normalizeString($settings[$numberKey] ?? null) : null;

        return [
            'department' => $department,
            'enabled' => $enabled,
            'number' => $number,
            'default_number' => $this->defaultWhatsappNumber(),
        ];
    }

    private function normalizeReturnPolicy(mixed $value): ?string
    {
        return $this->normalizeString($value);
    }

    private function normalizeString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $value = trim($value);

            return $value === '' ? null : $value;
        }

        if (is_numeric($value)) {
            return (string) $value;
        }

        return null;
    }

    private function toBoolean(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN);
    }

    private function settings(): array
    {
        if ($this->settings !== null) {
            return $this->settings;
        }

        $settings = CachingService::getSystemSettings();

        if ($settings instanceof Collection) {
            $settings = $settings->toArray();
        } elseif ($settings instanceof ArrayAccess) {
            $settings = (array) $settings;
        }

        if (! is_array($settings)) {
            $settings = [];
        }

        return $this->settings = $settings;
    }
}