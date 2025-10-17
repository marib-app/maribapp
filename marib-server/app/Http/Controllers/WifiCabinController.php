<?php

namespace App\Http\Controllers;



use App\Models\WifiCodeBatch;
use App\Services\Wifi\WifiOwnerRequestService;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

use App\Services\Wifi\WifiCabinService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Arr;
use Illuminate\Validation\ValidationException;
use Throwable;





class WifiCabinController extends Controller
{
    public function __construct(
        private readonly WifiCabinService $wifiCabinService,
        private readonly WifiOwnerRequestService $wifiOwnerRequestService,
    )
    
    
    {
        $this->middleware('permission:wifi-cabin-manage');
    }

    /**
     * Display the WiFi cabin dashboard with networks, plans and alerts.
     */
    public function index(): View
    {
        $data = $this->wifiCabinService->getDashboardData();

        return view('wifi.index', $data);
    }

    /**
     * Show the form for creating WiFi cabin vouchers or plans.
     */
    public function create(): View
    {
        return view('wifi.create', [
            'networks' => $this->wifiCabinService->getNetworks(),
            'plans' => $this->wifiCabinService->getPlans(),
        ]);
    }


    /**
     * Handle the submission of the WiFi voucher batch form.
     */
    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'network_id' => ['required', 'integer', 'exists:wifi_networks,id'],
            'plan_id' => [
                'required',
                'integer',
                Rule::exists('wifi_plans', 'id')->where(function ($query) use ($request) {
                    $networkId = $request->input('network_id');

                    if ($networkId) {
                        $query->where('wifi_network_id', $networkId);
                    }
                }),
            ],
            'quantity' => ['required', 'integer', 'min:1', 'max:1000'],
            'reference' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ], [], [
            'network_id' => __('network'),
            'plan_id' => __('plan'),
            'quantity' => __('quantity'),
            'reference' => __('reference'),
            'notes' => __('notes'),
        ]);

        try {
            $batch = $this->wifiCabinService->createVoucherBatch($validated, $request->user());
        } catch (ValidationException $exception) {
            return redirect()->back()
                ->withErrors($exception->errors())
                ->withInput();
        } catch (AuthorizationException $exception) {
            return redirect()->back()
                ->with('error', $exception->getMessage())
                ->withInput();
        } catch (Throwable $exception) {
            report($exception);

            return redirect()->back()
                ->with('error', __('Unable to create the Wi-Fi voucher batch at the moment.'))
                ->withInput();
        }

        $issuedCount = (int) ($batch->accepted_rows ?? $validated['quantity']);

        return redirect()
            ->route('wifi.create')
            ->with('status', __('Voucher batch issued successfully with :count vouchers.', ['count' => $issuedCount]));
    }



    /**
     * Show the edit view for a specific WiFi network.
     */
    public function edit(string $network): View
    {
        return view('wifi.edit', [
            'network' => $this->wifiCabinService->getNetwork($network),
            'plans' => $this->wifiCabinService->getPlans($network),
            'stock' => $this->wifiCabinService->getStockSummary($network),
            'alerts' => $this->wifiCabinService->getNetworkAlerts($network),
        ]);
    }
    public function approveOwnerRequest(WifiCodeBatch $batch): RedirectResponse
    {
        return $this->processOwnerRequestDecision(
            fn () => $this->wifiOwnerRequestService->approve($batch, auth()->user()),
            __('Owner request approved successfully.'),
            __('Failed to approve the owner request.'),
            __('An unexpected error occurred while approving the owner request.'),
        );
    
    }

    public function rejectOwnerRequest(WifiCodeBatch $batch): RedirectResponse
    {
        return $this->processOwnerRequestDecision(
            fn () => $this->wifiOwnerRequestService->reject($batch, auth()->user()),
            __('Owner request rejected successfully.'),
            __('Failed to reject the owner request.'),
            __('An unexpected error occurred while rejecting the owner request.'),
        );
    }

    /**
     * @param  callable():WifiCodeBatch  $decision
     */
    protected function processOwnerRequestDecision(
        callable $decision,
        string $successMessage,
        string $validationFallbackMessage,
        string $unexpectedErrorMessage,
    ): RedirectResponse {
        try {
            $decision();

            return redirect()->back()->with('status', $successMessage);
        } catch (ValidationException $exception) {
            $errors = $exception->errors();
            $flattened = Arr::flatten($errors);
            $message = Arr::first($flattened) ?? $validationFallbackMessage;

            return redirect()->back()
                ->withErrors($errors, 'wifiOwnerRequests')
                ->with('error', $message);
        } catch (AuthorizationException $exception) {
            return redirect()->back()->with('error', $exception->getMessage());
        } catch (Throwable $exception) {
            report($exception);

            return redirect()->back()->with('error', $unexpectedErrorMessage);
        }
    
    
    }
}