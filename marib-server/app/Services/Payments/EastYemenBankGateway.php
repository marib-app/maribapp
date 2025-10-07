<?php

namespace App\Services\Payments;

use App\Models\PaymentConfiguration;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Http;
use JsonException;
use RuntimeException;

class EastYemenBankGateway
{
    protected string $baseUrl;
    protected string $appKey;
    protected string $apiKey;

    public function __construct(string $baseUrl, string $appKey, string $apiKey)
    {
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->appKey = $appKey;
        $this->apiKey = $apiKey;
    }

    public static function fromConfig(): self
    {
        $configuration = PaymentConfiguration::query()
            ->where('payment_method', 'east_yemen_bank')
            ->first();

        if (!$configuration || !$configuration->status) {
            throw new RuntimeException('East Yemen Bank gateway is disabled.');
        }

        $baseUrl = (string) config('services.east_yemen_bank.base_url');
        if (empty($baseUrl)) {
            throw new RuntimeException('East Yemen Bank base URL is not configured.');
        }

        return new self($baseUrl, (string) $configuration->secret_key, (string) $configuration->api_key);
    }

    public function requestPayment(array $payload): array
    {
        return $this->post('E_Payment/RequestPayment', $payload);
    }

    public function confirmPayment(string $voucherNumber, array $payload = []): array
    {
        $payload = array_merge(['voucher_number' => $voucherNumber], $payload);

        return $this->post('E_Payment/ConfirmPayment', $payload);
    }

    public function checkVoucher(string $voucherNumber, array $payload = []): array
    {
        $payload = array_merge(['voucher_number' => $voucherNumber], $payload);

        return $this->post('E_Payment/CheckVoucher', $payload);
    }

    public function encrypt(array $payload): string
    {
        try {
            $plaintext = json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
        } catch (JsonException $exception) {
            throw new RuntimeException('Unable to encode payload for East Yemen Bank.', 0, $exception);
        }

        $key = substr(hash('sha256', $this->appKey, true), 0, 32);
        $iv = substr(hash('sha256', $this->apiKey, true), 0, 16);

        $encrypted = openssl_encrypt($plaintext, 'AES-256-CBC', $key, OPENSSL_RAW_DATA, $iv);

        if ($encrypted === false) {
            throw new RuntimeException('Failed to encrypt payload for East Yemen Bank.');
        }

        return base64_encode($encrypted);
    }

    protected function post(string $endpoint, array $payload): array
    {
        $payload = $this->preparePayload($payload);

        try {
            $response = Http::baseUrl($this->baseUrl)
                ->acceptJson()
                ->asJson()
                ->withHeaders($this->defaultHeaders())
                ->post(ltrim($endpoint, '/'), [
                    'payload' => $this->encrypt($payload),
                ])->throw();
        } catch (RequestException $exception) {
            throw new RuntimeException(
                sprintf('East Yemen Bank request failed: %s', $exception->getMessage()),
                0,
                $exception
            );
        }

        return $response->json() ?? [];
    }

    protected function preparePayload(array $payload): array
    {
        return Arr::where($payload, static fn ($value) => $value !== null && $value !== '');
    }

    protected function defaultHeaders(): array
    {
        return [
            'X-APP-KEY' => $this->appKey,
            'X-API-KEY' => $this->apiKey,
        ];
    }
}