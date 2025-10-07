<?php

namespace App\Http\Controllers;
use App\Models\WifiCodeBatch;

use App\Services\Wifi\WifiCabinService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;

class WifiCabinController extends Controller
{
    public function __construct(private readonly WifiCabinService $wifiCabinService)
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
        return redirect()->back()->with('status', __('Owner request approval handling is not yet implemented.'));
    }

    public function rejectOwnerRequest(WifiCodeBatch $batch): RedirectResponse
    {
        return redirect()->back()->with('status', __('Owner request rejection handling is not yet implemented.'));
    }
}