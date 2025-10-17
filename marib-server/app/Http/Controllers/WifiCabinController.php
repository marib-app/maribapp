<?php

namespace App\Http\Controllers;



use App\Models\WifiCodeBatch;
use App\Services\Wifi\WifiOwnerRequestService;
use Illuminate\Auth\Access\AuthorizationException;


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