<?php

namespace App\Services\Store;

use App\Enums\StoreClosureMode;
use App\Enums\StoreStatus;
use App\Models\Store;
use App\Models\StorePolicy;
use App\Models\StoreSetting;
use App\Models\StoreStaff;
use App\Models\StoreWorkingHour;
use App\Models\User;
use App\Services\FileService;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

class StoreRegistrationService
{
    /**
     * @param  User  $user
     * @param  array<string, mixed>  $payload
     */
    public function register(User $user, array $payload): Store
    {
        return DB::transaction(function () use ($user, $payload) {
            $store = $user->stores()->firstOrNew([]);

            $basic = $this->extractBasicData($payload, $user);
            $store->fill($basic);

            if (empty($store->slug)) {
                $store->slug = $this->generateUniqueSlug($store->name ?? $user->name ?? 'store');
            }

            if (! $store->status) {
                $store->status = StoreStatus::PENDING->value;
            }

            if (! empty($payload['financial']['policy_type'])) {
                $store->financial_policy_type = $payload['financial']['policy_type'];
            }

            if (array_key_exists('financial', $payload) && array_key_exists('policy_payload', $payload['financial'] ?? [])) {
                $store->financial_policy_payload = $payload['financial']['policy_payload'];
            }

            $meta = $this->buildMetaPayload($payload);
            if ($meta !== []) {
                $store->meta = $meta;
            }

            $store->status_changed_at = now();
            $store->save();

            $this->syncSettings($store, $payload['settings'] ?? []);
            $this->syncWorkingHours($store, $payload['working_hours'] ?? []);
            $this->syncPolicies($store, $payload['policies'] ?? []);
            $this->applyOwnerCredentials($store, $user, $payload);
            $this->ensureOwnerStaffRecord($store, $user->fresh());

            return $store->load([
                'settings',
                'workingHours',
                'policies',
                'staff',
            ]);
        });
    }

