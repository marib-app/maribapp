<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NotificationDelivery;
use App\Services\NotificationInboxService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class NotificationPaymentController extends Controller
{
    public function __construct(private readonly NotificationInboxService $inboxService)
    {
    }

    public function update(Request $request, NotificationDelivery $delivery): JsonResponse
    {
        $user = $request->user();

        if (! $user || (int) $delivery->user_id !== (int) $user->getKey()) {
            return response()->json([
                'message' => __('Notification not found.'),
            ], 404);
        }

        $meta = is_array($delivery->meta) ? $delivery->meta : [];
        $paymentRequest = data_get($meta, 'payment_request');

        if (! is_array($paymentRequest)) {
            return response()->json([
                'message' => __('No payment request attached to this notification.'),
            ], 422);
        }

        $validated = $request->validate([
            'status' => ['required', Rule::in(['pending', 'submitted', 'paid', 'cancelled'])],
            'transaction_id' => ['nullable', 'string', 'max:191'],
            'transaction_reference' => ['nullable', 'string', 'max:191'],
            'note' => ['nullable', 'string', 'max:400'],
        ]);

        $paymentRequest['status'] = $validated['status'];
        if (array_key_exists('transaction_id', $validated)) {
            $paymentRequest['transaction_id'] = $validated['transaction_id'] ?: null;
        }
        if (array_key_exists('transaction_reference', $validated)) {
            $paymentRequest['transaction_reference'] = $validated['transaction_reference'] ?: null;
        }
        if (array_key_exists('note', $validated)) {
            $paymentRequest['client_note'] = $validated['note'] ?: null;
        }
        $paymentRequest['updated_at'] = now()->toIso8601String();

        $meta['payment_request'] = $paymentRequest;
        $delivery->meta = $meta;
        $delivery->save();

        $payload = $this->inboxService->transform($delivery->fresh());

        return response()->json([
            'payment_request' => $paymentRequest,
            'delivery' => $payload,
        ]);
    }
}
