<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Arr;

class CampaignSegment extends Model
{
    use HasFactory;

    protected $fillable = [
        'campaign_id',
        'name',
        'description',
        'filters',
        'estimated_size',
        'last_calculated_at',
    ];

    protected $casts = [
        'filters' => 'array',
        'last_calculated_at' => 'datetime',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(Campaign::class);
    }

    public function getFilter(string $key, $default = null)
    {
        return Arr::get($this->filters ?? [], $key, $default);
    }
}