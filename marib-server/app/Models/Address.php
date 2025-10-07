<?php

namespace App\Models;

use App\Models\Area;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Address extends Model
{
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'user_id',
        'label',
        'phone',
        'latitude',
        'longitude',
        'distance_km',
        'area_id',
        'street',
        'building',
        'note',
        'is_default',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'is_default' => 'boolean',
        'latitude' => 'float',
        'longitude' => 'float',
        'distance_km' => 'decimal:3',

    ];

    protected static function booted(): void
    {
        static::saving(function (self $address): void {
            if ($address->distance_km === null) {
                return;
            }

            if ($address->distance_km < 0) {
                throw new \InvalidArgumentException('The distance in kilometers must be greater than or equal to zero.');
            }

            $address->distance_km = round($address->distance_km, 3);
        });
    }

    public function setDistanceKmAttribute($value): void
    {
        if ($value === null || $value === '') {
            $this->attributes['distance_km'] = null;

            return;
        }

        $distance = (float) $value;

        if ($distance < 0) {
            throw new \InvalidArgumentException('The distance in kilometers must be greater than or equal to zero.');
        }

        $this->attributes['distance_km'] = round($distance, 3);
    }

    public function distanceInKm(): ?float
    {
        $distance = $this->distance_km;

        return $distance === null ? null : (float) $distance;
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class);
    }
}