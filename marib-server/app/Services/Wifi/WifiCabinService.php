<?php

namespace App\Services\Wifi;



use App\Models\User;
use App\Models\WifiCode;
use App\Models\WifiCodeBatch;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use Illuminate\Auth\Access\AuthorizationException;

use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\URL;
use Illuminate\Validation\ValidationException;

use Throwable;

class WifiCabinService
{
    /**
     * Fetch aggregated dashboard data for the WiFi cabin module.
     */
    public function getDashboardData(): array
    {
        return [
            'networks' => $this->getNetworks(),
            'plans' => $this->getPlans(),
            'balances' => $this->getBalances(),
            'ownerRequests' => $this->getOwnerRequests(),
            'alerts' => $this->getAlerts(),
        ];
    }

    /**
     * Retrieve the available WiFi networks.
     */
    public function getNetworks(): Collection
    {
        $payload = $this->fetch('networks');

        return collect(Arr::get($payload, 'data', $payload ?? []));
    }

    /**
     * Retrieve the available WiFi plans (optionally for a specific network).
     */
    public function getPlans(?string $networkId = null): Collection
    {
        $endpoint = $networkId ? "networks/{$networkId}/plans" : 'plans';
        $payload = $this->fetch($endpoint);

        $plans = Arr::get($payload, 'data', $payload ?? []);

        return collect($plans)->map(function ($plan) {
            $planArray = $this->normalizePlanData($plan);

            return $this->transformPlan($planArray);
        });
    }



    /**
     * @param  array{network_id:int|string, plan_id:int|string, quantity:int, reference?:string|null, notes?:string|null}  $data
     */
    public function createVoucherBatch(array $data, ?User $actor = null): WifiCodeBatch
    {
        $actor ??= auth()->user();

        if ($actor === null) {
            throw ValidationException::withMessages([
                'user' => __('Authentication is required to issue Wi-Fi vouchers.'),
            ]);
        }

        if (! $actor->can('wifi-cabin-manage')) {
            throw new AuthorizationException(__('You are not authorized to issue Wi-Fi vouchers.'));
        }

        $networkId = (int) $data['network_id'];
        $planId = (int) $data['plan_id'];
        $quantity = max(1, (int) $data['quantity']);
        $reference = isset($data['reference']) ? trim((string) $data['reference']) : null;
        $notes = isset($data['notes']) ? trim((string) $data['notes']) : null;

        $network = WifiNetwork::query()->find($networkId);

        if (! $network) {
            throw ValidationException::withMessages([
                'network_id' => __('The selected Wi-Fi network could not be found.'),
            ]);
        }

        $plan = WifiPlan::query()
            ->where('wifi_network_id', $network->getKey())
            ->find($planId);

        if (! $plan) {
            throw ValidationException::withMessages([
                'plan_id' => __('The selected Wi-Fi plan is not available for this network.'),
            ]);
        }

        return DB::transaction(function () use ($actor, $network, $plan, $quantity, $reference, $notes) {
            $timestamp = now();

            $batchMeta = $this->filterMeta([
                'reference' => $reference,
                'notes' => $notes,
                'requested_quantity' => $quantity,
                'issued_via' => 'wifi_cabin_admin_form',
                'generated_by' => $actor->getKey(),
                'generated_by_name' => $actor->name,
            ]);

            $batch = WifiCodeBatch::create([
                'wifi_network_id' => $network->getKey(),
                'wifi_plan_id' => $plan->getKey(),
                'uploaded_by' => $actor->getKey(),
                'original_filename' => null,
                'total_rows' => $quantity,
                'accepted_rows' => $quantity,
                'rejected_rows' => 0,
                'status' => WifiCodeBatch::STATUS_PROCESSED,
                'processed_at' => $timestamp,
                'meta' => $batchMeta,
            ]);

            $existingHashes = WifiCode::query()
                ->where('wifi_network_id', $network->getKey())
                ->pluck('code_hash')
                ->all();

            $knownHashes = array_fill_keys($existingHashes, true);
            $records = [];

            for ($index = 1; $index <= $quantity; $index++) {
                $voucher = $this->generateVoucherCredentials($network, $batch, $index, $knownHashes);

                $records[] = [
                    'wifi_network_id' => $network->getKey(),
                    'wifi_plan_id' => $plan->getKey(),
                    'wifi_code_batch_id' => $batch->getKey(),
                    'code_encrypted' => Crypt::encryptString($voucher['code']),
                    'code_hash' => $voucher['hash'],
                    'username_encrypted' => $voucher['username'] ? Crypt::encryptString($voucher['username']) : null,
                    'password_encrypted' => $voucher['password'] ? Crypt::encryptString($voucher['password']) : null,
                    'serial_encrypted' => $voucher['serial'] ? Crypt::encryptString($voucher['serial']) : null,
                    'status' => WifiCode::STATUS_AVAILABLE,
                    'meta' => $this->buildVoucherMeta($index, $reference, $notes, $actor),
                    'created_at' => $timestamp,
                    'updated_at' => $timestamp,
                ];
            }

            if ($records !== []) {
                WifiCode::insert($records);
            }

            return $batch->fresh(['codes']);
        });
    }

