<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    use HasFactory;

    /**
     * الحقول القابلة للتعبئة الجماعية
     *
     * @var array
     */
    protected $fillable = [
        'order_id',
        'item_id',
        'variant_id',
        'attributes',
        'weight_kg',
        'item_name',
        'price',
        'quantity',
        'subtotal',
        'options',
        'item_snapshot',
        'pricing_snapshot',
        'weight_grams',

        'deposit_minimum_amount',
        'deposit_ratio',
        'deposit_amount_paid',
        'deposit_remaining_balance',
        'deposit_includes_shipping',






    ];

    /**
     * الحقول التي يجب تحويلها
     *
     * @var array
     */
    protected $casts = [
        'variant_id' => 'integer',
        'options' => 'array',
        'attributes' => 'array',
        'item_snapshot' => 'array',
        'pricing_snapshot' => 'array',
        'weight_grams' => 'float',
        'weight_kg' => 'float',
        'deposit_minimum_amount' => 'float',
        'deposit_ratio' => 'float',
        'deposit_amount_paid' => 'float',
        'deposit_remaining_balance' => 'float',
        'deposit_includes_shipping' => 'bool',
    ];

    /**
     * علاقة مع الطلب
     *
     * @return BelongsTo
     */
    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    /**
     * علاقة مع العنصر
     *
     * @return BelongsTo
     */
    public function item(): BelongsTo
    {
        return $this->belongsTo(Item::class);
    }
}
