<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class CurrencyRate extends Model
{
    use HasFactory;
    protected $table = 'currency_rates'; // <-- make sure this is correct

    protected $fillable = [
        'currency_name',
        'sell_price',
        'buy_price',
        'last_updated_at',
        'icon_path',
        'icon_alt',
        'icon_uploaded_by',
        'icon_uploaded_at',
        'icon_removed_by',
        'icon_removed_at',
    ];

    protected $casts = [
        'last_updated_at' => 'datetime',
        'sell_price' => 'decimal:2',
        'buy_price' => 'decimal:2',
        'icon_uploaded_at' => 'datetime',
        'icon_removed_at' => 'datetime',
    ];

    protected $appends = [
        'icon_url',
    ];

    public function getIconUrlAttribute(): ?string
    {
        if (empty($this->icon_path)) {
            return null;
        }

        return Storage::disk('public')->url($this->icon_path);
    }

}
