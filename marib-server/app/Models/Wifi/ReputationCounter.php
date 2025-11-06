<?php

namespace App\Models\Wifi;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReputationCounter extends Model
{
    use HasFactory;

    protected $table = 'wifi_reputation_counters';

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'wifi_network_id',
        'metric',
        'score',
        'value',
        'period_start',
        'period_end',
        'meta',
    ];

    protected $casts = [
        'score' => 'decimal:2',
        'value' => 'integer',
        'period_start' => 'date',
        'period_end' => 'date',
        'meta' => 'array',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(WifiNetwork::class, 'wifi_network_id');
    }
}