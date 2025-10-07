<?php

namespace App\Http\Controllers;

use App\Http\Resources\AddressResource;
use App\Models\Address;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class AddressController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $addresses = $request->user()
            ->addresses()
            ->orderByDesc('is_default')
            ->latest()
            ->get();

        return AddressResource::collection($addresses)
            ->additional([
                'status' => true,
                'message' => __('تم جلب العناوين بنجاح.'),
            ])
            ->response();
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        $validated = $this->validateStore($request);
        $validated['user_id'] = $user->id;

        $address = DB::transaction(function () use ($validated, $user) {
            $isDefault = (bool) ($validated['is_default'] ?? false);

            if ($isDefault) {
                Address::where('user_id', $user->id)->update(['is_default' => false]);
            }

            $address = Address::create($validated);

            if (! $isDefault) {
                $hasDefault = Address::where('user_id', $user->id)
                    ->where('is_default', true)
                    ->exists();

                if (! $hasDefault) {
                    $address->update(['is_default' => true]);
                }
            }

            return $address->fresh();
        });

        return AddressResource::make($address)
            ->additional([
                'status' => true,
                'message' => __('تم إنشاء العنوان بنجاح.'),
            ])
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function show(Request $request, Address $address): JsonResponse
    {
        $this->ensureOwnership($request, $address);

        return AddressResource::make($address)
            ->additional([
                'status' => true,
                'message' => __('تم جلب العنوان بنجاح.'),
            ])
            ->response();
    }

    public function update(Request $request, Address $address): JsonResponse
    {
        $this->ensureOwnership($request, $address);
        $validated = $this->validateUpdate($request);

        DB::transaction(function () use ($request, $address, $validated) {
            if (array_key_exists('is_default', $validated) && $validated['is_default']) {
                Address::where('user_id', $request->user()->id)
                    ->whereKeyNot($address->getKey())
                    ->update(['is_default' => false]);
            }

            $address->fill($validated);
            $address->save();
        });

        $address->refresh();

        return AddressResource::make($address)
            ->additional([
                'status' => true,
                'message' => __('تم تحديث العنوان بنجاح.'),
            ])
            ->response();
    }

    public function destroy(Request $request, Address $address): JsonResponse
    {
        $this->ensureOwnership($request, $address);

        DB::transaction(function () use ($request, $address) {
            $wasDefault = $address->is_default;
            $userId = $request->user()->id;

            $address->delete();

            if ($wasDefault) {
                $nextDefault = Address::where('user_id', $userId)
                    ->orderByDesc('is_default')
                    ->orderByDesc('id')
                    ->first();

                if ($nextDefault) {
                    Address::where('user_id', $userId)->update(['is_default' => false]);
                    $nextDefault->update(['is_default' => true]);
                }
            }
        });

        return response()->json([
            'status' => true,
            'message' => __('تم حذف العنوان بنجاح.'),
        ]);
    }

    public function setDefault(Request $request, Address $address): JsonResponse
    {
        $this->ensureOwnership($request, $address);

        DB::transaction(function () use ($request, $address) {
            Address::where('user_id', $request->user()->id)
                ->update(['is_default' => false]);

            $address->update(['is_default' => true]);
        });

        $address->refresh();

        return AddressResource::make($address)
            ->additional([
                'status' => true,
                'message' => __('تم تحديث العنوان الافتراضي بنجاح.'),
            ])
            ->response();
    }

    private function ensureOwnership(Request $request, Address $address): void
    {
        abort_unless($address->user_id === $request->user()->id, Response::HTTP_NOT_FOUND);
    }

    private function validateStore(Request $request): array
    {
        return $request->validate([
            'label' => ['required', 'string', 'max:100'],
            'phone' => ['required', 'string', 'max:50'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'distance_km' => ['required', 'numeric', 'min:0'],


            'area_id' => ['nullable', Rule::exists('areas', 'id')],
            'street' => ['nullable', 'string', 'max:255'],
            'building' => ['nullable', 'string', 'max:255'],
            'note' => ['nullable', 'string', 'max:500'],
            'is_default' => ['sometimes', 'boolean'],
        ]);
    }

    private function validateUpdate(Request $request): array
    {
        return $request->validate([
            'label' => ['sometimes', 'string', 'max:100'],
            'phone' => ['sometimes', 'string', 'max:50'],
            'latitude' => ['sometimes', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'numeric', 'between:-180,180'],
            'distance_km' => ['sometimes', 'numeric', 'min:0'],


            'area_id' => ['sometimes', 'nullable', Rule::exists('areas', 'id')],
            'street' => ['sometimes', 'nullable', 'string', 'max:255'],
            'building' => ['sometimes', 'nullable', 'string', 'max:255'],
            'note' => ['sometimes', 'nullable', 'string', 'max:500'],
            'is_default' => ['sometimes', 'boolean'],
        ]);
    }
}