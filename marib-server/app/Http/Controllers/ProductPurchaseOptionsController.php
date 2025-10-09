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
        $item->loadMissing(['stocks']);

        $data = $this->purchaseOptionsService->buildPurchaseOptions($item);

        return response()->json([
            'status' => true,
            'message' => __('تم جلب خيارات الشراء بنجاح.'),
            'data' => $data,
        ]);
    }
}