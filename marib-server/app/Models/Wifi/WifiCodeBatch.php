<?php

namespace App\Models\Wifi;

use App\Enums\Wifi\WifiCodeBatchStatus;
use App\Models\User;
use App\Models\Wifi\WifiNetwork;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class WifiCodeBatch extends Model
{
    use HasFactory;

    protected $table = 'wifi_code_batches';

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'wifi_plan_id',
        'wifi_network_id',
        'uploaded_by',
        'label',
        'source_filename',
        'checksum',
        'status',
        'total_codes',
        'available_codes',
        'validated_at',
        'activated_at',
        'notes',
        'meta',
    ];

    protected $casts = [
        'status' => WifiCodeBatchStatus::class,
        'total_codes' => 'integer',
        'available_codes' => 'integer',
        'validated_at' => 'datetime',
        'activated_at' => 'datetime',
        'meta' => 'array',
    ];


    public function plan(): BelongsTo
    {
        return $this->belongsTo(WifiPlan::class, 'wifi_plan_id');
    }

    public function network(): BelongsTo
    {
        return $this->belongsTo(WifiNetwork::class, 'wifi_network_id');
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function codes(): HasMany
    {
        return $this->hasMany(WifiCode::class, 'wifi_code_batch_id');
    }
}
