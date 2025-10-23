<?php

namespace App\Http\Controllers;

use App\Models\Item;
use App\Models\ItemAttribute;

use App\Models\ItemStock;
use App\Services\ItemPurchaseOptionsService;
use Illuminate\Database\DatabaseManager;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;
use App\Support\ColorFieldParser;
use App\Support\VariantKeyNormalizer;

class ItemPurchaseManagementController extends Controller
{
    public function __construct(
        private readonly ItemPurchaseOptionsService $purchaseOptionsService,
        private readonly DatabaseManager $db
    ) {
    }

    public function updateAttributes(Request $request, Item $item): JsonResponse
    {
        if (! $this->purchaseOptionsService->supportsProductManagement($item)) {
            return $this->forbiddenResponse();
        }


        $deliverySizeProvided = $request->has('delivery_size');
        $deliverySizeValue = $item->delivery_size;

        if ($deliverySizeProvided) {
            $rawDeliverySize = $request->input('delivery_size');

            if ($rawDeliverySize === null || (is_string($rawDeliverySize) && trim($rawDeliverySize) === '')) {
                throw ValidationException::withMessages([
                    'delivery_size' => [__('يرجى إدخال وزن المنتج بالكيلوجرام.')],
                ]);
            }

            if (is_array($rawDeliverySize)) {
                throw ValidationException::withMessages([
                    'delivery_size' => [__('صيغة حقل حجم التوصيل غير صحيحة.')],
                ]);
            }
            $normalizedDeliverySize = $this->normalizeDeliverySizeValue($rawDeliverySize);

            if ($normalizedDeliverySize === null) {
                throw ValidationException::withMessages([
                    'delivery_size' => [__('يجب إدخال وزن صالح بالكيلوجرام (مثال: 2 أو 2.75).')],
                ]);
            }
                        $deliverySizeValue = $normalizedDeliverySize;

        }

        $item->loadMissing(['purchaseAttributes', 'purchaseAttributes.values']);

        $rawAttributes = $request->input('attributes', []);
        if (! is_array($rawAttributes)) {


            throw ValidationException::withMessages([
                'attributes' => [__('صيغة بيانات السمات غير صحيحة.')],
            ]);
        }

        $normalizedAttributes = [];
        foreach ($rawAttributes as $index => $entry) {
            if (! is_array($entry)) {
                continue;
            }

            $type = strtolower($this->stringifyValue($entry['type'] ?? ''));
            if (! in_array($type, ['color', 'size', 'custom'], true)) {
                throw ValidationException::withMessages([
                    'attributes' => [__('نوع السمة :type غير مدعوم.', ['type' => $entry['type'] ?? ''])],
                ]);
            }

            $name = $this->stringifyValue($entry['name'] ?? '');
            if ($name === '') {
                $name = match ($type) {
                    'color' => __('اللون'),
                    'size' => __('المقاس'),
                    default => __('سمة المنتج'),
                };
            }
            $required = filter_var($entry['required_for_checkout'] ?? false, FILTER_VALIDATE_BOOLEAN);
            $affectsStock = filter_var($entry['affects_stock'] ?? false, FILTER_VALIDATE_BOOLEAN);

            if ($type === 'color') {
                if (! array_key_exists('required_for_checkout', $entry)) {
                    $required = true;
                }

                if (! array_key_exists('affects_stock', $entry)) {
                    $affectsStock = true;
                }
            }


            $values = $entry['values'] ?? [];
            if (! is_array($values)) {
                $values = [];
            }

            $metadata = $entry['metadata'] ?? [];
            if (! is_array($metadata)) {
                $metadata = [];
            }



            $valuePayload = [];
            if ($type === 'color') {
                $seen = [];
                foreach ($values as $value) {
                    $code = null;
                    $quantity = null;
                    $label = null;

                    if (is_array($value)) {
                        $code = ColorFieldParser::normalizeCode($value['code'] ?? $value['value'] ?? null);
                        $label = $this->stringifyValue($value['label'] ?? '');
                        if (isset($value['quantity'])) {
                            $quantity = is_numeric($value['quantity']) ? (int) floor((float) $value['quantity']) : null;
                            if ($quantity !== null && $quantity < 0) {
                                $quantity = 0;
                            }
                        }
                    } else {
                        $code = ColorFieldParser::normalizeCode($value);
                    }



                    if (! $code || isset($seen[$code])) {
                        continue;
                    }

                    $seen[$code] = true;
                    $entryPayload = [
                        'code' => strtoupper($code),
                    ];

                    if ($quantity !== null) {
                        $entryPayload['quantity'] = $quantity;
                    }

                    if ($label !== '') {
                        $entryPayload['label'] = $label;
                    }

                    $valuePayload[] = $entryPayload;

                }

                if ($valuePayload === [] && ($required || $affectsStock)) {


                    throw ValidationException::withMessages([
                        'attributes' => [__('يجب إضافة لون واحد على الأقل للسمة :name.', ['name' => $name])],

                    ]);
                }

            } else {
                foreach ($values as $value) {
                    $stringValue = $this->stringifyValue(is_array($value) ? ($value['value'] ?? $value['label'] ?? '') : $value);
                    if ($stringValue === '') {
                        continue;
                    }

                    $valuePayload[] = $stringValue;
                }


                $valuePayload = array_values(array_unique($valuePayload));


                if ($valuePayload === [] && ($required || $affectsStock)) {

                    throw ValidationException::withMessages([
                        'attributes' => [__('يجب إضافة خيار واحد على الأقل للسمة :name.', ['name' => $name])],

                    ]);
                }
            }

            $normalizedAttributes[] = [
                'id' => isset($entry['id']) && is_numeric($entry['id']) ? (int) $entry['id'] : null,
                'name' => $name,
                'type' => $type,
                'required_for_checkout' => $required,
                'affects_stock' => $affectsStock,
                'position' => (int) $index,
                'metadata' => $metadata,
                'values' => $valuePayload,
            ];
        }

        $this->db->transaction(function () use ($item, $normalizedAttributes, $deliverySizeProvided, $deliverySizeValue) {
            $existing = $item->purchaseAttributes()->with('values')->get()->keyBy('id');
            $retainedIds = [];


            if ($deliverySizeProvided && $item->delivery_size !== $deliverySizeValue) {
                $item->forceFill([
                    'delivery_size' => $deliverySizeValue,
                ])->save();
            }



            foreach ($normalizedAttributes as $payload) {
                $attribute = null;
                if ($payload['id'] && $existing->has($payload['id'])) {
                    $attribute = $existing->get($payload['id']);
                }



                if (! $attribute instanceof ItemAttribute) {
                    $attribute = new ItemAttribute(['item_id' => $item->getKey()]);
                }

                $attribute->fill([
                    'name' => $payload['name'],
                    'type' => $payload['type'],
                    'required_for_checkout' => (bool) $payload['required_for_checkout'],
                    'affects_stock' => (bool) $payload['affects_stock'],
                    'position' => $payload['position'],
                    'metadata' => $payload['metadata'],
                ]);



                $attribute->item()->associate($item);
                $attribute->save();

                $retainedIds[] = $attribute->getKey();

                $attribute->values()->delete();

                $values = $payload['values'];
                $position = 0;
                foreach ($values as $value) {
                    $position++;
                    if ($payload['type'] === 'color') {
                        $attribute->values()->create([
                            'value' => $value['code'],
                            'quantity' => $value['quantity'] ?? null,
                            'label' => $value['label'] ?? null,
                            'position' => $position,
                        ]);
                    } else {
                        $attribute->values()->create([
                            'value' => $value,
                            'label' => $value,
                            'position' => $position,
                        ]);
                    }

                }
            }



            if ($retainedIds !== []) {
                $item->purchaseAttributes()
                    ->whereNotIn('id', $retainedIds)
                    ->each(function (ItemAttribute $attribute) {
                        $attribute->delete();
                    });
            } else {
                $item->purchaseAttributes()->each(function (ItemAttribute $attribute) {
                    $attribute->delete();
                });
            }


             $hasVariantAttributes = false;
            foreach ($normalizedAttributes as $payload) {
                if (! empty($payload['affects_stock'])) {
                    $hasVariantAttributes = true;
                    break;
                }
            }

            if (! $hasVariantAttributes) {
                ItemStock::query()
                    ->where('item_id', $item->getKey())
                    ->whereNotNull('variant_key')
                    ->where('variant_key', '!=', '')
                    ->delete();
            }
        });

        $item->loadMissing(['purchaseAttributes', 'purchaseAttributes.values']);


        return $this->successResponse($item, __('تم حفظ السمات بنجاح.'));
    }

