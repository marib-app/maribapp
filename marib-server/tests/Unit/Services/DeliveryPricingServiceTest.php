<?php

namespace Tests\Unit\Services;

use App\Services\DeliveryPricingResult;
use App\Services\DeliveryPricingService;
use App\Services\Exceptions\DeliveryPricingException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class DeliveryPricingServiceTest extends TestCase
{
    public function test_it_returns_result_from_api(): void
    {
        config([
            'services.delivery_pricing.base_url' => 'https://pricing.test',
            'services.delivery_pricing.size_weight_map' => [
                'small' => 2.5,
            ],
        ]);

        Http::fake([
            'https://pricing.test/api/delivery-prices/calculate' => Http::response([
                'status' => true,
                'message' => 'تم الحساب',
                'data' => [
                    'total' => 42.5,
                    'currency' => 'SAR',
                    'breakdown' => [
                        ['type' => 'distance_rule', 'amount' => 42.5],
                    ],
                ],
            ]),
        ]);

        $service = app(DeliveryPricingService::class);
        $result = $service->calculate(12.0, 'small');

        $this->assertInstanceOf(DeliveryPricingResult::class, $result);
        $this->assertSame(42.5, $result->total);
        $this->assertCount(1, $result->breakdown);

        Http::assertSent(function (Request $request) {
            return $request->url() === 'https://pricing.test/api/delivery-prices/calculate'
                && $request['mode'] === 'weight_distance'
                && $request['distance'] === 12.0
                && $request['weight'] === 2.5;
        });
    }

    public function test_it_throws_exception_on_failure(): void
    {
        $this->expectException(DeliveryPricingException::class);

        config(['services.delivery_pricing.base_url' => 'https://pricing.test']);

        Http::fake([
            'https://pricing.test/api/delivery-prices/calculate' => Http::response([
                'status' => false,
                'message' => 'خدمة غير متاحة',
            ], 422),
        ]);

        $service = app(DeliveryPricingService::class);
        $service->calculate(5, 'medium');
    }
}