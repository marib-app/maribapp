<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\URL;

class Slider extends Model
{
    use HasFactory;

    public const STATUS_ACTIVE = 'active';
    public const STATUS_PAUSED = 'paused';
    public const STATUS_INACTIVE = 'inactive';
    public const STATUS_DRAFT = 'draft';
    public const ACTION_OPEN_CHAT = 'open_chat';
    public const ACTION_APPLY_COUPON = 'apply_coupon';
    public const ACTION_OPEN_LINK = 'open_link';



    protected $fillable = [
        'image',
        'item_id',
        'third_party_link',
        'sequence',
        'name',
        'sold_out',
        'interface_type',
        'priority',
        'weight',
        'share_of_voice',
        'status',
        'starts_at',
        'ends_at',
        'dayparting_json',
        'per_user_per_day_limit',
        'per_user_per_session_limit',
        'target_type',
        'target_id',
        'action_type',
        'action_payload',

    ];

    protected $casts = [
        'priority'                   => 'integer',
        'weight'                     => 'integer',
        'share_of_voice'             => 'float',
        'starts_at'                  => 'datetime',
        'ends_at'                    => 'datetime',
        'dayparting_json'            => 'array',
        'per_user_per_day_limit'     => 'integer',
        'per_user_per_session_limit' => 'integer',
        'target_id'                  => 'integer',
        'action_payload'             => 'array',

    ];

    protected $attributes = [
        'priority'       => 0,
        'weight'         => 1,
        'share_of_voice' => 0,
        'status'         => self::STATUS_ACTIVE,
    ];


    public static function targetTypeMap(): array
    {
        return [
            'item'     => Item::class,
            'category' => Category::class,
            'blog'     => Blog::class,
            'user'     => User::class,
            'service'  => Service::class,
        ];
    }

    public static function availableTargetTypes(): array
    {
        return array_keys(self::targetTypeMap());
    }

    public static function availableActionTypes(): array
    {
        return [
            self::ACTION_OPEN_CHAT,
            self::ACTION_APPLY_COUPON,
            self::ACTION_OPEN_LINK,
        ];
    }


    public static function availableStatuses(): array
    {
        return [
            self::STATUS_ACTIVE,
            self::STATUS_PAUSED,
            self::STATUS_INACTIVE,
            self::STATUS_DRAFT,
        ];
    }

    public function item()
    {
        return $this->belongsTo(Item::class);
    }

    public function getImageAttribute($image)
    {
        if (empty($image)) {
            return $image;
        }

        $storageUrl = Storage::url($image);

        if (Str::startsWith($storageUrl, ['http://', 'https://'])) {
            return $storageUrl;
        }

        $normalizedPath = '/' . ltrim($storageUrl, '/');

        if (! app()->runningInConsole()) {
            $request = request();

            if ($request && $request->getHost()) {
                return rtrim($request->getSchemeAndHttpHost(), '/') . $normalizedPath;
            }
        }

        return URL::to($normalizedPath);
    }

    public function scopeSearch($query, $search)
    {
        $search = "%" . $search . "%";
        $query = $query->where(function ($q) use ($search) {
            $q->orWhere('sequence', 'LIKE', $search)
                ->orWhere('model_type', 'LIKE', $search)
                ->orWhere('third_party_link', 'LIKE', $search)
                ->orWhere('model_id', 'LIKE', $search)
                ->orWhereHas('model', function ($q) use ($search) {
                    $q->where('name', 'LIKE', $search);
                });
        });

        return $query;
    }

    public function scopeSort($query, $column, $order)
    {
        if ($column == "item_name") {
            $query = $query->leftjoin('items', 'items.id', '=', 'sliders.item_id')->orderBy('items.name', $order);
        } else {
            $query = $query->orderBy($column, $order);
        }

        return $query->select('sliders.*');
    }

    public function scopeStatus(Builder $query, string|array $status): Builder
    {
        return is_array($status)
            ? $query->whereIn('status', $status)
            : $query->where('status', $status);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->status(self::STATUS_ACTIVE);
    }

    public function scopeEligibleAt(Builder $query, ?Carbon $moment = null): Builder
    {
        $moment ??= Carbon::now();

        return $query->active()
            ->where(function (Builder $builder) use ($moment) {
                $builder->whereNull('starts_at')
                    ->orWhere('starts_at', '<=', $moment);
            })
            ->where(function (Builder $builder) use ($moment) {
                $builder->whereNull('ends_at')
                    ->orWhere('ends_at', '>=', $moment);
            });
    }

    public function scopeOrderByPriority(Builder $query): Builder
    {
        return $query->orderByDesc('priority')->orderBy('id');
    }

    public function categories()
    {
        return $this->hasOne(Category::class);
    }

    public function model(): MorphTo
    {
        return $this->morphTo();
    }


    public function metrics(): HasMany
    {
        return $this->hasMany(SliderMetric::class);
    }

    public function target(): MorphTo
    {
        return $this->morphTo(__FUNCTION__, 'target_type', 'target_id');
    }

    public function targetSummary(): ?array
    {
        if ($this->action_type) {
            return [
                'type'    => $this->action_type,
                'label'   => $this->actionLabel(),
                'payload' => $this->action_payload ?? null,
            ];
        }

        $target = $this->resolvedTarget();

        if (! $target instanceof EloquentModel) {
            return null;
        }

        return [
            'type'   => $this->normalizeTargetAlias($target::class),
            'class'  => $target::class,
            'id'     => $target->getKey(),
            'label'  => $this->extractTargetLabel($target),
        ];
    }

    public function destinationTypeLabel(): string
    {
        $kind = $this->destinationKind();

        return __(Str::headline(str_replace('-', ' ', $kind)));
    }

