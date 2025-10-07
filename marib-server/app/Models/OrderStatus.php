<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class OrderStatus extends Model
{
    use HasFactory;

    /**
     * الحقول القابلة للتعبئة الجماعية
     *
     * @var array
     */
    protected $fillable = [
        'name',
        'code',
        'color',
        'icon',
        'description',
        'is_default',
        'is_active',
        'is_reserve',
        'sort_order',
    ];

    /**
     * الحقول التي يجب تحويلها
     *
     * @var array
     */
    protected $casts = [
        'is_default' => 'boolean',
        'is_active' => 'boolean',
        'is_reserve' => 'boolean',


    ];

    /**
     * نطاق الحالات النشطة
     *
     * @param $query
     * @return mixed
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    /**
     * نطاق الحالة الافتراضية
     *
     * @param $query
     * @return mixed
     */
    public function scopeDefault($query)
    {
        return $query->where('is_default', true);
    }

    /**
     * الحصول على الحالة الافتراضية
     *
     * @return mixed
     */
    public static function getDefault()
    {
        return self::default()->first();
    }
}
