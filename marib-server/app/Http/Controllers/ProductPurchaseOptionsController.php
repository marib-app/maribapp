<?php

namespace App\Http\Controllers;

use App\Models\Item;
use App\Services\ItemPurchaseOptionsService;
use Illuminate\Http\JsonResponse;

class ProductPurchaseOptionsController extends Controller
{
    public function __construct(private readonly ItemPurchaseOptionsService $purchaseOptionsService)
    {
    }

    public function show(Item $item): JsonResponse
    {

        if (! $this->purchaseOptionsService->supportsProductManagement($item)) {
            return response()->json([
                'status' => false,
                'message' => __('خيارات المنتج غير متاحة لهذا الإعلان.'),
                'data' => null,
            ], 403);
        }


        $item->loadMissing(['stocks']);

        $data = $this->purchaseOptionsService->buildPurchaseOptions($item);

        return response()->json([
            'status' => true,
            'message' => __('تم جلب خيارات الشراء بنجاح.'),
            'data' => $data,
        ]);
    }
}