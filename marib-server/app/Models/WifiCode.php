<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;

class WifiCode extends Model
{
    use HasFactory;

    public const STATUS_AVAILABLE = 'available';
    public const STATUS_ALLOCATED = 'allocated';
    public const STATUS_REDEEMED = 'redeemed';

    protected $fillable = [
        'wifi_network_id',
        'wifi_plan_id',
        'wifi_code_batch_id',
        'code_encrypted',
        'code_hash',
        'username_encrypted',
        'password_encrypted',
        'serial_encrypted',
        'expires_at',
        'status',
        'allocated_to_user_id',
        'allocated_at',
        'meta',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'allocated_at' => 'datetime',
        'meta' => 'array',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(WifiNetwork::class, 'wifi_network_id');
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(WifiPlan::class, 'wifi_plan_id');
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(WifiCodeBatch::class, 'wifi_code_batch_id');
    }

    public function allocatedTo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'allocated_to_user_id');
    }

    public function scopeAvailable($query)
    {
        return $query->where('status', self::STATUS_AVAILABLE);
    }

    public function scopeForPlan($query, WifiPlan $plan)
    {
        return $query->where('wifi_plan_id', $plan->getKey());
    }

    public function getDecryptedCode(): ?string
    {
        return $this->code_encrypted ? Crypt::decryptString($this->code_encrypted) : null;
    }

    public function getDecryptedUsername(): ?string
    {
        return $this->username_encrypted ? Crypt::decryptString($this->username_encrypted) : null;
    }

    public function getDecryptedPassword(): ?string
    {
        return $this->password_encrypted ? Crypt::decryptString($this->password_encrypted) : null;
    }

    
    public function getDecryptedSerialNumber(): ?string
    {
        return $this->serial_encrypted ? Crypt::decryptString($this->serial_encrypted) : null;
    }



    public function toDecryptedArray(): array
    {
        return [
            'code' => $this->getDecryptedCode(),
            'username' => $this->getDecryptedUsername(),
            'password' => $this->getDecryptedPassword(),
            'serial_no' => $this->getDecryptedSerialNumber(),
            'expires_at' => optional($this->expires_at)->toDateTimeString(),
        ];
    }

    public static function hashCode(?string $code): string
    {
        return hash('sha256', Str::lower(trim((string) $code)));
    }
}