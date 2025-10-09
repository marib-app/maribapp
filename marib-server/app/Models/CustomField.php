<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;
use Throwable;

class CustomField extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'type',
        'image',
        'required',
        'required_for_checkout',
        'is_customer_option',
        'status',
        'values',
        'allowed_values',
        'affects_stock',
        'min_length',
        'max_length',
        'notes',
        'sequence',
    ];

    protected $hidden = ['created_at', 'updated_at'];

    // إذا لا تحتاج "value" المشتق، احذف السطر التالي وكل الـ accessor الخاص به.
    protected $appends = ['value'];

    /**
     * نحافظ على أنواع مستقرة للتطبيق:
     * - values: سنعالجها يدوياً لتكون Array دائماً.
     * - required/status: أعداد صحيحة (0/1) حتى لا تقع أخطاء type 'bool' is not a subtype of type 'int'
     */
    protected $casts = [
        'required'    => 'integer',
        'status'      => 'integer',
        'sequence'    => 'integer',
        'min_length'  => 'integer',
        'max_length'  => 'integer',
        'required_for_checkout' => 'boolean',
        'affects_stock' => 'boolean',

        // اترك values بدون cast لأننا نضمن النوع في Accessor/Mutator
    ];

    /* -------------------- العلاقات -------------------- */

    public function custom_field_category()
    {
        return $this->hasMany(CustomFieldCategory::class, 'custom_field_id');
    }

    public function item_custom_field_values()
    {
        return $this->hasMany(ItemCustomFieldValue::class);
    }

    public function categories()
    {
        return $this->belongsToMany(
            Category::class,
            'custom_field_categories',
            'custom_field_id',
            'category_id'
        );
    }

    /* -------------------- Accessors/Mutators -------------------- */

    // URL عام للصورة
    public function getImageAttribute($image)
    {
        if (!empty($image)) {
            return url(Storage::url($image));
        }
        return $image;
    }

    /**
     * نعيد دائمًا Array:
     * - null/فارغ  -> []
     * - JSON مصفوفة -> نفس المصفوفة
     * - JSON قيمة مفردة/نص -> [القيمة]
     * - مصفوفة أصلاً -> كما هي مع إعادة فهرسة
     */
    public function getValuesAttribute($value)
    {
        // لو جاء من DB كسلسلة
        if (is_string($value)) {
            $trim = trim($value);
            if ($trim === '' || $trim === 'null') {
                return [];
            }
            try {
                $decoded = json_decode($trim, true, 512, JSON_THROW_ON_ERROR);
                if (is_array($decoded)) {
                    return array_values($decoded);
                }
                // قيمة مفردة في JSON
                return [$decoded];
            } catch (Throwable) {
                // ليس JSON: اعتبرها قيمة مفردة نصية
                return [$trim];
            }
        }

        // لو جاء مصفوفة بالفعل
        if (is_array($value)) {
            return array_values($value);
        }

        // أي شيء آخر (null، أعداد، ..) نحوله إلى []
        return [];
    }

    /**
     * نضمن حفظ values كـ JSON Array دائمًا.
     */
    public function setValuesAttribute($val): void
    {
        if ($val === null) {
            $this->attributes['values'] = json_encode([], JSON_UNESCAPED_UNICODE);
            return;
        }

        if (is_array($val)) {
            $val = array_values(array_filter($val, static fn($v) => $v !== '' && $v !== null));
            $this->attributes['values'] = json_encode($val, JSON_UNESCAPED_UNICODE);
            return;
        }

        if (is_string($val)) {
            $trim = trim($val);
            if ($trim === '') {
                $this->attributes['values'] = json_encode([], JSON_UNESCAPED_UNICODE);
                return;
            }
            try {
                $decoded = json_decode($trim, true, 512, JSON_THROW_ON_ERROR);
                $this->attributes['values'] = is_array($decoded)
                    ? json_encode(array_values($decoded), JSON_UNESCAPED_UNICODE)
                    : json_encode([$decoded], JSON_UNESCAPED_UNICODE);
                return;
            } catch (Throwable) {
                $this->attributes['values'] = json_encode([$trim], JSON_UNESCAPED_UNICODE);
                return;
            }
        }

        // أي نوع آخر: حوله لنص داخل Array
        $this->attributes['values'] = json_encode([strval($val)], JSON_UNESCAPED_UNICODE);
    }


    public function getAllowedValuesAttribute($value): array
    {
        if ($value === null) {
            return [];
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            if ($trimmed === '' || $trimmed === 'null') {
                return [];
            }

            try {
                $decoded = json_decode($trimmed, true, 512, JSON_THROW_ON_ERROR);
                if (is_array($decoded)) {
                    return array_values($decoded);
                }

                return [$decoded];
            } catch (Throwable) {
                return [$trimmed];
            }
        }

        if (is_array($value)) {
            return array_values($value);
        }

        return [];
    }

    public function setAllowedValuesAttribute($val): void
    {
        if ($val === null) {
            $this->attributes['allowed_values'] = null;
            return;
        }

        if (is_array($val)) {
            $normalized = array_values(array_filter($val, static fn ($v) => $v !== null && $v !== ''));
            $this->attributes['allowed_values'] = json_encode($normalized, JSON_UNESCAPED_UNICODE);
            return;
        }

        if (is_string($val)) {
            $trimmed = trim($val);

            if ($trimmed === '') {
                $this->attributes['allowed_values'] = null;
                return;
            }

            try {
                $decoded = json_decode($trimmed, true, 512, JSON_THROW_ON_ERROR);
                if (is_array($decoded)) {
                    $this->attributes['allowed_values'] = json_encode(array_values($decoded), JSON_UNESCAPED_UNICODE);
                    return;
                }
            } catch (Throwable) {
                // fall through and store raw string
            }

            $this->attributes['allowed_values'] = json_encode([$trimmed], JSON_UNESCAPED_UNICODE);
            return;
        }

        $this->attributes['allowed_values'] = json_encode([strval($val)], JSON_UNESCAPED_UNICODE);
    }

    // قيمة مشتقة لأوّل عنصر (لو واجهتك تعتمد عليه)
    public function getValueAttribute()
    {
        $vals = $this->values; // سيعود Array دائماً
        return isset($vals[0]) ? $vals[0] : null;
    }

    /* -------------------- Scopes -------------------- */

    public function scopeSearch($query, $search)
    {
        $search = "%" . $search . "%";
        return $query->where(function ($q) use ($search) {
            $q->orWhere('name', 'LIKE', $search)
              ->orWhere('type', 'LIKE', $search)
              ->orWhere('values', 'LIKE', $search)
              ->orWhere('status', 'LIKE', $search)
              ->orWhereHas('categories', function ($q) use ($search) {
                  $q->where('name', 'LIKE', $search);
              });
        });
    }

    public function scopeFilter($query, $filterObject)
    {
        if (!empty($filterObject)) {
            foreach ($filterObject as $column => $value) {
                if ($column == 'category_names') {
                    $query->whereHas('custom_field_category', function ($query) use ($value) {
                        $query->where('category_id', $value);
                    });
                } else {
                    $query->where((string)$column, (string)$value);
                }
            }
        }
        return $query;
    }
}
