<?php

namespace App\Http\Requests\Api;

use App\Http\Controllers\Api\ApiController;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Arr;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

class PublishAdDraftRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'draft_id' => ['nullable', 'integer', 'min:1'],
            'payload' => ['required', 'array'],
            'payload.interface_type' => ['required', 'string', 'max:64', Rule::in(ApiController::INTERFACE_TYPES)],
            'payload.main_category_id' => ['required', 'integer'],
            'payload.sub_category_id' => ['required', 'integer'],
            'payload.title' => ['required', 'string', 'min:10', 'max:90'],
            'payload.description' => ['required', 'string', 'min:30', 'max:1200'],
            'payload.contact' => ['required', 'string', 'max:255'],
            'payload.price' => ['required', 'numeric', 'min:0.01'],
            'payload.currency' => ['required', 'string', 'max:8'],
            'payload.media' => ['required', 'array'],
            'payload.media.images' => ['sometimes', 'array'],
            'payload.media.images.*' => ['array'],
            'payload.media.videos' => ['sometimes', 'array'],
            'payload.media.videos.*' => ['array'],
            'payload.media.video_links' => ['sometimes', 'array'],
            'payload.media.video_links.*' => ['string', 'max:2048'],
            'payload.location' => ['sometimes', 'array'],
            'payload.location.address' => ['required_with:payload.location', 'string', 'max:255'],
            'payload.location.latitude' => ['required_with:payload.location', 'numeric', 'between:-90,90'],
            'payload.location.longitude' => ['required_with:payload.location', 'numeric', 'between:-180,180'],
            'payload.inventory' => ['sometimes', 'array'],
            'payload.inventory.variations' => ['sometimes', 'array'],
            'payload.inventory.variations.*.name' => ['required_with:payload.inventory.variations', 'string', 'max:255'],
            'payload.inventory.variations.*.price' => ['required_with:payload.inventory.variations', 'numeric', 'min:0'],
            'payload.inventory.variations.*.quantity' => ['required_with:payload.inventory.variations', 'integer', 'min:0'],
            'payload.inventory.variations.*.sku' => ['sometimes', 'nullable', 'string', 'max:64'],
            'payload.custom_fields' => ['sometimes', 'array'],
            'payload.product_link' => ['sometimes', 'nullable', 'string', 'max:2048'],
            'payload.review_link' => ['sometimes', 'nullable', 'string', 'max:2048'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            $payload = $this->input('payload', []);
            $media = Arr::get($payload, 'media', []);
            $images = Arr::get($media, 'images', []);
            $videos = Arr::get($media, 'videos', []);
            $links = Arr::get($media, 'video_links', []);
            if (empty($images) && empty($videos) && empty($links)) {
                $validator->errors()->add('payload.media', __('يجب إضافة صورة أو فيديو واحد على الأقل.'));
            }

            $variations = Arr::get($payload, 'inventory.variations');
            if (is_array($variations)) {
                foreach ($variations as $index => $variation) {
                    $name = Arr::get($variation, 'name');
                    $price = Arr::get($variation, 'price');
                    $quantity = Arr::get($variation, 'quantity');

                    if ($name !== null && trim((string) $name) === '') {
                        $validator->errors()->add("payload.inventory.variations.$index.name", __('حقل الاسم مطلوب.'));
                    }
                    if ($price !== null && (float) $price <= 0) {
                        $validator->errors()->add("payload.inventory.variations.$index.price", __('السعر يجب أن يكون أكبر من صفر.'));
                    }
                    if ($quantity !== null && (int) $quantity < 0) {
                        $validator->errors()->add("payload.inventory.variations.$index.quantity", __('الكمية يجب أن تكون صفر أو أكثر.'));
                    }
                }
            }
        });
    }

    public function normalized(): array
    {
        $validated = $this->validated();
        $payload = $validated['payload'];
        $payload['title'] = trim((string) $payload['title']);
        $payload['description'] = trim((string) $payload['description']);
        $payload['contact'] = trim((string) $payload['contact']);
        $payload['price'] = (float) $payload['price'];
        $payload['currency'] = strtoupper((string) $payload['currency']);
        $payload['media'] = $this->normalizeMedia($payload['media'] ?? []);

        if (isset($payload['inventory']['variations']) && is_array($payload['inventory']['variations'])) {
            $payload['inventory']['variations'] = array_values(array_map(function ($variation) {
                return [
                    'id' => Arr::get($variation, 'id'),
                    'name' => Arr::has($variation, 'name') ? trim((string) Arr::get($variation, 'name')) : null,
                    'sku' => Arr::has($variation, 'sku') ? trim((string) Arr::get($variation, 'sku')) : null,
                    'price' => Arr::has($variation, 'price') ? (float) Arr::get($variation, 'price') : null,
                    'quantity' => Arr::has($variation, 'quantity') ? (int) Arr::get($variation, 'quantity') : null,
                ];
            }, $payload['inventory']['variations']));
        }

        return [
            'draft_id' => $validated['draft_id'] ?? null,
            'payload' => $payload,
        ];
    }

    private function normalizeMedia(array $media): array
    {
        if (isset($media['images']) && is_array($media['images'])) {
            $media['images'] = array_values($media['images']);
        }
        if (isset($media['videos']) && is_array($media['videos'])) {
            $media['videos'] = array_values($media['videos']);
        }
        if (isset($media['video_links']) && is_array($media['video_links'])) {
            $media['video_links'] = array_values($media['video_links']);
        }

        return $media;
    }
}