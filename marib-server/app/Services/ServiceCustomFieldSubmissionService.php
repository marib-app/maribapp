<?php

namespace App\Services;

use App\Models\Service;
use App\Models\ServiceCustomField;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ServiceCustomFieldSubmissionService
{
    /**
     * Collect and validate the payload for a service request submission.
     *
     * @param  array  $customFields     Values submitted from the client (can be associative array or array of maps)
     * @param  array  $customFieldFiles Uploaded files indexed by the same keys as $customFields
     *
     * @throws ValidationException
     */
    public function collectRequestPayload(Service $service, array $customFields, array $customFieldFiles): array
    {
        $definitions = $this->resolveFieldDefinitions($service);

        if ($definitions->isEmpty()) {
            return [];
        }

        [$valueInputs, $fileInputs] = $this->normalizeIncomingPayload($definitions, $customFields, $customFieldFiles);

        $this->validateInputs($definitions, $valueInputs, $fileInputs);

        return $this->buildPayload($definitions, $valueInputs, $fileInputs);
    }

    private function resolveFieldDefinitions(Service $service): Collection
    {
        $schema = $service->service_fields_schema;

        if (is_array($schema) && $schema !== []) {
            return $this->buildDefinitionsFromSchema($schema);
        }

        $service->loadMissing('serviceCustomFields');

        return $this->buildDefinitionsFromModels($service->serviceCustomFields);
    }

    private function buildDefinitionsFromSchema(array $schema): Collection
    {
        $definitions = collect();

        foreach ($schema as $index => $field) {
            if (!is_array($field)) {
                continue;
            }

            $type = $this->normalizeFieldType($field['type'] ?? $field['field_type'] ?? $field['input_type'] ?? 'textbox');
            $isActive = $field['status'] ?? $field['active'] ?? true;

            if (!$isActive) {
                continue;
            }

            $label = trim((string) ($field['title'] ?? $field['label'] ?? $field['name'] ?? ''));
            $key = trim((string) ($field['name'] ?? $field['key'] ?? ''));

            if ($key === '') {
                $key = 'field_' . ($index + 1);
            }

            if ($label === '') {
                $label = Str::title(str_replace(['_', '-'], ' ', $key));
            }

            $options = $this->normalizeOptions($field['values'] ?? ($field['options'] ?? []));

            $properties = $field['properties'] ?? [];
            if (!is_array($properties)) {
                $properties = [];
            }

            foreach (['min', 'max', 'min_length', 'max_length'] as $property) {
                if (!array_key_exists($property, $properties) && array_key_exists($property, $field)) {
                    $properties[$property] = $field[$property];
                }
            }

            $definitions->push([
                'id'         => $field['id'] ?? null,
                'key'        => $key,
                'label'      => $label,
                'type'       => $type,
                'required'   => (bool) ($field['required'] ?? $field['is_required'] ?? false),
                'note'       => $field['note'] ?? ($field['description'] ?? null),
                'meta'       => $field['meta'] ?? null,
                'options'    => $options,
                'properties' => $this->normalizeNumericProperties($properties),
                'aliases'    => $this->buildSchemaAliases($key, $field['id'] ?? null),
            ]);
        }

        return $definitions;
    }

    private function buildDefinitionsFromModels(Collection $fields): Collection
    {
        return $fields->map(function (ServiceCustomField $field) {
            return [
                'id'         => $field->id,
                'key'        => $field->form_key,
                'label'      => $field->name ?? $field->form_key,
                'type'       => $field->normalizedType(),
                'required'   => (bool) $field->is_required,
                'note'       => $field->note,
                'meta'       => $field->meta,
                'options'    => $this->normalizeOptions($field->values),
                'properties' => $this->normalizeNumericProperties([
                    'min'        => $field->min_value,
                    'max'        => $field->max_value,
                    'min_length' => $field->min_length,
                    'max_length' => $field->max_length,
                ]),
                'aliases'    => $this->buildModelAliases($field),
            ];
        })->values();
    }



    private function normalizeInputKey($key): string
    {
        if (is_int($key)) {
            return (string) $key;
        }

        $key = trim((string) $key);
        if ($key === '') {
            return '';
        }

        $bracketPatterns = [
            '/^custom_fields\[(.+)\]$/',
            '/^custom_field_files\[(.+)\]$/',
            '/^fields\[(.+)\]$/',
            '/^field\[(.+)\]$/',
        ];

        foreach ($bracketPatterns as $pattern) {
            if (preg_match($pattern, $key, $matches)) {
                $key = $matches[1];
                break;
            }
        }

        if (str_contains($key, '.')) {
            $parts = array_values(array_filter(explode('.', $key), static function ($part) {
                return $part !== '';
            }));

            if (!empty($parts)) {
                if (in_array($parts[0], ['custom_fields', 'fields', 'customField', 'field'], true)) {
                    $key = end($parts);
                }
            }
        }

        return trim($key);
    }



    private function normalizeFieldType(string $type): string
    {
        $type = strtolower(trim($type));

        return match ($type) {
            'select'   => 'dropdown',
            'file',
            'image'    => 'fileinput',
            'textarea' => 'textbox',
            default    => in_array($type, ['textbox', 'number', 'dropdown', 'radio', 'checkbox', 'fileinput', 'color'], true)
                ? $type
                : 'textbox',
        };
    }

    private function normalizeOptions($options): array
    {
        if (!is_array($options)) {
            return [];
        }

        return array_values(array_filter(array_map(function ($value) {
            if (is_scalar($value) || (is_object($value) && method_exists($value, '__toString'))) {
                return (string) $value;
            }

            return null;
        }, $options), static fn ($value) => $value !== null));
    }

    private function normalizeNumericProperties(array $properties): array
    {
        $normalized = [];

        foreach (['min', 'max', 'min_length', 'max_length'] as $property) {
            if (!array_key_exists($property, $properties)) {
                continue;
            }

            $value = $properties[$property];

            if ($value === null || $value === '') {
                continue;
            }

            $normalized[$property] = is_numeric($value) ? 0 + $value : $value;
        }

        return $normalized;
    }

    private function buildSchemaAliases(string $key, $id): array
    {
        $aliases = [$key];

        if ($id !== null) {
            $aliases[] = (string) $id;
        }

        return array_values(array_unique($aliases));
    }

    private function buildModelAliases(ServiceCustomField $field): array
    {
        $aliases = [$field->form_key];

        if (!empty($field->handle)) {
            $aliases[] = $field->handle;
        }

        if (!empty($field->name)) {
            $aliases[] = ServiceCustomField::normalizeKey($field->name);
        }

        $aliases[] = (string) $field->id;

        return array_values(array_unique(array_filter($aliases)));
    }

    private function normalizeIncomingPayload(Collection $definitions, array $customFields, array $customFieldFiles): array
    {
        $valueInputs = $this->normalizeCustomFieldValues($customFields);
        $fileInputs = $this->normalizeCustomFieldFiles($customFieldFiles);

        $mappedValues = [];
        $mappedFiles = [];

        foreach ($definitions as $definition) {
            foreach ($definition['aliases'] as $alias) {
                if (array_key_exists($alias, $valueInputs)) {
                    $mappedValues[$definition['key']] = $valueInputs[$alias];
                    break;
                }
            }

            foreach ($definition['aliases'] as $alias) {
                if (array_key_exists($alias, $fileInputs)) {
                    $mappedFiles[$definition['key']] = $fileInputs[$alias];
                    break;
                }
            }
        }

        return [$mappedValues, $mappedFiles];
    }

    private function normalizeCustomFieldValues(array $inputs): array
    {
        if (Arr::isAssoc($inputs)) {
            $normalizedAssoc = [];
            foreach ($inputs as $key => $value) {
                $normalizedKey = $this->normalizeInputKey($key);
                if ($normalizedKey === '') {
                    continue;
                }
                $normalizedAssoc[$normalizedKey] = $value;
            }

            return $normalizedAssoc;
        
        }

        $normalized = [];

        foreach ($inputs as $entry) {
            if (!is_array($entry)) {
                continue;
            }

            $key = $entry['name'] ?? $entry['key'] ?? $entry['form_key'] ?? $entry['id'] ?? null;
            if ($key === null || $key === '') {
                continue;
            }



            $key = $this->normalizeInputKey($key);

            if ($key === '') {
                continue;
            }

            if (array_key_exists('value', $entry)) {
                $normalized[$key] = $entry['value'];
                continue;
            }

            foreach (['values', 'selected', 'checked'] as $candidate) {
                if (array_key_exists($candidate, $entry)) {
                    $normalized[$key] = $entry[$candidate];
                    break;
                }
            }
        }

        return $normalized;
    }

    private function normalizeCustomFieldFiles(array $inputs): array
    {
        $normalized = [];

        foreach ($inputs as $key => $value) {


            $normalizedKey = $this->normalizeInputKey($key);
            if ($normalizedKey === '') {
                continue;
            }

            if ($value instanceof UploadedFile) {
                $normalized[$normalizedKey] = $value;
                continue;
            }

            if (!is_array($value)) {
                continue;
            }

            foreach ($value as $nestedKey => $nestedValue) {
                if ($nestedValue instanceof UploadedFile) {
                    $normalizedNestedKey = $this->normalizeInputKey($nestedKey);

                    if ($normalizedNestedKey !== '') {
                        $normalized[$normalizedNestedKey] = $nestedValue;


                    }

                    if (!isset($normalized[$normalizedKey])) {
                        $normalized[$normalizedKey] = $nestedValue;
                    }
                }
            }
        }

        return $normalized;
    }

    private function validateInputs(Collection $definitions, array $values, array $files): void
    {
        $rules = [];
        $attributes = [];

        foreach ($definitions as $definition) {
            $key = $definition['key'];
            $label = $definition['label'];
            $type = $definition['type'];
            $required = (bool) $definition['required'];
            $options = $definition['options'];
            $properties = $definition['properties'];

            $attributes["custom_fields.$key"] = $label;
            $attributes["custom_field_files.$key"] = $label;

            switch ($type) {
                case 'checkbox':
                    $rule = [$required ? 'required' : 'nullable', 'array'];
                    if ($required) {
                        $rule[] = 'min:1';
                    }
                    $rules["custom_fields.$key"] = $rule;
                    if (!empty($options)) {
                        $rules["custom_fields.$key.*"] = [Rule::in($options)];
                    }
                    break;
                case 'number':
                    $rule = [$required ? 'required' : 'nullable', 'numeric'];
                    if (isset($properties['min'])) {
                        $rule[] = 'min:' . $properties['min'];
                    }
                    if (isset($properties['max'])) {
                        $rule[] = 'max:' . $properties['max'];
                    }
                    $rules["custom_fields.$key"] = $rule;
                    break;
                case 'dropdown':
                case 'radio':
                case 'color':
                    $rule = [$required ? 'required' : 'nullable', 'string'];
                    if (!empty($options)) {
                        $rule[] = Rule::in($options);
                    }
                    $rules["custom_fields.$key"] = $rule;
                    break;
                case 'fileinput':
                    $rules["custom_field_files.$key"] = [
                        $required ? 'required' : 'nullable',
                        'file',
                        'max:10240',
                    ];
                    break;
                default:
                    $rule = [$required ? 'required' : 'nullable', 'string'];
                    if (isset($properties['min_length'])) {
                        $rule[] = 'min:' . (int) $properties['min_length'];
                    } elseif (isset($properties['min'])) {
                        $rule[] = 'min:' . (int) $properties['min'];
                    }

                    if (isset($properties['max_length'])) {
                        $rule[] = 'max:' . (int) $properties['max_length'];
                    } elseif (isset($properties['max'])) {
                        $rule[] = 'max:' . (int) $properties['max'];
                    }

                    $rules["custom_fields.$key"] = $rule;
            }
        }

        $validator = Validator::make([
            'custom_fields'       => $values,
            'custom_field_files'  => $files,
        ], $rules, [], $attributes);

        if ($validator->fails()) {
            throw new ValidationException($validator);
        }
    }

    private function buildPayload(Collection $definitions, array $values, array $files): array
    {
        $payload = [];

        foreach ($definitions as $definition) {
            $key = $definition['key'];
            $type = $definition['type'];
            $label = $definition['label'];
            $note = $definition['note'] ?? null;
            $meta = $definition['meta'] ?? null;
            $options = $definition['options'];
            $properties = $definition['properties'];

            $entry = [
                'id'     => $definition['id'],
                'name'   => $key,
                'label'  => $label,
                'title'  => $label,
                'type'   => $type,
            ];

            if (!empty($definition['required'])) {
                $entry['required'] = true;
            }

            if (!empty($options)) {
                $entry['options'] = $options;
            }

            if (!empty($properties)) {
                $entry['properties'] = $properties;
            }

            if ($note !== null && $note !== '') {
                $entry['note'] = $note;
            }

            if (!empty($meta)) {
                $entry['meta'] = $meta;
            }

            if ($type === 'fileinput') {
                $file = $files[$key] ?? null;
                $path = $file instanceof UploadedFile
                    ? FileService::upload($file, 'service_requests/custom_fields')
                    : null;

                if ($path !== null) {
                    $entry['value'] = $path;
                    $entry['file_path'] = $path;
                    $entry['file_url'] = Storage::disk('public')->url($path);
                } else {
                    $entry['value'] = null;
                }
            } else {
                $raw = $values[$key] ?? null;
                [$scalar, $list] = $this->normalizeValueForPayload($type, $raw, $options);

                if ($scalar !== null) {
                    $entry['value'] = $scalar;
                }

                if ($list !== null) {
                    $entry['values'] = $list;
                    $entry['display_value'] = implode(', ', array_map('strval', $list));
                } elseif ($scalar !== null) {
                    $entry['display_value'] = (string) $scalar;
                }
            }

            $payload[] = $entry;
        }

        return $payload;
    }

    private function normalizeValueForPayload(string $type, $value, array $options): array
    {
        if ($type === 'checkbox') {
            $values = is_array($value) ? $value : ($value !== null ? [$value] : []);
            $values = array_values(array_filter(array_map(function ($item) {
                if (is_scalar($item) || (is_object($item) && method_exists($item, '__toString'))) {
                    return (string) $item;
                }

                return null;
            }, $values), static fn ($item) => $item !== null));

            if (!empty($options)) {
                $values = array_values(array_intersect($values, $options));
            }

            return [null, $values];
        }

        if ($value === null || $value === '') {
            return [null, null];
        }

        if (is_array($value)) {
            $value = Arr::first($value);
        }

        $scalar = (string) $value;

        if ($type === 'color') {
            $scalar = strtoupper(ltrim($scalar, '#'));
        }

        return [$scalar, null];
    }
}