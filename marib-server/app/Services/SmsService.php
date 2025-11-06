<?php

namespace App\Services;

use App\Services\EnjazatikWhatsAppService;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class SmsService
{
    public function send(string $phoneNumber, string $message): bool
    {
        $normalizedNumber = trim($phoneNumber);
        $normalizedMessage = trim($message);

        if ($normalizedNumber === '' || $normalizedMessage === '') {
            return false;
        }

        $driver = Str::lower((string) config('services.sms.driver', 'log'));

        return match ($driver) {
            'http' => $this->sendViaHttpGateway($normalizedNumber, $normalizedMessage),
            'whatsapp' => $this->sendViaWhatsApp($normalizedNumber, $normalizedMessage),
            default => $this->logMessage($normalizedNumber, $normalizedMessage),
        };
    }

    private function sendViaHttpGateway(string $phoneNumber, string $message): bool
    {
        $endpoint = (string) config('services.sms.http.endpoint', '');

        if ($endpoint === '') {
            Log::warning('sms.gateway.http_missing_endpoint', []);

            return $this->logMessage($phoneNumber, $message);
        }

        $method = Str::upper((string) config('services.sms.http.method', 'POST'));
        $timeout = (float) config('services.sms.http.timeout', 10);
        $token = config('services.sms.http.token');

        try {
            $request = Http::timeout($timeout);

            if (is_string($token) && $token !== '') {
                $request = $request->withToken($token);
            }

            $response = $request->send($method, $endpoint, [
                'json' => [
                    'to' => $phoneNumber,
                    'message' => $message,
                ],
            ]);

            if (! $response->successful()) {
                Log::warning('sms.gateway.http_failed', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);

                return false;
            }

            return true;
        } catch (Throwable $exception) {
            Log::error('sms.gateway.http_exception', [
                'message' => $exception->getMessage(),
            ]);

            return false;
        }
    }

    private function sendViaWhatsApp(string $phoneNumber, string $message): bool
    {
        try {
            $service = app(EnjazatikWhatsAppService::class);
            $response = $service->sendMessage($phoneNumber, $message);

            if (is_array($response) && ($response['success'] ?? false)) {
                return true;
            }

            Log::warning('sms.gateway.whatsapp_failed', [
                'response' => $response,
            ]);
        } catch (Throwable $exception) {
            Log::error('sms.gateway.whatsapp_exception', [
                'message' => $exception->getMessage(),
            ]);
        }

        return false;
    }

    private function logMessage(string $phoneNumber, string $message): bool
    {
        Log::info('sms.gateway.log', [
            'to' => $phoneNumber,
            'message' => $message,
        ]);

        return true;
    }
}