    public function bulkSetStock(Request $request, Item $item): JsonResponse
    {
        if (! $this->purchaseOptionsService->supportsProductManagement($item)) {
            return $this->forbiddenResponse();
        }

        $rows = $request->input('rows');
        if (! is_array($rows)) {
            throw ValidationException::withMessages([
                'rows' => [__('صيغة بيانات المخزون غير صحيحة.')],
            ]);
        }

        $normalizedRows = [];
        foreach ($rows as $row) {
            if (! is_array($row)) {
                continue;
            }

            $rawKey = $this->stringifyValue($row['variant_key'] ?? '');
            $stock = $this->normalizeStockAmount($row['stock'] ?? null);

            $attributes = VariantKeyNormalizer::decode($rawKey);
            $canonicalKey = $attributes === []
                ? ''
                : VariantKeyNormalizer::normalize($rawKey);

            $legacyKey = $attributes === []
                ? ''
                : VariantKeyNormalizer::legacyFromAttributes($attributes);

            $normalizedRows[$canonicalKey] = [
                'variant_key' => $canonicalKey,
                'legacy_keys' => array_values(array_filter([
                    $legacyKey !== '' && $legacyKey !== $canonicalKey ? $legacyKey : null,
                    $rawKey !== '' && ! in_array($rawKey, [$canonicalKey, $legacyKey], true) ? $rawKey : null,
                ])),


                'stock' => $stock,
            ];
        }

        $this->db->transaction(function () use ($item, $normalizedRows) {
            $affectedKeys = array_keys($normalizedRows);

            foreach ($normalizedRows as $row) {
                $query = ItemStock::query()
                    ->where('item_id', $item->getKey())
                    ->where(function ($builder) use ($row) {
                        $builder->where('variant_key', $row['variant_key']);

                        foreach ($row['legacy_keys'] as $legacyKey) {
                            $builder->orWhere('variant_key', $legacyKey);
                        }
                    })
                    ->lockForUpdate();

                /** @var ItemStock|null $existing */
                $existing = $query->first();

                if ($existing) {
                    $existing->fill([
                        'variant_key' => $row['variant_key'],
                        'stock' => $row['stock'],
                        'reserved_stock' => 0,
                    ])->save();
                } else {
                    ItemStock::create([


                        'item_id' => $item->getKey(),
                        'variant_key' => $row['variant_key'],

                        'stock' => $row['stock'],
                        'reserved_stock' => 0,
                    ]);
                }
            }

            if ($affectedKeys !== []) {
                ItemStock::query()
                    ->where('item_id', $item->getKey())
                    ->whereNotIn('variant_key', $affectedKeys)
                    ->delete();
            }
        });

        $item->load('stocks');

        return $this->successResponse($item, __('تم تحديث المخزون بنجاح.'));
    }

