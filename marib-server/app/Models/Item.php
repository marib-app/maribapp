<?php

namespace App\Models;
use App\Models\AdminNotification;
use App\Models\Concerns\NotifiesAdminOnApprovalStatus;
use App\Models\StoreFollower;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\ItemStock;
use App\Models\ItemAttribute;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use function __;
use function url;

class Item extends Model {
    use HasFactory, SoftDeletes;
    use NotifiesAdminOnApprovalStatus;

    protected static function booted(): void
    {
        static::created(function (Item $item): void {
            if ($item->status === 'approved') {
                $item->notifyStoreFollowers();
            }
        });

        static::updated(function (Item $item): void {
            if ($item->wasChanged('status') && $item->status === 'approved') {
                $item->notifyStoreFollowers();
            }
        });
    }

    protected $fillable = [
        'category_id',
        'name',
        'price',
        'description',
        'latitude',
        'longitude',
        'address',
        'contact',
        'show_only_to_premium',
        'video_link',
        'status',
        'rejected_reason',
        'user_id',
        'store_id',
        'image',
        'thumbnail_url',
        'detail_image_url',
        'country',
        'state',
        'city',
        'area_id',
        'all_category_ids',
        'slug',
        'sold_to',
        'expiry_date',
        'currency',

        'interface_type',
        'product_link',
        'review_link',

        'discount_type',
        'discount_value',
        'discount_start',
        'discount_end',
        'delivery_size',
    ];

    protected $casts = [
        'discount_value' => 'float',
        'discount_start' => 'datetime',
        'discount_end' => 'datetime',    
        'delivery_size' => 'string',


    ];

