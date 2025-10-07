<?php

namespace App\Http\Controllers;

use App\Services\CartShippingQuoteService;
use App\Services\Exceptions\DeliveryPricingException;
use Illuminate\Http\JsonResponse;
use App\Services\OrderCheckoutService;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CartShippingQuoteController extends Controller
{
    public function __construct(private readonly CartShippingQuoteService $service)
    {
        $this->middleware('throttle:cart-shipping-quote');
    }

    public function __invoke(Request $request): JsonResponse
    {
        $departments = Config::get('cart.departments', []);

        try {
            $validated = $request->validate([
                'address_id' => ['required', 'integer'],
                'department' => ['required', 'string', Rule::in($departments)],
                'force_refresh' => ['sometimes', 'boolean'],                
                'deposit_enabled' => ['sometimes', 'boolean'],



                'delivery_payment_timing' => ['nullable', 'string', Rule::in(OrderCheckoutService::allowedDeliveryPaymentTimingTokens())],

            ], [
                'address_id.required' => __('يجب اختيار عنوان صالح لحساب رسوم الشحن.'),
                'address_id.integer' => __('يجب اختيار عنوان صالح لحساب رسوم الشحن.'),
                'department.required' => __('يجب اختيار عنوان صالح لحساب رسوم الشحن.'),



            ]);
        } catch (ValidationException $exception) {
            return response()->json([
                'status' => false,
                'code' => 'address_required',
                'message' => __('يجب اختيار عنوان صالح لحساب رسوم الشحن.'),
                'errors' => $exception->errors(),
            ], 422);
        }

        $user = $request->user();

        try {
            $quote = $this->service->quote(
                $user,
                isset($validated['address_id']) ? (string) $validated['address_id'] : null,
                $validated['department'] ?? null,
                array_filter([
                    'force_refresh' => (bool) ($validated['force_refresh'] ?? false),
                    'deposit_enabled' => (bool) ($validated['deposit_enabled'] ?? false),


                    'timing' => OrderCheckoutService::normalizeTimingToken($validated['delivery_payment_timing'] ?? null),
                ], static fn ($value) => $value !== null),
            
            
            );

            return response()->json([
                'status' => true,
                'code' => 'shipping_quote_generated',
                'message' => __('تم حساب عرض الشحن بنجاح.'),
                'data' => $quote,
            ]);
        } catch (ValidationException $exception) {
            $errors = $exception->errors();
            $message = collect($errors)->flatten()->first() ?? $exception->getMessage();

            return response()->json([
                'status' => false,
                'message' => $message,
                'errors' => $errors,
            ], 422);
        } catch (DeliveryPricingException $exception) {
            Log::error('cart.shipping_quote.pricing_failed', [
                'user_id' => $user->id,
                'address_id' => $validated['address_id'] ?? null,
                'department' => $validated['department'] ?? null,
                'error' => $exception->getMessage(),
            ]);

            return response()->json([
                'status' => false,
                'message' => $exception->getMessage(),
            ], 502);
        } catch (\Throwable $throwable) {
            Log::error('cart.shipping_quote.unhandled_exception', [
                'user_id' => $user->id,
                'address_id' => $validated['address_id'] ?? null,
                'department' => $validated['department'] ?? null,
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'status' => false,
                'message' => __('حدث خطأ غير متوقع أثناء حساب عرض الشحن.'),
            ], 500);
        }
    }
}