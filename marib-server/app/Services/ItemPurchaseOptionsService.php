<?php

namespace App\Services;

use App\Models\Item;
use App\Models\ItemAttribute;
use App\Models\ItemAttributeValue;
use App\Models\ItemStock;
use App\Support\VariantKeyGenerator;
use App\Support\ColorFieldParser;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;
use App\Support\VariantKeyNormalizer;
use App\Services\DepartmentAdvertiserService;
use Illuminate\Support\Facades\Config;
class ItemPurchaseOptionsService
{
    public function __construct(
        private readonly DatabaseManager $db,
        private readonly DepartmentAdvertiserService $departmentAdvertiserService
    )
    {
    }




    public function supportsProductManagement(Item $item): bool
    {

        if ($this->departmentAdvertiserService->isExcludedSectionItem($item)) {
            return false;
        }


        $department = $this->departmentAdvertiserService->resolveDepartmentForItem($item);

        if (in_array($department, ['shein', 'computer', 'store'], true)) {
            return true;
        }

        $allowedRoots = collect(Config::get('cart.department_roots', []))
            ->only(['shein', 'computer', 'store'])
            ->map(static fn ($id) => $id !== null ? (int) $id : null)
            ->filter(static fn ($id) => $id !== null && $id > 0)
            ->unique()
            ->values();

        if ($allowedRoots->isEmpty()) {
            return false;
        }

        $candidateIds = collect();

        if ($item->category_id) {
            $candidateIds->push((int) $item->category_id);
        }

        if ($item->category && $item->category->id) {
            $candidateIds->push((int) $item->category->id);
        }

        if (! empty($item->all_category_ids)) {
            preg_match_all('/\d+/', (string) $item->all_category_ids, $matches);
            foreach (($matches[0] ?? []) as $value) {
                $candidateIds->push((int) $value);
            }
        }

        $ids = $candidateIds
            ->filter(static fn ($id) => $id !== null)
            ->map(static fn ($id) => (int) $id)
            ->unique();

        return $ids->contains(static fn ($id) => $allowedRoots->contains($id));
    }


