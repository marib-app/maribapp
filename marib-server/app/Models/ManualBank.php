<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

class ManualBank extends Model
{
    use HasFactory;

    // ✅ نستخدم fillable لآمان أعلى
    protected $fillable = [
        'name',
        'logo_path',
        'beneficiary_name',
        'note',
        'display_order',
        'status',
    ];

    protected $casts = [
        'status' => 'boolean',
        'display_order' => 'integer',
    ];

    // لعرض رابط شعار البنك مباشرة
    protected $appends = ['logo_url'];

    /**
     * علاقة: طلبات التحويل اليدوي المرتبطة بهذا البنك
     */
    public function manualPaymentRequests(): HasMany
    {
        return $this->hasMany(ManualPaymentRequest::class);
    }

    /**
     * Scope ديناميكي لإرجاع البنوك المفعّلة
     * يتحقق من وجود عمود status أو is_active
     */
    public function scopeActive($query)
    {
        $table = $this->getTable();

        if (Schema::hasColumn($table, 'status')) {
            return $query->where('status', true);
        }

        if (Schema::hasColumn($table, 'is_active')) {
            return $query->where('is_active', true);
        }

        return $query;
    }

    /**
     * Accessor: logo_url
     */
    public function getLogoUrlAttribute(): ?string
    {
        if (empty($this->logo_path)) {
            return null;
        }

        return url(Storage::url($this->logo_path));
    }
}
