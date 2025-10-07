<?php

namespace Tests\Unit\Models;

use App\Models\Order;
use App\Models\User;
use App\Services\DeliveryPricingService;
use App\Services\Exceptions\DeliveryPricingException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery\MockInterface;
use Tests\TestCase;

class OrderDeliveryPriceTest extends TestCase
{
    use RefreshDatabase;

    public function test_update_delivery_price_persists_result(): void
    {
        $user = User::factory()->create();

        $order = Order::create([
            'user_id' => $user->id,
            'seller_id' => null,
            'order_number' => 'ORD-001',
            'total_amount' => 100,
            'tax_amount' => 10,
            'discount_amount' => 5,
            'final_amount' => 105,
        ]);

        $this->mock(DeliveryPricingService::class, function (MockInterface $mock) {
            $mock->shouldReceive('calculate')
                ->once()
                ->andReturn(new \App\Services\DeliveryPricingResult(20.0, [
                    ['type' => 'distance_rule', 'amount' => 20.0],
                ]));
        });

        $this->assertTrue($order->updateDeliveryPrice(5, 'small'));
        $order->refresh();

        $this->assertSame(20.0, $order->delivery_price);
        $this->assertSame(125.0, $order->final_amount);
        $this->assertSame('distance_rule', $order->delivery_price_breakdown[0]['type']);
    }

    public function test_update_delivery_price_handles_failure(): void
    {
        $user = User::factory()->create();

        $order = Order::create([
            'user_id' => $user->id,
            'seller_id' => null,
            'order_number' => 'ORD-002',
            'total_amount' => 50,
            'tax_amount' => 0,
            'discount_amount' => 0,
            'final_amount' => 50,
        ]);

        $this->mock(DeliveryPricingService::class, function (MockInterface $mock) {
            $mock->shouldReceive('calculate')
                ->once()
                ->andThrow(new DeliveryPricingException('Service unavailable'));
        });

        $this->assertFalse($order->updateDeliveryPrice(10, 'medium'));
        $order->refresh();

        $this->assertNull($order->delivery_price);
        $this->assertNull($order->delivery_price_breakdown);
        $this->assertSame(50.0, $order->final_amount);
    }
}