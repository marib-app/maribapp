<?php

namespace App\Http\Controllers;

use App\Models\Service;
use Illuminate\Support\Str; 
use Illuminate\Support\Facades\Storage;

class PublicServiceController extends Controller
{
    public function show(string $serviceIdentifier)
    {
        $service = Service::query()
            ->where('status', true)
            ->where(function ($query) {
                $query->whereNull('expiry_date')->orWhere('expiry_date', '>', now());
            })
            ->where(function ($query) use ($serviceIdentifier) {
                $query->where('service_uid', $serviceIdentifier)
                    ->orWhere('slug', $serviceIdentifier);

                if (ctype_digit($serviceIdentifier)) {
                    $query->orWhere('id', (int) $serviceIdentifier);
                }
            })
            ->with(['category:id,name', 'owner:id,name,email,profile'])
            ->firstOrFail();

        $url = static function (?string $path) {
            if (empty($path)) {
                return null;
            }

            if (Str::startsWith($path, ['http://', 'https://'])) {
                return $path;
            }

            return Storage::disk('public')->url(ltrim($path, '/'));
        };

        return view('public.services.show', [
            'service'   => $service,
            'imageUrl'  => $url($service->image),
            'iconUrl'   => $url($service->icon),
        ]);
    }
}