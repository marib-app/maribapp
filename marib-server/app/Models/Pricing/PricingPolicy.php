<?php

namespace App\Models\Pricing;
use App\Models\User;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

use Illuminate\Database\Eloquent\Relations\HasMany;

class PricingPolicy extends Model
{
    use HasFactory;

    public const STATUS_DRAFT = 'draft';
    public const STATUS_ACTIVE = 'active';
    public const STATUS_INACTIVE = 'inactive';
    public const STATUS_ARCHIVED = 'archived';


    public const MODE_DISTANCE_ONLY = 'distance_only';
    public const MODE_WEIGHT_DISTANCE = 'weight_distance';

    protected $fillable = [
        'name',
        'code',
        'description',
        'status',
        'mode',
        'is_default',
        'currency',
        'free_shipping_enabled',
        'free_shipping_threshold',
        'department',
        'vendor_id',
        'min_order_total',
        'max_order_total',
        'notes',

    ];

    protected $casts = [
        'is_default' => 'boolean',
        'free_shipping_enabled' => 'boolean',
        'free_shipping_threshold' => 'float',
        'min_order_total' => 'float',
        'max_order_total' => 'float',
        'vendor_id' => 'integer',

    ];


    protected $attributes = [
        'mode' => self::MODE_DISTANCE_ONLY,
    ];


    public function weightTiers(): HasMany
    {
        return $this->hasMany(PricingWeightTier::class);
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'vendor_id');
    }



    public function distanceRules(): HasMany
    {
        return $this->hasMany(PricingDistanceRule::class)
            ->where('applies_to', PricingDistanceRule::APPLIES_TO_POLICY);
    }




    public function audits(): HasMany
    {
        return $this->hasMany(PricingAudit::class);
    }

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopeForDepartment($query, ?string $department)
    {
        if ($department === null) {
            return $query->whereNull('department');
        }

        return $query->where('department', $department);
    }

    public static function resolveDefaultForDepartment(?string $department): self
    {
        $query = static::query()
            ->forDepartment($department)
            ->where('is_default', true);

        $policy = $query->first();

        if ($policy) {
            return $policy;
        }

        $codeBase = $department ? 'default-'.$department : 'default-global';
        $codeBase = $department ? 'default-' . $department : 'default-global';


        $code = $codeBase;
        $suffix = 1;

        while (static::query()->where('code', $code)->exists()) {
            $code = $codeBase . '-' . $suffix++;
        }

        return static::create([
            'name' => $department ? "سياسة التسعير ({$department})" : 'السياسة الافتراضية للتسعير',
            'code' => $code,
            'status' => self::STATUS_ACTIVE,
            'mode' => self::MODE_DISTANCE_ONLY,


            'is_default' => true,
            'currency' => strtoupper(config('app.currency', 'SAR')),
            'department' => $department,

            'min_order_total' => null,
            'max_order_total' => null,
            'notes' => null,

        ]);
    }
}