    public function updateDiscount(Request $request, Item $item): JsonResponse
    {

        if (! $this->purchaseOptionsService->supportsProductManagement($item)) {
            return $this->forbiddenResponse();
        }

        $enabled = filter_var($request->boolean('enabled'), FILTER_VALIDATE_BOOLEAN);

        if (! $enabled) {
            $item->forceFill([
                'discount_type' => null,
                'discount_value' => null,
                'discount_start' => null,
                'discount_end' => null,
            ])->save();

            $item->refresh();

            return $this->successResponse($item, __('تم تعطيل الخصم بنجاح.'));
        }

        $data = $request->validate([
            'discount_type' => ['required', 'string', 'in:percent,fixed,percentage'],
            'discount_value' => ['required', 'numeric', 'min:0'],
            'discount_start' => ['required', 'date'],
            'discount_end' => ['required', 'date'],
        ]);

        $type = strtolower((string) $data['discount_type']);
        if ($type === 'percent') {
            $type = 'percentage';
        }

        if ($type === 'percentage' && (float) $data['discount_value'] > 90) {
            throw ValidationException::withMessages([
                'discount_value' => [__('لا يمكن أن تتجاوز نسبة الخصم 90%.')],
            ]);
        }

        $start = Carbon::parse($data['discount_start']);
        $end = Carbon::parse($data['discount_end']);

        if ($end->lt($start)) {
            throw ValidationException::withMessages([
                'discount_end' => [__('تاريخ نهاية الخصم يجب أن يكون بعد بدايته.')],
            ]);
        }

        $item->forceFill([
            'discount_type' => $type,
            'discount_value' => (float) $data['discount_value'],
            'discount_start' => $start,
            'discount_end' => $end,
        ])->save();

        $item->refresh();

        return $this->successResponse($item, __('تم تحديث بيانات الخصم بنجاح.'));
    }