    /**
     * @return array<string, mixed>
     */
    private function extractBasicData(array $payload, User $user): array
    {
        $name = $payload['name'] ?? $payload['business_name'] ?? $user->name;

        $logoValue = $payload['logo']
            ?? $payload['logo_path']
            ?? $payload['logo_url']
            ?? $payload['business_logo']
            ?? null;

        $bannerValue = $payload['banner']
            ?? $payload['banner_path']
            ?? $payload['banner_url']
            ?? $payload['cover']
            ?? $payload['cover_path']
            ?? $payload['cover_url']
            ?? $payload['cover_image']
            ?? $payload['store_cover']
            ?? $payload['store_image']
            ?? $payload['store_photo']
            ?? $payload['storefront']
            ?? $payload['business_cover']
            ?? null;

        return array_filter([
            'name' => $name,
            'description' => $payload['description'] ?? $payload['business_description'] ?? null,
            'contact_email' => $payload['contact_email'] ?? $payload['business_email'] ?? $user->email,
            'contact_phone' => $payload['contact_phone'] ?? $payload['business_phone'] ?? $user->mobile,
            'contact_whatsapp' => $payload['contact_whatsapp'] ?? $payload['business_whatsapp'] ?? null,
            'location_address' => $payload['address'] ?? $payload['business_location'] ?? null,
            'location_latitude' => $payload['latitude'] ?? ($payload['location']['lat'] ?? null),
            'location_longitude' => $payload['longitude'] ?? ($payload['location']['lng'] ?? null),
            'location_city' => $payload['city'] ?? null,
            'location_state' => $payload['state'] ?? null,
            'location_country' => $payload['country'] ?? null,
            'location_notes' => $payload['location_notes'] ?? null,
            'logo_path' => $this->maybeStoreMedia($logoValue, 'stores/logos'),
            'banner_path' => $this->maybeStoreMedia($bannerValue, 'stores/banners'),
        ], static fn ($value) => $value !== null);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function buildMetaPayload(array $payload): array
    {
        $meta = [];

        if (! empty($payload['meta']) && is_array($payload['meta'])) {
            $meta = $payload['meta'];
        }

        $categoriesSource = $meta['categories'] ?? $payload['business_categories'] ?? null;
        if (! empty($categoriesSource)) {
            $meta['categories'] = array_values(array_unique(array_map('intval', (array) $categoriesSource)));
        }

        $paymentMethodsSource = $meta['payment_methods'] ?? $payload['payment_methods'] ?? null;
        if (! empty($paymentMethodsSource)) {
            $meta['payment_methods'] = array_values(array_unique(array_map('strval', (array) $paymentMethodsSource)));
        }

        if (! empty($payload['payment_account_details'])) {
            $meta['payment_accounts_snapshot'] = $payload['payment_account_details'];
        }

        return $meta;
    }

    /**
     * @param  array<string, mixed>  $settings
     */
    private function syncSettings(Store $store, array $settings): void
    {
        $defaults = [
            'closure_mode' => StoreClosureMode::FULL->value,
            'allow_delivery' => true,
            'allow_pickup' => true,
            'allow_manual_payments' => true,
            'allow_wallet' => false,
            'allow_cod' => false,
            'auto_accept_orders' => true,
            'order_acceptance_buffer_minutes' => 15,
        ];

        $data = array_merge($defaults, $settings);

        if (! empty($settings['closure_mode']) && ! in_array($settings['closure_mode'], StoreClosureMode::values(), true)) {
            $data['closure_mode'] = StoreClosureMode::FULL->value;
        }

        StoreSetting::updateOrCreate(
            ['store_id' => $store->id],
            $data
        );
    }

    /**
     * @param  array<int, mixed>|array<string, mixed>  $workingHours
     */
    private function syncWorkingHours(Store $store, array $workingHours): void
    {
        $normalized = $this->normalizeWorkingHours($workingHours);

        $store->workingHours()->delete();

        foreach ($normalized as $hour) {
            StoreWorkingHour::create(array_merge($hour, ['store_id' => $store->id]));
        }
    }

    /**
     * @param  array<int, mixed>|array<string, mixed>  $workingHours
     * @return array<int, array<string, mixed>>
     */
    private function normalizeWorkingHours(array $workingHours): array
    {
        $result = [];

        $weekdayMap = [
            'sun' => 0,
            'mon' => 1,
            'tue' => 2,
            'wed' => 3,
            'thu' => 4,
            'fri' => 5,
            'sat' => 6,
        ];

        foreach ($workingHours as $key => $value) {
            if (is_array($value) && array_key_exists('weekday', $value)) {
                $weekday = (int) $value['weekday'];
            } elseif (is_string($key) && isset($weekdayMap[strtolower($key)])) {
                $weekday = $weekdayMap[strtolower($key)];
            } else {
                continue;
            }

            $result[] = [
                'weekday' => $weekday,
                'is_open' => filter_var($value['enabled'] ?? $value['is_open'] ?? false, FILTER_VALIDATE_BOOLEAN),
                'opens_at' => $value['from'] ?? $value['opens_at'] ?? null,
                'closes_at' => $value['to'] ?? $value['closes_at'] ?? null,
            ];
        }

        return $result;
    }

    /**
     * @param  array<int, array<string, mixed>>  $policies
     */
    private function syncPolicies(Store $store, array $policies): void
    {
        $store->policies()->delete();

        foreach ($policies as $policyPayload) {
            if (empty($policyPayload['policy_type']) || empty($policyPayload['content'])) {
                continue;
            }

            StorePolicy::create([
                'store_id' => $store->id,
                'policy_type' => strtolower($policyPayload['policy_type']),
                'title' => $policyPayload['title'] ?? null,
                'content' => $policyPayload['content'],
                'is_required' => $policyPayload['is_required'] ?? true,
                'is_active' => $policyPayload['is_active'] ?? true,
                'display_order' => $policyPayload['display_order'] ?? 0,
            ]);
        }
    }

    private function applyOwnerCredentials(Store $store, User $owner, array $payload): void
    {
        $credentials = $this->extractCredentialsPayload($payload);
        $email = $credentials['email'];
        $password = $credentials['password'];

        $hasChanges = false;

        if ($email !== null) {
            $currentEmail = strtolower((string) $owner->email);
            if ($currentEmail !== strtolower($email)) {
                $this->assertStaffEmailAvailable($email, $store, 'credentials.handle');
                $owner->email = $email;
                $hasChanges = true;
            }
        }

        if ($password !== null) {
            $owner->password = Hash::make($password);
            $hasChanges = true;
        }

        if ($owner->account_type !== User::ACCOUNT_TYPE_SELLER) {
            $owner->account_type = User::ACCOUNT_TYPE_SELLER;
            $hasChanges = true;
        }

        if (! $owner->terms_and_policy_accepted) {
            $owner->terms_and_policy_accepted = true;
            $hasChanges = true;
        }

        if (! $owner->email_verified_at) {
            $owner->email_verified_at = now();
            $hasChanges = true;
        }

        if ($hasChanges) {
            $owner->save();
        }
    }

    private function ensureOwnerStaffRecord(Store $store, User $user): void
    {
        $store->staff()->updateOrCreate(
            [
                'store_id' => $store->id,
                'user_id' => $user->id,
            ],
            [
                'email' => $user->email ?? $user->name . '@example.com',
                'role' => 'owner',
                'status' => 'active',
                'permissions' => null,
                'accepted_at' => now(),
            ]
        );

        $this->assignStoreRole($user, $store);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array{email: ?string, password: ?string}
     */
    private function extractCredentialsPayload(array $payload): array
    {
        $handleSource = Arr::get($payload, 'credentials.handle')
            ?? Arr::get($payload, 'staff.invited_email');

        $passwordSource = Arr::get($payload, 'credentials.password')
            ?? Arr::get($payload, 'staff.password');

        $email = $this->normalizeStaffEmail($handleSource);
        $password = is_string($passwordSource) ? trim($passwordSource) : null;

        if ($password === '') {
            $password = null;
        }

        return [
            'email' => $email,
            'password' => $password,
        ];
    }

    private function assignStoreRole(User $user, Store $store): void
    {
        $role = $this->determineStoreRole($store);

        if (! $user->hasRole($role->name)) {
            $user->assignRole($role);
        }

        if ($user->account_type !== User::ACCOUNT_TYPE_SELLER) {
            $user->account_type = User::ACCOUNT_TYPE_SELLER;
        }

        if (! $user->terms_and_policy_accepted) {
            $user->terms_and_policy_accepted = true;
        }

        if (! $user->email_verified_at) {
            $user->email_verified_at = now();
        }

        if ($user->isDirty()) {
            $user->save();
        }
    }

    private function determineStoreRole(Store $store): Role
    {
        $roleName = sprintf('store-owner-%s', $store->id);

        $role = Role::firstOrCreate(
            ['name' => $roleName, 'guard_name' => 'web'],
            ['name' => $roleName, 'guard_name' => 'web']
        );

        if ($role->wasRecentlyCreated) {
            $this->refreshPermissionCache();
        }

        $permission = $this->ensureMerchantPortalPermission();
        if (! $role->hasPermissionTo($permission)) {
            $role->givePermissionTo($permission);
            $this->refreshPermissionCache();
        }

        return $role;
    }

    private function ensureMerchantPortalPermission(): Permission
    {
        $permission = Permission::firstOrCreate(
            ['name' => 'merchant-portal-access', 'guard_name' => 'web'],
            ['name' => 'merchant-portal-access', 'guard_name' => 'web']
        );

        if ($permission->wasRecentlyCreated) {
            $this->refreshPermissionCache();
        }

        return $permission;
    }

    private function refreshPermissionCache(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    private function normalizeStaffEmail(mixed $raw): ?string
    {
        if (! is_string($raw)) {
            return null;
        }

        $candidate = trim($raw);
        if ($candidate === '') {
            return null;
        }

        $attribute = 'credentials.handle';
        $domain = strtolower(config('store.staff_email_domain', 'maribsrv.com'));
        $localPart = $candidate;

        if (str_contains($candidate, '@')) {
            [$localPart, $incomingDomain] = explode('@', strtolower($candidate), 2);
            if ($incomingDomain !== $domain) {
                throw ValidationException::withMessages([
                    $attribute => 'Handle must belong to the ' . $domain . ' domain.',
                ]);
            }
        }

        $normalizedLocal = strtolower(preg_replace('/[^a-z0-9._-]/i', '', $localPart) ?? '');
        $min = (int) config('store.staff_email_min_length', 3);
        $max = (int) config('store.staff_email_max_length', 48);

        if ($normalizedLocal === '' || strlen($normalizedLocal) < $min || strlen($normalizedLocal) > $max) {
            throw ValidationException::withMessages([
                $attribute => "Handle must be between {$min} and {$max} characters.",
            ]);
        }

        if (! preg_match('/^[a-z0-9._-]+$/', $normalizedLocal)) {
            throw ValidationException::withMessages([
                $attribute => 'Handle may only contain letters, numbers, dots, underscores, or dashes.',
            ]);
        }

        return $normalizedLocal . '@' . $domain;
    }

    private function assertStaffEmailAvailable(string $email, Store $store, string $attribute = 'staff.invited_email'): void
    {
        $existsElsewhere = StoreStaff::query()
            ->where('email', $email)
            ->whereNull('revoked_at')
            ->where('store_id', '!=', $store->id)
            ->exists();

        if ($existsElsewhere) {
            throw ValidationException::withMessages([
                $attribute => 'This store handle is already linked to another merchant.',
            ]);
        }

        $emailLower = strtolower($email);

        $userConflict = User::query()
            ->whereRaw('LOWER(email) = ?', [$emailLower])
            ->whereDoesntHave('storeStaffAssignments', static function ($query) use ($store) {
                $query->where('store_id', $store->id);
            })
            ->exists();

        if ($userConflict) {
            throw ValidationException::withMessages([
                $attribute => 'This store handle is already linked to another merchant.',
            ]);
        }
    }

    private function generateUniqueSlug(string $name): string
    {
        $base = Str::slug($name);
        if ($base === '') {
            $base = 'store';
        }

        $slug = $base;
        $index = 1;
        while (Store::where('slug', $slug)->exists()) {
            $slug = $base . '-' . $index;
            $index++;
        }

        return $slug;
    }

    /**
     * @param  string|UploadedFile|null  $media
     */
    private function maybeStoreMedia($media, string $directory, ?string $existingPath = null): ?string
    {
        if ($media instanceof UploadedFile) {
            return FileService::replace($media, $directory, $existingPath);
        }

        if (is_string($media) && Str::contains($media, 'base64,')) {
            return $this->storeBase64Image($media, $directory, $existingPath);
        }

        if (is_string($media) && $media !== '') {
            return $media;
        }

        return $existingPath;
    }

    private function storeBase64Image(string $payload, string $directory, ?string $existingPath = null): ?string
    {
        if (! Str::contains($payload, 'base64,')) {
            return $existingPath;
        }

        [, $data] = explode('base64,', $payload, 2);
        $decoded = base64_decode($data, true);

        if ($decoded === false) {
            throw new RuntimeException('Invalid base64 encoded image provided.');
        }

        $extension = 'png';
        if (Str::contains($payload, 'image/jpeg')) {
            $extension = 'jpg';
        } elseif (Str::contains($payload, 'image/webp')) {
            $extension = 'webp';
        }

        $filename = $directory . '/' . uniqid('store_', true) . '.' . $extension;
        Storage::disk(config('filesystems.default'))->put($filename, $decoded);

        if ($existingPath) {
            FileService::delete($existingPath);
        }

        return $filename;
    }
}
