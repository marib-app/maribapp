<?php

namespace App\Models\Wifi;

use App\Enums\Wifi\WifiReportStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WifiReport extends Model
{
    use HasFactory;

    protected $table = 'wifi_reports';

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'wifi_network_id',
        'reported_by',
        'assigned_to',
        'status',
        'category',
        'priority',
        'title',
        'description',
        'resolution_notes',
        'attachments',
        'meta',
        'reported_at',
        'resolved_at',
    ];

    protected $casts = [
        'status' => WifiReportStatus::class,
        'attachments' => 'array',
        'meta' => 'array',
        'reported_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    protected $attributes = [
        'status' => WifiReportStatus::OPEN,
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(WifiNetwork::class, 'wifi_network_id');
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_by');
    }

    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }
}