    /**
     * @param  array<string,mixed>  $meta
     * @return array<string,mixed>
     */
    protected function filterMeta(array $meta): array
    {
        return array_filter($meta, static fn ($value) => $value !== null && $value !== '');
    }

    /**
     * @param  array<string, bool>  $knownHashes
     * @return array{code:string, hash:string, username:string, password:string, serial:string}
     */
    protected function generateVoucherCredentials(
        WifiNetwork $network,
        WifiCodeBatch $batch,
        int $sequence,
        array &$knownHashes
    ): array {
        $prefixSource = (string) ($network->slug ?: $network->name ?: 'WIFI');
        $prefix = Str::upper(Str::slug($prefixSource, ''));

        if ($prefix === '') {
            $prefix = 'WIFI';
        }

        $prefix = Str::substr($prefix, 0, 6);

        do {
            $codeBody = strtoupper(Str::random(4)) . '-' . strtoupper(Str::random(4)) . '-' . strtoupper(Str::random(4));
            $code = ($prefix !== '' ? $prefix . '-' : '') . $codeBody;
            $hash = WifiCode::hashCode($code);
        } while (isset($knownHashes[$hash]));

        $knownHashes[$hash] = true;

        $usernamePrefix = Str::substr($prefix ?: 'WIFI', 0, 4);
        $username = sprintf('%s%03d%s', $usernamePrefix, $sequence, strtoupper(Str::random(2)));
        $password = strtoupper(Str::random(10));
        $serial = sprintf('B%s-%05d', $batch->getKey(), $sequence);

        return [
            'code' => $code,
            'hash' => $hash,
            'username' => $username,
            'password' => $password,
            'serial' => $serial,
        ];
    }

    /**
     * @return array<string,mixed>
     */
    protected function buildVoucherMeta(int $sequence, ?string $reference, ?string $notes, User $actor): array
    {
        return $this->filterMeta([
            'sequence' => $sequence,
            'batch_reference' => $reference,
            'batch_notes' => $notes,
            'issued_via' => 'wifi_cabin_admin_form',
            'generated_by' => $actor->getKey(),
        ]);
    }
    

    protected function normalizePlanData(mixed $plan): array
    {
        if ($plan instanceof Collection) {
            return $plan->toArray();
        }

        if (is_object($plan)) {
            return collect($plan)->toArray();
        }

        if (! is_array($plan)) {
            return (array) $plan;
        }

        return $plan;
    }

    protected function transformPlan(array $plan): array
    {
        $allowanceMb = Arr::get($plan, 'data_allowance_mb');

        if ($allowanceMb !== null) {
            $allowanceMb = (int) $allowanceMb;

            $plan['data_allowance_mb'] = $allowanceMb;
            $plan['data_allowance_gb'] = round($allowanceMb / 1024, 2);
            $plan['data_allowance_label'] = $this->formatDataAllowance($allowanceMb);

            if (! Arr::has($plan, 'allowance')) {
                $plan['allowance'] = $plan['data_allowance_label'];
            }
        }

        $validityDays = Arr::get($plan, 'validity_days');

        if ($validityDays !== null) {
            $validityDays = (int) $validityDays;

            $plan['validity_days'] = $validityDays;
            $plan['validity_label'] = $this->formatValidityDays($validityDays);

            if (! Arr::has($plan, 'validity')) {
                $plan['validity'] = $plan['validity_label'];
            }
        }

        $speedMbps = Arr::get($plan, 'speed_mbps');

        if ($speedMbps !== null) {
            $plan['speed_mbps'] = (float) $speedMbps;
            $plan['speed_label'] = $this->formatSpeed($plan['speed_mbps']);
        }



        $available = (int) Arr::get($plan, 'available_count', Arr::get($plan, 'stock.available', 0));
        $reserved = (int) Arr::get($plan, 'stock.reserved', 0);
        $issued = (int) Arr::get($plan, 'stock.issued', 0);
        $sold = (int) Arr::get($plan, 'sold_count', $reserved + $issued);
        $total = (int) Arr::get($plan, 'total_codes', $available + $sold);

        $plan['available_count'] = $available;
        $plan['sold_count'] = $sold;
        $plan['total_codes'] = $total;
        $plan['owner_net_amount'] = round((float) Arr::get($plan, 'owner_net_amount', 0), 2);
        $plan['gross_revenue_amount'] = round((float) Arr::get($plan, 'gross_revenue_amount', 0), 2);


        return $plan;
    }

