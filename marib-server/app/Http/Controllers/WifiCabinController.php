<?php

namespace App\Http\Controllers;

use Illuminate\View\View;

class WifiCabinController extends Controller
{
    public function index(): View
    {
        return view('wifi.index');
    }
}