    public function destinationKind(): string
    {
        if ($this->action_type) {
            return $this->action_type;
        }

        $target = $this->resolvedTarget();

        if ($target instanceof EloquentModel) {
            return $this->normalizeTargetAlias($target::class) ?? 'model';
        }

        if (! empty($this->third_party_link)) {
            return 'external_link';
        }

        return 'none';
    }

    public function destinationLabel(): ?string
    {
        if ($this->action_type) {
            return $this->actionLabel();
        }

        $target = $this->resolvedTarget();

        if ($target instanceof EloquentModel) {
            return $this->extractTargetLabel($target);
        }

        if (! empty($this->third_party_link)) {
            return $this->third_party_link;
        }

        return null;
    }

    public function destinationUrl(): ?string
    {
        if ($this->action_type === self::ACTION_OPEN_LINK) {
            return Arr::get($this->action_payload ?? [], 'url') ?? $this->third_party_link ?? null;
        }

        return $this->third_party_link ?? null;
    }

    public function isEligible(?Carbon $moment = null): bool
    {
        $moment ??= Carbon::now();

        if ($this->status !== self::STATUS_ACTIVE) {
            return false;
        }

        if ($this->starts_at instanceof Carbon && $moment->lt($this->starts_at)) {
            return false;
        }

        if ($this->ends_at instanceof Carbon && $moment->gt($this->ends_at)) {
            return false;
        }

        return $this->isWithinDaypart($moment);
    }

    public function isWithinDaypart(Carbon $moment): bool
    {
        $schedule = $this->normalizedDayparting();

        if (empty($schedule)) {
            return true;
        }

        $dayKey = strtolower($moment->format('l'));

        $slots = $schedule[$dayKey] ?? $schedule['all'] ?? [];

        if (empty($slots)) {
            return false;
        }

        foreach ($slots as $slot) {
            $start = $this->makeTimeForDay($moment, Arr::get($slot, 'start') ?? Arr::get($slot, 'from'));
            $end = $this->makeTimeForDay($moment, Arr::get($slot, 'end') ?? Arr::get($slot, 'to'));

            if (! $start || ! $end) {
                continue;
            }

            if ($end->lessThan($start)) {
                $end->addDay();
            }

            if ($moment->betweenIncluded($start, $end)) {
                return true;
            }
        }

        return false;
    }

    protected function normalizedDayparting(): array
    {
        $raw = $this->dayparting_json;

        if (empty($raw)) {
            return [];
        }

        if (is_string($raw)) {
            $decoded = json_decode($raw, true);
            $raw = is_array($decoded) ? $decoded : [];
        }

        if (! is_array($raw)) {
            return [];
        }

        $normalized = [];

        foreach ($raw as $day => $entries) {
            $dayKey = strtolower((string) $day);
            $entries = is_array($entries) ? $entries : [];

            $normalized[$dayKey] = collect($entries)
                ->map(function ($entry) {
                    if (! is_array($entry)) {
                        return null;
                    }

                    $start = Arr::get($entry, 'start') ?? Arr::get($entry, 'from');
                    $end = Arr::get($entry, 'end') ?? Arr::get($entry, 'to');

                    if (! $start || ! $end) {
                        return null;
                    }

                    return [
                        'start' => $start,
                        'end'   => $end,
                    ];
                })
                ->filter()
                ->values()
                ->all();
        }

        return array_filter($normalized);
    }


    protected function resolvedTarget(): ?EloquentModel
    {
        $target = $this->getRelationValue('target');

        if ($target instanceof EloquentModel) {
            return $target;
        }

        if ($this->target_type && $this->target_id) {
            return $this->target;
        }

        $legacy = $this->getRelationValue('model');

        if ($legacy instanceof EloquentModel) {
            return $legacy;
        }

        if ($this->model_type && $this->model_id) {
            return $this->model;
        }

        return null;
    }

    protected function normalizeTargetAlias(?string $class): ?string
    {
        if (! $class) {
            return null;
        }

        $map = array_flip(self::targetTypeMap());

        return $map[$class] ?? $class;
    }

    protected function extractTargetLabel(?EloquentModel $model): ?string
    {
        if (! $model) {
            return null;
        }

        foreach (['name', 'title', 'full_name', 'username'] as $attribute) {
            if (isset($model->{$attribute}) && $model->{$attribute} !== '') {
                return (string) $model->{$attribute};
            }
        }

        if (method_exists($model, '__toString')) {
            return (string) $model;
        }

        return null;
    }

    protected function actionLabel(): ?string
    {
        return match ($this->action_type) {
            self::ACTION_OPEN_CHAT   => __('فتح دردشة'),
            self::ACTION_APPLY_COUPON => $this->buildCouponLabel(),
            self::ACTION_OPEN_LINK   => Arr::get($this->action_payload ?? [], 'title')
                ?? Arr::get($this->action_payload ?? [], 'url'),
            default                  => null,
        };
    }

    protected function buildCouponLabel(): ?string
    {
        $code = Arr::get($this->action_payload ?? [], 'code');
        $label = Arr::get($this->action_payload ?? [], 'label');

        if ($label) {
            return $label;
        }

        if ($code) {
            return __('كوبون :code', ['code' => $code]);
        }

        return null;
    }


    protected function makeTimeForDay(Carbon $day, ?string $time): ?Carbon
    {
        if (! $time) {
            return null;
        }

        try {
            $timeInstance = Carbon::parse($time, $day->getTimezone());
        } catch (\Throwable) {
            return null;
        }

        return $timeInstance->setDate($day->year, $day->month, $day->day);
    }
}
