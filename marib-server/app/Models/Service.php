<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Support\Str;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;




/**
 * نموذج الخدمة (لوحة الإدارة + التطبيق)
 *
 * الحقول الرئيسية:
 * - category_id, title, description, image, icon, status, is_main, service_type, tags, views, expiry_date
 *
 * تحكم تدفّق زر "متابعة" في التطبيق:
 * - is_paid / price / currency / price_note
 * - has_custom_fields
 * - direct_to_user / direct_user_id
 * - service_uid (مُعرّف ثابت يولَّد تلقائيًا)
 *
 * تعريفات إضافية:
 * - service_fields_schema (ARRAY عبر cast) لتعريف حقول مخصّصة على مستوى الخدمة
 *
 * ربط الحقول المخصّصة:
 * - many-to-many عبر Pivot: services_custom_fields (أعمدة pivot: is_required, sequence)
 *  * - hasMany serviceCustomFields (حقول مصممة لكل خدمة على حدة)

 */
class Service extends Model
{
    /* ----------------------------------------------------------------------
     | Mass-Assignable Attributes
     |-----------------------------------------------------------------------*/
    protected $fillable = [
        // أساسية
        'category_id',
        'owner_id',


        'title',
        'slug',
        'description',
        'image',
        'icon',
        'status',
        'is_main',
        'service_type',
        'tags',
        'views',
        'expiry_date',

        // مخطط الحقول المخصّصة على مستوى الخدمة (JSON)
        'service_fields_schema',

        // تحكّم بالتدفّق (الدفع)
        'is_paid',
        'price',
        'currency',
        'price_note',

        // تحكّم بالتدفّق (حقول مخصّصة/توجيه)
        'has_custom_fields',
        'direct_to_user',
        'direct_user_id',

        // مُعرّف ثابت للاستخدامات المختلفة
        'service_uid',
    ];

    /* ----------------------------------------------------------------------
     | Attribute Casting
     |-----------------------------------------------------------------------*/
    protected $casts = [
        'owner_id'              => 'integer',
        'status'                => 'boolean',
        'is_main'               => 'boolean',
        'is_paid'               => 'boolean',
        'has_custom_fields'     => 'boolean',
        'direct_to_user'        => 'boolean',

        'views'                 => 'integer',
        'tags'                  => 'array',
        'service_fields_schema' => 'array',   // سنطبعها أكثر في الـ accessor أدناه

        // سعر بدقتين عشريتين
        'price'                 => 'decimal:2',

        // إن أردت تحويلها لتاريخ/وقت فعّل السطر التالي:
        // 'expiry_date'        => 'datetime',
    ];

    /* ----------------------------------------------------------------------
     | Model Hooks
     |  - توليد service_uid تلقائيًا عند الإنشاء.
     |  - تطبيع التبعيات قبل الحفظ (is_paid/direct_to_user/has_custom_fields/...)
     |-----------------------------------------------------------------------*/
    protected static function booted(): void
    {
        static::creating(function (self $model): void {
            if (empty($model->service_uid)) {
                $model->service_uid = (string) Str::ulid();
            }
        });

        static::saving(function (self $model): void {
            // إذا الخدمة ليست مدفوعة → أفرغ السعر والعملة
            if (!$model->is_paid) {
                $model->price    = null;
                $model->currency = null;
            } else {
                // عملة موحّدة بصيغة كبيرة
                if (!empty($model->currency)) {
                    $model->currency = strtoupper((string) $model->currency);
                }
            }

            // إذا لا يوجد توجيه مباشر → أفرغ المعرف
            if (!$model->direct_to_user) {
                $model->direct_user_id = null;
            }

            // حدّث has_custom_fields تلقائيًا حسب وجود سكيمة فعلية
            $schema    = $model->service_fields_schema; // عبر الـ accessor (مصفوفة مضمونة)
            $hasSchema = is_array($schema) && count($schema) > 0;

            $hasFallbackFields = false;

            if (!$hasSchema) {
                if ($model->relationLoaded('serviceCustomFields')) {
                    $hasFallbackFields = $model->serviceCustomFields->isNotEmpty();
                } else {
                    if ($model->relationLoaded('__serviceCustomFieldsExists')) {
                        $hasFallbackFields = (bool) $model->getRelationValue('__serviceCustomFieldsExists');
                    } else {
                        $hasFallbackFields = $model->serviceCustomFields()->exists();
                        // Fallback requirement: keep has_custom_fields true when only the relationship data exists.
                        $model->setRelation('__serviceCustomFieldsExists', $hasFallbackFields);
                    }
                }
            }

            $model->has_custom_fields = $hasSchema || $hasFallbackFields;

            // نظافة طفيفة
            if (is_string($model->price_note)) {
                $model->price_note = trim($model->price_note);
            }
        });
    }

    /* ----------------------------------------------------------------------
     | Accessors / Mutators
     |-----------------------------------------------------------------------*/

