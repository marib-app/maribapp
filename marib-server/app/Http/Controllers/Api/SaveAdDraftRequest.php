<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SaveAdDraftRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'current_step' => ['required', 'string', 'max:64', Rule::in([
                'mainCategory',
                'subCategory',
                'customFields',
                'media',
                'textDetails',
                'locationInventory',
                'review',
            ])],
            'payload' => ['required', 'array'],
            'step_payload' => ['nullable', 'array'],
            'temporary_media' => ['nullable', 'array'],
            'temporary_media.pending' => ['sometimes', 'array'],
            'temporary_media.pending.*.type' => ['sometimes', 'string', 'max:32'],
            'temporary_media.pending.*.name' => ['sometimes', 'nullable', 'string', 'max:255'],
            'temporary_media.pending.*.path' => ['sometimes', 'nullable', 'string'],
            'temporary_media.pending.*.size' => ['sometimes', 'nullable', 'integer'],
            'temporary_media.video_links' => ['sometimes', 'array'],
            'temporary_media.video_links.*' => ['string'],
        ];
    }

    public function normalized(): array
    {
        $data = $this->validated();
        $data['step_payload'] = $data['step_payload'] ?? [];
        $data['temporary_media'] = $data['temporary_media'] ?? [];

        return $data;
    }
}