<?php

namespace App\Http\Controllers;
use App\Models\WalletAccount;
use Illuminate\Support\Facades\Schema;

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
     private ?bool $wifiNetworkHasSlugColumn = null;

     public function index(Request $request): JsonResponse
    {

        $ownerOnly = $request->boolean('owner_only', ! $request->boolean('public'));

        if (! $ownerOnly) {
            return $this->searchCatalogNetworks($request);
        }


        $query = WifiNetwork::query()->with('plans');

        if ($request->user()) {
            $query->where('user_id', $request->user()->getKey());
        }

        if ($request->filled('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

         $supportsSlug = $this->hasWifiNetworkSlugColumn();

         if ($request->filled('q')) {
            $search = trim((string) $request->input('q'));
            if ($search !== '') {
                $query->where(static function ($builder) use ($search, $supportsSlug) {
                    $builder->where('name', 'like', "%{$search}%");

                    if ($supportsSlug) {
                        $builder->orWhere('slug', 'like', "%{$search}%");
                    }
                });
            }
        }



        $networks = $query->orderByDesc('id')->paginate($request->integer('per_page', 15));

        return response()->json($networks);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'slug' => $this->slugValidationRules(),
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

        if ($this->hasWifiNetworkSlugColumn()) {
            $networkData['slug'] = $this->prepareSlug($validated['slug'] ?? null, $validated['name']);
        }
        
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

            'slug' => $this->slugValidationRules($network, true),


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

        if ($this->hasWifiNetworkSlugColumn() && array_key_exists('slug', $validated)) {

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

    private function searchCatalogNetworks(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'q' => ['nullable', 'string', 'max:255'],

            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);
        $supportsSlug = $this->hasWifiNetworkSlugColumn();
        $queryText = trim((string) ($validated['q'] ?? ''));
        $limit = (int) ($validated['limit'] ?? 50);

        $networksQuery = WifiNetwork::query()

            ->select('wifi_networks.*')
            ->where('is_active', true)
            ->whereHas('plans', static function ($builder) {
                $builder->where('is_active', true);
            })
            ->with(['plans' => static function ($builder) {
                $builder->select([
                    'id',
                    'wifi_network_id',
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
                    'meta',
                    'is_active',
                ])
                ->where('is_active', true)
                ->orderBy('price')
                ->orderBy('id');
            }])
            ->orderBy('name')
            ->orderBy('id');

        if ($queryText !== '') {
            $networksQuery->where(static function ($builder) use ($queryText, $supportsSlug) {
                $builder->where('name', 'like', "%{$queryText}%");

                if ($supportsSlug) {
                    $builder->orWhere('slug', 'like', "%{$queryText}%");
                }
            });
        }

        $networks = $networksQuery->limit($limit)->get();

        $data = $networks->map(function (WifiNetwork $network) use ($supportsSlug) {

            $attributes = [


 
                'id',
                'name',
                'location_name',
                'description',
                'coverage_radius_km',
                'logo_url',
                'login_screenshot_url',
                'contacts',
                'notes',
                'meta',
            ];

            if ($supportsSlug) {
                $attributes[] = 'slug';
            }

            $base = Arr::only($network->toArray(), $attributes);

            $base['plan_count'] = $network->plans->count();
            $base['plans'] = $network->plans
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
                        'meta',
                    ]);
                })
                ->values()
                ->all();

            $base['currencies'] = $network->plans
                ->pluck('currency')
                ->filter()
                ->map(static fn ($currency) => strtoupper((string) $currency))
                ->unique()
                ->values()
                ->all();

            return $base;

        })->values();

        return response()->json([
            'data' => $data,
            'meta' => [
                'count' => $data->count(),
                'query' => $queryText,
                'limit' => $limit,
            ],
        ]);
        
    }

    private function assertOwner(?int $userId, WifiNetwork $network): void
    {
        if ($userId === null || $network->user_id !== $userId) {
            abort(403, __('You are not allowed to manage this Wi-Fi network.'));
        }
    }



    private function slugValidationRules(?WifiNetwork $network = null, bool $includeSometimes = false): array
    {
        $rules = $includeSometimes ? ['sometimes'] : [];

        $rules[] = 'nullable';
        $rules[] = 'string';
        $rules[] = 'max:255';

        if ($this->hasWifiNetworkSlugColumn()) {
            $uniqueRule = Rule::unique('wifi_networks', 'slug');

            if ($network) {
                $uniqueRule->ignore($network->getKey());
            }

            $rules[] = $uniqueRule;
        }

        return $rules;
    }

    private function hasWifiNetworkSlugColumn(): bool
    {
        if ($this->wifiNetworkHasSlugColumn === null) {
            $this->wifiNetworkHasSlugColumn = Schema::hasColumn('wifi_networks', 'slug');
        }

        return $this->wifiNetworkHasSlugColumn;
    }


    private function prepareSlug(?string $slug, string $name, ?int $ignoreId = null): string
    {

        if (! $this->hasWifiNetworkSlugColumn()) {
            return Str::slug($slug ?: $name) ?: Str::slug(Str::random(8));
        }


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

        if (! $this->hasWifiNetworkSlugColumn()) {
            return false;
        }

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
        $walletsHaveCurrency = Schema::hasColumn('wallet_accounts', 'currency');

        if ($requestedWalletId) {
            return $query->whereKey($requestedWalletId)->first();
        }


                if (! $walletsHaveCurrency) {
            return $query->first();
        }


        $defaultCurrency = strtoupper((string) config('app.currency', 'SAR'));

        $wallet = (clone $query)->where('currency', $defaultCurrency)->first();

        if (! $wallet) {
            $walletAttributes = [

                'user_id' => $user->getKey(),
                'balance' => 0,
            ];

            if ($walletsHaveCurrency) {
                $walletAttributes['currency'] = $defaultCurrency;
            }

            $wallet = WalletAccount::create($walletAttributes);
        }

        return $wallet;
    }



}