<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Throwable;

class ManualBank extends Model
{
    use HasFactory;

    private static ?string $defaultDisplayNameCache = null;
    /**
     * @var array<string, bool>
     */
    private static array $columnSupportCache = [];


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
     * Determine if the manual banks table includes the given column.
     */
    public static function supportsColumn(string $column): bool
    {
        if (array_key_exists($column, self::$columnSupportCache)) {
            return self::$columnSupportCache[$column];
        }

        try {
            $instance = new self();
            $table = $instance->getTable();

            if (! Schema::hasTable($table)) {
                return self::$columnSupportCache[$column] = false;
            }

            return self::$columnSupportCache[$column] = Schema::hasColumn($table, $column);
        } catch (Throwable) {
            return self::$columnSupportCache[$column] = false;
        }
    }

    /**
     * Columns that can be safely selected when eager loading the manual bank relation.
     *
     * @return array<int, string>
     */
    public static function relationSelectColumns(): array
    {
        $columns = ['id'];

        foreach (['name', 'bank_name', 'beneficiary_name'] as $column) {
            if (self::supportsColumn($column)) {
                $columns[] = $column;
            }
        }

        return $columns;
    }

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


    public static function defaultDisplayName(): string
    {
        if (self::$defaultDisplayNameCache !== null) {
            return self::$defaultDisplayNameCache;
        }

        $configuredName = config('payments.default_manual_bank_name');

        if (is_string($configuredName)) {
            $trimmed = trim($configuredName);

            if ($trimmed !== '') {
                return self::$defaultDisplayNameCache = $trimmed;
            }
        }

        $configuredId = config('payments.default_manual_bank_id');
        $bank = null;

        if ($configuredId !== null && $configuredId !== '') {
            $normalizedId = is_numeric($configuredId) ? (int) $configuredId : null;

            if ($normalizedId && $normalizedId > 0) {
                try {
                    $bank = self::query()->find($normalizedId);
                } catch (Throwable) {
                    $bank = null;
                }
            }
        }

        if ($bank === null) {
            try {
                $instance = new self();
                $table = $instance->getTable();

                if (! Schema::hasTable($table)) {
                    return self::$defaultDisplayNameCache = trans('Bank Transfer');
                }

                $query = self::query();

                if (Schema::hasColumn($table, 'status')) {
                    $query->where('status', true);
                } elseif (Schema::hasColumn($table, 'is_active')) {
                    $query->where('is_active', true);
                }

                if (Schema::hasColumn($table, 'display_order')) {
                    $query->orderBy('display_order');
                }

                $bank = $query->orderBy('name')->orderBy('id')->first();
            } catch (Throwable) {
                $bank = null;
            }
        }

        $name = $bank && is_string($bank->name) ? trim($bank->name) : '';

        if ($name !== '') {
            return self::$defaultDisplayNameCache = $name;
        }

        return self::$defaultDisplayNameCache = trans('Bank Transfer');
    }

}
