<?php


namespace App\Services;

use Illuminate\Support\Facades\Http;

class EnjazatikWhatsAppService
{
    protected $baseUrl = 'https://business.enjazatik.com/api/v1/';
    protected $token;

    public function __construct()
    {
        $configuredToken = CachingService::getSystemSettings('whatsapp_otp_token');

        if (!is_string($configuredToken) || $configuredToken === '') {
            $configuredToken = config('services.whatsapp.token');
        }

        $this->token = $configuredToken;
    
    
    }

    public function checkNumber(string $phone): array
    {
        $response = Http::withToken($this->token)
            ->post($this->baseUrl . 'check-number', ['number' => $phone]);

        return $response->json();
    }

    public function sendMessage(string $phone, string $message): array
    {
        $response = Http::withToken($this->token)
            ->post($this->baseUrl . 'send-message', [
                'number' => $phone,
                'message' => $message,
            ]);

        return $response->json();
    }
}