    private function successResponse(Item $item, string $message): JsonResponse
    {
        $item->loadMissing(['stocks', 'purchaseAttributes', 'purchaseAttributes.values']);

        return response()->json([
            'status' => true,
            'message' => $message,
            'data' => [
                'purchase_options' => $this->purchaseOptionsService->buildPurchaseOptions($item),
                'final_price' => $item->final_price,
            ],
        ]);
    }


    private function forbiddenResponse(): JsonResponse
    {
        return response()->json([
            'status' => false,
            'message' => __('إدارة المنتج غير متاحة لهذا الإعلان.'),
            'data' => null,
        ], 403);
    }



    private function normalizeSelectionArray(mixed $value): array
    {
        if ($value === null) {
            return [];
        }

        if (is_string($value) || is_numeric($value) || is_bool($value)) {
            $string = $this->stringifyValue($value);
            return $string === '' ? [] : [$string];
        }

        if (! is_array($value)) {
            return [];
        }

        $normalized = [];
        foreach ($value as $entry) {
            $string = $this->stringifyValue($entry);
            if ($string === '') {
                continue;
            }

            $normalized[] = $string;
        }

        return array_values(array_unique($normalized));
    }

    private function normalizeStockAmount(mixed $value): int
    {
        if (is_numeric($value)) {
            $intValue = (int) $value;
            return $intValue < 0 ? 0 : $intValue;
        }

        return 0;
    }

    private function stringifyValue(mixed $value): string
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
            $first = reset($value);
            return $this->stringifyValue($first);
        }

        return trim((string) $value);
    }


    private function normalizeDeliverySizeValue(mixed $value): ?string
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

            if (str_contains($normalized, '.')) {
                $decimalPlaces = strlen($normalized) - strpos($normalized, '.') - 1;
                if ($decimalPlaces > 3) {
                    return null;
                }
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

        $rounded = round($weight, 3);
        $formatted = number_format($rounded, 3, '.', '');
        $formatted = rtrim(rtrim($formatted, '0'), '.');

        if ($formatted === '') {
            return null;
        }

        if (mb_strlen($formatted) > 16) {
            return null;
        }

        return $formatted;
    }




    private function normalizeColorSelections(mixed $value): array
    {
        $parsed = ColorFieldParser::parse($value);

        if ($parsed === []) {
            return [];
        }

        $normalized = [];
        foreach ($parsed as $entry) {
            if (! is_array($entry)) {
                $code = ColorFieldParser::normalizeCode($entry);
                if ($code === null) {
                    continue;
                }
                $normalized[$code] = ['code' => $code];
                continue;
            }

            $code = ColorFieldParser::normalizeCode($entry['code'] ?? $entry);
            if ($code === null) {
                continue;
            }

            $quantity = $entry['quantity'] ?? null;
            if ($quantity !== null) {
                $quantity = is_numeric($quantity)
                    ? max(0, (int) $quantity)
                    : null;
            }

            $normalized[$code] = $quantity !== null
                ? ['code' => $code, 'quantity' => $quantity]
                : ['code' => $code];
        }

        return array_values($normalized);
    }

}
