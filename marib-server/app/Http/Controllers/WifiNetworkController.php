<?php

namespace App\Http\Controllers;
use App\Models\WalletAccount;

use App\Models\WifiNetwork;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;


class WifiNetworkController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = WifiNetwork::query()->with('plans');

        if ($request->boolean('owner_only', true) && $request->user()) {
            $query->where('user_id', $request->user()->getKey());
        }

        if ($request->filled('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        $networks = $query->orderByDesc('id')->paginate($request->integer('per_page', 15));

        return response()->json($networks);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'slug' => 'nullable|string|max:255|unique:wifi_networks,slug',
            'description' => 'nullable|string',
            'location_name' => 'nullable|string|max:255',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'commission_rate' => 'nullable|numeric|min:0|max:100',
            'commission_flat' => 'nullable|numeric|min:0',
            'coverage_radius_km' => 'nullable|numeric|min:0',
            'contacts' => 'nullable',
            'notes' => 'nullable|string',
            'is_active' => 'boolean',
            'meta' => 'array|nullable',
            'logo' => 'nullable|image|max:4096',
            'login_screenshot' => 'nullable|image|max:4096',

        ]);

        $user = $request->user();
        $walletAccount = $this->resolveWalletAccount($user, null);

        $networkData = Arr::only($validated, [
            'name',
            'description',
            'location_name',
            'latitude',
            'longitude',
            'commission_rate',
            'commission_flat',
            'coverage_radius_km',
            'notes',
            'is_active',
            'meta',
        ]);

        $networkData['slug'] = $this->prepareSlug($validated['slug'] ?? null, $validated['name']);
        $networkData['contacts'] = $this->normalizeContacts($request->input('contacts'));
        $networkData['user_id'] = $user?->getKey();
        $networkData['wallet_id'] = $walletAccount?->getKey();
        $networkData['commission_rate'] = $networkData['commission_rate'] ?? 0;
        $networkData['commission_flat'] = $networkData['commission_flat'] ?? 0;
        $networkData['is_active'] = $networkData['is_active'] ?? true;

        if (array_key_exists('coverage_radius_km', $networkData)) {
            $networkData['coverage_radius_km'] = $this->normalizeCoverageRadius($networkData['coverage_radius_km']);
        }

        if ($request->hasFile('logo')) {
            $networkData['logo_path'] = $this->storeUploadedFile($request->file('logo'), 'wifi/logos');
        }

        if ($request->hasFile('login_screenshot')) {
            $networkData['login_screenshot_path'] = $this->storeUploadedFile($request->file('login_screenshot'), 'wifi/login-screens');
        }

        $network = WifiNetwork::create($networkData);

        return response()->json(['data' => $network->fresh()], 201);
    
    
    }

    public function update(Request $request, WifiNetwork $network): JsonResponse
    {
        $this->assertOwner($request->user()?->getKey(), $network);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',

            'slug' => [
                'sometimes',
                'nullable',
                'string',
                'max:255',
                Rule::unique('wifi_networks', 'slug')->ignore($network->getKey()),
            ],

            'description' => 'nullable|string',
            'location_name' => 'nullable|string|max:255',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'commission_rate' => 'nullable|numeric|min:0|max:100',
            'commission_flat' => 'nullable|numeric|min:0',
            'coverage_radius_km' => 'nullable|numeric|min:0',
            'contacts' => 'nullable',
            'notes' => 'nullable|string',

            'is_active' => 'boolean',
            'meta' => 'array|nullable',
            'logo' => 'nullable|image|max:4096',
            'login_screenshot' => 'nullable|image|max:4096',

        ]);

        $updateData = Arr::only($validated, [
            'name',
            'description',
            'location_name',
            'latitude',
            'longitude',
            'commission_rate',
            'commission_flat',
            'coverage_radius_km',
            'notes',
            'is_active',
            'meta',
        ]);

        if ($request->has('contacts')) {
            $updateData['contacts'] = $this->normalizeContacts($request->input('contacts'));
        }

        if (array_key_exists('coverage_radius_km', $updateData)) {
            $updateData['coverage_radius_km'] = $this->normalizeCoverageRadius($updateData['coverage_radius_km']);
        }

        if (array_key_exists('slug', $validated)) {
            $nameForSlug = $validated['name'] ?? $network->name;
            $updateData['slug'] = $this->prepareSlug($validated['slug'], $nameForSlug, $network->getKey());
        }

        if ($request->hasFile('logo')) {
            $updateData['logo_path'] = $this->storeUploadedFile(
                $request->file('logo'),
                'wifi/logos',
                $network->logo_path
            );
        }

        if ($request->hasFile('login_screenshot')) {
            $updateData['login_screenshot_path'] = $this->storeUploadedFile(
                $request->file('login_screenshot'),
                'wifi/login-screens',
                $network->login_screenshot_path
            );
        }

        if (! $network->wallet_id) {
            $walletAccount = $this->resolveWalletAccount($request->user(), null);
            $updateData['wallet_id'] = $walletAccount?->getKey();
        }

        $network->fill($updateData)->save();


        return response()->json(['data' => $network->fresh()]);
    }

    public function nearby(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'radius' => ['nullable', 'numeric', 'min:0.1', 'max:100'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $latitude = array_key_exists('latitude', $validated) ? (float) $validated['latitude'] : null;
        $longitude = array_key_exists('longitude', $validated) ? (float) $validated['longitude'] : null;
        $radius = (float) ($validated['radius'] ?? 5.0);
        $limit = (int) ($validated['limit'] ?? 20);

        $query = WifiNetwork::query()
            ->select('wifi_networks.*')
            ->where('is_active', true)
            ->with('plans');

        if ($latitude !== null && $longitude !== null) {
            $query->whereNotNull('latitude')->whereNotNull('longitude');

            $haversine = '(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude))))';

            $query->selectRaw("{$haversine} as distance", [$latitude, $longitude, $latitude])
            
            
            ->having('distance', '<=', $radius)
                ->orderBy('distance');
        } else {
            $query->selectRaw('NULL as distance')->orderByDesc('id');
        }

        $networks = $query->limit($limit)->get();

        $data = $networks->map(function (WifiNetwork $network) {
            $networkData = Arr::only($network->toArray(), [
                'id',
                'name',
                'slug',
                'location_name',
                'latitude',
                'longitude',
                'coverage_radius_km',
                'is_active',
                'meta',
            ]);

            $networkData['distance'] = $network->distance !== null ? (float) $network->distance : null;

            $networkData['plans'] = $network->plans
                ->map(static function ($plan) {
                    return Arr::only($plan->toArray(), [
                        'id',
                        'name',
                        'description',
                        'duration_minutes',
                        'data_allowance_mb',
                        'data_allowance_gb',
                        'data_allowance_label',
                        'validity_days',
                        'validity_label',
                        'speed_mbps',
                        'speed_label',
                        'price',
                        'currency',
                        'is_active',
                        'meta',
                    ]);
                })
                ->values()
                ->all();

            return $networkData;
        })->values();

        return response()->json(['data' => $data]);
    }

    private function assertOwner(?int $userId, WifiNetwork $network): void
    {
        if ($userId === null || $network->user_id !== $userId) {
            abort(403, __('You are not allowed to manage this Wi-Fi network.'));
        }
    }



    private function prepareSlug(?string $slug, string $name, ?int $ignoreId = null): string
    {
        $base = Str::slug($slug ?: $name);

        if ($base === '') {
            $base = Str::slug(Str::random(8));
        }

        $base = substr($base, 0, 255);
        $original = $base;
        $counter = 1;

        while ($this->slugExists($base, $ignoreId)) {
            $suffix = '-' . $counter++;
            $base = substr($original, 0, 255 - strlen($suffix)) . $suffix;
        }

        return $base;
    }

    private function slugExists(string $slug, ?int $ignoreId = null): bool
    {
        $query = WifiNetwork::query()->where('slug', $slug);

        if ($ignoreId !== null) {
            $query->whereKeyNot($ignoreId);
        }

        return $query->exists();
    }

    private function storeUploadedFile(UploadedFile $file, string $directory, ?string $existingPath = null): string
    {
        $disk = 'public';

        if ($existingPath && Storage::disk($disk)->exists($existingPath)) {
            Storage::disk($disk)->delete($existingPath);
        }

        return $file->store($directory, $disk);
    }

    private function normalizeContacts(mixed $contacts): ?array
    {
        if ($contacts === null || $contacts === '') {
            return null;
        }

        $values = is_string($contacts)
            ? preg_split('/[\r\n,;]+/', $contacts)
            : Arr::wrap($contacts);

        $values = collect($values)
            ->flatMap(static function ($value) {
                if (is_array($value)) {
                    return array_filter(array_map('strval', $value));
                }

                return [$value];
            })
            ->map(static function ($value) {
                return is_string($value) ? trim($value) : (string) $value;
            })
            ->filter()
            ->values()
            ->all();

        return $values === [] ? null : $values;
    }

    private function normalizeCoverageRadius(mixed $radius): ?float
    {
        if ($radius === null || $radius === '') {
            return null;
        }

        return max(0, round((float) $radius, 2));
    }

    private function resolveWalletAccount(?\App\Models\User $user, ?int $requestedWalletId = null): ?WalletAccount
    {
        if ($user === null) {
            return null;
        }

        $query = WalletAccount::query()->where('user_id', $user->getKey());

        if ($requestedWalletId) {
            return $query->whereKey($requestedWalletId)->first();
        }

        $defaultCurrency = strtoupper((string) config('app.currency', 'SAR'));

        $wallet = (clone $query)->where('currency', $defaultCurrency)->first();

        if (! $wallet) {
            $wallet = WalletAccount::create([
                'user_id' => $user->getKey(),
                'currency' => $defaultCurrency,
                'balance' => 0,
            ]);
        }

        return $wallet;
    }



}