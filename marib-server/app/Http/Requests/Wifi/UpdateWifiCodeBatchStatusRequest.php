<?php

namespace App\Http\Requests\Wifi;

use App\Enums\Wifi\WifiCodeBatchStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class UpdateWifiCodeBatchStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        $batch = $this->route('batch');

        return $batch !== null && $this->user()?->can('update', $batch);
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'status' => ['required', 'string', Rule::in([
                WifiCodeBatchStatus::VALIDATED->value,
                WifiCodeBatchStatus::ACTIVE->value,
                WifiCodeBatchStatus::ARCHIVED->value,
            ])],
            'notes' => ['nullable', 'string'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $batch = $this->route('batch');
            if (! $batch) {
                return;
            }

            $current = $batch->status;
            $target = WifiCodeBatchStatus::from($this->input('status'));

            if ($current === $target) {
                $validator->errors()->add('status', __('The batch already has this status.'));
                return;
            }

            $allowed = match ($current) {
                WifiCodeBatchStatus::UPLOADED => [WifiCodeBatchStatus::VALIDATED, WifiCodeBatchStatus::ARCHIVED],
                WifiCodeBatchStatus::VALIDATED => [WifiCodeBatchStatus::ACTIVE, WifiCodeBatchStatus::ARCHIVED],
                WifiCodeBatchStatus::ACTIVE => [WifiCodeBatchStatus::ARCHIVED],
                default => [],
            };

            if (! in_array($target, $allowed, true)) {
                $validator->errors()->add('status', __('The requested transition is not allowed.'));
            }
        });
    }
}