    protected function formatDataAllowance(int $megabytes): string
    {
        if ($megabytes >= 1024) {
            $gigabytes = $megabytes / 1024;
            $formatted = $this->formatDecimal($gigabytes);

            return sprintf('%s GB', $formatted);
        }

        return sprintf('%s MB', number_format($megabytes));
    }

    protected function formatValidityDays(int $days): string
    {
        return sprintf('%s %s', number_format($days), Str::plural('day', $days));
    }

    protected function formatSpeed(float $speed): string
    {
        $formatted = $this->formatDecimal($speed);

        return sprintf('%s Mbps', $formatted);
    }

    protected function formatDecimal(float $value, int $precision = 2): string
    {
        $formatted = number_format($value, $precision, '.', '');

        return rtrim(rtrim($formatted, '0'), '.') ?: '0';
    
    }

    /**
     * Retrieve aggregated balance information for all networks.
     */
    public function getBalances(): Collection
    {
        $payload = $this->fetch('balances');

        return collect(Arr::get($payload, 'data', $payload ?? []));
    }

    /**
     * Retrieve stock alerts for all networks.
     */
    public function getAlerts(): Collection
    {
        $payload = $this->fetch('alerts');

        return collect(Arr::get($payload, 'data', $payload ?? []));
    }


    /**
     * Retrieve pending owner requests for WiFi cabin approval.
     */
    public function getOwnerRequests(): Collection
    {
        $payload = $this->fetch('owner-requests');

        return collect(Arr::get($payload, 'data', $payload ?? []));
    }

    /**
     * Retrieve a specific network with its metadata.
     */
    public function getNetwork(string $networkId): array
    {
        $payload = $this->fetch("networks/{$networkId}");

        return Arr::get($payload, 'data', $payload ?? []);
    }

    /**
     * Retrieve a stock summary for a particular network.
     */
    public function getStockSummary(string $networkId): array
    {
        $payload = $this->fetch("networks/{$networkId}/stock");

        return Arr::get($payload, 'data', $payload ?? []);
    }

    /**
     * Retrieve alerts for a specific network.
     */
    public function getNetworkAlerts(string $networkId): Collection
    {
        $payload = $this->fetch("networks/{$networkId}/alerts");

        return collect(Arr::get($payload, 'data', $payload ?? []));
    }

    /**
     * Perform a GET request against the WiFi cabin backend.
     */
    protected function fetch(string $endpoint): array
    {
        $client = $this->http();

        if (! $client) {
            return [];
        }

        try {
            $response = $client->get($endpoint);

            if ($response->successful()) {
                return $response->json() ?? [];
            }

            Log::warning('WifiCabinService: Non-success response received.', [
                'endpoint' => $endpoint,
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
        } catch (Throwable $exception) {
            Log::warning('WifiCabinService: Failed to fetch data from backend.', [
                'endpoint' => $endpoint,
                'message' => $exception->getMessage(),
            ]);
        }

        return [];
    }

    /**
     * Configure the HTTP client for the WiFi cabin backend.
     */
    protected function http(): ?PendingRequest
    {
        $baseUrl = (string) config('services.wifi.base_url');

        if ($baseUrl === '') {
            $baseUrl = URL::to('/api/wifi-cabin');
        }

        $baseUrl = rtrim($baseUrl, '/');
        
        if ($baseUrl === '') {
            return null;
        }

        $request = Http::baseUrl($baseUrl);

        if ($timeout = config('services.wifi.timeout')) {
            $request = $request->timeout((int) $timeout);
        }

        if ($token = config('services.wifi.token')) {
            $request = $request->withToken($token);
        }

        $verify = config('services.wifi.verify_ssl');
        if ($verify !== null && $verify !== '') {
            $parsedVerify = filter_var($verify, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            $request = $request->withOptions(['verify' => $parsedVerify ?? $verify]);
        }

        if ($caPath = config('services.wifi.ca_path')) {
            $request = $request->withOptions(['verify' => $caPath]);
        }

        return $request;
    }
}