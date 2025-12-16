<?php

namespace App\Models;

use App\Models\CartCouponSelection;
use App\Models\CartItem;
use App\Models\ReferralAttempt;
use App\Models\Store;
use App\Models\StoreGatewayAccount;
use App\Models\StoreStaff;
use App\Models\WalletAccount;
use App\Models\WalletTransaction;
use App\Models\VerificationRequest;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasPermissions;
use Spatie\Permission\Traits\HasRoles;


class User extends Authenticatable {
    use HasApiTokens, HasFactory, Notifiable, HasRoles, SoftDeletes, HasPermissions;

    protected $appends = ['verification_status', 'verification_expires_at'];

    /**
     * Always eager load relations that are commonly required on the mobile app.
     *
     * @var array<int, string>
     */
    protected $with = ['store'];

    /**
     * ثوابت أنواع الحسابات
     */
    const ACCOUNT_TYPE_CUSTOMER = 1;    
    const ACCOUNT_TYPE_REAL_ESTATE = 2;
    const ACCOUNT_TYPE_SELLER = 3;


    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'mobile',
        'password',
        'type',
        'firebase_id',
        'profile',
        'address',
        'location',
        'notification',
        'country_code',
        'show_personal_details',
        'is_verified',
        'account_type',
        'terms_and_policy_accepted',
        'additional_info',
        'payment_info',
        'email_verified_at'
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'email_verified_at' => 'datetime',
        'account_type' => 'integer',
        'additional_info' => 'json',
        'payment_info' => 'json',
    ];


    public function getProfileAttribute($image) {
        if (!empty($image) && !filter_var($image, FILTER_VALIDATE_URL)) {
            return url(Storage::url($image));
        }
        return $image;
    }

    /**
     * التحقق مما إذا كان المستخدم عميلاً
     *
     * @return bool
     */
    public function isCustomer()
    {
        return $this->account_type === self::ACCOUNT_TYPE_CUSTOMER;
    }

    /**
     * التحقق مما إذا كان المستخدم تاجراً
     *
     * @return bool
     */
    public function isSeller()
    {
        return $this->account_type === self::ACCOUNT_TYPE_SELLER;
    }


    public function walletAccount(): HasOne
    {
        return $this->hasOne(WalletAccount::class);
    }

    public function walletTransactions(): HasManyThrough
    {
        return $this->hasManyThrough(
            WalletTransaction::class,
            WalletAccount::class,
            'user_id',
            'wallet_account_id'
        );
    }

    public function verificationRequests(): HasMany
    {
        return $this->hasMany(VerificationRequest::class);
    }

    public function latestApprovedVerificationRequest(): HasOne
    {
        return $this->hasOne(VerificationRequest::class)
            ->where('status', 'approved')
            ->latest('approved_at');
    }

    public function hasActiveVerification(): bool
    {
        $latest = $this->relationLoaded('latestApprovedVerificationRequest')
            ? $this->latestApprovedVerificationRequest
            : $this->latestApprovedVerificationRequest()->first();

        if (! $latest || $this->is_verified !== 1) {
            return false;
        }

        if (! $latest->expires_at) {
            return true;
        }

        try {
            return Carbon::parse($latest->expires_at)->isFuture();
        } catch (\Throwable) {
            return false;
        }
    }

    public function getVerificationStatusAttribute(): string
    {
        if ($this->hasActiveVerification()) {
            return 'active';
        }

        return $this->is_verified === 1 ? 'expired' : 'unverified';
    }

    public function getVerificationExpiresAtAttribute(): ?string
    {
        $latest = $this->relationLoaded('latestApprovedVerificationRequest')
            ? $this->latestApprovedVerificationRequest
            : $this->latestApprovedVerificationRequest()->first();

        if (! $latest || ! $latest->expires_at) {
            return null;
        }

        try {
            return Carbon::parse($latest->expires_at)->toIso8601String();
        } catch (\Throwable) {
            return null;
        }
    }


    public function addresses(): HasMany
    {
        return $this->hasMany(Address::class);
    }

    /**
     * التحقق مما إذا كان المستخدم مسوقاً
     *
     * @return bool
     */


    /**
     * الحصول على اسم نوع الحساب
     *
     * @return string
     */
    public function getAccountTypeName()
    {
        switch ($this->account_type) {
            case self::ACCOUNT_TYPE_CUSTOMER:
                return 'عميل';
            case self::ACCOUNT_TYPE_REAL_ESTATE:
                return 'عقاري';
            case self::ACCOUNT_TYPE_SELLER:
                return 'تاجر';
            default:
                return 'غير محدد';
        }
    }

    /**
     * نطاق للحصول على العملاء
     *
     * @param $query
     * @return mixed
     */
    public function scopeCustomers($query)
    {
        return $query->where('account_type', self::ACCOUNT_TYPE_CUSTOMER);
    }

    /**
     * نطاق للحصول على التجار
     *
     * @param $query
     * @return mixed
     */
    public function scopeSellers($query)
    {
        return $query->where('account_type', self::ACCOUNT_TYPE_SELLER);
    }

    /**
     * نطاق للحصول على المسوقين
     *
     * @param $query
     * @return mixed
     */


    public function items() {
        return $this->hasMany(Item::class);
    }



    public function cartItems()
    {
        return $this->hasMany(CartItem::class);
    }

    public function preference(): HasOne
    {
        return $this->hasOne(UserPreference::class);
    }



    public function cartCouponSelection(): HasOne
    {
        return $this->hasOne(CartCouponSelection::class);
    }

    public function storeGatewayAccounts(): HasMany
    {
        return $this->hasMany(StoreGatewayAccount::class);
    }

    public function stores(): HasMany
    {
        return $this->hasMany(Store::class);
    }

    public function storeStaffAssignments(): HasMany
    {
        return $this->hasMany(StoreStaff::class);
    }

    public function referralAttemptsAsReferrer(): HasMany
    {
        return $this->hasMany(ReferralAttempt::class, 'referrer_id');
    }

    public function referralAttemptsAsReferred(): HasMany
    {
        return $this->hasMany(ReferralAttempt::class, 'referred_user_id');
    }


    /** الفئات التي يديرها المستخدم */
    public function managedCategories(): BelongsToMany



    {
        return $this->belongsToMany(Category::class, 'category_managers')->withTimestamps();
    }



    /** الخدمات التي يملكها المستخدم */
    public function ownedServices(): HasMany
    {
        return $this->hasMany(Service::class, 'owner_id');
    }



        /** مراجعات الخدمات التي كتبها المستخدم */
    public function serviceReviews(): HasMany
    {
        return $this->hasMany(ServiceReview::class);
    }


    public function sellerReview() {
        return $this->hasMany(SellerRating::class , 'seller_id');
    }

    public function scopeSearch($query, $search) {
        $search = "%" . $search . "%";
        return $query->where(function ($q) use ($search) {
            $q->orWhere('email', 'LIKE', $search)
                ->orWhere('mobile', 'LIKE', $search)
                ->orWhere('name', 'LIKE', $search)
                ->orWhere('type', 'LIKE', $search)
                ->orWhere('notification', 'LIKE', $search)
                ->orWhere('firebase_id', 'LIKE', $search)
                ->orWhere('address', 'LIKE', $search)
                ->orWhere('created_at', 'LIKE', $search)
                ->orWhere('updated_at', 'LIKE', $search);
        });
    }

    public function user_reports() {
        return $this->hasMany(UserReports::class);
    }

    public function fcm_tokens() {
        return $this->hasMany(UserFcmToken::class);
    }


        public function notificationDeliveries() {
        return $this->hasMany(NotificationDelivery::class);
    }

    public function orders() {
        return $this->hasMany(Order::class);
    }

    protected static function booted()
    {
        static::creating(function ($user) {
            $user->referral_code = self::generateReferralCode();
        });
    }

    public static function generateReferralCode()
    {
        do {
            $code = strtoupper(Str::random(6));
        } while (self::where('referral_code', $code)->exists());

        return $code;
    }

    public function referrals()
    {
        return $this->hasMany(Referral::class, 'referrer_id');
    }

    public function referredBy()
    {
        return $this->hasOne(Referral::class, 'referred_user_id');
    }

    /**
     * الحصول على المعلومات الإضافية مع قيم افتراضية
     *
     * @return array
     */
    public function getAdditionalInfoAttribute($value)
    {
        $defaultStructure = [
            'addresses' => [],
            'categories' => [],
            'place_names' => [],
            'contact_info' => [],
            'delegate_sections' => [],
        
        ];
        
        if (empty($value)) {
            return $defaultStructure;
        }
        
        $decoded = is_string($value) ? json_decode($value, true) : $value;
        
        // التأكد من أن $decoded هو array قبل الدمج
        if (!is_array($decoded)) {
            return $defaultStructure;
        }
        
        // دمج مع الهيكل الافتراضي لضمان وجود جميع الحقول
        return array_merge($defaultStructure, $decoded);
    }

    /**
     * تعيين المعلومات الإضافية
     *
     * @param array $value
     */
    public function setAdditionalInfoAttribute($value)
    {
        $this->attributes['additional_info'] = json_encode($value);
    }

    /**
     * إضافة عنوان جديد
     *
     * @param array $address
     */
    public function addAddress($address)
    {
        $additionalInfo = $this->additional_info;
        $additionalInfo['addresses'][] = $address;
        $this->additional_info = $additionalInfo;
    }

    /**
     * إضافة فئة جديدة
     *
     * @param array $category
     */
    public function addCategory($category)
    {
        $additionalInfo = $this->additional_info;
        $additionalInfo['categories'][] = $category;
        $this->additional_info = $additionalInfo;
    }

    /**
     * إضافة اسم مكان جديد
     *
     * @param array $placeName
     */
    public function addPlaceName($placeName)
    {
        $additionalInfo = $this->additional_info;
        $additionalInfo['place_names'][] = $placeName;
        $this->additional_info = $additionalInfo;
    }

    public function store(): HasOne
    {
        return $this->hasOne(Store::class);
    }

    /**
     * تحديث معلومات الاتصال
     *
     * @param array $contactInfo
     */
    public function updateContactInfo($contactInfo)
    {
        $additionalInfo = $this->additional_info;
        $additionalInfo['contact_info'] = $contactInfo;
        $this->additional_info = $additionalInfo;
    }
}
