<?php

namespace App\Models;
use App\Models\AdminNotification;
use App\Models\Concerns\NotifiesAdminOnApprovalStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Database\Eloquent\Relations\HasMany;
use function __;
use function url;

class Item extends Model {
    use HasFactory, SoftDeletes;
    use NotifiesAdminOnApprovalStatus;

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
        'image',
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
        'review_link'   
    ];

    // Relationships
    public function user() {
        return $this->belongsTo(User::class);
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
