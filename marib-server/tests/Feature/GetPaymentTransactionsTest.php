<?php

namespace Tests\Feature;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GetPaymentTransactionsTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_returns_empty_array_when_user_has_no_transactions(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/payment-transactions');

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [],
        ]);
    }

    public function test_it_returns_transactions_with_manual_payment_request_details(): void
    {
        Carbon::setTestNow(Carbon::create(2024, 1, 1, 12));

        $user = User::factory()->create();

        $manualBank = ManualBank::create([
            'name' => 'Test Bank',
            'status' => true,
        ]);

        $manualPaymentRequest = ManualPaymentRequest::create([
            'user_id' => $user->id,
            'manual_bank_id' => $manualBank->id,
            'amount' => 150,
            'currency' => 'USD',
            'receipt_path' => 'receipts/example.jpg',
            'status' => ManualPaymentRequest::STATUS_APPROVED,
        ]);

        $transaction = PaymentTransaction::create([
            'user_id' => $user->id,
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'amount' => 150,
            'currency' => 'USD',
            'payment_gateway' => 'manual',
            'payment_status' => 'succeed',
            'created_at' => Carbon::now(),
            'updated_at' => Carbon::now(),
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/payment-transactions');

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [
                [
                    'id' => $transaction->id,
                    'status' => $transaction->payment_status,
                    'amount' => (float) $transaction->amount,
                    'currency' => $transaction->currency,
                    'manual_payment_request' => [
                        'id' => $manualPaymentRequest->id,
                        'status' => $manualPaymentRequest->status,
                        'bank' => [
                            'id' => $manualBank->id,
                            'name' => $manualBank->name,
                            'logo_url' => null,
                        ],
                    ],
                ],
            ],
        ]);

        $response->assertJsonPath('data.0.created_at', Carbon::now()->toIso8601String());

        Carbon::setTestNow();
    }
}