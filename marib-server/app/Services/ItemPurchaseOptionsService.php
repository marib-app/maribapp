<?php

namespace App\Services;

use App\Models\Item;
use App\Models\ItemCustomFieldValue;
use App\Models\ItemStock;
use App\Support\VariantKeyGenerator;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

class ItemPurchaseOptionsService
{
    public function __construct(private readonly DatabaseManager $db)
    {
    }

    /**
     * @return Collection<int, array<string, mixed>>
     */
    public function collectAttributes(Item $item): Collection
    {
        $item->loadMissing(['item_custom_field_values', 'custom_fields']);

        $fields = $item->custom_fields ?? collect();
        $values = $item->item_custom_field_values instanceof Collection
            ? $item->item_custom_field_values->keyBy('custom_field_id')
            : collect();

        return $fields
            ->filter(static fn ($field) => (bool) ($field->required_for_checkout ?? false) || (bool) ($field->affects_stock ?? false))
            ->values()
            ->map(function ($field) use ($values) {
                $customValue = $values->get($field->id);
                $selectedValues = $this->resolveSelectedValues($customValue);


                return [
                    'id' => $field->id,
                    'key' => $this->attributeKey($field->id),
                    'name' => $field->name,
                    'type' => $field->type,
                    'required_for_checkout' => (bool) ($field->required_for_checkout ?? false) || (bool) ($field->affects_stock ?? false),
                    'affects_stock' => (bool) ($field->affects_stock ?? false),
                    'allowed_values' => $this->normalizeAllowedValues($field->allowed_values ?? $field->values ?? []),
                    'values' => $this->normalizeAllowedValues($field->values ?? []),
                    'default_value' => $this->resolveCustomFieldValue($customValue),
                    'selected_values' => $selectedValues,
                    'ui_type' => $field->type ?? null,

                ];
            });
    }

    /**
     * @param array<string, mixed> $attributes
     * @return array<string, string>
     * @throws ValidationException
     */
    public function sanitizeAttributes(Item $item, array $attributes): array
    {
        $definitions = $this->collectAttributes($item);
        if ($definitions->isEmpty()) {
            return [];
        }

        $normalizedInput = [];
        foreach ($attributes as $key => $value) {
            $normalizedInput[$this->normalizeAttributeKey($key)] = $this->stringifyValue($value);
        }

        $result = [];
        foreach ($definitions as $definition) {
            $key = $definition['key'];
            $value = $normalizedInput[$key] ?? '';

            $isRequired = (bool) ($definition['required_for_checkout'] ?? false);
            if (! $isRequired && (bool) ($definition['affects_stock'] ?? false)) {
                $isRequired = true;
            }

            if ($isRequired && $value === '') {
                throw ValidationException::withMessages([
                    'attributes' => __('يجب اختيار خيار :name قبل المتابعة.', ['name' => $definition['name']]),
                ]);
            }

            if ($value !== '') {
                $allowed = $definition['allowed_values'] ?? [];
                if (is_array($allowed) && $allowed !== []) {
                    $allowedNormalized = array_map([$this, 'stringifyValue'], $allowed);
                    if (! in_array($value, $allowedNormalized, true)) {
                        throw ValidationException::withMessages([
                            'attributes' => __('الخيار المحدد غير متاح لحقل :name.', ['name' => $definition['name']]),
                        ]);
                    }
                }

                $result[$key] = $value;
            }
        }

        return $result;
    }

    /**
     * @param array<string, string> $attributes
     */
    public function generateVariantKey(Item $item, array $attributes): string
    {
        $definitions = $this->collectAttributes($item);
        $affecting = $definitions->filter(static fn ($definition) => (bool) ($definition['affects_stock'] ?? false));

        if ($affecting->isEmpty()) {
            return '';
        }

        $selection = [];
        foreach ($affecting as $definition) {
            $key = $definition['key'];
            $selection[$key] = $attributes[$key] ?? '';
        }

        return VariantKeyGenerator::fromAttributes($selection);
    }

    public function resolveAvailableStock(Item $item, string $variantKey): ?int
    {
        $record = $this->findStockRecord($item, $variantKey);

        if (! $record) {
            return null;
        }

        return max(0, (int) $record->stock - (int) $record->reserved_stock);
    }

    public function ensureStockAvailability(Item $item, string $variantKey, int $quantity): void
    {
        if ($quantity <= 0) {
            return;
        }

        $record = $this->findStockRecord($item, $variantKey);

        if (! $record) {
            throw ValidationException::withMessages([
                'cart' => __('الكمية المطلوبة غير متاحة حالياً لهذا الخيار.'),
            ]);
        }

        $available = max(0, (int) $record->stock - (int) $record->reserved_stock);

        if ($quantity > $available) {
            throw ValidationException::withMessages([
                'cart' => __('الكمية المطلوبة غير متاحة حالياً لهذا الخيار.'),
            ]);
        }
    }

