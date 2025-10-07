<?php

namespace Tests\Unit;

use App\Models\Order;
use App\Models\PaymentTransaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class PaymentTransactionTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_belongs_to_an_order(): void
    {
        $user = User::factory()->create();

        $order = Order::create([
            'user_id' => $user->id,
            'seller_id' => $user->id,
            'order_number' => 'ORD-' . Str::random(8),
            'total_amount' => 100,
            'final_amount' => 100,
            'payment_status' => 'pending',
            'order_status' => 'pending',
        ]);

        $transaction = PaymentTransaction::create([
            'user_id' => $user->id,
            'amount' => 100,
            'currency' => 'USD',
            'payment_gateway' => 'manual',
            'payment_status' => 'pending',
            'order_id' => $order->id,
        ])->fresh();

        $this->assertTrue($transaction->order->is($order));
    }
}