    /**
     * @return Collection<int, array<string, mixed>>
     */
    public function collectAttributes(Item $item): Collection
    {
         $item->loadMissing(['purchaseAttributes', 'purchaseAttributes.values']);

        $attributes = $item->purchaseAttributes instanceof Collection
            ? $item->purchaseAttributes
            : collect($item->purchaseAttributes ?? []);


        return $attributes
            ->sortBy(fn (ItemAttribute $attribute) => [$attribute->position, $attribute->id])
            ->values()
            ->map(function (ItemAttribute $attribute) {
                $type = strtolower((string) ($attribute->type ?? 'custom'));

                $allowedValues = [];
                $selectedValues = [];
                $colorEntries = [];

                $values = $attribute->values instanceof Collection
                    ? $attribute->values
                    : collect($attribute->values ?? []);

                $values = $values
                    ->sortBy(fn (ItemAttributeValue $value) => [$value->position, $value->id])
                    ->values();

                if ($type === 'color') {
                    $register = static function (array &$entries, ItemAttributeValue $value): void {
                        $code = ColorFieldParser::normalizeCode($value->value);
                        if (! $code) {
                            return;
                        }

                        $entry = ['code' => strtoupper($code)];
                        if ($value->quantity !== null) {
                            $entry['quantity'] = max(0, (int) $value->quantity);
                        }

                        if ($value->label) {
                            $entry['label'] = $value->label;
                        }

                        $entries[$entry['code']] = $entry;
                    };

                    foreach ($values as $value) {
                        $register($colorEntries, $value);
                    }

                    $allowedValues = array_keys($colorEntries);
                    $selectedValues = $allowedValues;
                } else {
                    foreach ($values as $value) {
                        $string = $this->stringifyValue($value->value);
                        if ($string === '') {
                            continue;
                        }


                        $allowedValues[] = $string;
                    }

                    $allowedValues = array_values(array_unique($allowedValues));
                    $selectedValues = $allowedValues;
                }


                return [
                    'id' => $attribute->id,
                    'key' => $this->attributeKey($attribute->id),
                    'name' => $attribute->name,
                    'type' => $type,
                    'required_for_checkout' => (bool) ($attribute->required_for_checkout ?? false) || (bool) ($attribute->affects_stock ?? false),
                    'affects_stock' => (bool) ($attribute->affects_stock ?? false),
                    'allowed_values' => $allowedValues,
                    'values' => $allowedValues,
                    'default_value' => null,
                    'selected_values' => $selectedValues,
                    'ui_type' => $type,
                    'color_entries' => array_values($colorEntries),
                    'metadata' => $attribute->metadata ?? [],
                    'position' => $attribute->position,

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

        if (! $this->itemHasVariantSpecificStock($item)) {
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

            if (! $this->itemHasManagedStock($item)) {
                return;
            }

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

        $keys = VariantKeyNormalizer::expand($variantKey);
        $record = $this->stockQuery($item, $keys, true)->first();

        $record = $this->ensureCanonicalStockKey($record, $keys[0] ?? '');


        if (! $record) {

            if (! $this->itemHasManagedStock($item)) {
                return;
            }

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


    private function itemHasManagedStock(Item $item): bool
    {
        if (! $item->getKey()) {
            return false;
        }

        if ($item->relationLoaded('stocks')) {
            return $item->stocks->isNotEmpty();
        }

        return ItemStock::query()
            ->where('item_id', $item->getKey())
            ->exists();
    }

    private function itemHasVariantSpecificStock(Item $item): bool
    {
        if (! $item->getKey()) {
            return false;
        }

        if ($item->relationLoaded('stocks')) {
            return $item->stocks->contains(static function (ItemStock $stock) {
                $key = trim((string) ($stock->variant_key ?? ''));

                return $key !== '';
            });
        }

        return ItemStock::query()
            ->where('item_id', $item->getKey())
            ->whereNotNull('variant_key')
            ->where('variant_key', '!=', '')
            ->exists();
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
                'color_entries' => $definition['color_entries'] ?? [],
                'metadata' => $definition['metadata'] ?? [],
                'position' => $definition['position'] ?? 0,
            ];
        })->values()->all();

        $stocks = $item->stocks->map(function (ItemStock $stock) {
            $currentKey = (string) ($stock->variant_key ?? '');
            $normalizedKey = VariantKeyNormalizer::normalize($currentKey);

            if ($normalizedKey !== $currentKey) {
                $stock->variant_key = $normalizedKey;
                $stock->save();
            }
            
            return [
                'variant_key' => $normalizedKey,
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
            'delivery_size' => $this->normalizeDeliverySizeValue($item->delivery_size),
            'attributes' => $attributes,
            'variant_stocks' => $stocks,
        ];
    }


    private function normalizeDeliverySizeValue(mixed $value): ?float
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $normalized = trim($value);

            if ($normalized !== '') {
                $normalized = strtr($normalized, [
                    '٠' => '0',
                    '١' => '1',
                    '٢' => '2',
                    '٣' => '3',
                    '٤' => '4',
                    '٥' => '5',
                    '٦' => '6',
                    '٧' => '7',
                    '٨' => '8',
                    '٩' => '9',
                    '٫' => '.',
                ]);
            }

            $normalized = str_replace(',', '.', $normalized);
            

            if ($normalized === '') {
                return null;
            }

            if (str_starts_with($normalized, '.')) {
                $normalized = '0' . $normalized;
            }

            if (!preg_match('/^(?:\d+)(?:\.\d+)?$/', $normalized)) {
                return null;
            }

            $weight = (float) $normalized;
        } elseif (is_numeric($value)) {
            $weight = (float) $value;
        } else {
            return null;
        }

        if ($weight <= 0) {
            return null;
        }

        return round($weight, 3);
    }



    private function attributeKey(int $id): string
    {
        return sprintf('attr%d', $id);

    }

    private function normalizeAttributeKey(mixed $key): string
    {
        $stringKey = is_string($key) ? $key : (string) $key;
        $trimmed = trim($stringKey);

        if ($trimmed === '') {
            return $trimmed;
        }

        if (preg_match('/^attr\d+$/', $trimmed)) {


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



    

    private function findStockRecord(Item $item, string $variantKey): ?ItemStock
    {
        if (! $item->getKey()) {
            return null;
        }

        $keys = VariantKeyNormalizer::expand($variantKey);

        if ($item->relationLoaded('stocks')) {
            foreach ($keys as $candidate) {
                $record = $item->stocks->firstWhere('variant_key', $candidate);

                if ($record) {
                    return $this->ensureCanonicalStockKey($record, $keys[0] ?? '');
                }
            }

            return null;
        
        }

        $record = $this->stockQuery($item, $keys)->first();

        return $this->ensureCanonicalStockKey($record, $keys[0] ?? '');
    
    }

    private function stockQuery(Item $item, array $variantKeys, bool $lock = false)
    {
        $query = ItemStock::query()
            ->where('item_id', $item->getKey());

        if (count($variantKeys) === 1) {
            $query->where('variant_key', $variantKeys[0]);
        } else {
            $query->whereIn('variant_key', $variantKeys);
        }



        if ($lock) {
            $query->lockForUpdate();
        }

        return $query;
    }


    private function ensureCanonicalStockKey(?ItemStock $stock, string $canonicalKey): ?ItemStock
    {
        if (! $stock) {
            return null;
        }

        $currentKey = (string) ($stock->variant_key ?? '');

        if ($canonicalKey !== '' && $currentKey !== $canonicalKey) {
            $stock->variant_key = $canonicalKey;
            $stock->save();
            $stock->variant_key = $canonicalKey;
        }

        return $stock;
    }
}
