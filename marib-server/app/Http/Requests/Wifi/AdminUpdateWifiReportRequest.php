<?php

namespace App\Http\Requests\Wifi;

use App\Enums\Wifi\WifiReportStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class AdminUpdateWifiReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'status' => ['required', 'string', Rule::in(array_map(static fn (WifiReportStatus $status) => $status->value, WifiReportStatus::cases()))],
            'assigned_to' => ['nullable', 'integer', 'exists:users,id'],
            'resolution_notes' => ['nullable', 'string'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $report = $this->route('report');
            if (! $report) {
                return;
            }

            $target = WifiReportStatus::from($this->input('status'));
            $current = $report->status;

            if ($current === $target) {
                $validator->errors()->add('status', __('The report already has this status.'));
                return;
            }

            $allowed = match ($current) {
                WifiReportStatus::OPEN => [WifiReportStatus::INVESTIGATING, WifiReportStatus::DISMISSED],
                WifiReportStatus::INVESTIGATING => [WifiReportStatus::RESOLVED, WifiReportStatus::DISMISSED],
                default => [],
            };

            if (! in_array($target, $allowed, true)) {
                $validator->errors()->add('status', __('The requested status transition is not permitted.'));
            }
        });
    }
}