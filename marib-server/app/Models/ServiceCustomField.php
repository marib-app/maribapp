<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Str;

class ServiceCustomField extends Model
{
    protected $fillable = [
        'service_id',
        'name',
        'handle',
        'type',
        'is_required',
        'note',
        'image',
        'values',
        'min_length',
        'max_length',
        'min_value',
        'max_value',
        'sequence',
        'status',
        'meta',
    ];

    protected $casts = [
        'is_required' => 'boolean',
        'status'      => 'boolean',
        'sequence'    => 'integer',
        'min_length'  => 'integer',
        'max_length'  => 'integer',
        'min_value'   => 'float',
        'max_value'   => 'float',
        'meta'        => 'array',
    ];

    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }


    public function value(): HasOne
    {
        return $this->hasOne(ServiceCustomFieldValue::class, 'service_custom_field_id');
    }

    public function getFormKeyAttribute(): string
    {
        $metaKey = null;
        $meta = $this->meta;
        if (is_array($meta) && isset($meta['form_key'])) {
            $metaKey = (string) $meta['form_key'];
        }

        $candidates = [
            $metaKey,
            $this->handle,
            $this->name,
            $this->defaultHandle(),
        ];

        foreach ($candidates as $candidate) {
            $candidate = $this->sanitizeFormKey($candidate);
            if ($candidate !== '') {
                return $candidate;
            }
        }

        return 'field_' . $this->id;
    }



    public function getValuesAttribute($value): array
    {
        if (is_array($value)) {
            return array_values($value);
        }

        if (is_string($value)) {
            $trimmed = trim($value);
            if ($trimmed === '' || $trimmed === 'null') {
                return [];
            }

            $decoded = json_decode($trimmed, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                return is_array($decoded) ? array_values($decoded) : [$decoded];
            }

            return [$trimmed];
        }

        if ($value === null) {
            return [];
        }

        return [strval($value)];
    }

    public function setValuesAttribute($value): void
    {
        if ($value === null) {
            $this->attributes['values'] = json_encode([], JSON_UNESCAPED_UNICODE);
            return;
        }

        if (is_array($value)) {
            $normalized = array_values(array_filter($value, static function ($v) {
                return $v !== null && $v !== '';
            }));

            $this->attributes['values'] = json_encode($normalized, JSON_UNESCAPED_UNICODE);
            return;
        }

        if (is_string($value)) {
            $trimmed = trim($value);
            if ($trimmed === '') {
                $this->attributes['values'] = json_encode([], JSON_UNESCAPED_UNICODE);
                return;
            }

            $decoded = json_decode($trimmed, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $this->attributes['values'] = json_encode(is_array($decoded) ? array_values($decoded) : [$decoded], JSON_UNESCAPED_UNICODE);
                return;
            }

            $this->attributes['values'] = json_encode([$trimmed], JSON_UNESCAPED_UNICODE);
            return;
        }

        $this->attributes['values'] = json_encode([strval($value)], JSON_UNESCAPED_UNICODE);
    }

    public function setHandleAttribute($value): void
    {
        if ($value === null || $value === '') {
            $this->attributes['handle'] = null;
            return;
        }

        $slug = Str::snake(Str::slug((string) $value));
        $this->attributes['handle'] = $slug !== '' ? $slug : null;
    }

    public function toSchemaPayload(): array
    {
        $values = $this->values;
        $note   = is_string($this->note) ? trim($this->note) : '';
        $statusFlag = $this->status === null ? true : (bool) $this->status;
        $label = is_string($this->name) ? trim($this->name) : '';
        if ($label === '') {
            $label = $this->handle ?: $this->defaultHandle();
        }


        $payload = [
            'id'        => $this->id,
            'name'      => $this->form_key,
            'title'     => $label,
            'label'     => $label,

            'type'      => $this->normalizedType(),
            'required'  => (bool) $this->is_required,
            'note'      => $note,
            'sequence'  => (int) ($this->sequence ?? 0),
            'values'    => $values,
            'min'       => $this->min_value !== null ? (float) $this->min_value : null,
            'max'       => $this->max_value !== null ? (float) $this->max_value : null,
            'min_length'=> $this->min_length,
            'max_length'=> $this->max_length,
            'status'    => $statusFlag,
            'active'    => $statusFlag,

        ];

        if (!empty($this->image)) {
            $payload['image'] = $this->image;
        }

        if (!empty($this->meta)) {
            $payload['meta'] = $this->meta;
        }

        return $payload;
    }

    protected function defaultHandle(): string
    {
        $base = $this->name ?: 'field';
        $slug = Str::snake(Str::slug($base));

        if ($slug === '') {
            $slug = 'field_' . $this->id;
        }

        return $slug;
    }

    public function normalizedType(): string
    {
        $type = strtolower((string) $this->type);
        return match ($type) {
            'select'   => 'dropdown',
            'file'     => 'fileinput',
            'image'    => 'fileinput',
            'textarea' => 'textbox',
            default    => in_array($type, ['number', 'textbox', 'fileinput', 'radio', 'dropdown', 'checkbox', 'color'], true)
                ? $type
                : 'textbox',
        };
    }


    protected function sanitizeFormKey(?string $value): string
    {
        $value = $value ?? '';
        $slug = Str::snake(Str::slug($value));
        return $slug ?? '';
    }

}