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

class ItemPurchaseManagementController extends Controller
{
    public function __construct(
        private readonly ItemPurchaseOptionsService $purchaseOptionsService,
        private readonly DatabaseManager $db
    ) {
    }

    public function updateAttributes(Request $request, Item $item): JsonResponse
    {
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

        $this->db->transaction(function () use ($item, $normalizedAttributes) {
            $existing = $item->purchaseAttributes()->with('values')->get()->keyBy('id');
            $retainedIds = [];

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

            $variantKey = $this->stringifyValue($row['variant_key'] ?? '');
            $stock = $this->normalizeStockAmount($row['stock'] ?? null);

            $normalizedRows[$variantKey] = [
                'variant_key' => $variantKey,
                'stock' => $stock,
            ];
        }

        $this->db->transaction(function () use ($item, $normalizedRows) {
            $affectedKeys = array_keys($normalizedRows);

            foreach ($normalizedRows as $row) {
                ItemStock::updateOrCreate(
                    [
                        'item_id' => $item->getKey(),
                        'variant_key' => $row['variant_key'],
                    ],
                    [
                        'stock' => $row['stock'],
                        'reserved_stock' => 0,
                    ]
                );
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