    // Relationships
    public function user() {
        return $this->belongsTo(User::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function category()
    {
        return $this->hasOne(Category::class, 'id', 'category_id');
    }

    public function gallery_images() {
        return $this->hasMany(ItemImages::class);
    }

    public function custom_fields() {
        return $this->hasManyThrough(
            CustomField::class, CustomFieldCategory::class,
            'category_id', 'id', 'category_id', 'custom_field_id'
        );
    }

    public function item_custom_field_values() {
        return $this->hasMany(ItemCustomFieldValue::class);
    }

    public function featured_items() {
        return $this->hasMany(FeaturedItems::class)->onlyActive();
    }

    public function favourites() {
        return $this->hasMany(Favourite::class);
    }

    public function item_offers() {
        return $this->hasMany(ItemOffer::class);
    }
    
    public function cartItems(): HasMany
    {
        return $this->hasMany(CartItem::class);
    }
    public function stocks(): HasMany
    {
        return $this->hasMany(ItemStock::class);
    }

    public function purchaseAttributes(): HasMany
    {
        return $this->hasMany(ItemAttribute::class)->orderBy('position')->orderBy('id');
    }

    public function user_reports() {
        return $this->hasMany(UserReports::class);
    }

    public function sliders(): MorphMany {
        return $this->morphMany(Slider::class, 'model');
    }

    public function area() {
        return $this->belongsTo(Area::class);
    }

    public function review() {
        return $this->hasMany(SellerRating::class);
    }


    protected function getAdminNotificationType(): string
    {
        return AdminNotification::TYPE_ITEM_REVIEW;
    }

    protected function getAdminNotificationTitle(): string
    {
        $owner = $this->user?->name ?? __('User #:id', ['id' => $this->user_id]);

        return __('Item #:id (:name) requires review for :owner', [
            'id'    => $this->getKey(),
            'name'  => $this->name,
            'owner' => $owner,
        ]);
    }

    protected function getAdminNotificationLink(): ?string
    {
        return url(sprintf('/items/%d/edit', $this->getKey()));
    }

    protected function getAdminNotificationMeta(): array
    {
        return [
            'user_id' => $this->user_id,
            'status'  => $this->getRawOriginal('status'),
            'price'   => $this->price,
        ];
    }

    protected function getAdminNotificationPendingStatus(): string
    {
        return 'review';
    }

    protected function getAdminNotificationResolvedStatuses(): array
    {
        return ['approved', 'rejected'];
    }


    // Accessors
    public function getImageAttribute($image) {
        return !empty($image) ? url(Storage::url($image)) : $image;
    }


    public function getThumbnailUrlAttribute($image)
    {
        return !empty($image) ? url(Storage::url($image)) : null;
    }

    public function getDetailImageUrlAttribute($image)
    {
        return !empty($image) ? url(Storage::url($image)) : null;
    }



    public function getStatusAttribute($value)
    {
    if ($this->deleted_at) {
        return "inactive";
    }
    if ($this->expiry_date && $this->expiry_date < Carbon::now()) {
        return "expired";
    }
    return $value;
    }

    // Scopes
    public function scopeSearch($query, $search) {
        $search = "%" . $search . "%";
        return $query->where(function ($q) use ($search) {
            $q->orWhere('name', 'LIKE', $search)
                ->orWhere('description', 'LIKE', $search)
                ->orWhere('price', 'LIKE', $search)
                ->orWhere('image', 'LIKE', $search)
                ->orWhere('latitude', 'LIKE', $search)
                ->orWhere('longitude', 'LIKE', $search)
                ->orWhere('address', 'LIKE', $search)
                ->orWhere('contact', 'LIKE', $search)
                ->orWhere('show_only_to_premium', 'LIKE', $search)
                ->orWhere('status', 'LIKE', $search)
                ->orWhere('video_link', 'LIKE', $search)
                ->orWhere('clicks', 'LIKE', $search)
                ->orWhere('user_id', 'LIKE', $search)
                ->orWhere('country', 'LIKE', $search)
                ->orWhere('state', 'LIKE', $search)
                ->orWhere('city', 'LIKE', $search)
                ->orWhere('category_id', 'LIKE', $search)
                ->orWhereHas('category', function ($q) use ($search) {
                    $q->where('name', 'LIKE', $search);
                })->orWhereHas('user', function ($q) use ($search) {
                    $q->where('name', 'LIKE', $search);
                });
        });
    }

    public function scopeOwner($query) {
        if (Auth::user()->hasRole('User')) {
            return $query->where('user_id', Auth::user()->id);
        }
        return $query;
    }

    public function hasActiveDiscount(?Carbon $now = null): bool
    {
        if (! $this->discount_type || $this->discount_value === null) {
            return false;
        }

        $now ??= Carbon::now();

        if ($this->discount_start instanceof Carbon && $now->lt($this->discount_start)) {
            return false;
        }

        if ($this->discount_end instanceof Carbon && $now->gt($this->discount_end)) {
            return false;
        }

        return true;
    }

    public function calculateDiscountedPrice(?Carbon $now = null): float
    {
        $basePrice = (float) ($this->price ?? 0.0);

        if (! $this->hasActiveDiscount($now)) {
            return round($basePrice, 2);
        }

        $value = (float) $this->discount_value;
        $type = strtolower((string) $this->discount_type);

        $discountAmount = match ($type) {
            'percentage', 'percent' => $basePrice * ($value / 100),
            'fixed', 'amount', 'flat' => $value,
            default => $value,
        };

        $final = max(0.0, $basePrice - $discountAmount);

        return round($final, 2);
    }

    public function getFinalPriceAttribute(): float
    {
        return $this->calculateDiscountedPrice();
    }

    public function getDiscountSnapshotAttribute(): ?array
    {
        if ($this->discount_type === null && $this->discount_value === null) {
            return null;
        }

        return [
            'type' => $this->discount_type,
            'value' => $this->discount_value !== null ? (float) $this->discount_value : null,
            'start' => $this->discount_start?->toIso8601String(),
            'end' => $this->discount_end?->toIso8601String(),
            'is_active' => $this->hasActiveDiscount(),
        ];
    }

    private function notifyStoreFollowers(): void
    {
        if ($this->store_id === null) {
            return;
        }

        $store = $this->store()->first();
        if ($store === null) {
            return;
        }

        $followerIds = StoreFollower::query()
            ->where('store_id', $store->getKey())
            ->pluck('user_id')
            ->filter()
            ->values()
            ->all();

        if ($followerIds === []) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->whereIn('user_id', $followerIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = __('متجر :store أضاف منتجاً جديداً', ['store' => $store->name]);
        $body = $this->name;

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_new_item',
            [
                'store_id' => $store->getKey(),
                'item_id' => $this->getKey(),
                'store_name' => $store->name,
                'item_name' => $this->name,
            ]
        );
    }
    
    public function scopeApproved($query) {
        return $query->where('status', 'approved');
    }

    public function scopeNotOwner($query) {
        return $query->where('user_id', '!=', Auth::user()->id);
    }

    public function scopeSort($query, $column, $order) {
        if ($column == "user_name") {
            return $query->leftJoin('users', 'users.id', '=', 'items.user_id')
                ->orderBy('users.name', $order)
                ->select('items.*');
        }
        return $query->orderBy($column, $order);
    }

    public function scopeFilter($query, $filterObject) {
        if (empty($filterObject)) {
            return $query;
        }

        if ($filterObject instanceof \Traversable) {
            $filterObject = iterator_to_array($filterObject);
        } elseif (is_object($filterObject)) {
            $filterObject = get_object_vars($filterObject);
        }

        if (!is_array($filterObject)) {
            return $query;
        }

        foreach ($filterObject as $column => $value) {
            if (self::isEmptyFilterValue($value)) {
                continue;


            }

            $query->where((string) $column, $value);

        }
        return $query;
    }


    private static function isEmptyFilterValue($value): bool
    {
        if ($value === null) {
            return true;
        }

        if (is_string($value)) {
            $normalized = strtolower(trim($value));

            if ($normalized === '' || $normalized === 'undefined' || $normalized === 'null') {
                return true;
            }
        }

        if (is_array($value)) {
            return empty($value);
        }

        return false;
    }

    public function scopeOnlyNonBlockedUsers($query) {
        $blocked_user_ids = BlockUser::where('user_id', Auth::user()->id)
            ->pluck('blocked_user_id');
        return $query->whereNotIn('user_id', $blocked_user_ids);
    }
    public function scopeGetNonExpiredItems($query) {
        return $query->where(function($query) {
            $query->where('expiry_date', '>', Carbon::now())->orWhereNull('expiry_date');
        });
    }

}
