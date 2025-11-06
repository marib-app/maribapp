<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;

class StoreGateway extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'logo_path',
        'is_active',
    ];


    protected $appends = [
        'logo_url',
    ];


    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function accounts(): HasMany
    {
        return $this->hasMany(StoreGatewayAccount::class);
    }



    public function getLogoUrlAttribute(): ?string
    {
        $logoPath = $this->logo_path;

        if (empty($logoPath)) {
            return null;
        }

        return url(Storage::url($logoPath));
    }
}