    public function reserveStock(Item $item, string $variantKey, int $quantity): void
    {
        if ($quantity <= 0) {
            return;
        }

        $record = $this->stockQuery($item, $variantKey, true)->first();

        if (! $record) {
            throw ValidationException::withMessages([
                'cart' => __('الكمية المطلوبة غير متاحة حالياً لهذا الخيار.'),
            ]);
        }

        $available = max(0, (int) $record->stock - (int) $record->reserved_stock);

        if ($quantity > $available) {
            throw ValidationException::withMessages([
                'cart' => __('الكمية المطلوبة غير متاحة حالياً لهذا الخيار.'),
            ]);
        }

        $record->reserved_stock += $quantity;
        $record->save();
    }

    /**
     * @return array<string, mixed>
     */
    public function buildPurchaseOptions(Item $item): array
    {
        $item->loadMissing('stocks');

        $attributes = $this->collectAttributes($item)->map(function (array $definition) {
            return [
                'id' => $definition['id'],
                'key' => $definition['key'],
                'name' => $definition['name'],
                'type' => $definition['type'],
                'required_for_checkout' => (bool) $definition['required_for_checkout'],
                'affects_stock' => (bool) $definition['affects_stock'],
                'allowed_values' => $definition['allowed_values'],
                'values' => $definition['values'],
                'default_value' => $definition['default_value'],
                'selected_values' => $definition['selected_values'] ?? [],
                'ui_type' => $definition['ui_type'] ?? null,

            ];
        })->values()->all();

        $stocks = $item->stocks->map(static function (ItemStock $stock) {
            return [
                'variant_key' => $stock->variant_key,
                'stock' => (int) $stock->stock,
                'reserved_stock' => (int) $stock->reserved_stock,
                'available_stock' => $stock->available,
            ];
        })->values()->all();

        return [
            'item_id' => $item->getKey(),
            'base_price' => (float) ($item->price ?? 0.0),
            'final_price' => (float) $item->final_price,
            'discount' => $item->discount_snapshot,
            'attributes' => $attributes,
            'variant_stocks' => $stocks,
        ];
    }

    private function attributeKey(int $id): string
    {
        return sprintf('cf%d', $id);
    }

    private function normalizeAttributeKey(mixed $key): string
    {
        $stringKey = is_string($key) ? $key : (string) $key;
        $trimmed = trim($stringKey);

        if ($trimmed === '') {
            return $trimmed;
        }

        if (preg_match('/^cf\d+$/', $trimmed)) {
            return $trimmed;
        }

        if (ctype_digit($trimmed)) {
            return $this->attributeKey((int) $trimmed);
        }

        return $trimmed;
    }

    /**
     * @param mixed $value
     */
    private function stringifyValue($value): string
    {
        if ($value === null) {
            return '';
        }

        if (is_bool($value)) {
            return $value ? '1' : '0';
        }

        if (is_numeric($value)) {
            return (string) $value;
        }

        if (is_array($value)) {
            if (isset($value['value'])) {
                return $this->stringifyValue($value['value']);
            }

            if (isset($value['label'])) {
                return $this->stringifyValue($value['label']);
            }

            if ($value === []) {
                return '';
            }

            $first = reset($value);

            return $this->stringifyValue($first);
        }

        return trim((string) $value);
    }

    /**
     * @param mixed $values
     * @return array<int, string>
     */
    private function normalizeAllowedValues($values): array
    {
        if (! is_array($values)) {
            $values = $values === null ? [] : [$values];
        }

        $normalized = [];
        foreach ($values as $value) {
            $stringValue = $this->stringifyValue($value);
            if ($stringValue === '') {
                continue;
            }

            $normalized[] = $stringValue;
        }

        return array_values(array_unique($normalized));
    }

    private function resolveCustomFieldValue(?ItemCustomFieldValue $value): ?string
    {
        if (! $value) {
            return null;
        }

        $raw = $value->value;

        if (is_array($raw)) {
            $first = reset($raw);
            return $first === false ? null : $this->stringifyValue($first);
        }

        return $this->stringifyValue($raw);
    }

    private function resolveSelectedValues(?ItemCustomFieldValue $value): array
    {
        if (! $value) {
            return [];
        }

        $raw = $value->value;

        if (is_array($raw)) {
            $normalized = [];
            foreach ($raw as $entry) {
                $stringValue = $this->stringifyValue($entry);
                if ($stringValue === '') {
                    continue;
                }

                $normalized[] = $stringValue;
            }

            return array_values(array_unique($normalized));
        }

        $stringValue = $this->stringifyValue($raw);

        return $stringValue === '' ? [] : [$stringValue];
    }


    private function findStockRecord(Item $item, string $variantKey): ?ItemStock
    {
        if (! $item->getKey()) {
            return null;
        }

        $normalizedKey = $variantKey === '' ? '' : $variantKey;

        if ($item->relationLoaded('stocks')) {
            return $item->stocks->firstWhere('variant_key', $normalizedKey);
        }

        return $this->stockQuery($item, $normalizedKey)->first();
    }

    private function stockQuery(Item $item, string $variantKey, bool $lock = false)
    {
        $query = ItemStock::query()
            ->where('item_id', $item->getKey())
            ->where('variant_key', $variantKey);

        if ($lock) {
            $query->lockForUpdate();
        }

        return $query;
    }
}