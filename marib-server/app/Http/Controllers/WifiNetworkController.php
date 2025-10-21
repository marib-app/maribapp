<?php

namespace App\Http\Controllers;



use App\Models\WalletAccount;
use App\Http\Requests\Wifi\StoreWifiNetworkRequest;
use App\Models\WifiNetwork;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Schema;

class WifiNetworkController extends Controller
{
    private ?bool $wifiNetworkHasSlugColumn = null;
    private ?bool $walletAccountsHaveCurrencyColumn = null;

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

    public function store(StoreWifiNetworkRequest $request): JsonResponse
    {
        $validated = $request->validated();


        $user = $request->user();
        $walletAccount = null;
        if ($user) {
            $requestedWalletId = array_key_exists('wallet_id', $validated)
                ? (int) $validated['wallet_id']
                : null;

            $walletAccount = $this->resolveWalletAccount($user, $requestedWalletId);

            if (! $walletAccount) {
                $latestOwnerWalletId = WifiNetwork::query()
                    ->where('user_id', $user->getKey())
                    ->whereNotNull('wallet_id')
                    ->latest('id')
                    ->value('wallet_id');

                if ($latestOwnerWalletId !== null) {
                    $walletAccount = WalletAccount::query()
                        ->where('user_id', $user->getKey())
                        ->whereKey((int) $latestOwnerWalletId)
                        ->first();
                }
            }

            if (! $walletAccount) {
                return response()->json([
                    'message' => __('Unable to create the Wi-Fi network.'),
                    'errors' => [
                        'wallet_id' => [__('We were unable to find a wallet for your account.')],
                    ],
                ], 422);
            }
        }

        
        $fillable = (new WifiNetwork())->getFillable();

        $contacts = $validated['contacts'] ?? null;
        $meta = $validated['meta'] ?? null;



        $networkData = Arr::only($validated, $fillable);


        $supportsSlug = $this->hasWifiNetworkSlugColumn();

        if ($supportsSlug) {
            
            $networkData['slug'] = $this->prepareSlug($validated['slug'] ?? null, $validated['name']);
        }
        
        $networkData['contacts'] = $this->normalizeContacts($contacts);
        $networkData['meta'] = $this->normalizeMeta($meta);
        
        $networkData['user_id'] = $user?->getKey();
        if ($walletAccount) {
            $networkData['wallet_id'] = $walletAccount->getKey();
        } else {
            unset($networkData['wallet_id']);
        }
        
        $networkData['commission_rate'] = $networkData['commission_rate'] ?? 0;
        $networkData['commission_flat'] = $networkData['commission_flat'] ?? 0;
        $networkData['is_active'] = $networkData['is_active'] ?? true;

        if ($request->hasFile('logo')) {
            $networkData['logo_path'] = $this->storeUploadedFile($request->file('logo'), 'wifi/logos');
        }

        if ($request->hasFile('login_screenshot')) {
            $networkData['login_screenshot_path'] = $this->storeUploadedFile($request->file('login_screenshot'), 'wifi/login-screens');
        }

        $networkData = Arr::only($networkData, (new WifiNetwork())->getFillable());
        $networkData = collect($networkData)
            ->reject(static fn ($value, $key) => is_int($key) || (is_string($key) && trim($key) === ''))
            ->all();

        $network = null;
        $maxAttempts = $supportsSlug ? 5 : 3;
        $walletConstraintRetried = false;

        $isOwnerNetworkRequest = $this->isOwnerNetworkRequest($networkData['meta'] ?? null);

        if ($user && $isOwnerNetworkRequest) {
            $existingNetwork = WifiNetwork::query()
                ->where('user_id', $user->getKey())
                ->latest('id')
                ->first();

            if ($existingNetwork) {
                $network = $this->applyNetworkUpdates($existingNetwork, $networkData);

                return response()->json(['data' => ['id' => $network->getKey()]], 201);
            }
        }


        for ($attempt = 0; $attempt < $maxAttempts; $attempt++) {

             if ($walletAccount) {
                $networkData['wallet_id'] = $walletAccount->getKey();
            } else {
                unset($networkData['wallet_id']);
            }


            try {
                $network = WifiNetwork::create($networkData);
                break;
            } catch (QueryException $exception) {
                if ($supportsSlug && $this->isDuplicateWifiNetworkSlugException($exception)) {
                    if ($attempt < $maxAttempts - 1) {
                        $networkData['slug'] = $this->prepareSlug(null, $validated['name']);

                        continue;
                    }

                    return response()->json([
                        'message' => __('Unable to create the Wi-Fi network.'),
                        'errors' => [
                            'slug' => [__('The Wi-Fi network link is already in use. Please try a different name.')],
                        ],
                    ], 422);


                }



                if ($walletAccount && $this->isDuplicateWifiNetworkWalletException($exception)) {
                    $existingNetwork = WifiNetwork::query()
                        ->where('wallet_id', $walletAccount->getKey())
                        ->latest('id')
                        ->first();

                    if ($existingNetwork) {
                        if ($user && $existingNetwork->user_id !== $user->getKey()) {
                            return response()->json([
                                'message' => __('Unable to create the Wi-Fi network.'),
                                'errors' => [
                                    'wallet_id' => [__('This wallet is already linked to another Wi-Fi network.')],
                                ],
                            ], 422);
                        }

                        $network = $this->applyNetworkUpdates($existingNetwork, $networkData);


                        break;
                    }

                    return response()->json([
                        'message' => __('Unable to create the Wi-Fi network.'),
                        'errors' => [
                            'wallet_id' => [__('This wallet is already linked to another Wi-Fi network.')],
                        ],
                    ], 422);
                }



                if ($walletAccount) {
                    $walletFallback = $this->handleWalletConstraintFallback($walletAccount, $user, $networkData);

                    if ($walletFallback instanceof WifiNetwork) {
                        $network = $walletFallback;

                        break;
                    }

                    if ($walletFallback instanceof JsonResponse) {
                        return $walletFallback;
                    }
                }


                if ($user && $this->isDuplicateWifiNetworkOwnerException($exception)) {
                    $existingNetwork = WifiNetwork::query()
                        ->where('user_id', $user->getKey())
                        ->latest('id')
                        ->first();

                    if ($existingNetwork) {
                        $network = $this->applyNetworkUpdates($existingNetwork, $networkData);


                        break;
                    }
                }



                if ($user && $this->isWalletAssignmentConstraint($exception, $networkData)) {
                    if (! $walletConstraintRetried) {
                        $walletConstraintRetried = true;
                        $walletAccount = $this->resolveWalletAccount($user, null);
                        
                        if ($walletAccount) {
                            $networkData['wallet_id'] = $walletAccount->getKey();

                            continue;
                        }

                    }


                    report($exception);

                    return response()->json([
                        'message' => __('Unable to create the Wi-Fi network.'),
                        'errors' => [
                            'wallet_id' => [__('We were unable to link your wallet account to the Wi-Fi network. Please try again or contact support.')],
                        ],
                    ], 422);


                
                }

                report($exception);

                return response()->json([
                    'message' => __('Unable to create the Wi-Fi network.'),
                    'errors' => [
                        'database' => [__('A database constraint prevented the Wi-Fi network from being created.')],
                    ],
                ], 422);
            }
        }

        if (! $network) {

            return response()->json([
                'message' => __('Unable to create the Wi-Fi network.'),
                'errors' => [
                    'database' => [__('A database constraint prevented the Wi-Fi network from being created.')],
                ],
            ], 422);
        }


        return response()->json(['data' => ['id' => $network->getKey()]], 201);
    
    
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
            'notes',
            'is_active',
            'meta',
        ]);

        if ($request->has('contacts')) {
            $updateData['contacts'] = $this->normalizeContacts($request->input('contacts'));
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


    private function walletAccountsHaveCurrencyColumn(): bool
    {
        if ($this->walletAccountsHaveCurrencyColumn === null) {
            $this->walletAccountsHaveCurrencyColumn = Schema::hasColumn('wallet_accounts', 'currency');
        }

        return $this->walletAccountsHaveCurrencyColumn;
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



    private function normalizeMeta(mixed $meta): ?array
    {
        if ($meta === null || $meta === '') {
            return null;
        }

        if (is_string($meta)) {
            $decoded = json_decode($meta, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $meta = $decoded;
            }
        }

        if (! is_array($meta)) {
            return null;
        }

        $normalize = function ($items) use (&$normalize) {
            return collect($items)
                ->mapWithKeys(static function ($value, $key) use (&$normalize) {
                    if (! is_string($key) || trim($key) === '') {
                        return [];
                    }

                    if (is_array($value)) {
                        $normalizedChild = $normalize($value);

                        return $normalizedChild === [] ? [] : [$key => $normalizedChild];
                    }

                    if ($value === null) {
                        return [];
                    }

                    if (is_string($value)) {
                        $value = trim($value);
                        if ($value === '') {
                            return [];
                        }
                    }

                    return [$key => $value];
                })
                ->all();
        };

        $normalized = $normalize($meta);

        return $normalized === [] ? null : $normalized;
    }



    private function isOwnerNetworkRequest(mixed $meta): bool
    {
        if (! is_array($meta)) {
            return false;
        }

        $requestTypeRaw = Arr::get($meta, 'request_type');

        if ($requestTypeRaw === null) {
            $requestTypeRaw = Arr::get($meta, 'requestType');
        }

        $requestType = Str::of((string) $requestTypeRaw)
        
        ->trim()
            ->snake('_')

            ->toString();

        if ($requestType === 'owner_network') {
            return true;
        }

        $sourceRaw = Arr::get($meta, 'source');

        if ($sourceRaw === null) {
            $sourceRaw = Arr::get($meta, 'request_source');
        }

        $source = Str::of((string) $sourceRaw)
        
        ->trim()
            ->snake('_')

            ->toString();

        return $source === 'mobile_app' && $requestType === '';
    }

    private function applyNetworkUpdates(WifiNetwork $network, array $networkData): WifiNetwork
    {
        $updateData = Arr::except($networkData, ['slug']);

        if ($updateData !== []) {
            $network->fill($updateData);

            if ($network->isDirty()) {
                $network->save();
            }
        }

        return $network->fresh();
    }



   private function handleWalletConstraintFallback(WalletAccount $walletAccount, ?\App\Models\User $user, array $networkData): JsonResponse|WifiNetwork|null
    {
        $existingNetwork = WifiNetwork::query()
            ->where('wallet_id', $walletAccount->getKey())
            ->latest('id')
            ->first();

        if (! $existingNetwork) {
            return null;
        }

        if ($user && $existingNetwork->user_id !== $user->getKey()) {
            return response()->json([
                'message' => __('Unable to create the Wi-Fi network.'),
                'errors' => [
                    'wallet_id' => [__('This wallet is already linked to another Wi-Fi network.')],
                ],
            ], 422);
        }

        return $this->applyNetworkUpdates($existingNetwork, $networkData);
    }


    private function resolveWalletAccount(?\App\Models\User $user, ?int $requestedWalletId = null): ?WalletAccount
    {
        if ($user === null) {
            return null;
        }

        $query = WalletAccount::query()->where('user_id', $user->getKey());
        $walletsHaveCurrency = $this->walletAccountsHaveCurrencyColumn();

        if ($requestedWalletId) {
            return (clone $query)->whereKey($requestedWalletId)->first();
        }

        if (! $walletsHaveCurrency) {
            $wallet = (clone $query)->first();

            if ($wallet) {
                return $wallet;
            }

            try {
                return WalletAccount::create([
                    'user_id' => $user->getKey(),
                    'balance' => 0,
                ]);
            } catch (QueryException $exception) {
                if (! $this->isDuplicateWalletAccountException($exception)) {
                    throw $exception;
                }


                return (clone $query)->first();
            }

        }


        $defaultCurrency = strtoupper((string) config('app.currency', 'SAR'));

        $wallet = $this->findWalletAccountByCurrency($query, $defaultCurrency);

        if ($wallet) {
            return $wallet;
        }
        try {
            return WalletAccount::create([


                'user_id' => $user->getKey(),
                'balance' => 0,
                'currency' => $defaultCurrency,
            ]);
        } catch (QueryException $exception) {
            if (! $this->isDuplicateWalletAccountException($exception)) {
                throw $exception;


            }

            return $this->findWalletAccountByCurrency($query, $defaultCurrency)
                ?? (clone $query)->first();
        }


    }

    private function findWalletAccountByCurrency(Builder $query, string $currency): ?WalletAccount
    {
        $normalizedCurrency = strtoupper($currency);
        $lowerCurrency = strtolower($currency);

        return (clone $query)
            ->where(static function (Builder $builder) use ($normalizedCurrency, $lowerCurrency) {
                $builder->where('currency', $normalizedCurrency)
                    ->orWhereRaw('LOWER(currency) = ?', [$lowerCurrency]);
            })
            ->first();
    }

    private function isDuplicateWalletAccountException(QueryException $exception): bool
    {
        $message = strtolower($exception->getMessage());

        if (! str_contains($message, 'wallet_accounts')) {
            return false;
        }

        $sqlState = $exception->getCode();
        if (in_array($sqlState, ['23000', '23505'], true)) {
            return true;
        }

        $errorInfo = $exception->errorInfo ?? [];
        $driverCode = isset($errorInfo[1]) ? (int) $errorInfo[1] : null;

        return in_array($driverCode, [1062, 1555, 23505], true)
            || str_contains($message, 'wallet_accounts_user_currency_unique');
    }



    private function isWalletAssignmentConstraint(QueryException $exception, array $networkData = []): bool
    {
        $message = strtolower($exception->getMessage());

        $constraint = strtolower((string) ($exception->errorInfo[2] ?? ''));

        $mentionsWallet = str_contains($message, 'wallet_accounts')
            || str_contains($message, 'wallet_id')
            || str_contains($message, 'wallet')
            || ($constraint !== '' && (
                str_contains($constraint, 'wallet_accounts')
                || str_contains($constraint, 'wallet_id')
                || str_contains($constraint, 'wallet')
            ));

        $driverCode = isset($exception->errorInfo[1]) ? (int) $exception->errorInfo[1] : null;

        if ($mentionsWallet) {
            
            return true;
        }

        $foreignKeyViolation = str_contains($message, 'foreign key constraint')
            || str_contains($constraint, 'foreign key');


        if ($foreignKeyViolation && array_key_exists('wallet_id', $networkData)) {
            return true;
        }

        return $driverCode !== null && in_array($driverCode, [1062, 1452, 1555, 23505], true)
            && $foreignKeyViolation
            && array_key_exists('wallet_id', $networkData);
    }





    private function isDuplicateWifiNetworkSlugException(QueryException $exception): bool
    {
        $message = strtolower($exception->getMessage());

        $errorInfo = $exception->errorInfo ?? [];
        $constraint = strtolower((string) ($errorInfo[2] ?? ''));
        $sqlState = $exception->getCode();
        $driverCode = isset($errorInfo[1]) ? (int) $errorInfo[1] : null;

        $mentionsSlug = str_contains($message, 'slug')
            || ($constraint !== '' && str_contains($constraint, 'slug'));


        if (! $mentionsSlug && $errorInfo !== []) {
            foreach ($errorInfo as $value) {
                if (! is_string($value)) {
                    continue;
                }

                if (str_contains(strtolower($value), 'slug')) {
                    $mentionsSlug = true;
                    break;
                }
            }
        }

        if (! $mentionsSlug) {


            return false;
        }

        if (str_contains($message, 'duplicate') || str_contains($message, 'unique')) {

            return true;
        }

        if ($constraint !== '' && (str_contains($constraint, 'duplicate') || str_contains($constraint, 'unique'))) {

            return true;
        }

        if (in_array($sqlState, ['23000', '23505'], true)) {

            return true;
        }

        return $driverCode !== null && in_array($driverCode, [19, 1062, 1555, 23505], true);
    }

    private function isDuplicateWifiNetworkWalletException(QueryException $exception): bool
    {
        $message = strtolower($exception->getMessage());
        $errorInfo = $exception->errorInfo ?? [];
        $constraint = strtolower((string) ($errorInfo[2] ?? ''));
        $sqlState = $exception->getCode();
        $driverCode = isset($errorInfo[1]) ? (int) $errorInfo[1] : null;

        $mentionsWallet = str_contains($message, 'wallet_id')
            || str_contains($message, 'wallet account')
            || str_contains($message, 'wallet')
            || ($constraint !== '' && (str_contains($constraint, 'wallet_id') || str_contains($constraint, 'wallet')));

        if (! $mentionsWallet) {
            return false;
        }

        $mentionsNetwork = str_contains($message, 'wifi_networks')
            || str_contains($message, 'wifi network')
            || ($constraint !== '' && (str_contains($constraint, 'wifi_networks') || str_contains($constraint, 'wifi_network')));

        if (! $mentionsNetwork) {
            $mentionsNetwork = str_contains($message, 'into `wifi_networks`')
                || str_contains($message, 'into "wifi_networks"')
                || str_contains($message, 'table "wifi_networks"')
                || str_contains($message, 'table `wifi_networks`');
        }

        if (! $mentionsNetwork) {
            $mentionsNetwork = str_contains($message, "for key 'wallet_id'")
                || str_contains($constraint, 'wallet_id');
        }


        if (! $mentionsNetwork) {
            return false;
        }

        if (str_contains($message, 'duplicate') || str_contains($message, 'unique')) {
            return true;
        }

        if ($constraint !== '' && (str_contains($constraint, 'duplicate') || str_contains($constraint, 'unique'))) {
            return true;
        }

        if (in_array($sqlState, ['23000', '23505'], true)) {
            return true;
        }

        return $driverCode !== null && in_array($driverCode, [19, 1062, 1555, 23505], true);
    }

    private function isDuplicateWifiNetworkOwnerException(QueryException $exception): bool
    
    
    
    {
        $message = strtolower($exception->getMessage());
        $errorInfo = $exception->errorInfo ?? [];
        $constraint = strtolower((string) ($errorInfo[2] ?? ''));
        $sqlState = $exception->getCode();
        $driverCode = isset($errorInfo[1]) ? (int) $errorInfo[1] : null;

        $mentionsNetwork = str_contains($message, 'wifi_networks')
            || ($constraint !== '' && str_contains($constraint, 'wifi_networks'));
        $mentionsUser = str_contains($message, 'user_id')
            || ($constraint !== '' && str_contains($constraint, 'user_id'));



        if (! $mentionsNetwork && $mentionsUser) {
            $mentionsNetwork = str_contains($message, 'duplicate')
                || str_contains($message, 'unique')
                || ($constraint !== '' && (str_contains($constraint, 'duplicate') || str_contains($constraint, 'unique')));
        }



        if (! $mentionsNetwork || ! $mentionsUser) {
            return false;
        }

        if (str_contains($message, 'duplicate') || str_contains($message, 'unique')) {
            return true;
        }

        if ($constraint !== '' && (str_contains($constraint, 'duplicate') || str_contains($constraint, 'unique'))) {
            return true;
        }

        if (in_array($sqlState, ['23000', '23505'], true)) {
            return true;
        }

        return $driverCode !== null && in_array($driverCode, [19, 1062, 1555, 23505], true);
    }

}