    /**
     * نعيد دومًا مصفوفة سكيمة موحّدة:
     * - نفك أي ترميز JSON مضاعف (لو القيمة كانت سلسلة JSON داخل JSON).
     * - نوحّد أسماء الأنواع للسبعة المعتمدة: number, textbox, fileinput, radio, dropdown, checkbox, color
     * - نحافظ على الحقول المألوفة: title/label/name, required, note, values/colors, min/max, min_length/max_length, sequence
     */
    public function getServiceFieldsSchemaAttribute($value): array
    {

        if ($this->relationLoaded('serviceCustomFields')) {
            return $this->serviceCustomFields
                ->map(fn(ServiceCustomField $field) => $field->toSchemaPayload())
                ->values()
                ->all();

            $fields = $this->serviceCustomFields;

            if ($fields->isNotEmpty()) {
                return $fields
                    ->map(fn(ServiceCustomField $field) => $field->toSchemaPayload())
                    ->values()
                    ->all();
            }

        }
        




        $decode = function ($v) {
            if (is_array($v)) return $v;
            if (is_string($v) && $v !== '') {
                $d = json_decode($v, true);
                if (json_last_error() === JSON_ERROR_NONE) {
                    return $d;
                }
            }
            return [];
        };

        $raw = $decode($value);


        if ($raw === [] && $this->exists) {
            $fields = $this->serviceCustomFields()->orderBy('sequence')->get();
            if ($fields->isNotEmpty()) {
                return $fields
                    ->map(fn(ServiceCustomField $field) => $field->toSchemaPayload())
                    ->values()
                    ->all();
            }
        }


        // لو كان الناتج سلسلة JSON داخلية (حالة ترميز مضاعف قديم)
        if (is_string($raw) && $raw !== '') {
            $tmp = json_decode($raw, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($tmp)) {
                $raw = $tmp;
            } else {
                $raw = [];
            }
        }

        if (!is_array($raw)) return [];

        $normType = function ($t) {
            $t = strtolower((string) $t);
            if ($t === 'select') return 'dropdown';
            if ($t === 'file' || $t === 'image') return 'fileinput';
            if ($t === 'textarea') return 'textbox';
            $allowed = ['number','textbox','fileinput','radio','dropdown','checkbox','color'];
            return in_array($t, $allowed, true) ? $t : 'textbox';
        };

        $out = [];
        $seq = 1;
        foreach ($raw as $r) {
            if (!is_array($r)) continue;

            $type = $normType($r['type'] ?? $r['field_type'] ?? $r['input_type'] ?? 'textbox');
            $title = trim((string) ($r['title'] ?? $r['label'] ?? $r['name'] ?? ''));

            $row = [
                'title'     => $title,
                'type'      => $type,
                'required'  => (bool) ($r['required'] ?? false),
                'note'      => isset($r['note']) ? trim((string) $r['note']) : '',
                'sequence'  => (int) ($r['sequence'] ?? $seq),
            ];

            // قيم الاختيارات/الألوان
            $vals = $r['values'] ?? $r['options'] ?? $r['choices'] ?? [];
            if (!is_array($vals)) $vals = [];
            if (in_array($type, ['radio','dropdown','checkbox','color'], true)) {
                $vals = array_values(array_filter(array_map('strval', $vals)));
                $row['values'] = $vals;
            }

            // قيود الطول/المدى
            if ($type === 'number') {
                if (isset($r['min'])) $row['min'] = (float) $r['min'];
                if (isset($r['max'])) $row['max'] = (float) $r['max'];
            } elseif ($type === 'textbox') {
                if (isset($r['min_length'])) $row['min_length'] = (int) $r['min_length'];
                if (isset($r['max_length'])) $row['max_length'] = (int) $r['max_length'];
            }

            $out[] = $row;
            $seq++;
        }

        usort($out, fn($a, $b) => ($a['sequence'] ?? 0) <=> ($b['sequence'] ?? 0));

        return $out;
    }

    /**
     * نتقبّل array أو string ونحفظ نسخة موحّدة قابلة للتسلسل JSON.
     */
    public function setServiceFieldsSchemaAttribute($value): void
    {
        $decode = function ($v) {
            if (is_array($v)) return $v;
            if (is_string($v) && $v !== '') {
                $d = json_decode($v, true);
                if (json_last_error() === JSON_ERROR_NONE) {
                    return $d;
                }
            }
            return [];
        };

        $arr = $decode($value);

        // لو كان ترميزًا مضاعفًا (سلسلة JSON داخل Array)
        if (is_string($arr) && $arr !== '') {
            $tmp = json_decode($arr, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($tmp)) {
                $arr = $tmp;
            } else {
                $arr = [];
            }
        }

        // إعادة فهرسة وتنضيف بسيطة
        $arr = array_values(array_filter($arr, fn($r) => is_array($r)));

        $this->attributes['service_fields_schema'] = json_encode($arr, JSON_UNESCAPED_UNICODE);
    }

    /* ----------------------------------------------------------------------
     | Relationships
     |-----------------------------------------------------------------------*/

    /** الفئة المرتبطة بالخدمة */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    /** المعلن المستهدف للدردشة المباشرة (اختياري) */
    public function directUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'direct_user_id');
    }


    /** مالك الخدمة (عميل) */
    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }




    /**
     * الحقول المخصّصة المرتبطة بالخدمة عبر Pivot
     * Pivot Table: services_custom_fields
     * Pivot Columns: is_required, sequence
     */
    public function customFields(): BelongsToMany
    {
        return $this->belongsToMany(CustomField::class, 'services_custom_fields')
            ->withPivot(['is_required', 'sequence'])
            ->orderBy('services_custom_fields.sequence');
    }




    /**
     * تعريفات الحقول المخصّصة الخاصة بهذه الخدمة.
     */
    public function serviceCustomFields(): HasMany
    {
        return $this->hasMany(ServiceCustomField::class)->orderBy('sequence');
    }


    public function serviceCustomFieldValues(): HasMany
    {
        return $this->hasMany(ServiceCustomFieldValue::class);
    }



    /** جميع مراجعات الخدمة */
    public function reviews(): HasMany
    {
        return $this->hasMany(ServiceReview::class);
    }




    /** جميع الطلبات المرتبطة بالخدمة */
    public function requests(): HasMany
    {
        return $this->hasMany(ServiceRequest::class);
    }

    /** آخر طلب مرتبط بالخدمة */
    public function latestRequest(): HasOne
    {
        return $this->hasOne(ServiceRequest::class)->latestOfMany();
    }





}
