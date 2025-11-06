<?php

namespace App\Models\Wifi;

use App\Enums\Wifi\WifiCodeStatus;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;

class WifiCode extends Model
{
    use HasFactory;

    protected $table = 'wifi_codes';

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'wifi_plan_id',
        'wifi_code_batch_id',
        'status',
        'code_encrypted',
        'code_suffix',
        'code_hash',
        'username_encrypted',
        'password_encrypted',
        'serial_no_encrypted',
        'expiry_date',
        'delivered_at',
        'sold_at',
        'meta',
    ];

    protected $casts = [
        'status' => WifiCodeStatus::class,
        'expiry_date' => 'date',
        'delivered_at' => 'datetime',
        'sold_at' => 'datetime',
        'meta' => 'array',
    ];

    protected $hidden = [
        'code_encrypted',
        'username_encrypted',
        'password_encrypted',
        'serial_no_encrypted',
        'code_hash',
    ];

    protected $attributes = [
        'status' => WifiCodeStatus::AVAILABLE,
    ];

    public function plan(): BelongsTo
    {
        return $this->belongsTo(WifiPlan::class, 'wifi_plan_id');
    }

    public function batch(): BelongsTo
    {
        return $this->belongsTo(WifiCodeBatch::class, 'wifi_code_batch_id');
    }

    public function code(): Attribute
    {
        return Attribute::make(
            get: fn (?string $value, array $attributes) => $attributes['code_encrypted'] ?? null
                ? Crypt::decryptString($attributes['code_encrypted'])
                : null,
            set: function ($value): array {
                if ($value === null) {
                    return [
                        'code_encrypted' => null,
                        'code_suffix' => null,
                        'code_hash' => null,
                    ];
                }

                $value = trim((string) $value);

                if ($value === '') {
                    return [
                        'code_encrypted' => null,
                        'code_suffix' => null,
                        'code_hash' => null,
                    ];
                }
                $normalized = Str::of($value)
                    ->lower()
                    ->replaceMatches('/\s+/u', '')
                    ->value();

                return [
                    'code_encrypted' => Crypt::encryptString($value),
                    'code_suffix' => mb_substr($value, -4),
                    'code_hash' => hash('sha256', $normalized),
                ];
            }
        );
    }

    public function username(): Attribute
    {
        return $this->encryptedFieldAccessor('username_encrypted');
    }

    public function password(): Attribute
    {
        return $this->encryptedFieldAccessor('password_encrypted');
    }

    public function serialNo(): Attribute
    {
        return $this->encryptedFieldAccessor('serial_no_encrypted');
    }

    protected function encryptedFieldAccessor(string $column): Attribute
    {
        return Attribute::make(
            get: fn (?string $value, array $attributes) => $attributes[$column] ?? null
                ? Crypt::decryptString($attributes[$column])
                : null,
            set: function ($value) use ($column): array {
                if ($value === null) {
                    return [$column => null];
                }

                $value = trim((string) $value);

                if ($value === '') {
                    return [$column => null];
                }

                return [$column => Crypt::encryptString($value)];
            }
        );
    }
}