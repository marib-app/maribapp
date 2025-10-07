<?php

namespace Tests\Feature;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentConfiguration;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Services\Payments\EastYemenBankGateway;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Spatie\Permission\Models\Permission;
use Tests\TestCase;

class EastYemenBankGatewayTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Permission::create(['name' => 'manual-payments-review']);

        config(['services.east_yemen_bank.base_url' => 'https://bank.test/api']);

        PaymentConfiguration::create([
            'payment_method' => 'east_yemen_bank',
            'api_key' => 'api-key',
            'secret_key' => 'app-key',
            'webhook_secret_key' => '',
            'currency_code' => null,
            'status' => true,
        ]);
    }

    public function test_request_payment_sends_encrypted_payload(): void
    {
        $user = User::factory()->create();
        $user->givePermissionTo('manual-payments-review');
        $this->actingAs($user);

        $manualPaymentRequest = ManualPaymentRequest::create([
            'user_id' => $user->id,
            'amount' => 150.50,
            'currency' => 'YER',
            'reference' => 'INV-001',
            'status' => ManualPaymentRequest::STATUS_PENDING,
            'receipt_path' => null,
            'meta' => ['gateway' => 'east_yemen_bank'],
        ]);

        $transaction = PaymentTransaction::create([
            'user_id' => $user->id,
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'amount' => $manualPaymentRequest->amount,
            'currency' => 'YER',
            'payment_gateway' => 'east_yemen_bank',
            'payment_status' => 'pending',
        ]);

        $manualPaymentRequest->setRelation('paymentTransaction', $transaction);

        $capturedRequest = null;
        Http::fake([
            'https://bank.test/api/E_Payment/RequestPayment' => function ($request) use (&$capturedRequest) {
                $capturedRequest = $request;
                return Http::response(['voucher_number' => 'V123', 'status' => 'created'], 200);
            },
        ]);

        $response = $this->post(route('manual-payments.east-yemen.request', $manualPaymentRequest), [
            'customer_identifier' => 'CUST123',
            'description' => 'Test Voucher',
        ]);

        $response->assertOk();
        $response->assertJson(['error' => false]);

        $gateway = new EastYemenBankGateway('https://bank.test/api', 'app-key', 'api-key');
        $expectedPayload = $gateway->encrypt([
            'customer_identifier' => 'CUST123',
            'amount' => 150.5,
            'currency' => 'YER',
            'reference' => 'INV-001',
            'description' => 'Test Voucher',
        ]);

        $this->assertNotNull($capturedRequest);
        $this->assertSame('https://bank.test/api/E_Payment/RequestPayment', $capturedRequest->url());
        $this->assertSame('app-key', $capturedRequest->header('X-APP-KEY')[0] ?? null);
        $this->assertSame('api-key', $capturedRequest->header('X-API-KEY')[0] ?? null);
        $this->assertSame($expectedPayload, $capturedRequest->data()['payload'] ?? null);

        $manualPaymentRequest->refresh();
        $transaction->refresh();

        $this->assertSame('V123', $transaction->order_id);
        $this->assertSame('V123', data_get($manualPaymentRequest->meta, 'east_yemen_bank.request_payment.response.voucher_number'));
        $this->assertSame('CUST123', data_get($manualPaymentRequest->meta, 'east_yemen_bank.request_payment.payload.customer_identifier'));
    }

    public function test_confirm_payment_calls_gateway_and_records_meta(): void
    {
        $user = User::factory()->create();
        $user->givePermissionTo('manual-payments-review');
        $this->actingAs($user);

        $manualPaymentRequest = ManualPaymentRequest::create([
            'user_id' => $user->id,
            'amount' => 99.99,
            'currency' => 'YER',
            'reference' => 'INV-900',
            'status' => ManualPaymentRequest::STATUS_PENDING,
            'receipt_path' => null,
            'meta' => ['gateway' => 'east_yemen_bank'],
        ]);

        $transaction = PaymentTransaction::create([
            'user_id' => $user->id,
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'amount' => $manualPaymentRequest->amount,
            'currency' => 'YER',
            'payment_gateway' => 'east_yemen_bank',
            'payment_status' => 'pending',
        ]);

        $manualPaymentRequest->setRelation('paymentTransaction', $transaction);

        $capturedRequest = null;
        Http::fake([
            'https://bank.test/api/E_Payment/ConfirmPayment' => function ($request) use (&$capturedRequest) {
                $capturedRequest = $request;
                return Http::response(['status' => 'confirmed'], 200);
            },
        ]);

        $response = $this->post(route('manual-payments.east-yemen.confirm', $manualPaymentRequest), [
            'voucher_number' => 'VOUCHER-42',
            'otp' => '9876',
        ]);

        $response->assertOk();
        $response->assertJson(['error' => false]);

        $gateway = new EastYemenBankGateway('https://bank.test/api', 'app-key', 'api-key');
        $expectedPayload = $gateway->encrypt([
            'voucher_number' => 'VOUCHER-42',
            'amount' => 99.99,
            'currency' => 'YER',
            'otp' => '9876',
        ]);

        $this->assertNotNull($capturedRequest);
        $this->assertSame('https://bank.test/api/E_Payment/ConfirmPayment', $capturedRequest->url());
        $this->assertSame($expectedPayload, $capturedRequest->data()['payload'] ?? null);

        $manualPaymentRequest->refresh();
        $transaction->refresh();

        $this->assertSame('confirmed', data_get($transaction->meta, 'east_yemen_bank_status'));
        $this->assertSame('VOUCHER-42', data_get($manualPaymentRequest->meta, 'east_yemen_bank.confirm_payment.payload.voucher_number'));
    }

    public function test_check_voucher_records_response(): void
    {
        $user = User::factory()->create();
        $user->givePermissionTo('manual-payments-review');
        $this->actingAs($user);

        $manualPaymentRequest = ManualPaymentRequest::create([
            'user_id' => $user->id,
            'amount' => 10,
            'currency' => 'YER',
            'reference' => 'INV-777',
            'status' => ManualPaymentRequest::STATUS_PENDING,
            'receipt_path' => null,
            'meta' => ['gateway' => 'east_yemen_bank'],
        ]);

        $transaction = PaymentTransaction::create([
            'user_id' => $user->id,
            'manual_payment_request_id' => $manualPaymentRequest->id,
            'amount' => $manualPaymentRequest->amount,
            'currency' => 'YER',
            'payment_gateway' => 'east_yemen_bank',
            'payment_status' => 'pending',
        ]);

        $manualPaymentRequest->setRelation('paymentTransaction', $transaction);

        $capturedRequest = null;
        Http::fake([
            'https://bank.test/api/E_Payment/CheckVoucher' => function ($request) use (&$capturedRequest) {
                $capturedRequest = $request;
                return Http::response(['status' => 'pending'], 200);
            },
        ]);

        $response = $this->post(route('manual-payments.east-yemen.check', $manualPaymentRequest), [
            'voucher_number' => 'V-555',
        ]);

        $response->assertOk();
        $response->assertJson(['error' => false]);

        $gateway = new EastYemenBankGateway('https://bank.test/api', 'app-key', 'api-key');
        $expectedPayload = $gateway->encrypt([
            'voucher_number' => 'V-555',
            'currency' => 'YER',
        ]);

        $this->assertNotNull($capturedRequest);
        $this->assertSame('https://bank.test/api/E_Payment/CheckVoucher', $capturedRequest->url());
        $this->assertSame($expectedPayload, $capturedRequest->data()['payload'] ?? null);

        $manualPaymentRequest->refresh();
        $this->assertSame('pending', data_get($manualPaymentRequest->meta, 'east_yemen_bank.check_voucher.response.status'));
    }
}