<?php

namespace App\Http\Controllers;

use App\Models\Item;
use App\Models\ItemCustomFieldValue;
use App\Models\ItemStock;
use App\Services\ItemPurchaseOptionsService;
use Illuminate\Database\DatabaseManager;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

class ItemPurchaseManagementController extends Controller
{
    public function __construct(
        private readonly ItemPurchaseOptionsService $purchaseOptionsService,
        private readonly DatabaseManager $db
    ) {
    }

    public function updateAttributes(Request $request, Item $item): JsonResponse
    {
        $item->loadMissing(['custom_fields', 'item_custom_field_values']);

        $definitions = $this->purchaseOptionsService->collectAttributes($item);
        if ($definitions->isEmpty()) {
            return $this->successResponse($item, __('لا توجد سمات قابلة للتحديث لهذا المنتج.'));
        }

        $payload = $request->input('selected_values', []);
        if (! is_array($payload)) {
            throw ValidationException::withMessages([
                'selected_values' => [__('صيغة بيانات السمات غير صحيحة.')],
            ]);
        }

        $textInputs = $request->input('text_values', []);
        if (! is_array($textInputs)) {
            throw ValidationException::withMessages([
                'text_values' => [__('صيغة بيانات السمات النصية غير صحيحة.')],
            ]);
        }

        $updates = [];
        $definitions->each(function (array $definition) use (&$updates, $payload, $textInputs) {
            $key = $definition['key'];
            $allowed = $definition['allowed_values'] ?? [];
            $required = (bool) ($definition['required_for_checkout'] ?? false);
            $affectsStock = (bool) ($definition['affects_stock'] ?? false);

            if ($allowed !== []) {
                $incoming = $payload[$key] ?? [];
                $normalized = $this->normalizeSelectionArray($incoming);
                if ($normalized === [] && $required) {
                    throw ValidationException::withMessages([
                        'selected_values' => [
                            __('يجب اختيار قيمة واحدة على الأقل لحقل :name.', ['name' => $definition['name']]),
                        ],
                    ]);
                }

                $allowedNormalized = array_map([$this, 'stringifyValue'], $allowed);
                $selected = [];
                foreach ($normalized as $value) {
                    if (in_array($value, $allowedNormalized, true)) {
                        $selected[] = $value;
                    }
                }

                if ($selected === [] && ($required || $affectsStock)) {
                    throw ValidationException::withMessages([
                        'selected_values' => [
                            __('يجب اختيار قيمة واحدة على الأقل لحقل :name.', ['name' => $definition['name']]),
                        ],
                    ]);
                }

                $updates[$definition['id']] = $selected;
                return;
            }

            $raw = $textInputs[$key] ?? $payload[$key] ?? null;
            $text = $this->stringifyValue($raw);

            if ($text === '' && ($required || $affectsStock)) {
                throw ValidationException::withMessages([
                    'text_values' => [
                        __('حقل :name مطلوب.', ['name' => $definition['name']]),
                    ],
                ]);
            }

            $updates[$definition['id']] = $text;
        });

        $this->db->transaction(function () use ($item, $updates) {
            $existing = $item->item_custom_field_values
                ->keyBy(fn (ItemCustomFieldValue $value) => $value->custom_field_id);

            foreach ($updates as $fieldId => $value) {
                if ($value === [] || $value === '') {
                    if ($existing->has($fieldId)) {
                        ItemCustomFieldValue::where('item_id', $item->getKey())
                            ->where('custom_field_id', $fieldId)
                            ->delete();
                    }
                    continue;
                }

                $encoded = is_array($value)
                    ? json_encode(array_values($value), JSON_UNESCAPED_UNICODE)
                    : (string) $value;

                ItemCustomFieldValue::updateOrCreate(
                    [
                        'item_id' => $item->getKey(),
                        'custom_field_id' => $fieldId,
                    ],
                    [
                        'value' => $encoded,
                    ]
                );
            }
        });

        $item->load('item_custom_field_values');

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
        $item->loadMissing(['stocks', 'item_custom_field_values']);

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
}
