<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class PaymentConfiguration extends Model {
    use HasFactory;

    protected $fillable = [
        'payment_method',
        'api_key',
        'secret_key',
        'webhook_secret_key',
        'currency_code',
        'status',
        'display_name',
        'note',
        'logo_path',
    
    ];

        protected $appends = ['logo_url'];

    protected $casts = [
        'status' => 'boolean',
    ];

    public function getLogoUrlAttribute(): ?string
    {
        $logoPath = $this->logo_path;

        if (empty($logoPath)) {
            return null;
        }

        if (Str::startsWith($logoPath, ['http://', 'https://'])) {
            return $logoPath;
        }

        return Storage::disk(config('filesystems.default'))->url($logoPath);
    }
}
