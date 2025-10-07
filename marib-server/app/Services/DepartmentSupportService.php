<?php

namespace App\Services;

class DepartmentSupportService
{

    public function __construct(private readonly DepartmentPolicyService $policyService)
    {
    }

    /**
     * Get the WhatsApp support payload for a specific department.
     */
    public function whatsappSupport(?string $department): array
    {

        if ($department === null || ! $this->policyService->isSupported($department)) {
            return $this->payloadFromNumber($this->policyService->defaultWhatsappNumber(), null);
        }

        $policy = $this->policyService->policyFor($department);
        $whatsapp = $policy['whatsapp'] ?? null;

        if (! is_array($whatsapp) || empty($whatsapp['enabled'])) {
            return $this->disabledPayload($department);
        }

        return $this->payloadFromNumber($whatsapp['number'] ?? null, $department);

    }

    /**
     * Get support payload for a department grouped by channel.
     */
    public function supportFor(?string $department): array
    {

        $policy = $this->policyService->policyFor($department);


        return [
            'whatsapp' => $this->whatsappSupport($department),
            'policy' => [
                'return_policy_text' => $policy['return_policy_text'] ?? null,
            ],

        ];
    }

    /**
     * Return WhatsApp payload for all configured departments.
     */
    public function allWhatsAppSupport(): array
    {
        $support = [];

        foreach (array_keys($this->policyService->policies()) as $department) {
            $support[$department] = $this->whatsappSupport($department);
        }

        return $support;
    }

    private function disabledPayload(?string $department): array
    {
        return [
            'enabled' => false,
            'number' => null,
            'normalized_number' => null,
            'url' => null,
            'department' => $department,
        ];
    }


    private function payloadFromNumber(?string $number, ?string $department): array
    {
        $formatted = $this->formatNumber($number);

        if ($formatted === null) {
            return $this->disabledPayload($department);
        }

        return [
            'enabled' => true,
            'number' => $formatted['display'],
            'normalized_number' => $formatted['normalized'],
               'url' => 'https://wa.me/' . $formatted['normalized'],
            'department' => $department,
        ];
    }



    /**
     * @return array{display: string, normalized: string}|null
     */
    private function formatNumber(mixed $value): ?array
    {
        if (! is_string($value) && ! is_numeric($value)) {
            return null;
        }

        $display = trim((string) $value);

        if ($display === '') {
            return null;
        }

        $normalized = preg_replace('/[^0-9]/', '', $display) ?? '';

        if ($normalized === '') {
            return null;
        }

        return [
            'display' => $display,
            'normalized' => $normalized,
        ];
    }

}