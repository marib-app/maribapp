<?php

namespace App\Http\Controllers;

use App\Events\ManualPaymentRequestCreated;
use App\Events\MessageDelivered;
use App\Events\MessageRead;
use App\Events\MessageSent;
use App\Events\UserPresenceUpdated;
use App\Events\UserTyping;
use App\Http\Resources\ItemCollection;
use App\Http\Resources\ManualPaymentRequestResource;
use App\Http\Resources\PaymentTransactionResource;
use App\Http\Resources\WalletTransactionResource;
use App\Http\Resources\SliderResource;
use App\Services\SliderMetricService;
use App\Models\ManualPaymentRequestHistory;
use App\Services\DepartmentAdvertiserService;
use App\Services\TelemetryService;
use App\Models\Area;
use App\Models\BlockUser;
use App\Models\Blog;
use App\Models\Category;
use App\Models\Chat;
use App\Models\ChatMessage;
use App\Models\City;
use App\Models\ContactUs;
use App\Models\Country;
use App\Models\CustomField;
use App\Models\Faq;
use App\Models\Favourite;
use App\Models\FeaturedAdsConfig;
use App\Models\FeaturedItems;
use App\Models\Item;
use App\Models\ItemCustomFieldValue;
use App\Models\ItemImages;
use App\Models\ItemOffer;
use App\Models\Language;
use App\Models\Notifications;
use App\Models\Package;
use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentConfiguration;
use App\Models\PaymentTransaction;
use App\Models\ReportReason;
use App\Models\SellerRating;
use App\Models\SeoSetting;
use App\Models\Service;
use App\Models\ServiceCustomField;
use App\Models\ServiceCustomFieldValue;
use App\Models\ServiceRequest;
use App\Models\ServiceReview;
use App\Models\Setting;
use Illuminate\Pagination\AbstractPaginator;
use App\Services\DelegateNotificationService;
use App\Models\Slider;
use App\Models\SocialLogin;
use App\Models\State;
use App\Models\Tip;
use App\Models\TipTranslation;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Models\UserPurchasedPackage;
use App\Models\UserReports;
use App\Models\VerificationField;
use App\Models\VerificationFieldRequest;
use App\Models\VerificationFieldValue;
use App\Models\VerificationPlan;
use App\Models\VerificationRequest;
use App\Models\WalletAccount;
use App\Models\WalletTransaction;
use App\Models\WalletWithdrawalRequest;
use App\Models\ReferralAttempt;
use App\Services\SliderEligibilityService;
use App\Models\ServiceReviewReport;
use App\Policies\SectionDelegatePolicy;
use Illuminate\Support\Facades\Gate;
use Illuminate\Http\UploadedFile;
use App\Models\CurrencyRateQuote;
use App\Events\CurrencyCreated;
use App\Events\CurrencyRatesUpdated;
use App\Models\Governorate;
use App\Models\CurrencyRate;
use App\Models\Challenge;
use App\Models\Referral;
use App\Models\DepartmentTicket;
use App\Services\DepartmentSupportService;
use App\Enums\NotificationFrequency;
use App\Http\Resources\UserPreferenceResource;
use App\Models\UserPreference;
use App\Models\RequestDevice;
use App\Models\Order;
use App\Services\CachingService;
use App\Services\DelegateAuthorizationService;
use App\Services\DepartmentReportService;
use App\Services\FileService;
use App\Services\InterfaceSectionService;
use App\Services\HelperService;
use App\Services\NotificationService;
use App\Services\PaymentFulfillmentService;
use App\Services\WalletService;
use App\Services\ResponseService;
use App\Services\ServiceAuthorizationService;
use App\Services\Location\MaribBoundaryService;
use App\Services\ReferralAuditLogger;
use DateTimeInterface;
use App\Services\Pricing\ActivePricingPolicyCache;

use App\Models\Pricing\PricingPolicy;
use App\Models\Pricing\PricingDistanceRule;
use App\Models\Pricing\PricingWeightTier;
use App\Models\DeliveryPrice;



use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Database\Eloquent\Builder;
use App\Http\Resources\WalletWithdrawalRequestResource;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Log;

use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;


use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use App\Models\OTP;
use App\Jobs\SendOtpWhatsAppJob;
use App\Services\EnjazatikWhatsAppService;
use Throwable;
use Exception;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Symfony\Component\HttpFoundation\Response as HttpResponse;
use App\Services\ImageVariantService;

use JsonException;


class ApiController extends Controller {


    public const INTERFACE_TYPES = [
        'all',
        'public',
        'real_estate',
        'shein',
        'computer',
    ];
    private static function interfaceTypes(bool $includeLegacy = false): array
    {
        if (! $includeLegacy) {
            return self::INTERFACE_TYPES;
        }

        return array_values(array_unique(array_merge(
            self::INTERFACE_TYPES,
            InterfaceSectionService::legacySectionTypes()
        )));
    }

    public const WALLET_TRANSACTION_FILTERS = [
        'all',
        'top-ups',
        'payments',
        'transfers',
        'refunds',
    ];

    /**
     * Cache of the available columns on the items table.
     */
    private static ?array $itemColumnAvailability = null;



    private const CURRENCY_SYNONYMS = [
        'yer' => 'YER',
        'أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ¨' => 'YER',
        'أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ«' => 'YER',
        'أ¢â€¢ع¾أ¢â€“â€™.أ¢â€‌ع©ط£آ¨' => 'YER',
        'أ¢â€¢ع¾أ¢â€“â€™. أ¢â€‌ع©ط£آ¨.' => 'YER',
        'sar' => 'SAR',
        'أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨' => 'SAR',
        'أ¢â€¢ع¾أ¢â€“â€™.أ¢â€¢ع¾أ¢â€‌â€ڑ' => 'SAR',
        'أ¢â€¢ع¾أ¢â€“â€™. أ¢â€¢ع¾أ¢â€‌â€ڑ.' => 'SAR',
        'sar أ¢â€¢ع¾أ¢â€“â€™.أ¢â€¢ع¾أ¢â€‌â€ڑ' => 'SAR',
        'omr' => 'OMR',
        'أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ¨' => 'OMR',
        'أ¢â€¢ع¾أ¢â€“â€™.أ¢â€¢ع¾أ¢â€¢آ£' => 'OMR',
        'aed' => 'AED',
        'أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¨' => 'AED',
        'أ¢â€¢ع¾ط¢آ».أ¢â€¢ع¾ط·آ­' => 'AED',
        'kwd' => 'KWD',
        'أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¨' => 'KWD',
        'أ¢â€¢ع¾ط¢آ».أ¢â€‌ع©ط£آ¢' => 'KWD',
        'bhd' => 'BHD',
        'أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ¨' => 'BHD',
        'أ¢â€¢ع¾ط¢آ».أ¢â€¢ع¾ط·آ°' => 'BHD',
        'egp' => 'EGP',
        'أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ§ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨' => 'EGP',
        'أ¢â€¢ع¾ط·آ´.أ¢â€‌ع©ط£آ ' => 'EGP',
        'usd' => 'USD',
        'أ¢â€¢ع¾ط·آ«.أ¢â€¢ع¾أ¢â€“â€™' => 'USD',
        'أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™' => 'USD',
        'أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£آ¨' => 'USD',
        '$' => 'USD',
        'eur' => 'EUR',
        'ط·آ¸ط£آ©ط·آ´' => 'EUR',
        'أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ¨' => 'GBP',
        'gbp' => 'GBP',
        'أ¢â€‌آ¬ط·آ«' => 'GBP',
        'try' => 'TRY',
        'ط·آ¸ط£آ©أ¢â€¢â€ک' => 'TRY',
        'أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±' => 'TRY',
    ];

    private function getWalletCurrencyCode(): string
    {
        return $this->walletService->getPrimaryCurrency();
    }

    private function ensureWalletAccountCurrency(WalletAccount $walletAccount): WalletAccount
    {
        $currency = $this->getWalletCurrencyCode();
        $current = Str::upper((string) $walletAccount->currency);

        if ($current === $currency) {
            return $walletAccount;
        }

        $existing = WalletAccount::query()
            ->where('user_id', $walletAccount->user_id)
            ->whereRaw('UPPER(currency) = ?', [$currency])
            ->first();

        if ($existing) {
            return $existing;
        }

        $walletAccount->forceFill(['currency' => $currency])->save();

        return $walletAccount->fresh();
    }


    protected function getWalletWithdrawalMethods(): array
    {
        $configuredMethods = config('wallet.withdrawals.methods', []);

        $methods = [];

        foreach ($configuredMethods as $method) {
            $key = (string) ($method['key'] ?? '');

            if ($key === '') {
                continue;
            }

            $methods[$key] = [
                'key' => $key,
                'name' => __($method['name'] ?? Str::headline(str_replace('_', ' ', $key))),
                'description' => $method['description'] ?? null,
                
                'fields' => $this->normalizeWithdrawalMethodFields($method['fields'] ?? []),


            ];
        }

        return $methods;
    }

    /**
     * @param array<int, array<string, mixed>> $fields
     * @return array<int, array{key: string, label: string, required: bool, rules: array<int, string>}>
     */
    private function normalizeWithdrawalMethodFields(array $fields): array
    {
        $normalized = [];

        foreach ($fields as $field) {
            $fieldKey = (string) ($field['key'] ?? '');

            if ($fieldKey === '') {
                continue;
            }

            $label = $field['label'] ?? Str::headline(str_replace('_', ' ', $fieldKey));
            $required = (bool) ($field['required'] ?? false);

            $rules = $field['rules'] ?? [];

            if (is_string($rules)) {
                $rules = array_filter(explode('|', $rules), static fn ($rule) => $rule !== '');
            }

            if (!is_array($rules)) {
                $rules = [];
            }

            $rules = array_values(array_map(static fn ($rule) => (string) $rule, $rules));

            if ($required && !$this->fieldRulesContainRequired($rules)) {
                array_unshift($rules, 'required');
            }

            if (!$required && empty($rules)) {
                $rules = ['nullable'];
            }

            $normalized[] = [
                'key' => $fieldKey,
                'label' => __($label),
                'required' => $required,
                'rules' => $rules,
            ];
        }

        return $normalized;
    }

    private function fieldRulesContainRequired(array $rules): bool
    {
        foreach ($rules as $rule) {
            if (!is_string($rule)) {
                continue;
            }

            if ($rule === 'required' || Str::startsWith($rule, 'required_')) {
                return true;
            }
        }

        return false;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function validateWithdrawalMeta(Request $request, array $method): ?array
    {
        $fields = $method['fields'] ?? [];

        if (empty($fields)) {
            return null;
        }

        $metaRules = [];
        $attributeNames = [];

        foreach ($fields as $field) {
            $fieldKey = $field['key'];
            $rules = $field['rules'] ?? [];

            if (empty($rules)) {
                $rules = $field['required'] ? ['required'] : [];
            }

            $metaRules[$fieldKey] = $rules;
            $attributeNames[$fieldKey] = $field['label'] ?? Str::headline(str_replace('_', ' ', $fieldKey));
        }

        $metaData = $request->input('meta', []);

        if (!is_array($metaData)) {
            $metaData = [];
        }

        $metaValidator = Validator::make($metaData, $metaRules, [], $attributeNames);

        if ($metaValidator->fails()) {
            ResponseService::validationError($metaValidator->errors()->first());
        }

        $validatedMeta = $metaValidator->validated();

        $sanitizedMeta = [];

        foreach ($fields as $field) {
            $fieldKey = $field['key'];

            if (array_key_exists($fieldKey, $validatedMeta)) {
                $sanitizedMeta[$fieldKey] = $validatedMeta[$fieldKey];
            }
        }

        return $sanitizedMeta === [] ? null : $sanitizedMeta;
    }


    private string $uploadFolder;
    private array $departmentCategoryMap = [];
    private ?array $geoDisabledCategoryCache = null;
    private ?array $productLinkRequiredCategoryCache = null;
    private ?array $productLinkRequiredSectionCache = null;



    public function __construct(
        private DelegateAuthorizationService $delegateAuthorizationService,
        private DepartmentReportService $departmentReportService,
        private ServiceAuthorizationService $serviceAuthorizationService,
        private PaymentFulfillmentService $paymentFulfillmentService,

        private WalletService $walletService,
        private MaribBoundaryService $maribBoundaryService,
        private ReferralAuditLogger $referralAuditLogger,
        private DelegateNotificationService $delegateNotificationService


    ) {
        
        
        $this->uploadFolder = 'item_images';
        if (array_key_exists('HTTP_AUTHORIZATION', $_SERVER) && !empty($_SERVER['HTTP_AUTHORIZATION'])) {
            $this->middleware('auth:sanctum');
        }
    }


    private function formatReferralAttempt(ReferralAttempt $attempt): array
    {
        return array_filter([
            'id' => $attempt->id,
            'code' => $attempt->code,
            'status' => $attempt->status,
            'referrer_id' => $attempt->referrer_id,
            'referred_user_id' => $attempt->referred_user_id,
            'referral_id' => $attempt->referral_id,
            'challenge_id' => $attempt->challenge_id,
            'awarded_points' => $attempt->awarded_points,
            'lat' => $attempt->lat,
            'lng' => $attempt->lng,
            'admin_area' => $attempt->admin_area,
            'device_time' => $attempt->device_time,
            'contact' => $attempt->contact,
            'request_ip' => $attempt->request_ip,
            'user_agent' => $attempt->user_agent,
            'exception_message' => $attempt->exception_message,
            'meta' => $attempt->meta,
            'created_at' => $attempt->created_at?->toIso8601String(),
        ], static fn ($value) => $value !== null && $value !== '');
    }



    private function resolvePerPage(Request $request, int $default = 15, int $max = 100): int
    {
        $perPage = $request->integer('per_page', $default) ?? $default;

        if ($perPage <= 0) {
            $perPage = $default;
        }


        return min($perPage, $max);
    }



    private function requestHasBoundingBox(Request $request): bool
    {
        return $request->filled('sw_lat')
            && $request->filled('sw_lng')
            && $request->filled('ne_lat')
            && $request->filled('ne_lng');
    }

    private function applyBoundingBoxFilter(Builder $sql, Request $request): Builder
    {
        $swLat = (float) $request->query('sw_lat');
        $neLat = (float) $request->query('ne_lat');
        $swLng = (float) $request->query('sw_lng');
        $neLng = (float) $request->query('ne_lng');

        $minLat = min($swLat, $neLat);
        $maxLat = max($swLat, $neLat);

        $sql->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->whereBetween('latitude', [$minLat, $maxLat])
            ->where(function (Builder $query) use ($swLng, $neLng): void {
                if ($swLng <= $neLng) {
                    $minLng = min($swLng, $neLng);
                    $maxLng = max($swLng, $neLng);

                    $query->whereBetween('longitude', [$minLng, $maxLng]);

                    return;
                }

                $query->where(function (Builder $wrap) use ($swLng, $neLng): void {
                    $wrap->whereBetween('longitude', [$swLng, 180])
                        ->orWhereBetween('longitude', [-180, $neLng]);
                });
            });

        return $sql;
    }









    /**
     * @return array<int, string>
     */
    private function normalizeSettingNames(mixed $value): array
    {
        if (is_string($value)) {
            $value = explode(',', $value);
        }

        if (!is_array($value)) {
            return [];
        }

        $names = [];

        foreach ($value as $entry) {
            if (is_string($entry)) {
                $candidate = trim($entry);
            } elseif (is_numeric($entry)) {
                $candidate = (string) $entry;
            } else {
                continue;

            }
            if ($candidate !== '') {
                $names[] = $candidate;
            }
        }

        return array_values(array_unique($names));
    }

    /**
     * @return array<int, string>
     */
    private function socialLinkSettingKeys(): array
    {
        $meta = config('constants.SOCIAL_LINKS_META', []);




        $keys = [];

        foreach ($meta as $key => $definition) {
            if (!is_string($key) || $key === '') {
                continue;
            }

            $keys[] = $key;

            $enabledKey = $definition['enabled_key'] ?? null;

            if (is_string($enabledKey) && $enabledKey !== '') {
                $keys[] = $enabledKey;
            }
        }

        return array_values(array_unique($keys));
    }

    /**
     * @param array<int, string> $keys
     * @param array<string, mixed> $seed
     * @return array<string, mixed>
     */
    private function hydrateSettingValues(array $keys, array $seed): array
    {
        if (empty($keys)) {
            return $seed;
        }

        $missing = array_values(array_diff($keys, array_keys($seed)));

        if (!empty($missing)) {
            $additional = Setting::query()
                ->select(['name', 'value'])
                ->whereIn('name', $missing)
                ->pluck('value', 'name')
                ->all();

            foreach ($additional as $name => $value) {
                if (is_string($name) && $name !== '' && !array_key_exists($name, $seed)) {
                    $seed[$name] = $value;
                }
            }
        }


        return $seed;
    }

    /**
     * @param array<string, mixed> $settings
     * @return array<int, array{key: string, label: string, icon: mixed, url: string, department: mixed}>
     */
    private function buildSocialLinks(array $settings): array
    {
        $socialLinksMeta = config('constants.SOCIAL_LINKS_META', []);
        $socialLinks = [];


        foreach ($socialLinksMeta as $key => $meta) {
            if (!is_string($key) || $key === '') {
                continue;
            }

            $value = $settings[$key] ?? null;


            $enabledKey = $meta['enabled_key'] ?? null;


              if (is_string($enabledKey) && $enabledKey !== '') {
                $enabledValue = $settings[$enabledKey] ?? null;
                if (!filter_var($enabledValue, FILTER_VALIDATE_BOOLEAN)) {
                    continue;
                }

            }

            if (blank($value)) {
                continue;
            }

            $isWhatsapp = ($meta['type'] ?? null) === 'whatsapp';
            $url = $value;

            if ($isWhatsapp) {
                $normalizedNumber = preg_replace('/[^0-9]/', '', (string) $value) ?? '';


                if ($normalizedNumber === '') {

                    continue;
                }

                $url = 'https://wa.me/' . $normalizedNumber;
            }

            $socialLinks[] = [
                'key'        => $key,
                'label'      => $meta['label'] ?? Str::title(str_replace('_', ' ', $key)),
                'icon'       => $meta['icon'] ?? null,
                'url'        => $url,
                'department' => $meta['department'] ?? null,
            ];
        }

        return $socialLinks;
    }



    public function getSystemSettings(Request $request) {
        try {
            $perPage = $request->integer('per_page', 15) ?? 15;

            if ($perPage <= 0) {
                $perPage = 15;
            }

            $perPage = min($perPage, 50);


            $settingsQuery = Setting::select(['name', 'value', 'type'])->orderBy('name');


            $typeFilter = $this->normalizeSettingNames($request->input('type'));
            if (!empty($typeFilter)) {
                $settingsQuery->whereIn('name', $typeFilter);
            }
            $fieldsFilter = $this->normalizeSettingNames($request->input('fields'));
            if (!empty($fieldsFilter)) {
                $settingsQuery->whereIn('name', $fieldsFilter);
            }

            $settings = $settingsQuery
                ->paginate($perPage)
                ->withQueryString()
                ->through(static function (Setting $row): array {
                    return [
                        'name'  => $row->name,
                        'value' => $row->value,
                        'type'  => $row->type,
                    ];
                });

            $settingsCollection = $settings->getCollection();



            $currentValues = $settingsCollection
                ->filter(static function ($item) {
                    if (!is_array($item)) {
                        return false;
                    }

                    $name = $item['name'] ?? null;


                    return is_string($name) && $name !== '';
                })
                ->mapWithKeys(static fn (array $item) => [
                    $item['name'] => $item['value'] ?? null,
                ])
                ->all();

            $requiredKeys = $this->socialLinkSettingKeys();
            $hydratedValues = $this->hydrateSettingValues($requiredKeys, $currentValues);

            $socialLinks = $this->buildSocialLinks($hydratedValues);




            $supportService = app(DepartmentSupportService::class);


            $extras = [
                'social_links' => $socialLinks,
                'department_support' => $supportService->allWhatsAppSupport(),
                'demo_mode' => config('app.demo_mode'),
                'languages' => CachingService::getLanguages(),
                'admin' => User::role('Super Admin')->select(['name', 'profile'])->first(),
            ];

            ResponseService::successResponse(
                "Data Fetched Successfully",
                $settings,
                [
                    'items_key' => 'settings',
                    'append_to_data' => [
                        'extras' => $extras,
                    ],
                ]
            );
            
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getSystemSettings");
            ResponseService::errorResponse();
        }
    }

    public function userSignup(Request $request) {
        try {
            \Log::info('أ¢â€°طŒط·آ§ط£آ´ط·آ¥ UserSignup Request:', [
                'type' => $request->type,
                'firebase_id' => $request->firebase_id,
                'mobile' => $request->mobile ?? 'not provided',
                'name' => $request->name ?? 'not provided',
                'email' => $request->email ?? 'not provided',
                'account_type' => $request->account_type ?? 'not provided'
            ]);
            
            $validationRules = [
                'type'          => 'required|in:email,google,phone,apple',
                'firebase_id'   => 'required',
                'country_code'  => 'nullable|string',
                'flag'          => 'boolean',
                'platform_type' => 'nullable|in:android,ios'
            ];
            
            // أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ± validation أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾ أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط£ع¾ google
            if ($request->type == 'google') {
                $validationRules['mobile'] = 'nullable'; // أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â‚¬ Google
            } elseif ($request->type == 'phone') {
                $validationRules['mobile'] = 'required|unique:users,mobile';
            } elseif ($request->type == 'email') {
                $validationRules['email'] = 'required|email';
            }
            if ($request->filled('code')) {
                $validationRules['lat'] = 'required|numeric';
                $validationRules['lng'] = 'required|numeric';
                $validationRules['device_time'] = 'required';
                $validationRules['admin_area'] = 'nullable|string|max:255';
            }

            
            // أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ®أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€¢â€“أ¢â€¢ع¾ط·آ« أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آ±
            $customMessages = [
                'mobile.required' => 'أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ°.',
                'mobile.unique'   => 'أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·ع¾أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€“â€™.',
                'email.required' => 'أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ°.',
                'email.email' => 'أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµ.',
                'code.exists' => 'أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµ.'
            ];
            
            $validator = Validator::make($request->all(), $validationRules, $customMessages);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }

            $type = $request->type;
            $firebase_id = $request->firebase_id;
            $referralAttempt = null;

            if ($request->filled('email')) {
                $request->merge(['email' => Str::lower(trim($request->email))]);
            }

            if ($type === 'phone' && empty($request->email)) {
                $generatedEmail = $this->generatePhoneSignupEmail(
                    $request->country_code,
                    $request->mobile
                );

                $request->merge(['email' => $generatedEmail]);

                \Log::info('أ¢â€°طŒط·آ§ط£آ´ط·آ¯ Generated fallback email for phone signup', [
                    'mobile' => $request->mobile,
                    'country_code' => $request->country_code,
                    'generated_email' => $generatedEmail,
                ]);
            }

            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â‚¬ Google firebase_id
            $existingGoogleUser = null;
            if ($type == 'google') {
                $existingGoogleUser = SocialLogin::where('firebase_id', $firebase_id)
                    ->where('type', 'google')
                    ->with('user')
                    ->first();
                    
                \Log::info('أ¢â€°طŒط·آ§ط¢آ¤ط¢ع† Searching for existing Google user by firebase_id:', [
                    'firebase_id' => $firebase_id,
                    'found' => $existingGoogleUser ? 'yes' : 'no',
                    'user_id' => $existingGoogleUser ? $existingGoogleUser->user->id : null
                ]);
            }
            
            $socialLogin = SocialLogin::where('firebase_id', $firebase_id)->where('type', $type)->with('user', function ($q) {
                $q->withTrashed();
            })->whereHas('user', function ($q) {
                $q->role('User');
            })->first();
            
            if (!empty($socialLogin->user->deleted_at)) {
                ResponseService::errorResponse("User is deactivated. Please Contact the administrator");
            }
            
            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€‌â€ڑ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾ أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍
            $existingUser = null;
            if ($request->type == 'phone' && !empty($request->mobile)) {
                $existingUser = User::where('mobile', $request->mobile)->first();
            } elseif ($request->type == 'email' && !empty($request->email)) {
                $existingUser = User::where('email', $request->email)->first();
            } elseif ($request->type == 'google') {
                // أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â‚¬ Googleأ¢â€¢ع¾ط£آ® أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â‚¬ email أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯أ¢â€¢ع¾ط£آ® أ¢â€¢ع¾ط·آ³أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â‚¬ mobile أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯
                if (!empty($request->email)) {
                    $existingUser = User::where('email', $request->email)->first();
                    \Log::info('أ¢â€°طŒط·آ§ط¢آ¤ط¢ع† Searching for Google user by email:', [
                        'email' => $request->email,
                        'found' => $existingUser ? 'yes' : 'no'
                    ]);
                }
                if (!$existingUser && !empty($request->mobile)) {
                    $existingUser = User::where('mobile', $request->mobile)->first();
                    \Log::info('أ¢â€°طŒط·آ§ط¢آ¤ط¢ع† Searching for Google user by mobile:', [
                        'mobile' => $request->mobile,
                        'found' => $existingUser ? 'yes' : 'no'
                    ]);
                }
            }

            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»
            $shouldUpdateExistingUser = false;
            if ($existingUser) {
                \Log::info('أ¢â€°طŒط·آ§ط¢آ¤ط¢ع† Found existing user:', [
                    'user_id' => $existingUser->id,
                    'email' => $existingUser->email,
                    'mobile' => $existingUser->mobile,
                    'is_verified' => $existingUser->is_verified,
                    'email_verified_at' => $existingUser->email_verified_at,
                    'type' => $request->type
                ]);
                
                if ($existingUser->is_verified == 0 && $existingUser->email_verified_at === null) {
                    $shouldUpdateExistingUser = true;
                    \Log::info('ط·آ¸ط¢آ£ط£آ  User is not verified, allowing update');
                } elseif ($existingUser->is_verified == 1 && $existingUser->email_verified_at !== null) {
                    // أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â‚¬ Google usersأ¢â€¢ع¾ط£آ® أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ« أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯
                    if ($request->type == 'google') {
                        $shouldUpdateExistingUser = true;
                        \Log::info('ط·آ¸ط¢آ£ط£آ  Allowing Google user to update verified account:', [
                            'user_id' => $existingUser->id,
                            'email' => $existingUser->email
                        ]);
                    } else {
                        // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯ - أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€¢â€“أ¢â€¢ع¾ط·آ«
                        if ($request->type == 'phone') {
                            ResponseService::errorResponse('أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯. أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾ أ¢â€¢ع¾ط·ع¾أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€“â€™.');
                        } else {
                            ResponseService::errorResponse('أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ». أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·ع¾أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€“â€™.');
                        }
                    }
                }
            } else {
                \Log::info('أ¢â€°طŒط·آ§ط¢آ¤ط¢ع† No existing user found for:', [
                    'type' => $request->type,
                    'email' => $request->email ?? 'not provided',
                    'mobile' => $request->mobile ?? 'not provided'
                ]);
            }

            if ($type == 'google' && $existingGoogleUser) {
                \Log::info('أ¢â€°طŒط·آ§ط¢آ¤ط¢â€‍ Updating existing Google user:', [
                    'firebase_id' => $firebase_id,
                    'user_id' => $existingGoogleUser->user->id,
                    'mobile' => $request->mobile,
                    'name' => $request->name
                ]);
                
                DB::beginTransaction();
                
                $user = $existingGoogleUser->user;
                $userData = $request->all();
                
                // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ 
                if (!empty($request->password)) {
                    $userData['password'] = Hash::make($request->password);
                }
                $userData['profile'] = $request->hasFile('profile') ? $request->file('profile')->store('user_profile', 'public') : $request->profile;
                $targetAccountType = $userData['account_type'] ?? $user->account_type ?? null;
                if ((int) $targetAccountType === User::ACCOUNT_TYPE_SELLER) {
                    $userData['name'] = $this->fallbackSellerName($request, $userData, $user);
                }
                
                // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ±
                $user->update([
                    'name' => $userData['name'] ?? $user->name,
                    'mobile' => $userData['mobile'] ?? $user->mobile,
                    'email' => $userData['email'] ?? $user->email,
                    'password' => $userData['password'] ?? $user->password,
                    'account_type' => $userData['account_type'] ?? $user->account_type,
                    'country_code' => $userData['country_code'] ?? $user->country_code,
                    'country_name' => $userData['country_name'] ?? $user->country_name,
                    'flag_emoji' => $userData['flag_emoji'] ?? $user->flag_emoji,
                ]);
                
                \Log::info('ط·آ¸ط¢آ£ط£آ  Google user updated successfully:', [
                    'user_id' => $user->id,
                    'updated_fields' => [
                        'name' => $user->name,
                        'mobile' => $user->mobile,
                        'account_type' => $user->account_type
                    ]
                ]);
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§
                if (!empty($request->code)) {
                    $referralAttempt = $this->handleReferralCode(
                        $request->code,
                        $user,
                        $request->mobile ?? $request->email,
                        $this->buildReferralLocationPayload($request),
                        $this->buildReferralRequestMeta($request)
                    
                    );
                
                }
                
                Auth::guard('web')->login($user);
                $auth = User::find($user->id);
                
                DB::commit();
            } elseif (empty($socialLogin)) {
                DB::beginTransaction();

                if ($shouldUpdateExistingUser) {
                    // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»
                    \Log::info('أ¢â€°طŒط·آ§ط¢آ¤ط¢â€‍ Updating existing user:', [
                        'user_id' => $existingUser->id,
                        'type' => $request->type,
                        'mobile' => $request->mobile,
                        'name' => $request->name
                    ]);
                    
                    $userData = $request->all();
                    $targetAccountType = $userData['account_type'] ?? $existingUser->account_type ?? null;
                    if ((int) $targetAccountType === User::ACCOUNT_TYPE_SELLER) {
                        $userData['name'] = null;
                    }
                    if (!empty($request->password)) {
                        $userData['password'] = Hash::make($request->password);
                    }
                    $userData['profile'] = $request->hasFile('profile') ? $request->file('profile')->store('user_profile', 'public') : $request->profile;
                    
                    // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍
                    if (in_array($request->type, ['google', 'apple'])) {
                        $userData['is_verified'] = 1;
                        $userData['email_verified_at'] = now();
                    } else {
                        $userData['is_verified'] = 0;
                        $userData['email_verified_at'] = null;
                    }
                    
                    $existingUser->update($userData);
                    $user = $existingUser;
                    
                    \Log::info('ط·آ¸ط¢آ£ط£آ  Existing user updated successfully:', [
                        'user_id' => $user->id,
                        'updated_fields' => [
                            'name' => $user->name,
                            'mobile' => $user->mobile,
                            'account_type' => $user->account_type
                        ]
                    ]);
                    
                    // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§
                    if (!empty($request->code)) {
                        $referralAttempt = $this->handleReferralCode(
                            $request->code,
                            $user,
                            $request->mobile ?? $request->email,
                            $this->buildReferralLocationPayload($request)
                        );
                    
                    }
                    
                    SocialLogin::updateOrCreate([
                        'type'    => $request->type,
                        'user_id' => $user->id
                    ], [
                        'firebase_id' => $request->firebase_id,
                    ]);
                    
                    if (!$user->hasRole('User')) {
                        $user->assignRole('User');
                    }
                    
                    Auth::guard('web')->login($user);
                    $targetAccountType = $userData['account_type'] ?? null;
                    if ((int) $targetAccountType === User::ACCOUNT_TYPE_SELLER) {
                        $userData['name'] = $this->fallbackSellerName($request, $userData, $existingUser);
                    }
                    $auth = User::find($user->id);
                } else {
                    // أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»
                    $userData = $request->all();
                    if (!empty($request->password)) {
                        $userData['password'] = Hash::make($request->password);
                    }
                    $userData['profile'] = $request->hasFile('profile') ? $request->file('profile')->store('user_profile', 'public') : $request->profile;
                    $targetAccountType = $userData['account_type'] ?? null;
                    if ((int) $targetAccountType === User::ACCOUNT_TYPE_SELLER) {
                        $userData['name'] = $this->fallbackSellerName($request, $userData);
                    }
                    
                    // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍
                    if (in_array($request->type, ['google', 'apple'])) {
                        $userData['is_verified'] = 1;
                        $userData['email_verified_at'] = now();
                    } else {
                        $userData['is_verified'] = 0;
                        $userData['email_verified_at'] = null;
                    }
                    
                    // أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â‚¬ Google usersأ¢â€¢ع¾ط£آ® أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط£آ® أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  email أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â‚¬ mobile أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¬أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ²
                    if ($type == 'google' && empty($request->mobile)) {
                        $userData['mobile'] = $request->email ?? 'temp_' . time();
                        \Log::info('أ¢â€°طŒط·آ§ط£آ´أ¢â€“â€™ Using temporary mobile for Google user:', [
                            'email' => $request->email,
                            'temp_mobile' => $userData['mobile']
                        ]);
                    }
                    
                    if ($type == 'google') {
                        \Log::info('أ¢â€°طŒط·آ§ط¢â€ ط¸â‚¬ Creating new Google user:', [
                            'firebase_id' => $firebase_id,
                            'mobile' => $userData['mobile'],
                            'name' => $request->name
                        ]);
                    }
                    
                    $user = User::create($userData);
                    
                    if ($type == 'google') {
                        \Log::info('ط·آ¸ط¢آ£ط£آ  New Google user created:', [
                            'user_id' => $user->id,
                            'firebase_id' => $firebase_id
                        ]);
                    }
                    
                    // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§
                    if (!empty($request->code)) {
                        $referralAttempt = $this->handleReferralCode(
                            $request->code,
                            $user,
                            $request->mobile ?? $request->email,
                            $this->buildReferralLocationPayload($request),
                            $this->buildReferralRequestMeta($request)
                        );
                    
                    }
                    
                    SocialLogin::updateOrCreate([
                        'type'    => $request->type,
                        'user_id' => $user->id
                    ], [
                        'firebase_id' => $request->firebase_id,
                    ]);
                    $user->assignRole('User');
                    Auth::guard('web')->login($user);
                    $auth = User::find($user->id);
                }
                
                DB::commit();
            } else {
                Auth::guard('web')->login($socialLogin->user);
                $auth = Auth::user();
            }
            if (!$auth->hasRole('User')) {
                ResponseService::errorResponse('Invalid Login Credentials', null, config('constants.RESPONSE_CODE.INVALID_LOGIN'));
            }

            if (!empty($request->fcm_id)) {
//                UserFcmToken::insertOrIgnore(['user_id' => $auth->id, 'fcm_token' => $request->fcm_id, 'created_at' => Carbon::now(), 'updated_at' => Carbon::now()]);
                UserFcmToken::updateOrCreate(
                    ['fcm_token' => $request->fcm_id],
                    [
                        'user_id'          => $auth->id,
                        'platform_type'    => $request->platform_type,
                        'last_activity_at' => Carbon::now(),
                    ]
                );
            }

            if (!empty($request->registration)) {
                //If registration is passed then don't create token
                $token = null;
            } else {
                $token = $auth->createToken($auth->name ?? '')->plainTextToken;
            }

            $customResponseData = ['token' => $token];

            if ($referralAttempt !== null) {
                $customResponseData['referral_attempt'] = $referralAttempt;
            }

            ResponseService::successResponse('User logged-in successfully', $auth, $customResponseData);
        
        
        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, "API Controller -> Signup");
            ResponseService::errorResponse();
        }
    }

    public function userLogin(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'type'          => 'required|in:email,google,phone,apple,phone_password',
                'firebase_id'   => 'required_unless:type,phone_password',
                'mobile'        => 'required_if:type,phone_password',
                'password'      => 'required_if:type,phone_password',
                'country_code'  => 'nullable|string',
                'platform_type' => 'nullable|in:android,ios'
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }

            $type = $request->type;
            $auth = null;

            // Handle phone and password login
            if ($type == 'phone_password') {
                $user = User::where('mobile', $request->mobile)
                           ->whereHas('roles', function ($q) {
                               $q->where('name', 'User');
                           })
                           ->first();

                if (!$user) {
                    ResponseService::errorResponse('أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾ أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍. أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯.', null, config('constants.RESPONSE_CODE.INVALID_LOGIN'));
                }

                if ($user->trashed()) {
                    ResponseService::errorResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢â€کأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢. أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ±.', null, config('constants.RESPONSE_CODE.DEACTIVATED_ACCOUNT'));
                }

                // Check if user has password set
                if (!$user->password) {
                    ResponseService::errorResponse('
                    
                    أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°. أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ  OTP أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾ أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™.', null, config('constants.RESPONSE_CODE.INVALID_LOGIN'));
                }

                // Verify password
                if (!Hash::check($request->password, $user->password)) {
                    ResponseService::errorResponse('أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ±.', null, config('constants.RESPONSE_CODE.INVALID_LOGIN'));
                }

                Auth::guard('web')->login($user);
                $auth = $user;
            } else {
                // Handle Firebase-based login (existing logic)
                $firebase_id = $request->firebase_id;
                $socialLogin = SocialLogin::where('firebase_id', $firebase_id)->where('type', $type)->with('user', function ($q) {
                    $q->withTrashed();
                })->whereHas('user', function ($q) {
                    $q->role('User');
                })->first();

                if (!$socialLogin) {
                    ResponseService::errorResponse('أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍. أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯.', null, config('constants.RESPONSE_CODE.INVALID_LOGIN'));
                }

                if (!empty($socialLogin->user->deleted_at)) {
                    ResponseService::errorResponse("أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢â€کأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ . أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ±", null, config('constants.RESPONSE_CODE.DEACTIVATED_ACCOUNT'));
                }

                Auth::guard('web')->login($socialLogin->user);
                $auth = Auth::user();
            }

            if (!$auth->hasRole('User')) {
                ResponseService::errorResponse('أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ±', null, config('constants.RESPONSE_CODE.INVALID_LOGIN'));
            }

            // Update FCM token
            if (!empty($request->fcm_id)) {
                UserFcmToken::updateOrCreate(
                    ['fcm_token' => $request->fcm_id],
                    [
                        'user_id'          => $auth->id,
                        'platform_type'    => $request->platform_type,
                        'last_activity_at' => Carbon::now(),
                    ]
                );
            }

            // Generate token
            $token = $auth->createToken($auth->name ?? '')->plainTextToken;

            ResponseService::successResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ', $auth, ['token' => $token]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> Login");
            ResponseService::errorResponse();
        }
    }



    public function updateProfile(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'name'                  => 'nullable|string',
                'profile'               => 'nullable|mimes:jpg,jpeg,png|max:4096',
                'email'                 => 'nullable|email|unique:users,email,' . Auth::user()->id,
                'mobile'                => 'nullable|unique:users,mobile,' . Auth::user()->id,
                'fcm_id'                => 'nullable',
                'platform_type'         => 'nullable|in:android,ios',
                'address'               => 'nullable',
                'show_personal_details' => 'boolean',
                'country_code'          => 'nullable|string',
                'additional_data'       => 'nullable|array'
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }

            $app_user = Auth::user();
            //Email should not be updated when type is google.
            $data = $app_user->type == "google" ? $request->except('email') : $request->all();

            if ($request->hasFile('profile')) {
                $data['profile'] = FileService::compressAndReplace($request->file('profile'), 'profile', $app_user->getRawOriginal('profile'));
            }

            if (!empty($request->fcm_id)) {
                UserFcmToken::updateOrCreate(
                    ['fcm_token' => $request->fcm_id],
                    [
                        'user_id'          => $app_user->id,
                        'platform_type'    => $request->platform_type,
                        'last_activity_at' => Carbon::now(),
                    ]
                );
            }
            $data['show_personal_details'] = $request->show_personal_details;

            // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
            if ($request->has('additional_data') && !empty($request->additional_data)) {
                $additionalInfo = $app_user->additional_info ?: [];
                if (!is_array($additionalInfo)) {
                    $additionalInfo = [];
                }
                
                if (!isset($additionalInfo['contact_info'])) {
                    $additionalInfo['contact_info'] = [];
                }
                
                // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°
                foreach ($request->additional_data as $key => $value) {
                    $additionalInfo['contact_info'][$key] = $value;
                }
                
                $data['additional_info'] = $additionalInfo;
            }

            $app_user->update($data);
            ResponseService::successResponse("Profile Updated Successfully", $app_user);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> updateProfile');
            ResponseService::errorResponse();
        }
    }

    public function getPackage(Request $request) {
        $validator = Validator::make($request->toArray(), [
            'platform' => 'nullable|in:android,ios',
            'type'     => 'nullable|in:advertisement,item_listing'
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $packages = Package::where('status', 1);

            if (Auth::check()) {
                $packages = $packages->with('user_purchased_packages', function ($q) {
                    $q->onlyActive();
                });
            }

            if (isset($request->platform) && $request->platform == "ios") {
                $packages->whereNotNull('ios_product_id');
            }

            if (!empty($request->type)) {
                $packages = $packages->where('type', $request->type);
            }
            $packages = $packages->orderBy('id', 'ASC')->get();

            $packages->map(function ($package) {
                if (Auth::check()) {
                    $package['is_active'] = count($package->user_purchased_packages) > 0;
                } else {
                    $package['is_active'] = false;
                }
                return $package;
            });
            ResponseService::successResponse('Data Fetched Successfully', $packages);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getPackage");
            ResponseService::errorResponse();
        }
    }

    public function assignFreePackage(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'package_id' => 'required|exists:packages,id',
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }

            $user = Auth::user();

            $package = Package::where(['final_price' => 0, 'id' => $request->package_id])->firstOrFail();
            $activePackage = UserPurchasedPackage::where(['package_id' => $request->package_id, 'user_id' => Auth::user()->id])->first();
            if (!empty($activePackage)) {
                ResponseService::errorResponse("You already have purchased this package");
            }

            UserPurchasedPackage::create([
                'user_id'     => $user->id,
                'package_id'  => $request->package_id,
                'start_date'  => Carbon::now(),
                'total_limit' => $package->item_limit == "unlimited" ? null : $package->item_limit,
                'end_date'    => $package->duration == "unlimited" ? null : Carbon::now()->addDays($package->duration)
            ]);
            ResponseService::successResponse('Package Purchased Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> assignFreePackage");
            ResponseService::errorResponse();
        }
    }

    public function getLimits(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'package_type' => 'required|in:item_listing,advertisement',
            ]);
            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            


            $user = Auth::user();
            $today = Carbon::today();

            $package = UserPurchasedPackage::query()
                ->with('package')
                ->where('user_id', $user->id)
                ->whereDate('start_date', '<=', $today)
                ->where(function ($query) use ($today) {
                    $query->whereNull('end_date')
                        ->orWhereDate('end_date', '>=', $today);
                })
                ->whereHas('package', function ($query) use ($request) {
                    $query->where('type', $request->package_type);
                })
                ->orderByDesc('start_date')
                ->orderByDesc('id')
                ->first();

            $payload = [
                'allowed'    => false,
                'total'      => 0,
                'remaining'  => 0,
                'expires_at' => null,
            ];

            if (!empty($package)) {
                $totalLimit = $package->total_limit;
                $usedLimit = (int) ($package->used_limit ?? 0);

                if (is_null($totalLimit)) {
                    $payload['allowed'] = true;
                    $payload['total'] = null;
                    $payload['remaining'] = null;
                } else {
                    $remaining = max(0, $totalLimit - $usedLimit);
                    $payload['total'] = $totalLimit;
                    $payload['remaining'] = $remaining;
                    $payload['allowed'] = $remaining > 0;

                    if (!$payload['allowed']) {
                        $payload['remaining'] = 0;
                    }
                }

                $payload['expires_at'] = $package->end_date
                    ? Carbon::parse($package->end_date)->toDateString()
                    : null;
            }

            ResponseService::successResponse('Package limit fetched successfully', $payload);

            

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getLimits");
            ResponseService::errorResponse();
        }
    }




     public function getTips(Request $request)
     {
        $validator = Validator::make($request->all(), [
            'department' => ['required', Rule::in(config('cart.departments', []))],
            'item_id' => ['nullable', 'integer', 'exists:items,id'],
        ]);

        if ($validator->fails()) {
            return ResponseService::validationError($validator->errors()->first());
        }

        $departmentKey = $request->input('department');
        $itemId = $request->input('item_id');

        app(TelemetryService::class)->record('api.tips.called', [
            'department' => $departmentKey,
            'item_id' => $itemId,
        ]);

        $departments = app(DepartmentReportService::class)->availableDepartments();
        $departmentResolver = app(DepartmentAdvertiserService::class);

        $itemDepartment = null;
        $productLink = null;
        $reviewLink = null;

        $storePolicyText = null;

        if ($request->filled('item_id')) {
            $item = Item::with([
                'store.policies' => static function ($query) {
                    $query->where('is_active', true);
                },
            ])->select([
                'id',
                'product_link',
                'review_link',
                'interface_type',
                'category_id',
                'all_category_ids',
                'store_id',
            ])->find($request->integer('item_id'));

            if ($item !== null) {
                $itemDepartment = $departmentResolver->resolveDepartmentForItem($item);
                $productLink = $item->product_link;
                $reviewLink = $item->review_link;
                $storePolicyText = $this->buildStorePolicySummary($item->store);
            }
        }

        Log::info('tips.department_check', [
            'item_id' => $itemId,
            'requested_department' => $departmentKey,
            'item_department' => $itemDepartment,
        ]);


        $tips = Tip::with('translations.language')
            ->where('department', $departmentKey)
            ->orderBy('sequence')
            ->get();

        $tipsPayload = $tips->map(function (Tip $tip) {
            $translations = $tip->translations->mapWithKeys(static function (TipTranslation $translation) {
                $code = $translation->language?->code;

                if (empty($code)) {
                    return [];
                }

                return [$code => $translation->description];
            });

            return [
                'id' => $tip->id,
                'department' => $tip->department,
                'sequence' => $tip->sequence,
                'description' => $tip->translated_name,
                'default_description' => $tip->description,
                'translations' => $translations,
            ];
        })->values();

        $response = [
            'department' => [
                'key' => $departmentKey,
                'label' => $departments[$departmentKey] ?? $departmentKey,
            ],
            'tips' => $tipsPayload,
            'product_link' => null,
            'actions' => [],
            'review_link' => null,


            'presentation' => DepartmentReportService::DEPARTMENT_SHEIN === $departmentKey ? 'modal' : 'banner',


        ];

        if ($departmentKey === DepartmentReportService::DEPARTMENT_SHEIN) {
            $response['product_link'] = $productLink;
            $response['review_link'] = $reviewLink;

            $verificationLink = $reviewLink ?: $productLink;

            $response['actions'] = array_values(array_filter([


                [
                    'type' => 'navigate',
                    'target' => 'cart',
                    'label' => __('Continue Purchase'),
                ],
                $verificationLink ? [

                    'type' => 'open_url',
                    'url' => $verificationLink,

                    'label' => __('Verify Product'),
                    'payload' => array_filter([
                        'review_link' => $reviewLink,
                        'product_link' => $productLink,
                    ]),
                ] : null,
            ])); 
        }

        if ($storePolicyText !== null && ! isset($response['return_policy_text'])) {
            $response['return_policy_text'] = $storePolicyText;
        }


        $response['item_department'] = $itemDepartment;

        app(TelemetryService::class)->record('api.tips.response', [
            'department' => $departmentKey,
            'item_id' => $itemId,
            'tips_count' => $tipsPayload->count(),
            'actions_count' => count($response['actions']),
            'has_product_link' => $response['product_link'] !== null,
            'has_review_link' => $response['review_link'] !== null,


        ]);

        Log::info('tips.response_payload', [
            'department' => $departmentKey,
            'item_id' => $itemId,
            'tips_count' => $tipsPayload->count(),
            'actions_count' => count($response['actions']),
            'product_link' => $response['product_link'],
            'review_link' => $response['review_link'],


        ]);



        return ResponseService::successResponse('Tips fetched successfully.', $response);
     }
     
     private function buildStorePolicySummary($store): ?string
     {
        if ($store === null) {
            return null;
        }

        $policies = $store->relationLoaded('policies')
            ? $store->policies
            : $store->policies()->where('is_active', true)->get();

        if ($policies === null) {
            return null;
        }

        $lines = $policies->filter(static function ($policy) {
            return (bool) $policy->is_active && trim((string) $policy->content) !== '';
        })->sortBy(static function ($policy) {
            return $policy->display_order ?? 0;
        })->map(static function ($policy) {
            $title = trim((string) ($policy->title ?? ''));
            $content = trim((string) $policy->content);
            if ($content === '') {
                return null;
            }
            return $title !== '' ? "{$title}: {$content}" : $content;
        })->filter()->values();

        if ($lines->isEmpty()) {
            return null;
        }

        return $lines->map(static fn ($line) => 'ط·آ¸ط¢â‚¬ط·ع¾ ' . $line)->implode("\n");
     }




     public function addItem(Request $request) {
        try {


            if ($request->filled('custom_fields') && is_string($request->input('custom_fields'))) {
                try {
                    $decodedCustomFields = json_decode($request->input('custom_fields'), true, 512, JSON_THROW_ON_ERROR);
                } catch (JsonException $exception) {
                    ResponseService::validationErrors([
                        'custom_fields' => [
                            __('validation.json', ['attribute' => __('Custom Fields')]),
                        ],
                    ]);
                }

                if (! is_array($decodedCustomFields)) {
                    ResponseService::validationErrors([
                        'custom_fields' => [
                            __('validation.array', ['attribute' => __('Custom Fields')]),
                        ],
                    ]);
                }

                $request->merge(['custom_fields' => $decodedCustomFields]);
            }

            $categoryInput = $request->input('category_id');
            $categoryId = is_numeric($categoryInput) ? (int) $categoryInput : null;
            $requiresProductLink = $this->shouldRequireProductLink($categoryId);

            $allowedCustomFieldIds = collect();

            if ($categoryId !== null) {
                $categoryWithCustomFields = Category::query()
                    ->with(['custom_fields' => static function ($query) {
                        $query->select('id', 'category_id', 'custom_field_id');
                    }])
                    ->find($categoryId);

                if ($categoryWithCustomFields !== null) {
                    $allowedCustomFieldIds = $categoryWithCustomFields->custom_fields
                        ->pluck('custom_field_id')
                        ->filter(static fn ($id) => $id !== null)
                        ->map(static fn ($id) => (int) $id)
                        ->unique()
                        ->values();
                }
            }


            $validationRules = [

                'name'                 => 'required',
                'category_id'          => 'required|integer',
                'price'                => 'required',
                'description'          => 'required',
                'latitude'             => 'required',
                'longitude'            => 'required',
                'address'              => 'required',
                'contact'              => 'numeric',
                'show_only_to_premium' => 'required|boolean',
                'video_link'           => 'nullable|url',
                'gallery_images'       => 'nullable|array|min:1',
                'gallery_images.*'     => 'nullable|mimes:jpeg,png,jpg|max:4096',
                'image'                => 'required|mimes:jpeg,png,jpg|max:4096',
                'country'              => 'required',
                'state'                => 'nullable',
                'city'                 => 'required',
                'area_id'              => 'nullable',
                'custom_field_files'   => 'nullable|array',
                'custom_field_files.*' => 'nullable|mimes:jpeg,png,jpg,pdf,doc|max:4096',
                'custom_fields'        => 'nullable|array',
                'custom_fields.*'      => 'nullable',
                'slug'                 => 'nullable|regex:/^[a-z0-9-]+$/',
                'currency'             => 'required',

                'product_link'         => [
                    'nullable',
                    'url',
                    'max:2048',
                    Rule::requiredIf($requiresProductLink),
                ],
                'review_link'          => 'nullable|url|max:2048',

            ];

            if ($categoryId !== null && $this->isGeoDisabledCategory($categoryId)) {
                foreach (['latitude', 'longitude', 'city', 'area_id', 'address', 'country', 'state'] as $geoField) {
                    $validationRules[$geoField] = 'nullable';
                }
                $validationRules['image'] = 'nullable|mimes:jpeg,png,jpg|max:4096';
            }

            $validator = Validator::make($request->all(), $validationRules);





            if ($validator->fails()) {
                ResponseService::validationErrors($validator->errors());
            }


            $section = $this->resolveSectionByCategoryId((int) $request->category_id);
            $authorization = Gate::inspect('section.publish', $section);

            if ($authorization->denied()) {
                $message = $authorization->message() ?? SectionDelegatePolicy::FORBIDDEN_MESSAGE;

                ResponseService::errorResponse($message, null, 403);
            }


            DB::beginTransaction();
            $user = Auth::user();



            
            $user_package = UserPurchasedPackage::onlyActive()
                ->whereHas('package', static function ($q) {
                    $q->where('type', 'item_listing');
                })
                ->lockForUpdate()
                ->first();



            if (empty($user_package)) {
                DB::rollBack();
                ResponseService::errorResponse("No Active Package found for Item Creation");
            }


            // Generate a unique slug if the slug is not provided
            $slug = $request->input('slug');
            if (empty($slug)) {
                $slug = HelperService::generateRandomSlug();
            }
            $uniqueSlug = HelperService::generateUniqueSlug(new Item(), $slug);
            if ($uniqueSlug === '') {
                $uniqueSlug = Str::lower(Str::random(12));
            }
            $status = $this->resolveInitialItemStatus($user, $section);

            $data = Arr::only($request->all(), [
                'category_id',
                'price',
                'description',
                'latitude',
                'longitude',
                'address',
                'contact',
                'show_only_to_premium',
                'video_link',
                'country',
                'state',
                'city',
                'area_id',
                'all_category_ids',
                'interface_type',
            ]);

            

            $data['name'] = Str::upper($request->name);
            $data['slug'] = $uniqueSlug;
            $data['status'] = $status;
            $data['user_id'] = $user->id;
            $data['expiry_date'] = $user_package->end_date;
            $data['currency'] = $request->input('currency', 'YER');
            $data['show_only_to_premium'] = $request->boolean('show_only_to_premium');
            $data['product_link'] = $request->filled('product_link') ? $request->input('product_link') : null;
            $data['review_link'] = $request->filled('review_link') ? $request->input('review_link') : null;

            
        
            if ($request->hasFile('image')) {
                try {
                    $variants = ImageVariantService::storeWithVariants($request->file('image'), $this->uploadFolder);
                } catch (Throwable $exception) {
                    ResponseService::validationErrors([
                        'image' => [__('Unable to process the uploaded image. Please try again with a different file.')],
                    ]);
                }
            
            
            

                $data['image'] = $variants['original'];
                $data['thumbnail_url'] = $variants['thumbnail'];
                $data['detail_image_url'] = $variants['detail'];

            }
            $item = Item::create($data);

            if ($request->hasFile('gallery_images')) {
                $galleryImages = [];
                $timestamp = now();
                foreach ($request->file('gallery_images') as $file) {

                    try {
                        $galleryVariants = ImageVariantService::storeWithVariants($file, $this->uploadFolder);
                    } catch (Throwable $exception) {
                        ResponseService::validationErrors([
                            'gallery_images' => [__('Unable to process one of the gallery images. Please verify the files and retry.')],
                        ]);
                    }

                    $galleryImages[] = [
                        'image'      => $galleryVariants['original'],
                        'thumbnail_url' => $galleryVariants['thumbnail'],
                        'detail_image_url' => $galleryVariants['detail'],
                        'item_id'    => $item->id,
                        'created_at' => $timestamp,
                        'updated_at' => $timestamp->copy(),
                    ];
                }

                if (count($galleryImages) > 0) {
                    ItemImages::insert($galleryImages);
                }
            }

            if ($request->custom_fields) {
                $itemCustomFieldValues = [];
                // Handle both JSON string and array formats
                $customFields = is_string($request->custom_fields)
                    ? json_decode($request->custom_fields, true, 512, JSON_THROW_ON_ERROR)


                    : $request->custom_fields;
                    
                foreach ($customFields as $key => $custom_field) {


                    $customFieldId = is_numeric($key) ? (int) $key : null;

                    if ($customFieldId === null || ! $allowedCustomFieldIds->containsStrict($customFieldId)) {
                        ResponseService::validationErrors([
                            "custom_fields.$key" => [__('The selected custom field is invalid for this category.')],
                        ]);
                    }

                    if ($custom_field instanceof UploadedFile) {
                        ResponseService::validationErrors([
                            "custom_fields.$key" => [__('Custom field values cannot contain files. Use custom_field_files instead.')],
                        ]);
                    }

                    try {
                        $encodedValue = json_encode($custom_field, JSON_THROW_ON_ERROR);
                    } catch (JsonException $exception) {
                        ResponseService::validationErrors([
                            "custom_fields.$key" => [__('Unable to process the provided custom field value.')],
                        ]);
                    }

                    $timestamp = now();

                    $itemCustomFieldValues[] = [
                        'item_id'         => $item->id,
                        'custom_field_id' => $customFieldId,
                        'value'           => $encodedValue,
                        'created_at'      => $timestamp,
                        'updated_at'      => $timestamp->copy()
                    ];
                }

                if (count($itemCustomFieldValues) > 0) {
                    ItemCustomFieldValue::insert($itemCustomFieldValues);
                }
            }

            if ($request->custom_field_files) {
                $itemCustomFieldValues = [];
                foreach ($request->custom_field_files as $key => $file) {
                    $customFieldId = is_numeric($key) ? (int) $key : null;

                    if ($customFieldId === null || ! $allowedCustomFieldIds->containsStrict($customFieldId)) {
                        ResponseService::validationErrors([
                            "custom_field_files.$key" => [__('The selected custom field is invalid for this category.')],
                        ]);
                    }
 
                    if (! $file instanceof UploadedFile) {
                        
                        ResponseService::validationErrors([
                            "custom_field_files.$key" => [__('Each custom field file must be an uploaded file.')],
                        ]);
                    }

                    try {
                        $filePath = ! empty($file) ? FileService::upload($file, 'custom_fields_files') : '';
                    } catch (Throwable $exception) {
                        ResponseService::validationErrors([
                            "custom_field_files.$key" => [__('Failed to store the uploaded custom field file. Please try again.')],
                        ]);
                    }



                    $timestamp = now();

                    $itemCustomFieldValues[] = [

                        'item_id'         => $item->id,
                        'custom_field_id' => $customFieldId,
                        'value'           => $filePath,
                        'created_at'      => $timestamp,
                        'updated_at'      => $timestamp,
                    ];
                }

                if (count($itemCustomFieldValues) > 0) {
                    ItemCustomFieldValue::insert($itemCustomFieldValues);
                }
            }


            ++$user_package->used_limit;
            $user_package->save();



            // Add where condition here
            $result = Item::with(
                'user:id,name,email,mobile,profile,country_code',
                'category:id,name,image',
                'gallery_images:id,image,item_id,thumbnail_url,detail_image_url',
                'featured_items',
                'favourites',
                'item_custom_field_values.custom_field',
                'area'
            )->where('id', $item->id)->get();
            $result = new ItemCollection($result);

            DB::commit();
            ResponseService::successResponse("Item Added Successfully", $result);
        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, "API Controller -> addItem");
            ResponseService::errorResponse();
        }
    }


    public function getItem(Request $request) {
                if ($request->query->has('view')) {
            $request->query->set('view', strtolower((string) $request->query('view')));
        }
        $validator = Validator::make($request->all(), [
            'limit'          => 'nullable|integer',
            'offset'         => 'nullable|integer',
            'per_page'       => 'nullable|integer',
            'id'             => 'nullable',
            'custom_fields'  => 'nullable',
            'category_id'    => 'nullable',
            'category_ids'   => 'nullable|array',
            'category_ids.*' => 'integer',
            'store_id'       => 'nullable|integer|exists:stores,id',
            'user_id'        => 'nullable',
            'min_price'      => 'nullable',
            'max_price'      => 'nullable',
            'sort_by'        => [
                'nullable',
                Rule::in([
                    'latest',
                    'most_viewed',
                    'new-to-old',
                    'old-to-new',
                    'price-high-to-low',
                    'price-low-to-high',
                    'default',
                ]),
            ],
            
            'posted_since'   => 'nullable|in:all-time,today,within-1-week,within-2-week,within-1-month,within-3-month',
            'promoted'       => 'nullable|boolean',
            'interface_type' => ['nullable', Rule::in(self::interfaceTypes(includeLegacy: true))],
            'view'           => ['nullable', Rule::in(['summary', 'detail'])],
            'sw_lat'         => ['nullable', 'numeric', 'between:-90,90'],
            'sw_lng'         => ['nullable', 'numeric', 'between:-180,180'],
            'ne_lat'         => ['nullable', 'numeric', 'between:-90,90'],
            'ne_lng'         => ['nullable', 'numeric', 'between:-180,180'],


        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            //TODO : need to simplify this whole module

            $viewMode = strtolower((string) $request->query('view', 'detail'));
            $isSummaryView = $viewMode === 'summary';
            $isDetailView = ! $isSummaryView;

            if ($isSummaryView) {
                Log::info('getItem.params', $request->all());
            }

            // If this is an e_store context and store_id is missing, infer it from user_id
            if ($request->interface_type === 'e_store'
                && ! $request->filled('store_id')
                && $request->filled('user_id')) {
                $storeIdGuess = Store::where('user_id', $request->input('user_id'))
                    ->value('id');
                if ($storeIdGuess) {
                    $request->merge(['store_id' => $storeIdGuess]);
                }
            }

            // Prevent leaking cross-store items: if e_store context without store/user, return empty.
            if ($request->interface_type === 'e_store'
                && ! $request->filled('store_id')
                && ! $request->filled('user_id')) {
                return ResponseService::successResponse('OK', [
                    'data' => [],
                    'total' => 0,
                ]);
            }

            // Hard guard: in e_store context, enforce store or user filter.
            if ($request->interface_type === 'e_store') {
                if ($request->filled('store_id')) {
                    $request->merge(['store_id' => (int) $request->input('store_id')]);
                } elseif ($request->filled('user_id')) {
                    $request->merge(['user_id' => (int) $request->input('user_id')]);
                }
            }

            // Extra guard for store category requests (storefront root category = 3):
            if ((string) $request->input('category_id') === '3'
                && ! $request->filled('store_id')
                && ! $request->filled('user_id')) {
                return ResponseService::successResponse('OK', [
                    'data' => [],
                    'total' => 0,
                ]);
            }


            $interfaceTypeFilter = null;
            $interfaceTypeVariants = [];

            if ($request->filled('interface_type')) {
                $interfaceTypeFilter = InterfaceSectionService::normalizeSectionType($request->input('interface_type'));

                if ($interfaceTypeFilter !== null && $interfaceTypeFilter !== 'all') {
                    $interfaceTypeVariants = InterfaceSectionService::sectionTypeVariants($interfaceTypeFilter);
                }
            }


            $promotedFilter = null;

            if ($request->filled('promoted')) {
                $promotedFilter = filter_var($request->promoted, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            }


            $summarySelectColumns = $this->filterItemSelectColumns([
                'items.id',
                'items.name',
                'items.slug',
                'items.price',
                'items.currency',
                'items.thumbnail_url',
                'items.image',
                'items.created_at',
                'items.updated_at',
                'items.city',
                'items.state',
                'items.country',
                'items.address',
                'items.latitude',
                'items.longitude',
                'items.status',
                'items.interface_type',
                'items.item_type',
                'items.user_id',
                'items.category_id',
                'items.product_link',
                'items.discount_type',
                'items.discount_value',
                'items.discount_start',
                'items.discount_end',
                'items.clicks',
            ]);



            $detailRelations = [
                'user:id,name,email,mobile,profile,created_at,is_verified,show_personal_details,country_code,account_type',
                'user.latestApprovedVerificationRequest:id,user_id,expires_at,status,approved_at',
                'category:id,name,image',
                'gallery_images:id,image,item_id,thumbnail_url,detail_image_url',
                'featured_items',
                'favourites',
                'item_custom_field_values.custom_field',
                'area:id,name',
                'store:id,name,slug',
                'store.policies:id,store_id,policy_type,title,content,is_required,is_active,display_order',
            ];

            if ($isDetailView) {
                $sql = Item::with($detailRelations)
                    ->withCount('favourites')
                    ->withAvg('review as ratings_avg', 'ratings')
                    ->withCount('review as ratings_count')
                    ->select('items.*');
            } else {
                $sql = Item::query()
                    ->select($summarySelectColumns)
                    ->withCount('featured_items as featured_items_count')
                    ->withCount('favourites as favourites_count');

                if (Auth::check()) {
                    $sql->withExists([
                        'favourites as is_favorited' => static function ($query) {
                            $query->where('user_id', Auth::id());
                        },
                    ]);
                }

            }

            $sql = $sql


                ->when($request->id, function ($sql) use ($request) {
                    $sql->where('id', $request->id);
                })->when(($request->category_id), function ($sql) use ($request) {
                    $category = Category::where('id', $request->category_id)->with('children')->get();
                    $categoryIDS = HelperService::findAllCategoryIds($category);
                    return $sql->whereIn('category_id', $categoryIDS);
                })->when(($request->category_slug), function ($sql) use ($request) {
                    $category = Category::where('slug', $request->category_slug)->with('children')->get();
                    $categoryIDS = HelperService::findAllCategoryIds($category);
                    return $sql->whereIn('category_id', $categoryIDS);


                    })->when($request->filled('category_ids'), function ($sql) use ($request) {
                    $categoryIds = $request->category_ids;
                    if (!is_array($categoryIds)) {
                        $categoryIds = array_filter(explode(',', (string) $categoryIds));
                    }
                    $categoryIds = array_values(array_filter(array_map('intval', $categoryIds)));

                    if (empty($categoryIds)) {
                        return $sql;
                    }

                    return $sql->whereIn('category_id', $categoryIds);
                })->when($interfaceTypeFilter !== null, static function ($sql) use ($interfaceTypeFilter, $interfaceTypeVariants) {
                    if ($interfaceTypeFilter === 'all') {
                        return $sql;
                    }

                    return $sql->whereIn('interface_type', $interfaceTypeVariants);
                })->when($promotedFilter === true, function ($sql) {
                    return $sql->whereHas('featured_items');


                })->when((isset($request->min_price) || isset($request->max_price)), function ($sql) use ($request) {
                    $min_price = $request->min_price ?? 0;
                    $max_price = $request->max_price ?? Item::max('price');
                    return $sql->whereBetween('price', [$min_price, $max_price]);
                })->when($request->posted_since, function ($sql) use ($request) {
                    return match ($request->posted_since) {
                        "today" => $sql->whereDate('created_at', '>=', now()),
                        "within-1-week" => $sql->whereDate('created_at', '>=', now()->subDays(7)),
                        "within-2-week" => $sql->whereDate('created_at', '>=', now()->subDays(14)),
                        "within-1-month" => $sql->whereDate('created_at', '>=', now()->subMonths()),
                        "within-3-month" => $sql->whereDate('created_at', '>=', now()->subMonths(3)),
                        default => $sql
                    };
                // Remove location filtering to show all items regardless of location
                // })->when($request->country, function ($sql) use ($request) {
                //     return $sql->where('country', $request->country);
                // })->when($request->state, function ($sql) use ($request) {
                //     return $sql->where('state', $request->state);
                // })->when($request->city, function ($sql) use ($request) {
                //     return $sql->where('city', $request->city);
                // })->when($request->area_id, function ($sql) use ($request) {
                //     return $sql->where('area_id', $request->area_id);
                })->when($request->user_id, function ($sql) use ($request) {
                    return $sql->where('user_id', $request->user_id);
                })->when($request->store_id, function ($sql) use ($request) {
                    return $sql->where('store_id', $request->store_id);
                })->when($request->slug, function ($sql) use ($request) {
                    return $sql->where('slug', $request->slug);
                })->when($this->requestHasBoundingBox($request), function ($sql) use ($request) {
                    return $this->applyBoundingBoxFilter($sql, $request);

                // Remove radius/location-based filtering to show all items
                // })->when($request->latitude && $request->longitude && $request->radius, function ($sql) use ($request) {
                //     $latitude = $request->latitude;
                //     $longitude = $request->longitude;
                //     $radius = $request->radius;

                //     // Calculate distance using Haversine formula
                //     $haversine = "(6371 * acos(cos(radians($latitude))
                //                     * cos(radians(latitude))
                //                     * cos(radians(longitude)
                //                     - radians($longitude))
                //                     + sin(radians($latitude))
                //                     * sin(radians(latitude))))";

                //     $sql->select('items.*')
                //         ->selectRaw("{$haversine} AS distance")
                //         ->withCount('favourites')
                //         ->where('latitude', '!=', 0)
                //         ->where('longitude', '!=', 0)
                //         ->having('distance', '<', $radius)
                //         ->orderBy('distance', 'asc');
                });


            //            // Other users should only get approved items
            //            if (!Auth::check()) {
            //                $sql->where('status', 'approved');
            //            }


            // Sort By
            $sortBy = $request->sort_by;


            $sql = match ($sortBy) {
                'most_viewed' => $sql->orderBy('clicks', 'DESC'),

                'old-to-new' => $sql->orderBy('created_at'),
                'price-high-to-low' => $sql->orderByDesc('price'),
                'price-low-to-high' => $sql->orderBy('price'),
                null, 'default', 'latest', 'new-to-old' => $sql->orderByDesc('created_at'),
                default => $sql->orderByDesc('created_at'),
            };


            // Status
            if (!empty($request->status)) {
                if (in_array($request->status, array('review', 'approved', 'rejected', 'sold out'))) {
                    $sql->where('status', $request->status);
                } elseif ($request->status == 'inactive') {
                    //If status is inactive then display only trashed items
                    $sql->onlyTrashed();
                } elseif ($request->status == 'featured') {
                    //If status is featured then display only featured items
                    $sql->where('status', 'approved')->has('featured_items');
                }
            }

            // Feature Section Filtration
            if (!empty($request->featured_section_id) || !empty($request->featured_section_slug)) {
                $supportedFilters = config('interface_sections.default_filters', ['latest']);
                if (!is_array($supportedFilters) || $supportedFilters === []) {
                    $supportedFilters = ['latest'];
                }

                $filter = $request->input('featured_filter');
                if (!is_string($filter) || $filter === '') {
                    $filter = $supportedFilters[0] ?? 'latest';
                }

                $filter = strtolower($filter);
                if (!in_array($filter, $supportedFilters, true)) {
                    $filter = $supportedFilters[0] ?? 'latest';
                }

                $sql = match ($filter) {
                    'most_viewed' => $sql->reorder()->orderBy('clicks', 'DESC'),
                    'price_high_to_low', 'price-high-to-low' => $sql->reorder()->orderBy('price', 'DESC'),
                    'price_low_to_high', 'price-low-to-high' => $sql->reorder()->orderBy('price', 'ASC'),
                    default => $sql->reorder()->orderBy('created_at', 'DESC'),
                };
            }


            if (!empty($request->search)) {
                $sql->search($request->search);
            }

            if (!empty($request->custom_fields)) {
                $sql->whereHas('item_custom_field_values', function ($q) use ($request) {
                    $having = '';
                    foreach ($request->custom_fields as $id => $value) {
                        foreach (explode(",", $value) as $column_value) {
                            $having .= "WHEN custom_field_id = $id AND value LIKE \"%$column_value%\" THEN custom_field_id ";
                        }
                    }
                    $q->where(function ($q) use ($request) {
                        foreach ($request->custom_fields as $id => $value) {
                            $q->orWhere(function ($q) use ($id, $value) {
                                foreach (explode(",", $value) as $value) {
                                    $q->where('custom_field_id', $id)->where('value', 'LIKE', "%" . $value . "%");
                                }
                            });
                        }
                    })->groupBy('item_id')->having(DB::raw("COUNT(DISTINCT CASE $having END)"), '=', count($request->custom_fields));
                });
            }
            if ($isDetailView && Auth::check()) {
                $sql->with(['item_offers' => function ($q) {
                    $q->where('buyer_id', Auth::user()->id);
                }, 'user_reports'         => function ($q) {
                    $q->where('user_id', Auth::user()->id);
                }]);

                $currentURI = explode('?', $request->getRequestUri(), 2);

                if ($currentURI[0] == "/api/my-items") { //TODO: This if condition is temporary fix. Need something better
                    $sql->where(['user_id' => Auth::user()->id])->withTrashed();
                } else {
                    $sql->where('status', 'approved')->has('user')->onlyNonBlockedUsers()->getNonExpiredItems();
                }
            } else {
                //  Other users should only get approved items
                $sql->where('status', 'approved')->getNonExpiredItems();
            }
            
            $perPage = $this->resolvePerPage($request, 15, 60);
            if (!empty($request->id)) {
                /*
                 * Collection does not support first OR find method's result as of now. It's a part of R&D
                 * So currently using this shortcut method get() to fetch the first data
                 */
                $result = $sql->get();
                if (count($result) == 0) {
                    ResponseService::errorResponse("No item Found");
                }
            } else {
                $result = $sql->paginate($perPage);


            }


            //                // Add three regular items
            //                for ($i = 0; $i < 3 && $regularIndex < $regularItemCount; $i++) {
            //                    $items->push($regularItems[$regularIndex]);
            //                    $regularIndex++;
            //                }
            //
            //                // Add one featured item if available
            //                if ($featuredIndex < $featuredItemCount) {
            //                    $items->push($featuredItems[$featuredIndex]);
            //                    $featuredIndex++;
            //                }
            //            }
            // Return success response with the fetched items
            if ($isSummaryView) {
                $collection = $result instanceof AbstractPaginator ? $result->getCollection() : collect($result);

                $etagPayload = [];
                $latestUpdatedAt = null;

                if ($collection->isNotEmpty()) {
                    $latestUpdatedAt = $collection
                        ->map(static fn ($item) => $item->updated_at)
                        ->filter()
                        ->max();
                }

                $sortedFilters = $request->query();
                if (is_array($sortedFilters)) {
                    ksort($sortedFilters);
                } else {
                    $sortedFilters = [];
                }

                try {
                    $etagPayload = json_encode([
                        'view' => 'summary',
                        'filters' => $sortedFilters,
                        'items' => $collection->map(static function ($item) {
                            return [
                                'id' => $item->id,
                                'updated_at' => optional($item->updated_at)->toJSON(),
                            ];
                        })->values()->all(),
                    ], JSON_THROW_ON_ERROR);
                } catch (JsonException) {
                    $etagPayload = json_encode([
                        'view' => 'summary',
                        'filters' => [],
                        'items' => $collection->map(static function ($item) {
                            return [
                                'id' => $item->id,
                                'updated_at' => optional($item->updated_at)->timestamp,
                            ];
                        })->values()->all(),
                    ]);
                }

                $etag = '"' . sha1((string) $etagPayload) . '"';

                $lastModifiedHeader = null;

                if ($latestUpdatedAt instanceof Carbon) {
                    $lastModifiedHeader = $latestUpdatedAt->copy()->setTimezone('UTC')->toRfc7231String();
                }

                $ifNoneMatch = $request->headers->get('If-None-Match');
                $etagMatches = false;

                if ($ifNoneMatch !== null) {
                    $candidateEtags = array_map('trim', explode(',', $ifNoneMatch));
                    $etagMatches = in_array('*', $candidateEtags, true) || in_array($etag, $candidateEtags, true);
                }

                $ifModifiedSince = $request->headers->get('If-Modified-Since');
                $modifiedSinceMatches = false;

                if ($ifNoneMatch === null && $ifModifiedSince !== null && $lastModifiedHeader !== null) {
                    $modifiedSince = strtotime($ifModifiedSince);
                    $lastModifiedTime = strtotime($lastModifiedHeader);

                    if ($modifiedSince !== false && $lastModifiedTime !== false) {
                        $modifiedSinceMatches = $modifiedSince >= $lastModifiedTime;
                    }
                }

                if ($etagMatches || $modifiedSinceMatches) {
                    $response = response()->noContent(HttpResponse::HTTP_NOT_MODIFIED);
                    $response->setEtag($etag);

                    if ($lastModifiedHeader !== null) {
                        $response->headers->set('Last-Modified', $lastModifiedHeader);
                    }

                    return $response;
                }

                $summaryData = $this->formatSummaryResult($result);

                $payload = [
                    'error' => false,
                    'message' => trans('Item Fetched Successfully'),
                    'data' => $summaryData,
                    'code' => config('constants.RESPONSE_CODE.SUCCESS'),
                ];

                $response = response()->json($payload);
                $response->setEtag($etag);

                if ($lastModifiedHeader !== null) {
                    $response->headers->set('Last-Modified', $lastModifiedHeader);
                }

                return $response;
            }

            $payload = [
                'error' => false,
                'message' => trans('Item Fetched Successfully'),
                'data' => (new ItemCollection($result))->toArray($request),
                'code' => config('constants.RESPONSE_CODE.SUCCESS'),
            ];

            return response()->json($payload);
        
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getItem");
            ResponseService::errorResponse();
        }
    }


    /**
     * @param  AbstractPaginator|Collection  $result
     */
    protected function formatSummaryResult($result): array
    {
        $transformItem = static function (Item $item): array {
            $thumbnail = $item->thumbnail_url ?? $item->image;
            $finalPrice = $item->calculateDiscountedPrice();
            $discountSnapshot = $item->discount_snapshot;
            $featuredCount = $item->featured_items_count ?? 0;
            $favouritesCount = $item->favourites_count ?? 0;
            $isFavorited = $item->getAttribute('is_favorited');
            if ($isFavorited === null) {
                $isFavorited = $item->is_favorited ?? null;
            }

            $isLiked = (bool) ($isFavorited ?? false);

            return [
                'id' => $item->id,
                'name' => $item->name,
                'slug' => $item->slug,
                'price' => $item->price,
                'final_price' => $finalPrice,
                'currency' => $item->currency,
                'thumbnail_url' => $thumbnail,
                'thumbnail_fallback_url' => $item->image,
                'image' => $item->image,
                'created_at' => optional($item->created_at)->toIso8601String(),
                'updated_at' => optional($item->updated_at)->toIso8601String(),
                'city' => $item->city,
                'state' => $item->state,
                'country' => $item->country,
                'address' => $item->address,
                'latitude' => $item->latitude,
                'longitude' => $item->longitude,
                'status' => $item->status,
                'type' => $item->getAttribute('type') ?? $item->item_type ?? $item->interface_type,
                'item_type' => $item->item_type,
                'user_id' => $item->user_id,
                'category_id' => $item->category_id,
                'product_link' => $item->product_link,
                'discount' => $discountSnapshot,
                'total_likes' => (int) $favouritesCount,
                'is_liked' => $isLiked,
                'is_feature' => (int) $featuredCount > 0,
                'clicks' => $item->clicks,
            ];

        };

        if ($result instanceof AbstractPaginator) {
            $collection = $result->getCollection();
            $items = $collection->map($transformItem)->values()->all();
            $paginatorArray = $result->toArray();

            $meta = [
                'current_page' => $paginatorArray['current_page'] ?? null,
                'from' => $paginatorArray['from'] ?? null,
                'last_page' => $paginatorArray['last_page'] ?? null,
                'per_page' => $paginatorArray['per_page'] ?? null,
                'to' => $paginatorArray['to'] ?? null,
                'total' => $paginatorArray['total'] ?? null,
            ];

            if (method_exists($result, 'hasMorePages')) {
                $meta['has_more_pages'] = $result->hasMorePages();
            }

            if (method_exists($result, 'hasPages')) {
                $meta['has_pages'] = $result->hasPages();
            }

            $links = [
                'first_page_url' => $paginatorArray['first_page_url'] ?? null,
                'last_page_url' => $paginatorArray['last_page_url'] ?? null,
                'next_page_url' => $paginatorArray['next_page_url'] ?? null,
                'prev_page_url' => $paginatorArray['prev_page_url'] ?? null,
                'path' => $paginatorArray['path'] ?? null,
            ];

            $pagination = array_merge($meta, $links);
            $pagination['links'] = $paginatorArray['links'] ?? [];

            return [
                'items' => $items,
                'meta' => $meta,
                'links' => $links,
                'link_items' => $paginatorArray['links'] ?? [],
                'pagination' => $pagination,
            ];
        }

        if ($result instanceof Collection) {
            return [
                'items' => $result->map($transformItem)->values()->all(),
            ];
        }

        return ['items' => collect($result)->map($transformItem)->values()->all()];
    }


    public function getAllowedSections(Request $request, DelegateAuthorizationService $delegateAuthorizationService)
    {
        $user = $request->user();

        if (! $user instanceof User) {
            return response()->json([
                'permitted_sections' => [],
                'blocked_sections' => [],
            ]);
        }

        $access = $delegateAuthorizationService->getSectionAccessForUser($user);

        return response()->json([
            'permitted_sections' => $access['permitted'],
            'blocked_sections' => $access['blocked'],
        ]);
    }


    
    public function updateItem(Request $request) {

        $categoryInput = $request->input('category_id');
        $item = null;

        if (! is_numeric($categoryInput) && $request->filled('id')) {
            $item = Item::owner()->find($request->input('id'));
            $categoryInput = $item?->category_id;
        }

        $categoryId = is_numeric($categoryInput) ? (int) $categoryInput : null;
        $requiresProductLink = $this->shouldRequireProductLink($categoryId);

        $validator = Validator::make($request->all(), [
            'id'                   => 'required',
            'name'                 => 'nullable',
            // 'slug'                 => 'regex:/^[a-z0-9-]+$/',
            'price'                => 'nullable',
            'description'          => 'nullable',
            'latitude'             => 'nullable',
            'longitude'            => 'nullable',
            'address'              => 'nullable',
            'contact'              => 'nullable',
            'image'                => 'nullable|mimes:jpeg,jpg,png|max:4096',
            'custom_fields'        => 'nullable',
            'custom_field_files'   => 'nullable|array',
            'custom_field_files.*' => 'nullable|mimes:jpeg,png,jpg,pdf,doc|max:4096',
            'gallery_images'       => 'nullable|array',
            'currency'             => 'required',
            'product_link'         => [
                'nullable',
                'url',
                'max:2048',
                Rule::requiredIf($requiresProductLink),
            ],
            'review_link'          => 'nullable|url|max:2048',
        
         ]);

        if ($validator->fails()) {
            ResponseService::validationErrors($validator->errors());

        }


        $item ??= Item::owner()->findOrFail($request->id);

        if ($categoryId === null) {
            $categoryId = (int) $item->category_id;
        }

        $currentSection = $this->resolveSectionByCategoryId($item->category_id);
        $updateAuthorization = Gate::inspect('section.update', $currentSection);

        if ($updateAuthorization->denied()) {
            $message = $updateAuthorization->message() ?? SectionDelegatePolicy::FORBIDDEN_MESSAGE;

            ResponseService::errorResponse($message, null, 403);
        }

        $targetSection = $this->resolveSectionByCategoryId($categoryId);

        if ($targetSection !== $currentSection) {
            $changeAuthorization = Gate::inspect('section.change', [$currentSection, $targetSection]);

            if ($changeAuthorization->denied()) {
                $message = $changeAuthorization->message() ?? SectionDelegatePolicy::FORBIDDEN_MESSAGE;

                ResponseService::errorResponse($message, null, 403);
            }
        }


        DB::beginTransaction();

        try {


            // $slug = $request->input('slug', $item->slug);
            // $uniqueSlug = HelperService::generateUniqueSlug(new Item(), $slug,$request->id);

            $data = $request->all();


           if (array_key_exists('price', $data)) {
                $priceInput = $data['price'];
                if ($priceInput === null || $priceInput === '') {
                    unset($data['price']);
                } else {
                    $normalizedPrice = $priceInput;
                    if (is_string($priceInput)) {
                        $normalizedPrice = preg_replace(
                            '/[^0-9.]/',
                            '',
                            str_replace(',', '', $priceInput)
                        );
                    }

                    if ($normalizedPrice === null || $normalizedPrice === '') {
                        unset($data['price']);
                    } else {
                        $data['price'] = (float) $normalizedPrice;
                    }
                }
            }

            $data['product_link'] = $request->filled('product_link') ? $request->input('product_link') : null;
            $data['review_link'] = $request->filled('review_link') ? $request->input('review_link') : null;


            // $data['slug'] = $uniqueSlug;
            if ($request->hasFile('image')) {
                try {
                    $variants = ImageVariantService::storeWithVariants($request->file('image'), $this->uploadFolder);
                } catch (Throwable $exception) {
                    ResponseService::validationErrors([
                        'image' => [__('Unable to process the uploaded image. Please try again with a different file.')],
                    ]);
                }

                ImageVariantService::deleteStoredVariants([
                    $item->getRawOriginal('image'),
                    $item->getRawOriginal('thumbnail_url'),
                    $item->getRawOriginal('detail_image_url'),
                ]);

                $data['image'] = $variants['original'];
                $data['thumbnail_url'] = $variants['thumbnail'];
                $data['detail_image_url'] = $variants['detail'];
            
            }

            $item->update($data);

            //Update Custom Field values for item
            if ($request->custom_fields) {
                $itemCustomFieldValues = [];
                // Handle both JSON string and array formats
                $customFields = is_string($request->custom_fields) 
                    ? json_decode($request->custom_fields, true, 512, JSON_THROW_ON_ERROR) 
                    : $request->custom_fields;
                    
                foreach ($customFields as $key => $custom_field) {
                    $itemCustomFieldValues[] = [
                        'item_id'         => $item->id,
                        'custom_field_id' => $key,
                        'value'           => json_encode($custom_field, JSON_THROW_ON_ERROR),
                        'updated_at'      => now()

                    ];
                }

                if (count($itemCustomFieldValues) > 0) {
                    ItemCustomFieldValue::upsert($itemCustomFieldValues, ['item_id', 'custom_field_id'], ['value', 'updated_at']);
                }
            }

            //Add new gallery images
            if ($request->hasFile('gallery_images')) {
                $galleryImages = [];
                foreach ($request->file('gallery_images') as $file) {

                    try {
                        $galleryVariants = ImageVariantService::storeWithVariants($file, $this->uploadFolder);
                    } catch (Throwable $exception) {
                        ResponseService::validationErrors([
                            'gallery_images' => [__('Unable to process one of the gallery images. Please verify the files and retry.')],
                        ]);
                    }

                    $galleryImages[] = [
                        'image'      => $galleryVariants['original'],
                        'thumbnail_url' => $galleryVariants['thumbnail'],
                        'detail_image_url' => $galleryVariants['detail'],
                        'item_id'    => $item->id,
                        'created_at' => time(),
                        'updated_at' => time(),
                    ];
                }
                if (count($galleryImages) > 0) {
                    ItemImages::insert($galleryImages);
                }
            }

            if ($request->custom_field_files) {
                $itemCustomFieldValues = [];
                foreach ($request->custom_field_files as $key => $file) {
                    $value = ItemCustomFieldValue::where(['item_id' => $item->id, 'custom_field_id' => $key])->first();
                    if (!empty($value)) {
                        $file = FileService::replace($file, 'custom_fields_files', $value->getRawOriginal('value'));
                    } else {
                        $file = '';
                    }
                    $itemCustomFieldValues[] = [
                        'item_id'         => $item->id,
                        'custom_field_id' => $key,
                        'value'           => $file,
                        'updated_at'      => time()
                    ];
                }

                if (count($itemCustomFieldValues) > 0) {
                    ItemCustomFieldValue::upsert($itemCustomFieldValues, ['item_id', 'custom_field_id'], ['value', 'updated_at']);
                }
            }

            //Delete gallery images
            if (!empty($request->delete_item_image_id)) {
                $item_ids = explode(',', $request->delete_item_image_id);
                foreach (ItemImages::whereIn('id', $item_ids)->get() as $itemImage) {
                    ImageVariantService::deleteStoredVariants([
                        $itemImage->getRawOriginal('image'),
                        $itemImage->getRawOriginal('thumbnail_url'),
                        $itemImage->getRawOriginal('detail_image_url'),
                    ]);
                    
                    $itemImage->delete();
                }
            }

            $result = Item::with('user:id,name,email,mobile,profile,country_code', 'category:id,name,image', 'gallery_images:id,image,item_id,thumbnail_url,detail_image_url', 'featured_items', 'favourites', 'item_custom_field_values.custom_field', 'area')->where('id', $item->id)->get();
            /*
             * Collection does not support first OR find method's result as of now. It's a part of R&D
             * So currently using this shortcut method
            */
            $result = new ItemCollection($result);


            DB::commit();
            ResponseService::successResponse("Item Fetched Successfully", $result);
        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, "API Controller -> updateItem");
            ResponseService::errorResponse();
        }
    }

    public function deleteItem(Request $request) {
        try {

            $validator = Validator::make($request->all(), [
                'id' => 'required',
            ]);
            if ($validator->fails()) {
                ResponseService::errorResponse($validator->errors()->first());
            }
            $item = Item::owner()->with('gallery_images')->withTrashed()->findOrFail($request->id);
            ImageVariantService::deleteStoredVariants([
                $item->getRawOriginal('image'),
                $item->getRawOriginal('thumbnail_url'),
                $item->getRawOriginal('detail_image_url'),
            ]);
            if (count($item->gallery_images) > 0) {
                foreach ($item->gallery_images as $value) {
                    ImageVariantService::deleteStoredVariants([
                        $value->getRawOriginal('image'),
                        $value->getRawOriginal('thumbnail_url'),
                        $value->getRawOriginal('detail_image_url'),
                    ]);
                }
            }

            $item->forceDelete();
            ResponseService::successResponse("Item Deleted Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> deleteItem");
            ResponseService::errorResponse();
        }
    }

    public function updateItemStatus(Request $request) {
        $validator = Validator::make($request->all(), [
            'item_id' => 'required|integer',
            'status'  => 'required|in:sold out,inactive,active',
            // 'sold_to' => 'required_if:status,==,sold out|integer'
            'sold_to' => 'nullable|integer'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {


            $interfaceTypeFilter = null;
            $interfaceTypeVariants = [];

            if ($request->filled('interface_type')) {
                $interfaceTypeFilter = InterfaceSectionService::normalizeSectionType($request->input('interface_type'));

                if ($interfaceTypeFilter !== 'all') {
                    $interfaceTypeVariants = InterfaceSectionService::sectionTypeVariants($interfaceTypeFilter);
                }
            }

            $item = Item::owner()->whereNotIn('status', ['review', 'rejected'])->withTrashed()->findOrFail($request->item_id);
            
            $section = $this->resolveSectionByCategoryId($item->category_id);
            $authorization = Gate::inspect('section.update', $section);

            if ($authorization->denied()) {
                $message = $authorization->message() ?? SectionDelegatePolicy::FORBIDDEN_MESSAGE;

                ResponseService::errorResponse($message, null, 403);
            }


            if ($request->status == "inactive") {
                $item->delete();
            } else if ($request->status == "active") {
                $item->restore();
                $status = $this->resolveInitialItemStatus(Auth::user(), $section);
                $item->update(['status' => $status]);

            } else if ($request->status == "sold out") {
                $item->update([
                    'status'  => 'sold out',
                    'sold_to' => $request->sold_to
                ]);
            } else {
                $item->update(['status' => $request->status]);
            }
            ResponseService::successResponse('Item Status Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController -> updateItemStatus');
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function getItemBuyerList(Request $request) {
        $validator = Validator::make($request->all(), [
            'item_id' => 'required|integer'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $buyer_ids = ItemOffer::where('item_id', $request->item_id)->select('buyer_id')->pluck('buyer_id');
            $users = User::select(['id', 'name', 'profile'])->whereIn('id', $buyer_ids)->get();
            ResponseService::successResponse('Buyer List fetched Successfully', $users);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'ItemController -> updateItemStatus');
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function getSubCategories(Request $request) {
        $validator = Validator::make($request->all(), [
            'category_id' => 'nullable|integer'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $baseQuery = Category::withCount(['subcategories' => function ($q) {
                $q->where('status', 1);
            }])->with('translations')->where(['status' => 1])->orderBy('sequence', 'ASC')
                ->with(['subcategories'          => function ($query) {
                    $query->where('status', 1)->orderBy('sequence', 'ASC')->with('translations')->withCount(['approved_items', 'subcategories' => function ($q) {
                        $q->where('status', 1);
                    }]); // Order subcategories by 'sequence'
                }, 'subcategories.subcategories' => function ($query) {
                    $query->where('status', 1)->orderBy('sequence', 'ASC')->with('translations')->withCount(['approved_items', 'subcategories' => function ($q) {
                        $q->where('status', 1);
                    }]);
                }]);
            if (!empty($request->category_id)) {
                $category = (clone $baseQuery)
                    ->where('id', $request->category_id)
                    ->firstOrFail();

                $category->all_items_count = $category->all_items_count;

                $childrenPaginator = (clone $baseQuery)
                    ->where('parent_category_id', $request->category_id)
                    ->paginate();

                $childrenPaginator->getCollection()->transform(function ($category) {
                    $category->all_items_count = $category->all_items_count;
                    return $category;
                });

                ResponseService::successResponse(null, $childrenPaginator, [
                    'self_category'  => $category,
                    'append_to_data' => ['self_category' => $category],
                ]);

                return;


            }

            $paginator = $baseQuery->whereNull('parent_category_id')->paginate();
            $paginator->getCollection()->transform(function ($category) {


                $category->all_items_count = $category->all_items_count;
                return $category;
            });
            ResponseService::successResponse(null, $paginator, [
                'self_category'  => null,
                'append_to_data' => ['self_category' => null],
            ]);
        
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getCategories');
            ResponseService::errorResponse();
        }
    }

    public function getParentCategoryTree(Request $request) {
        $validator = Validator::make($request->all(), [
            'child_category_id' => 'nullable|integer',
            'tree'              => 'nullable|boolean',
            'slug'              => 'nullable|string'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $sql = Category::when($request->child_category_id, function ($sql) use ($request) {
                $sql->where('id', $request->child_category_id);
            })
                ->when($request->slug, function ($sql) use ($request) {
                    $sql->where('slug', $request->slug);
                })
                ->firstOrFail()
                ->ancestorsAndSelf()->breadthFirst()->get();
            if ($request->tree) {
                $sql = $sql->toTree();
            }
            ResponseService::successResponse(null, $sql);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getCategories');
            ResponseService::errorResponse();
        }
    }

    public function getNotificationList(Request $request) {
        try {
            $perPage = (int) max(1, min($request->integer('per_page', 20), 50));
            $query = Notifications::query()
                ->where(function ($query) {
                    $query->whereRaw("FIND_IN_SET(" . Auth::user()->id . ",user_id)")
                        ->orWhere('send_to', 'all');
                })
                ->orderByDesc('id');

            if ($request->filled('since')) {
                try {
                    $since = Carbon::parse($request->input('since'));
                    $query->where('created_at', '>=', $since);
                } catch (Throwable $th) {
                    // Ignore invalid date filters to avoid failing the request.
                }
            }

            $notifications = $query->paginate($perPage)
                ->appends($request->only(['per_page', 'page', 'since']));
                
            ResponseService::successResponse("Notification fetched successfully", $notifications);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getNotificationList');
            ResponseService::errorResponse();
        }
    }

    public function getLanguages(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'language_code' => 'required',
                'type'          => 'nullable|in:app,web'
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            $language = Language::where('code', $request->language_code)->firstOrFail();
            if ($request->type == "web") {
                $json_file_path = base_path('resources/lang/' . $request->language_code . '_web.json');
            } else {
                $json_file_path = base_path('resources/lang/' . $request->language_code . '_app.json');
            }

            if (!is_file($json_file_path)) {
                ResponseService::errorResponse("Language file not found");
            }

            $json_string = file_get_contents($json_file_path);
            $json_data = json_decode($json_string, false, 512, JSON_THROW_ON_ERROR);

            if ($json_data == null) {
                ResponseService::errorResponse("Invalid JSON format in the language file");
            }
            $language->file_name = $json_data;

            ResponseService::successResponse("Data Fetched Successfully", $language);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getLanguages");
            ResponseService::errorResponse();
        }
    }


    public function getPaymentSettings() {
        try {
            $manualBanks = ManualBank::where('status', true)
                ->orderBy('display_order')
                ->orderBy('name')
                ->get()
                ->values()
                ->toArray();

            $eastYemenGateway = PaymentConfiguration::query()
                ->where('payment_method', 'east_yemen_bank')
                ->first();



            $eastYemenGatewayData = [
                'payment_method' => 'east_yemen_bank',
                'enabled' => false,
                'status' => false,
                'display_name' => null,
                'note' => null,
                'logo_url' => null,
                'currency_code' => null,
            ];




            if ($eastYemenGateway) {
                $eastYemenGatewayData = array_merge($eastYemenGatewayData, [
                    'enabled' => (bool) $eastYemenGateway->status,
                    'status' => (bool) $eastYemenGateway->status,
                    'display_name' => $eastYemenGateway->display_name,
                    'note' => $eastYemenGateway->note,
                    'logo_url' => $eastYemenGateway->logo_url,
                    'currency_code' => $eastYemenGateway->currency_code,
                ]);
            }



            ResponseService::successResponse(
                "Data Fetched Successfully",
                $manualBanks,
                [
                    'east_yemen_bank' => $eastYemenGatewayData,

                ]
            );
        
        
        
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getPaymentSettings");
            ResponseService::errorResponse();
        }
    }

    public function getCustomFields(Request $request) {
        try {
            $customField = CustomField::whereHas('custom_field_category', function ($q) use ($request) {
                $q->whereIn('category_id', explode(',', $request->input('category_ids')));
            })->where('status', 1)->orderBy('sequence')->orderBy('id')->get();
            ResponseService::successResponse("Data Fetched successfully", $customField);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getCustomFields");
            ResponseService::errorResponse();
        }
    }

    public function makeFeaturedItem(Request $request) {
        $validator = Validator::make($request->all(), [
            'item_id' => 'required|integer',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            DB::beginTransaction(); // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµ: أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€  beginTransaction أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€‌â€ڑ commit
            $user = Auth::user();
            $item = Item::where('user_id', $user->id)->where('status', 'approved')->findOrFail($request->item_id);



            $user_package = UserPurchasedPackage::onlyActive()
                ->where('user_id', $user->id)
                ->whereHas('package', static function ($q) {
                    $q->where(['type' => 'advertisement']);
                })
                ->with('package')
                ->lockForUpdate()
                ->first();

            if (empty($user_package)) {
                DB::rollBack();
                ResponseService::errorResponse("No Active Package found for Featuring Item");
            }

            
            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€‌â€ڑ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€œأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍
            $featuredItems = FeaturedItems::where([
                'item_id'    => $request->item_id,
                'package_id' => $user_package->package_id,
            ])->first();
            
            
            
            if (!empty($featuredItems)) {

                DB::rollBack();

                ResponseService::errorResponse("Item is already featured");
            }

            // أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€œ أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ±
            FeaturedItems::create([
                'item_id'                   => $request->item_id,
                'package_id'                => $user_package->package_id,
                'user_purchased_package_id' => $user_package->id,
                'start_date'                => Carbon::now()->toDateString(),
                'end_date'                  => $user_package->end_date,
            ]);


            ++$user_package->used_limit;
            $user_package->save();


            DB::commit();


            ResponseService::successResponse("Featured Item Created Successfully");




        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, "API Controller -> createAdvertisement");
            ResponseService::errorResponse();
        }
    }

    public function getFeaturedAdsCount(Request $request)
    {
        $user = Auth::user();

        $baseQuery = FeaturedItems::query()
            ->whereHas('item', static function ($query) use ($user): void {
                $query->where('user_id', $user->id);
            });

        $activeCount = (clone $baseQuery)
            ->whereDate('start_date', '<=', now()->toDateString())
            ->where(static function ($query): void {
                $query->whereNull('end_date')
                    ->orWhereDate('end_date', '>=', now()->toDateString());
            })
            ->count();

        $totalCount = $baseQuery->count();

        return response()->json([
            'error' => false,
            'message' => __('Featured ads count fetched successfully.'),
            'data' => [
                'featured_count' => $activeCount,
                'active' => $activeCount,
                'total' => $totalCount,
            ],
            'count' => $activeCount,
        ]);
    }

    public function unfeatureAd(Request $request, Item $item)
    {
        $user = Auth::user();

        if ((int) $item->user_id !== (int) $user->id) {
            ResponseService::errorResponse(__('You are not allowed to manage this advertisement.'), null, 403);
        }

        $featuredItems = FeaturedItems::query()
            ->where('item_id', $item->getKey())
            ->get();

        if ($featuredItems->isEmpty()) {
            ResponseService::errorResponse(__('This advertisement is not currently featured.'), null, 422);
        }

        DB::transaction(static function () use ($featuredItems): void {
            foreach ($featuredItems as $featured) {
                $packageId = $featured->user_purchased_package_id;
                $featured->delete();

                if ($packageId) {
                    $package = UserPurchasedPackage::find($packageId);
                    if ($package) {
                        $newUsedLimit = max(0, (int) $package->used_limit - 1);
                        $package->forceFill(['used_limit' => $newUsedLimit])->save();
                    }
                }
            }
        });

        ResponseService::successResponse(__('Featured advertisement removed successfully.'));
    }


    public function manageFavourite(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'item_id' => 'required',
            ]);
            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            $favouriteItem = Favourite::where('user_id', Auth::user()->id)->where('item_id', $request->item_id)->first();
            if (empty($favouriteItem)) {
                $favouriteItem = new Favourite();
                $favouriteItem->user_id = Auth::user()->id;
                $favouriteItem->item_id = $request->item_id;
                $favouriteItem->save();
                ResponseService::successResponse("Item added to Favourite");
            } else {
                $favouriteItem->delete();
                ResponseService::successResponse("Item remove from Favourite");
            }
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> manageFavourite");
            ResponseService::errorResponse();
        }
    }

    public function getFavouriteItem(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'page' => 'nullable|integer',
            ]);
            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            $favouriteItemIDS = Favourite::where('user_id', Auth::user()->id)->select('item_id')->pluck('item_id');
            $items = Item::whereIn('id', $favouriteItemIDS)
                ->with('user:id,name,email,mobile,profile,country_code', 'category:id,name,image', 'gallery_images:id,image,item_id,thumbnail_url,detail_image_url', 'featured_items', 'favourites', 'item_custom_field_values.custom_field')->where('status', '<>', 'sold out')->paginate();

            ResponseService::successResponse("Data Fetched Successfully", new ItemCollection($items));
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getFavouriteItem");
            ResponseService::errorResponse();
        }
    }

    public function getSlider(Request $request, SliderEligibilityService $sliderEligibilityService) {
        try {
            $now = Carbon::now();


            $requestedInterfaceType = (string) $request->input('interface_type', 'all');

            if ($requestedInterfaceType !== '') {
                $requestedInterfaceType = trim($requestedInterfaceType);
            }

            if ($requestedInterfaceType === '') {
                $requestedInterfaceType = 'all';
            }

            if ($requestedInterfaceType !== 'all') {
                $normalizedInterfaceType = InterfaceSectionService::normalizeSectionType($requestedInterfaceType);
                $interfaceTypes = array_values(array_unique(array_merge(
                    ['all'],
                    InterfaceSectionService::sectionTypeVariants($normalizedInterfaceType)
                )));
            } else {
                $interfaceTypes = ['all'];
                $normalizedInterfaceType = 'all';


            }



            $rows = Slider::with([
                'model' => function (MorphTo $morphTo) {
                    
                    $morphTo->constrain([Category::class => function ($query) {
                    $query->withCount('subcategories');
                }]);
                },
                'target',
            ])
                ->whereIn('interface_type', $interfaceTypes)
                ->eligibleAt($now)
                ->orderByPriority()
                ->get();

            $user = $request->user() ?? Auth::user();
            $userId = $user?->getAuthIdentifier();

            $sessionId = $this->resolveSliderSessionId($request);


            $eligibleSliders = $sliderEligibilityService->selectEligibleSliders($rows, $userId, $sessionId, $now);
            if ($eligibleSliders->isNotEmpty()) {
                $eligibleSliders->each(fn (Slider $slider) => $slider->loadMissing(['model', 'target']));

                ResponseService::successResponse(
                    'Sliders fetched successfully.',
                    SliderResource::collection($eligibleSliders)
                );

                return;
            }


            ResponseService::successResponse(
                null,
                $sliderEligibilityService->fallbackPayload($normalizedInterfaceType ?? 'all')
            );

            return;

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getSlider");
            ResponseService::errorResponse();
        }
    }

    public function getFeaturedSections(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'interface_type' => ['nullable', 'string', 'max:191'],
            'section_type'   => ['nullable', 'string', 'max:191'],
            'slug'           => ['nullable', 'string', 'max:191'],
            'limit'          => ['nullable', 'integer', 'min:1', 'max:50'],
            'filters'        => ['nullable'],
            'filters.*'      => ['nullable', 'string', 'max:191'],
            'page'           => ['nullable', 'integer', 'min:1'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $defaultFilters = config('interface_sections.default_filters', ['latest']);
            if (! is_array($defaultFilters) || $defaultFilters === []) {
                $defaultFilters = ['latest'];
            }
            $filterPool = array_values(array_unique(array_merge($defaultFilters, [
                'featured',
                'latest',
                'most_viewed',
                'price_range',
                'premium',
                'highest_price',
                'lowest_price',
            ])));

            $filtersInput = $request->input('filters');
            if (is_string($filtersInput)) {
                $filtersInput = array_map('trim', explode(',', $filtersInput));
            }

            $filters = [];
            foreach (Arr::wrap($filtersInput) as $filterValue) {
                if (! is_string($filterValue)) {
                    continue;
                }
                $normalized = (string) Str::of($filterValue)
                    ->lower()
                    ->replaceMatches('/[\s]+/u', '_')
                    ->replace('-', '_')
                    ->trim('_');

                if ($normalized !== '' && in_array($normalized, $filterPool, true)) {
                    $filters[] = $normalized;
                }
            }

            if ($filters === []) {
                $filters = $defaultFilters;
            }

            $filters = array_values(array_unique($filters));

            $page = $request->integer('page') ?? 1;
            $page = max(1, $page);

            $minItemsFirstPage = 6;
            $minItemsNextPage = 4;
            $configLimit = (int) config('interface_sections.section_item_limit', 12);

            $limitDefault = $page === 1
                ? max($minItemsFirstPage, $configLimit)
                : max($minItemsNextPage, min($configLimit, 8));

            $minRequired = $page === 1 ? $minItemsFirstPage : $minItemsNextPage;
            $limit = $request->integer('limit');
            $limit = $limit !== null ? max($minRequired, min($limit, 50)) : $limitDefault;
            $offset = ($page - 1) * $limit;

            $sectionTypeInput = $request->input('section_type') ?? $request->input('interface_type');
            $sectionType = InterfaceSectionService::normalizeSectionType($sectionTypeInput);
            if ($sectionType === null || $sectionType === '') {
                $sectionType = InterfaceSectionService::defaultSectionType() ?? 'homepage';
            }

            $allowedSectionTypes = InterfaceSectionService::allowedSectionTypes();
            if (! in_array($sectionType, $allowedSectionTypes, true)) {
                $sectionType = InterfaceSectionService::defaultSectionType() ?? 'homepage';
            }

            $categoryIds = InterfaceSectionService::categoryIdsForSection($sectionType);
            if ($categoryIds === []) {
                $categoryIds = null;
            }

            $rootIdentifiers = InterfaceSectionService::rootIdentifiers();
            $rootIdentifier = $rootIdentifiers[$sectionType] ?? null;
            $interfaceVariants = InterfaceSectionService::sectionTypeVariants($sectionType);

            $rootId = $request->integer('root_id') ?? $request->integer('root_category_id');

            $configs = FeaturedAdsConfig::query()
                ->where('enabled', true)
                ->when($sectionType, function ($query) use ($sectionType) {
                    $query->where(function ($inner) use ($sectionType) {
                        $inner->whereNull('interface_type')
                            ->orWhere('interface_type', $sectionType);
                    });
                })
                ->when($rootIdentifier, function ($query) use ($rootIdentifier) {
                    $query->where(function ($inner) use ($rootIdentifier) {
                        $inner->whereNull('root_identifier')
                            ->orWhere('root_identifier', $rootIdentifier);
                    });
                })
                ->when($rootId, function ($query) use ($rootId) {
                    $query->where(function ($inner) use ($rootId) {
                        $inner->whereNull('root_category_id')
                            ->orWhere('root_category_id', $rootId);
                    });
                })
                ->orderBy('position')
                ->orderBy('id')
                ->get();

            if ($configs->isEmpty()) {
                return response()->json([
                    'error' => false,
                    'message' => __('No featured ads configuration found for this section.'),
                    'data' => [
                        'interface_type' => $sectionType,
                        'filters' => $filters,
                        'sections' => [],
                    ],
                    'code' => 200,
                ], 200);
            }

            $relations = [
                'user:id,name,email,mobile,profile,country_code,show_personal_details',
                'category:id,name,image',
                'gallery_images:id,image,item_id,thumbnail_url,detail_image_url',
                'featured_items',
                'favourites',
                'item_custom_field_values.custom_field',
                'area:id,name',
            ];

            $titleMap = [
                'featured'      => __('Featured Items'),
                'premium'       => __('Featured Items'),
                'latest'        => __('Latest Listings'),
                'most_viewed'   => __('Popular Items'),
                'price_range'   => __('Budget Friendly'),
                'highest_price' => __('Highest Price'),
                'lowest_price'  => __('Lowest Price'),
            ];

            $allSections = [];
            $sequenceOffset = 0;

            foreach ($configs as $config) {
                $sectionTypeForConfig = $sectionType;
                $interfaceVariantsForConfig = $interfaceVariants;
                $rootIdentifierForConfig = $rootIdentifier;
                $categoryIdsForConfig = $categoryIds;
                $filtersForConfig = $filters;
                $rootIdForConfig = $rootId;

                if (is_string($config->interface_type) && $config->interface_type !== '') {
                    $sectionTypeForConfig = InterfaceSectionService::normalizeSectionType($config->interface_type);
                    $interfaceVariantsForConfig = InterfaceSectionService::sectionTypeVariants($sectionTypeForConfig);
                }

                if (is_string($config->root_identifier) && $config->root_identifier !== '') {
                    $rootIdentifierForConfig = $config->root_identifier;
                }

                $categoryIdsOverride = null;
                if (! empty($config->root_category_id)) {
                    $categoryIdsOverride = $this->collectCategoryTreeIds((int) $config->root_category_id);
                } elseif (! empty($rootIdForConfig)) {
                    $categoryIdsOverride = $this->collectCategoryTreeIds((int) $rootIdForConfig);
                }

                if ($categoryIdsOverride !== null) {
                    $categoryIdsForConfig = $categoryIdsOverride;
                }

                if ($categoryIdsForConfig === []) {
                    $categoryIdsForConfig = null;
                }

                $preferredOrder = $config->order_mode;
                if (is_string($preferredOrder)) {
                    $normalizedOrder = (string) Str::of($preferredOrder)
                        ->lower()
                        ->replaceMatches('/[\s]+/u', '_')
                        ->replace('-', '_')
                        ->trim('_');

                    if ($normalizedOrder !== '' && in_array($normalizedOrder, $filterPool, true)) {
                        $filtersForConfig = [$normalizedOrder];
                    }
                }

                $applyInterfaceFilterConfig = $sectionTypeForConfig !== null && $sectionTypeForConfig !== 'all';

                $makeBaseQuery = function (bool $withInterfaceFilter = true) use ($categoryIdsForConfig, $relations, $sectionTypeForConfig, $interfaceVariantsForConfig) {
                    $query = Item::query()
                        ->approved()
                        ->with($relations)
                        ->withCount('favourites')
                        ->withCount('featured_items');

                    if ($categoryIdsForConfig !== null) {
                        $query->whereIn('category_id', $categoryIdsForConfig);
                    }

                    if ($withInterfaceFilter && $sectionTypeForConfig !== null && $sectionTypeForConfig !== 'all') {
                        $query->whereIn('interface_type', $interfaceVariantsForConfig);
                    }

                    return $query;
                };

                $baseQuery = $makeBaseQuery($applyInterfaceFilterConfig);
                $sectionsForConfig = [];

                foreach ($filtersForConfig as $index => $filter) {
                    $query = clone $baseQuery;

                    switch ($filter) {
                        case 'featured':
                        case 'premium':
                            $query->whereHas('featured_items')->orderByDesc('items.updated_at');
                            break;
                        case 'most_viewed':
                            $query->orderByDesc('items.clicks');
                            break;
                        case 'highest_price':
                            $query->orderByDesc('items.price');
                            break;
                        case 'price_range':
                        case 'lowest_price':
                            $query->orderBy('items.price');
                            break;
                        case 'latest':
                        default:
                            $query->orderByDesc('items.created_at');
                            break;
                    }

                    $items = $query->skip($offset)->limit($limit)->get();

                    if ($items->isEmpty()) {
                        continue;
                    }

                    $sectionData = array_values((new ItemCollection($items))->toArray($request));

                    $sectionsForConfig[] = [
                        'id' => null,
                        'title' => $config->title ?? $titleMap[$filter] ?? Str::title(str_replace('_', ' ', $filter)),
                        'style' => $config->style_key ?? 'list',
                        'section_type' => $sectionTypeForConfig,
                        'filter' => $filter,
                        'slug' => $config->slug
                            ?? $request->input('slug')
                            ?? Str::slug($sectionTypeForConfig . '-' . $filter),
                        'sequence' => $sequenceOffset + $index + 1,
                        'root_identifier' => $config->root_identifier ?? $rootIdentifierForConfig,
                        'total_data' => count($sectionData),
                        'min_price' => $items->min('price'),
                        'max_price' => $items->max('price'),
                        'has_more' => $items->count() === $limit,
                        'section_data' => $sectionData,
                    ];
                }

                if ($sectionsForConfig === [] && $categoryIdsForConfig !== null && $applyInterfaceFilterConfig) {
                    // If interface filtering produced no data, fall back to category-only so the banner still renders inside the same section tree.
                    $baseQuery = $makeBaseQuery(false);
                    foreach ($filtersForConfig as $index => $filter) {
                        $query = clone $baseQuery;

                        switch ($filter) {
                            case 'featured':
                            case 'premium':
                                $query->whereHas('featured_items')->orderByDesc('items.updated_at');
                                break;
                            case 'most_viewed':
                                $query->orderByDesc('items.clicks');
                                break;
                            case 'highest_price':
                                $query->orderByDesc('items.price');
                                break;
                            case 'price_range':
                            case 'lowest_price':
                                $query->orderBy('items.price');
                                break;
                            case 'latest':
                            default:
                                $query->orderByDesc('items.created_at');
                                break;
                        }

                        $items = $query->skip($offset)->limit($limit)->get();
                        if ($items->isEmpty()) {
                            continue;
                        }

                        $sectionData = array_values((new ItemCollection($items))->toArray($request));

                        $sectionsForConfig[] = [
                            'id' => null,
                            'title' => $config->title ?? $titleMap[$filter] ?? Str::title(str_replace('_', ' ', $filter)),
                            'style' => $config->style_key ?? 'list',
                            'section_type' => $sectionTypeForConfig,
                            'filter' => $filter,
                            'slug' => $config->slug
                                ?? $request->input('slug')
                                ?? Str::slug($sectionTypeForConfig . '-' . $filter),
                            'sequence' => $sequenceOffset + $index + 1,
                            'root_identifier' => $config->root_identifier ?? $rootIdentifierForConfig,
                            'total_data' => count($sectionData),
                            'min_price' => $items->min('price'),
                            'max_price' => $items->max('price'),
                            'has_more' => $items->count() === $limit,
                            'section_data' => $sectionData,
                        ];
                    }
                }

                if ($sectionsForConfig === [] && $page === 1) {
                    $fallbackItems = (clone $baseQuery)
                        ->orderByDesc('items.created_at')
                        ->skip($offset)
                        ->limit($limit)
                        ->get();

                    if ($fallbackItems->isNotEmpty()) {
                        $sectionData = array_values((new ItemCollection($fallbackItems))->toArray($request));
                        $sectionsForConfig[] = [
                            'id' => null,
                            'title' => $config->title ?? $titleMap['latest'] ?? 'Latest Listings',
                            'style' => $config->style_key ?? 'list',
                            'section_type' => $sectionTypeForConfig,
                            'filter' => 'latest',
                            'slug' => $config->slug
                                ?? $request->input('slug')
                                ?? Str::slug($sectionTypeForConfig . '-latest'),
                            'sequence' => $sequenceOffset + 1,
                            'root_identifier' => $config->root_identifier ?? $rootIdentifierForConfig,
                            'total_data' => count($sectionData),
                            'min_price' => $fallbackItems->min('price'),
                            'max_price' => $fallbackItems->max('price'),
                            'has_more' => $fallbackItems->count() === $limit,
                            'section_data' => $sectionData,
                        ];
                    }
                }

                if ($sectionsForConfig === []) {
                    $singleItemQuery = Item::query()
                        ->approved()
                        ->with($relations)
                        ->withCount('favourites')
                        ->withCount('featured_items');

                    if ($categoryIdsForConfig !== null) {
                        $singleItemQuery->whereIn('category_id', $categoryIdsForConfig);
                    } elseif ($applyInterfaceFilterConfig) {
                        $singleItemQuery->whereIn('interface_type', $interfaceVariantsForConfig);
                    }

                    $singleItem = $singleItemQuery
                        ->orderByDesc('items.created_at')
                        ->first();

                    $sectionData = $singleItem
                        ? array_values((new ItemCollection([$singleItem]))->toArray($request))
                        : [];

                    $sectionsForConfig[] = [
                        'id' => null,
                        'title' => $config->title ?? $titleMap['latest'] ?? 'Latest Listings',
                        'style' => $config->style_key ?? 'list',
                        'section_type' => $sectionTypeForConfig,
                        'filter' => $config->order_mode ?? 'latest',
                        'slug' => $config->slug
                            ?? $request->input('slug')
                            ?? Str::slug($sectionTypeForConfig . '-latest'),
                        'sequence' => $sequenceOffset + 1,
                        'root_identifier' => $config->root_identifier ?? $rootIdentifierForConfig,
                        'total_data' => count($sectionData),
                        'min_price' => $singleItem?->price,
                        'max_price' => $singleItem?->price,
                        'has_more' => false,
                        'section_data' => $sectionData,
                    ];
                }

                $sequenceOffset += count($sectionsForConfig);
                $allSections = array_merge($allSections, $sectionsForConfig);
            }

            return response()->json([
                'error' => false,
                'message' => __('Featured sections fetched successfully.'),
                'data' => [
                    'interface_type' => $sectionType,
                    'filters' => $filters,
                    'page' => $page,
                    'per_page' => $limit,
                    'sections' => array_values($allSections),
                ],
                'code' => 200,
            ], 200);
        } catch (Throwable $th) {
            \Log::error('API Controller -> getFeaturedSections failed', [
                'exception' => $th,
            ]);

            return response()->json([
                'error' => true,
                'message' => 'Unable to load featured sections.',
                'code' => 500,
            ], 500);
        }
    }
    public function recordSliderClick(Request $request, Slider $slider, SliderMetricService $sliderMetricService)
    {
        try {
            $now = Carbon::now();
            $user = $request->user() ?? Auth::user();
            $userId = $user?->getAuthIdentifier();
            $sessionId = $this->resolveSliderSessionId($request);

            $sliderMetricService->recordClick($slider, $userId, $sessionId, $now);

            ResponseService::successResponse(__('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ.'));
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> recordSliderClick');
            ResponseService::errorResponse();
        }
    }


    public function getReportReasons(Request $request) {
        try {
            $report_reason = new ReportReason();
            if (!empty($request->id)) {
                $id = $request->id;
                $report_reason->where('id', '=', $id);
            }
            $result = $report_reason->paginate();
            $total = $report_reason->count();
            ResponseService::successResponse("Data Fetched Successfully", $result, ['total' => $total]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getReportReasons");
            ResponseService::errorResponse();
        }
    }


    protected function resolveSliderSessionId(Request $request): ?string
    {
        if ($request->hasSession()) {
            return $request->session()->getId();
        }

        return $request->header('X-Session-Id')
            ?? $request->cookie('slider_session')
            ?? $request->ip();
    }


    public function addReports(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'item_id'          => 'required',
                'report_reason_id' => 'required_without:other_message',
                'other_message'    => 'required_without:report_reason_id'
            ]);
            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            $user = Auth::user();
            $report_count = UserReports::where('item_id', $request->item_id)->where('user_id', $user->id)->first();
            if ($report_count) {
                ResponseService::errorResponse("Already Reported");
            }


            // Determine department: prefer client hint, fallback to category mapping
            $item = Item::select(['id', 'category_id'])->find($request->item_id);
            $categoryId = $item?->category_id;

            if ($categoryId === null) {
                $serviceRecord = Service::select(['id', 'category_id'])->find($request->item_id);
                $categoryId = $serviceRecord?->category_id;
            }

            if ($categoryId === null) {
                ResponseService::errorResponse(__('The selected item could not be found.'));
            }

            $clientDepartment = $request->input('department') ?? $request->input('report_department');
            $department = $clientDepartment ?: $this->resolveReportDepartment($categoryId);

            if (empty($department)) {
                ResponseService::errorResponse(__('Unable to determine the department for this report.'));
            }

            UserReports::create([
                ...$request->all(),
                'user_id'       => $user->id,
                'other_message' => $request->other_message ?? '',
                'department'    => $department,
            ]);
            ResponseService::successResponse("Report Submitted Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> addReports");
            ResponseService::errorResponse();
        }
    }




    

    public function setItemTotalClick(Request $request) {
        try {

            $validator = Validator::make($request->all(), [
                'item_id' => 'required',
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }

            $itemId = (int) $request->item_id;
            $recorded = false;

            $item = Item::find($itemId);
            if ($item) {
                $item->increment('clicks');
                $recorded = true;
            } else {
                $service = Service::find($itemId);
                if ($service) {
                    $service->increment('views');
                    $recorded = true;
                }
            }

            if (!$recorded) {
                ResponseService::errorResponse(__('The selected item could not be found.'));
            }

            ResponseService::successResponse(null, 'Update Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> setItemTotalClick");
            ResponseService::errorResponse();
        }
    }

    public function getFeaturedSection(Request $request)
    {
        $this->getFeaturedSections($request);
    }

    public function getPaymentIntent(Request $request) {
        ResponseService::errorResponse('Online payment gateways are no longer supported.');
    }

    public function getPaymentTransactions(Request $request) {
    
        try {
            $transactions = PaymentTransaction::with([
                'manualPaymentRequest.manualBank',
                'walletTransaction',
                'order' => static function ($query) {
                    $query->select('id', 'order_number', 'payment_status', 'department');
                },
            ])->where('user_id', Auth::id())
                ->latest()
                ->get();

            $data = $transactions->isEmpty()
                ? []
                : PaymentTransactionResource::collection($transactions)->resolve();

            ResponseService::successResponse('Payment Transactions fetched successfully', $data);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getPaymentTransactions');
            ResponseService::errorResponse();
        }
    }




    public function walletSummary(Request $request)
    {
        try {
            $user = Auth::user();

            $walletAccount = WalletAccount::query()->firstOrCreate(
                ['user_id' => $user->id],
                [
                    'balance' => 0,
                    'currency' => $this->getWalletCurrencyCode(),
                ]
            
            );
            $walletAccount = $this->ensureWalletAccountCurrency($walletAccount);
            $walletCurrency = Str::upper((string) ($walletAccount->currency ?? $this->getWalletCurrencyCode()));

            $latestTransaction = $walletAccount->transactions()
                ->latest('created_at')
                ->first();


            $data = [
                'account_id' => $walletAccount->getKey(),
                'balance' => [
                    'current' => (float) $walletAccount->balance,
                    'currency' => $walletCurrency,

                ],
                'last_transaction_at' => optional($latestTransaction?->created_at)->toIso8601String(),
                'updated_at' => optional($walletAccount->updated_at)->toIso8601String(),
                'fetched_at' => now()->toIso8601String(),
                'filters' => $this->buildWalletFilterPayload(null, true),

            ];

            ResponseService::successResponse('Wallet summary fetched successfully', $data);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> walletSummary');
            ResponseService::errorResponse();
        }
    }

    public function walletTransactions(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'filter' => 'nullable|in:' . implode(',', self::WALLET_TRANSACTION_FILTERS),
            'per_page' => 'nullable|integer|min:1|max:100',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $validated = $validator->validated();

        $filter = $validated['filter'] ?? 'all';
        $perPage = $validated['per_page'] ?? 15;

        try {
            $user = Auth::user();

            $walletAccount = WalletAccount::query()->firstOrCreate(
                ['user_id' => $user->id],
                [
                    'balance' => 0,
                    'currency' => $this->getWalletCurrencyCode(),
                ]
            
            );
            $walletAccount = $this->ensureWalletAccountCurrency($walletAccount);
            $walletCurrency = Str::upper((string) ($walletAccount->currency ?? $this->getWalletCurrencyCode()));

            $latestTransaction = $walletAccount->transactions()
                ->latest('created_at')
                ->first();


            $query = WalletTransaction::query()
                ->with([
                    'manualPaymentRequest',
                    'paymentTransaction.walletTransaction',
                ])
                ->where('wallet_account_id', $walletAccount->getKey())
                ->latest('created_at');

            $this->applyWalletTransactionFilter($query, $filter);

            $paginator = $query->paginate((int) $perPage)->appends($request->only(['filter', 'per_page']));

            $transactions = $paginator->getCollection()->map(static function (WalletTransaction $transaction) {
                return (new WalletTransactionResource($transaction))->resolve();
            })->values()->all();

            $data = [
                'account_id' => $walletAccount->getKey(),
                'balance' => [
                    'current' => (float) $walletAccount->balance,
                    'currency' => $walletCurrency,
                ],
                'filters' => $this->buildWalletFilterPayload($filter),

                'transactions' => $transactions,
                'pagination' => [
                    'current_page' => $paginator->currentPage(),
                    'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(),
                    'total' => $paginator->total(),
                    'next_page_url' => $paginator->nextPageUrl(),
                    'prev_page_url' => $paginator->previousPageUrl(),
                ],
                'last_transaction_at' => optional($latestTransaction?->created_at)->toIso8601String(),
                'fetched_at' => now()->toIso8601String(),
            ];

            ResponseService::successResponse('Wallet transactions fetched successfully', $data);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> walletTransactions');
            ResponseService::errorResponse();
        }
    }




    public function walletWithdrawalOptions(): void
    {
        try {

            $user = Auth::user();
            $walletAccount = WalletAccount::query()->firstOrCreate(
                ['user_id' => $user->id],
                [
                    'balance' => 0,
                    'currency' => $this->getWalletCurrencyCode(),
                ]
            );
            $walletAccount = $this->ensureWalletAccountCurrency($walletAccount);
            $walletCurrency = Str::upper((string) ($walletAccount->currency ?? $this->getWalletCurrencyCode()));

            $methods = array_values($this->getWalletWithdrawalMethods());

            $data = [
                'methods' => array_map(static function (array $method) {
                    $methodData = [
                        'key' => $method['key'],
                        'name' => $method['name'],
                        'fields' => array_map(static function (array $field) {
                            return [
                                'key' => $field['key'],
                                'label' => $field['label'],
                                'required' => $field['required'],
                                'rules' => $field['rules'],
                            ];
                        }, $method['fields'] ?? []),
                    ];

                    if (!empty($method['description'])) {
                        $methodData['description'] = $method['description'];
                    }

                    return $methodData;
                
                }, $methods),
                'minimum_amount' => (float) config('wallet.withdrawals.minimum_amount', 1),
                'currency' => $walletCurrency,
            ];

            ResponseService::successResponse('Wallet withdrawal options fetched successfully', $data);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> walletWithdrawalOptions');
            ResponseService::errorResponse();
        }
    }

    public function storeWalletWithdrawalRequest(Request $request): void
    {
        $methods = $this->getWalletWithdrawalMethods();

        $minimumAmount = max(0.01, (float) config('wallet.withdrawals.minimum_amount', 1));

        $validator = Validator::make($request->all(), [
            'amount' => ['required', 'numeric', 'min:' . $minimumAmount],
            'preferred_method' => ['required', Rule::in(array_keys($methods))],
            'notes' => ['nullable', 'string', 'max:500'],
            'meta' => ['nullable', 'array'],
        ], [], [
            'preferred_method' => __('Preferred method'),
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $validated = $validator->validated();

        $methodKey = $validated['preferred_method'];
        $method = $methods[$methodKey];
        $withdrawalMeta = $this->validateWithdrawalMeta($request, $method);


        try {
            $user = Auth::user();

            $walletAccount = WalletAccount::query()->firstOrCreate(
                ['user_id' => $user->id],
                [
                    'balance' => 0,
                    'currency' => $this->getWalletCurrencyCode(),
                ]
            );
            $walletAccount = $this->ensureWalletAccountCurrency($walletAccount);
            $walletCurrency = Str::upper((string) ($walletAccount->currency ?? $this->getWalletCurrencyCode()));

            $amount = round((float) $validated['amount'], 2);

            if ($amount > (float) $walletAccount->balance) {
                ResponseService::errorResponse('Insufficient wallet balance');
            }



            $idempotencyKey = sprintf('wallet:withdrawal-request:%d:%s', $user->id, Str::uuid()->toString());

            $transactionMeta = [
                'context' => 'wallet_withdrawal_request',
                'withdrawal_request_reference' => $idempotencyKey,
                'withdrawal_method' => $methodKey,
            ];

            if (!empty($validated['notes'])) {
                $transactionMeta['withdrawal_notes'] = $validated['notes'];
            }

            if ($withdrawalMeta !== null) {
                $transactionMeta['withdrawal_meta'] = $withdrawalMeta;
            }

            $transaction = $this->walletService->debit($user, $idempotencyKey, $amount, [
                'meta' => $transactionMeta,
            ]);

            $withdrawalRequest = WalletWithdrawalRequest::create([
                'wallet_account_id' => $walletAccount->getKey(),
                'wallet_transaction_id' => $transaction->getKey(),
                'status' => WalletWithdrawalRequest::STATUS_PENDING,
                'amount' => $amount,
                'preferred_method' => $methodKey,
                'wallet_reference' => $idempotencyKey,
                'notes' => $validated['notes'] ?? null,
                'meta' => $withdrawalMeta,
            ]);


            $data = [
                'id' => $withdrawalRequest->getKey(),
                'status' => $withdrawalRequest->status,
                'status_label' => $withdrawalRequest->statusLabel(),
                'amount' => (float) $withdrawalRequest->amount,
                'currency' => $walletCurrency,

                'preferred_method' => [
                    'key' => $method['key'],
                    'name' => $method['name'],
                    'description' => $method['description'],
                ],
                'wallet_transaction_id' => $transaction->getKey(),
                'wallet_reference' => $withdrawalRequest->wallet_reference,
                'notes' => $withdrawalRequest->notes,
                'submitted_at' => optional($withdrawalRequest->created_at)->toIso8601String(),
                'balance_after' => (float) $transaction->balance_after,
            ];

            if ($withdrawalRequest->meta !== null) {
                $data['meta'] = $withdrawalRequest->meta;
            }

            ResponseService::successResponse('Wallet withdrawal request submitted successfully', $data);
        } catch (RuntimeException $runtimeException) {
            if (str_contains(strtolower($runtimeException->getMessage()), 'insufficient wallet balance')) {
                ResponseService::errorResponse('Insufficient wallet balance');
            }

            ResponseService::logErrorResponse($runtimeException, 'API Controller -> storeWalletWithdrawalRequest');
            ResponseService::errorResponse('Failed to submit withdrawal request');
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'API Controller -> storeWalletWithdrawalRequest');
            ResponseService::errorResponse('Failed to submit withdrawal request');
        }
    }


    public function walletWithdrawalRequests(Request $request): void
    {
        $validator = Validator::make($request->all(), [
            'status' => ['nullable', Rule::in(WalletWithdrawalRequest::statuses())],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $validated = $validator->validated();

        $status = $validated['status'] ?? null;
        $perPage = (int) ($validated['per_page'] ?? 15);

        try {
            $user = Auth::user();

            $walletAccount = WalletAccount::query()->firstOrCreate(
                ['user_id' => $user->id],
                [
                    'balance' => 0,
                    'currency' => $this->getWalletCurrencyCode(),
                ]
            
            );
            $walletAccount = $this->ensureWalletAccountCurrency($walletAccount);
            $walletCurrency = Str::upper((string) ($walletAccount->currency ?? $this->getWalletCurrencyCode()));

            $query = WalletWithdrawalRequest::query()
                ->with(['transaction', 'account'])
                ->where('wallet_account_id', $walletAccount->getKey())
                ->latest('created_at');

            if ($status !== null) {
                $query->where('status', $status);
            }

            $paginator = $query->paginate($perPage)->appends($request->only(['status', 'per_page']));

            $methods = $this->getWalletWithdrawalMethods();

            $withdrawals = $paginator->getCollection()
                ->map(static function (WalletWithdrawalRequest $withdrawal) use ($methods) {
                    return (new WalletWithdrawalRequestResource($withdrawal, $methods))->resolve();
                })
                ->values()
                ->all();


            $data = [
                'account_id' => $walletAccount->getKey(),
                'filters' => [
                    'applied_status' => $status ?? 'all',
                    'available_statuses' => WalletWithdrawalRequest::statuses(),
                ],
                'currency' => $walletCurrency,
                'withdrawals' => $withdrawals,
                'pagination' => [
                    'current_page' => $paginator->currentPage(),
                    'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(),
                    'total' => $paginator->total(),
                    'next_page_url' => $paginator->nextPageUrl(),
                    'prev_page_url' => $paginator->previousPageUrl(),
                ],
                'fetched_at' => now()->toIso8601String(),
            ];

            ResponseService::successResponse('Wallet withdrawal requests fetched successfully', $data);
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'API Controller -> walletWithdrawalRequests');
            ResponseService::errorResponse('Failed to fetch wallet withdrawal requests');
        }
    }


    public function walletRecipient(User $recipient): void
    {
        try {
            $user = Auth::user();

            if ($user && $user->id === $recipient->id) {
                ResponseService::validationError('Cannot transfer funds to the same account.');
            }

            $maskedMobile = $this->maskMobileNumber($recipient->mobile);

            ResponseService::successResponse('Wallet recipient fetched successfully', [
                'id' => $recipient->id,
                'name' => $recipient->name,
                'mobile' => $maskedMobile,
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> walletRecipient');
            ResponseService::errorResponse('Failed to fetch wallet recipient details');
        }
    }

    public function walletRecipientLookup(Request $request): void
    {
        try {
            $mobileInput = trim((string) $request->get('mobile', ''));
            $normalizedMobile = preg_replace('/\D+/', '', $mobileInput);

            if ($normalizedMobile === '') {
                ResponseService::validationError(__('Please provide a valid mobile number.'));
            }

            $recipient = User::query()
                ->where(function (Builder $query) use ($mobileInput, $normalizedMobile) {
                    $query->where('mobile', $mobileInput)
                        ->orWhere('mobile', $normalizedMobile)
                        ->orWhere('mobile', 'like', "{$mobileInput}%")
                        ->orWhere('mobile', 'like', "%{$mobileInput}")
                        ->orWhere('mobile', 'like', "%{$normalizedMobile}");
                })
                ->first();

            if (!$recipient) {
                ResponseService::validationError(__('No matching wallet account was found for this mobile number.'));
            }

            $user = Auth::user();
            if ($user && $user->id === $recipient->id) {
                ResponseService::validationError(__('Cannot transfer funds to the same account.'));
            }

            $maskedMobile = $this->maskMobileNumber($recipient->mobile);

            ResponseService::successResponse('Wallet recipient fetched successfully', [
                'id' => $recipient->id,
                'name' => $recipient->name,
                'mobile' => $maskedMobile,
            ]);
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'API Controller -> walletRecipientLookup');
            ResponseService::errorResponse('Failed to lookup wallet recipient');
        }
    }




    public function showWalletWithdrawalRequest(int $withdrawalRequestId): void
    {
        try {
            $user = Auth::user();

            $withdrawalRequest = WalletWithdrawalRequest::query()
                ->with(['transaction', 'account'])
                ->findOrFail($withdrawalRequestId);

            if ($withdrawalRequest->account?->user_id !== $user->id) {
                ResponseService::errorResponse('Unauthorized access to withdrawal request', null, HttpResponse::HTTP_FORBIDDEN);
            }

            $methods = $this->getWalletWithdrawalMethods();

            $data = (new WalletWithdrawalRequestResource($withdrawalRequest, $methods))->resolve();

            ResponseService::successResponse('Wallet withdrawal request fetched successfully', $data);
        } catch (ModelNotFoundException $exception) {
            ResponseService::errorResponse('Withdrawal request not found', null, HttpResponse::HTTP_NOT_FOUND, $exception);
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'API Controller -> showWalletWithdrawalRequest');
            ResponseService::errorResponse('Failed to fetch wallet withdrawal request');
        }
    }


    public function transferRequest(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'recipient_id' => ['required', 'integer', 'exists:users,id'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'client_tag' => ['required', 'string', 'max:64'],
            'reference' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'currency' => ['nullable', 'string', 'max:16'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $validated = $validator->validated();

        try {
            $sender = Auth::user();
            $recipient = User::query()->findOrFail($validated['recipient_id']);

            if ($sender->id === $recipient->id) {
                ResponseService::validationError('Cannot transfer funds to the same account.');
            }

            $amount = (float) $validated['amount'];
            $clientTag = $validated['client_tag'];
            $reference = $validated['reference'] ?? null;
            $notes = $validated['notes'] ?? null;
            
            $currencyInput = $validated['currency'] ?? null;
            $walletCurrency = $this->getWalletCurrencyCode();

            if ($currencyInput !== null) {
                $normalizedCurrency = $this->normalizeCurrencyCode($currencyInput);

                if ($normalizedCurrency === null) {
                    ResponseService::validationError('Invalid currency provided.');
                }

                if ($normalizedCurrency !== $walletCurrency) {
                    ResponseService::validationError(sprintf(
                        'Wallet transfers must use the %s currency.',
                        $walletCurrency
                    ));
                }
            }



            $idempotencyKey = $this->buildWalletTransferIdempotencyKey($sender, $recipient, $amount, $clientTag);

            [$debitTransaction, $creditTransaction, $replayed] = $this->performWalletTransfer(
                $sender,
                $recipient,
                $amount,
                $idempotencyKey,
                $clientTag,
                $walletCurrency,
                $reference,
                $notes
            );

            $responseCurrency = $walletCurrency;


            $data = [
                'idempotency_key' => $idempotencyKey,
                'amount' => round($amount, 2),
                'currency' => Str::upper((string) $responseCurrency),
                'sender' => [
                    'id' => $sender->id,
                    'name' => $sender->name,
                    'transaction_id' => $debitTransaction->getKey(),
                    'balance_after' => (float) $debitTransaction->balance_after,
                ],
                'recipient' => [
                    'id' => $recipient->id,
                    'name' => $recipient->name,
                    'transaction_id' => $creditTransaction->getKey(),
                    'balance_after' => (float) $creditTransaction->balance_after,
                ],
                'meta' => array_filter([
                    'reference' => $reference,
                    'notes' => $notes,
                    'client_tag' => $clientTag,
                ], static fn ($value) => $value !== null && $value !== ''),
                'processed_at' => optional($debitTransaction->created_at)->toIso8601String(),
                'idempotency_replayed' => $replayed,
            ];

            ResponseService::successResponse('Wallet transfer processed successfully', $data);
        } catch (RuntimeException $runtimeException) {
            if (str_contains(strtolower($runtimeException->getMessage()), 'insufficient wallet balance')) {
                ResponseService::errorResponse('Insufficient wallet balance');
            }

            ResponseService::logErrorResponse($runtimeException, 'API Controller -> transferRequest');
            ResponseService::errorResponse('Failed to process wallet transfer');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> transferRequest');
            ResponseService::errorResponse();
        }
    }


    public function createItemOffer(Request $request) {

        $validator = Validator::make($request->all(), [
            'item_id' => 'required|integer',
            'amount'  => 'nullable|numeric',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $item = Item::approved()->notOwner()->findOrFail($request->item_id);
            $itemOffer = ItemOffer::updateOrCreate([
                'item_id'   => $request->item_id,
                'buyer_id'  => Auth::user()->id,
                'seller_id' => $item->user_id,
            ], ['amount' => $request->amount,]);

            $itemOffer = $itemOffer->load('seller:id,name,profile', 'buyer:id,name,profile', 'item:id,name,description,price,image');

            $fcmMsg = [
                'user_id'           => $itemOffer->buyer->id,
                'user_name'         => $itemOffer->buyer->name,
                'user_profile'      => $itemOffer->buyer->profile,
                'user_type'         => 'Buyer',
                'item_id'           => $itemOffer->item->id,
                'item_name'         => $itemOffer->item->name,
                'item_image'        => $itemOffer->item->image,
                'item_price'        => $itemOffer->item->price,
                'item_offer_id'     => $itemOffer->id,
                'item_offer_amount' => $itemOffer->amount,
                // 'type'              => $notificationPayload['message_type'],
                // 'message_type_temp' => $notificationPayload['message_type']
            ];
            /* message_type is reserved keyword in FCM so removed here*/
            unset($fcmMsg['message_type']);
            if ($request->has('amount') && $request->amount != 0) {
                $user_token = UserFcmToken::where('user_id', $item->user->id)->pluck('fcm_token')->toArray();
                $message = 'new offer is created by seller';
                 $notificationResponse = NotificationService::sendFcmNotification($user_token, 'New Offer', $message, "offer", $fcmMsg);

                if (is_array($notificationResponse) && ($notificationResponse['error'] ?? false)) {
                    \Log::warning('ApiController: Failed to send new offer notification', $notificationResponse);
                }

            }

            ResponseService::successResponse("Item Offer Created Successfully", $itemOffer,);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> createItemOffer");
            ResponseService::errorResponse();
        }
    }

    public function getChatList(Request $request) {
        $validator = Validator::make($request->all(), [
            'type' => 'sometimes|in:seller,buyer',
            'conversation_id' => 'sometimes|integer|exists:chat_conversations,id',
            'item_offer_id' => 'sometimes|integer|exists:item_offers,id',
            'page' => 'sometimes|integer|min:1',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        if (!$request->filled('type') && !$request->filled('conversation_id') && !$request->filled('item_offer_id')) {
            ResponseService::validationError('type is required when conversation_id or item_offer_id is not provided.');
        }

        try {



            $user = Auth::user();
            $authUserBlockList = BlockUser::where('user_id', $user->id)->pluck('blocked_user_id');
            $otherUserBlockList = BlockUser::where('blocked_user_id', $user->id)->pluck('user_id');
    
            $baseRelations = [


                'seller' => function ($query) {
                    $query->withTrashed()->select('id', 'name', 'profile');
                },
                'buyer' => function ($query) {
                    $query->withTrashed()->select('id', 'name', 'profile');
                },
                'item:id,name,description,price,image,status,deleted_at,sold_to',
                'item.review' => function ($q) use ($user) {
                    $q->where('buyer_id', $user->id);
                },
                'chat' => function ($query) use ($user) {
                    $query->latest('updated_at')
                        ->select('id', 'item_offer_id', 'updated_at')
                        ->with([
                            'participants' => function ($participantQuery) {
                                $participantQuery->withTrashed()->select('users.id', 'users.name', 'users.profile');
                            },
                            'latestMessage' => function ($messageQuery) {
                                $messageQuery->with([
                                    'sender:id,name,profile',
                                    'conversation:id,item_offer_id',
                                ]);
                            },
                        ])
                        ->withCount([
                            'messages as unread_messages_count' => function ($messageQuery) use ($user) {
                                $messageQuery->whereNull('read_at')
                                    ->where(function ($subQuery) use ($user) {
                                        $subQuery->whereNull('sender_id')
                                            ->orWhere('sender_id', '!=', $user->id);
                                    });
                            },
                        ]);
                },
            ];
    
            if ($request->filled('conversation_id') || $request->filled('item_offer_id')) {
                $offerRelations = $baseRelations;
                unset($offerRelations['chat']);
    
                if ($request->filled('conversation_id')) {
                    $conversation = Chat::with(['itemOffer' => function ($query) use ($offerRelations) {
                        $query->with($offerRelations);
                    }])->findOrFail($request->conversation_id);
    
                    if (!$conversation->participants()->where('users.id', $user->id)->exists()) {
                        ResponseService::errorResponse('You are not allowed to view this conversation', null, 403);
                    }
                    $itemOffer = $conversation->itemOffer;
                    if (!$itemOffer) {
                        ResponseService::errorResponse('Conversation is missing item offer reference');
                    }
                    $itemOffer->loadMissing($offerRelations);
    
                    $legacyTimes = $this->resolveLegacyLastMessageTimes(collect([$itemOffer->id]));
                    $type = $itemOffer->seller_id === $user->id ? 'seller' : 'buyer';
                    $payload = $this->enrichOfferWithChatData(
                        $itemOffer,
                        $user,
                        $authUserBlockList,
                        $otherUserBlockList,
                        $legacyTimes,
                        $type,
                        $conversation
                    );
    
                    ResponseService::successResponse('Chat conversation fetched successfully', [
                        'conversation' => $payload->toArray(),
                    ]);
                    return;

                }

                $itemOffer = ItemOffer::with($baseRelations)
                    ->owner()
                    ->findOrFail($request->item_offer_id);
    
                $legacyTimes = $this->resolveLegacyLastMessageTimes(collect([$itemOffer->id]));
                $type = $request->input('type');
                if (!$type) {
                    $type = $itemOffer->seller_id === $user->id ? 'seller' : 'buyer';
                }

                $payload = $this->enrichOfferWithChatData(
                    $itemOffer,
                    $user,
                    $authUserBlockList,
                    $otherUserBlockList,
                    $legacyTimes,
                    $type
                );
    
                ResponseService::successResponse('Chat conversation fetched successfully', [
                    'conversation' => $payload->toArray(),
                ]);
                return;
            }
    
            $itemOffer = ItemOffer::with($baseRelations)
                ->orderBy('id', 'DESC');
    
            if ($request->type === 'seller') {
                $itemOffer->where('seller_id', $user->id);
            } elseif ($request->type === 'buyer') {
                $itemOffer->where('buyer_id', $user->id);
            }
    
            $itemOffer = $itemOffer->paginate();
    
            $offerIds = $itemOffer->getCollection()->pluck('id')->filter()->values();
            $legacyLastMessageTimes = $this->resolveLegacyLastMessageTimes($offerIds);
    
            $itemOffer->getCollection()->transform(function (ItemOffer $offer) use (
                $user,
                $authUserBlockList,
                $otherUserBlockList,
                $legacyLastMessageTimes,
                $request
            ) {
                return $this->enrichOfferWithChatData(
                    $offer,
                    $user,
                    $authUserBlockList,
                    $otherUserBlockList,
                    $legacyLastMessageTimes,
                    $request->type
                );


            });

            ResponseService::successResponse('Chat List Fetched Successfully', $itemOffer);


        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getChatList');
            ResponseService::errorResponse();
        }
    }

    public function sendMessage(Request $request) {
        $validator = Validator::make($request->all(), [
            'item_offer_id' => 'required|integer',
            'message'       => (!$request->file('file') && !$request->file('audio')) ? "required" : "nullable",
            'file'          => 'nullable|mimes:jpg,jpeg,png|max:4096',
            'audio'         => 'nullable|mimetypes:audio/mpeg,video/mp4,audio/x-wav,text/plain|max:4096',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            DB::beginTransaction();
            $user = Auth::user();
            //List of users that Auth user has blocked
            $authUserBlockList = BlockUser::where('user_id', $user->id)->get();

            //List of Other users that have blocked the Auth user
            $otherUserBlockList = BlockUser::where('blocked_user_id', $user->id)->get();

            $itemOffer = ItemOffer::with('item')->findOrFail($request->item_offer_id);
            if ($itemOffer->seller_id == $user->id) {
                //If Auth user is seller then check if buyer has blocked the user
                $blockStatus = $authUserBlockList->filter(function ($data) use ($itemOffer) {
                    return $data->user_id == $itemOffer->seller_id && $data->blocked_user_id == $itemOffer->buyer_id;
                });
                if (count($blockStatus) !== 0) {
                    ResponseService::errorResponse("You Cannot send message because You have blocked this user");
                }

                $blockStatus = $otherUserBlockList->filter(function ($data) use ($itemOffer) {
                    return $data->user_id == $itemOffer->buyer_id && $data->blocked_user_id == $itemOffer->seller_id;
                });
                if (count($blockStatus) !== 0) {
                    ResponseService::errorResponse("You Cannot send message because other user has blocked you.");
                }
            } else {
                //If Auth user is seller then check if buyer has blocked the user
                $blockStatus = $authUserBlockList->filter(function ($data) use ($itemOffer) {
                    return $data->user_id == $itemOffer->buyer_id && $data->blocked_user_id == $itemOffer->seller_id;
                });
                if (count($blockStatus) !== 0) {
                    ResponseService::errorResponse("You Cannot send message because You have blocked this user");
                }

                $blockStatus = $otherUserBlockList->filter(function ($data) use ($itemOffer) {
                    return $data->user_id == $itemOffer->seller_id && $data->blocked_user_id == $itemOffer->buyer_id;
                });
                if (count($blockStatus) !== 0) {
                    ResponseService::errorResponse("You Cannot send message because other user has blocked you.");
                }
            }

            $department = $this->resolveSectionByCategoryId($itemOffer->item?->category_id);
            $delegates = !empty($department)
                ? $this->delegateAuthorizationService->getDelegatesForSection($department)
                : [];
            $assignedAgentId = $this->resolveConversationAssignedAgent($itemOffer, $delegates);


            $conversationAttributes = [];

            if ($department !== null && $this->chatConversationsSupportsColumn('department')) {
                $conversationAttributes['department'] = $department;
            }

            if ($assignedAgentId !== null && $this->chatConversationsSupportsColumn('assigned_to')) {
                $conversationAttributes['assigned_to'] = $assignedAgentId;
            }


            $conversation = Chat::firstOrCreate(
                [
                    'item_offer_id' => $itemOffer->id,
                ],
                $conversationAttributes

            );


           
            $conversationWasJustCreated = $conversation->wasRecentlyCreated;
            $assignmentWasAutoUpdated = false;

            if (!$conversationWasJustCreated) {
                $assignmentWasAutoUpdated = $this->syncConversationDepartmentAndAssignment(
                    $conversation,
                    $department,
                    $assignedAgentId
                );
            }


            $conversation->participants()->syncWithoutDetaching(array_filter([
                $itemOffer->seller_id,
                $itemOffer->buyer_id,
            ]));

                        $now = Carbon::now();

            $conversation->participants()->updateExistingPivot($user->id, [
                'is_online' => true,
                'last_seen_at' => $now,
                'is_typing' => false,
                'last_typing_at' => $now,
                'updated_at' => $now,
            ]);


            $filePath = $request->hasFile('file') ? FileService::compressAndUpload($request->file('file'), 'chat') : null;
            $audioPath = $request->hasFile('audio') ? FileService::compressAndUpload($request->file('audio'), 'chat') : null;

            $chatMessage = $conversation->messages()->create([
                'sender_id' => Auth::id(),
                'message'   => $request->message,
                'file'      => $filePath,
                'audio'     => $audioPath,
                'status'    => ChatMessage::STATUS_SENT,
    
            ]);

            $conversation->touch();

            $chatMessage->load('sender');


            if ($conversationWasJustCreated || $assignmentWasAutoUpdated) {
                $this->handleSupportEscalation(
                    $conversation,
                    $chatMessage,
                    $conversation->department ?? $department,
                    $user
                );
            }



            
            try {
                broadcast(new UserTyping($conversation, $user, false, $now))->toOthers();
            } catch (Throwable $broadcastException) {
                \Log::warning('Broadcast typing indicator failed', [
                    'conversation_id' => $conversation->id,
                    'user_id' => $user->id,
                    'error' => $broadcastException->getMessage(),
                ]);
            }

            try {
                broadcast(new MessageSent($conversation, $chatMessage))->toOthers();
            } catch (Throwable $broadcastException) {
                \Log::warning('Broadcast chat message failed', [
                    'conversation_id' => $conversation->id,
                    'message_id' => $chatMessage->id,
                    'error' => $broadcastException->getMessage(),
                ]);
            }



            if ($itemOffer->seller_id == $user->id) {
                $receiver_id = $itemOffer->buyer_id;
                $userType = "Seller";
            } else {
                $receiver_id = $itemOffer->seller_id;
                $userType = "Buyer";
            }

            $notificationPayload = $chatMessage->toArray();
            $messageType = $notificationPayload['message_type'] ?? null;
            $notificationPayload['item_offer_id'] = $conversation->item_offer_id;
            $notificationPayload['conversation_id'] = $conversation->id;
            $messagePreview = $request->message ?? $chatMessage->message ?? '';


            

            $fcmMsg = [
                ...$notificationPayload,
                'user_id'             => $user->id,
                'user_name'           => $user->name,
                'user_profile'        => $user->profile,
                'user_type'           => $userType,
                'item_id'             => $itemOffer->item->id,
                'item_name'           => $itemOffer->item->name,
                'item_image'          => $itemOffer->item->image,
                'item_price'          => $itemOffer->item->price,
                'item_offer_id'       => $itemOffer->id,
                'item_offer_amount'   => $itemOffer->amount,
                'notification_type'   => 'chat',
                'type'                => 'chat',
                'chat_message_type'   => $notificationPayload['message_type'] ?? null,
                'message_preview'     => $messagePreview,
            ];

            $receiverFCMTokens = UserFcmToken::where('user_id', $receiver_id)
                ->pluck('fcm_token')
                ->filter()
                ->unique()
                ->values()
                ->all();

            if (empty($receiverFCMTokens)) {
                \Log::info('ApiController: No FCM tokens found for chat receiver.', [
                    'conversation_id' => $conversation->id,
                    'receiver_id' => $receiver_id,
                ]);

                $notification = [
                    'error' => false,
                    'message' => 'Receiver has no notification tokens.',
                    'data' => [],
                ];
            } else {
                $notification = NotificationService::sendFcmNotification(
                    $receiverFCMTokens,
                    'Message',
                    $request->message,
                    'chat',
                    $fcmMsg
                );


            }
            


            if (is_array($notification) && ($notification['error'] ?? false)) {
                \Log::warning('ApiController: Failed to send chat notification', $notification);
            }

            DB::commit();
            ResponseService::successResponse("Message Fetched Successfully", $chatMessage, ['debug' => $notification]);

        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, "API Controller -> sendMessage");
            ResponseService::errorResponse();
        }
    }

    public function getChatMessages(Request $request) {
        $validator = Validator::make($request->all(), [
            'item_offer_id' => 'sometimes|integer|exists:item_offers,id',
            'conversation_id' => 'sometimes|integer|exists:chat_conversations,id',
            'page' => 'sometimes|integer|min:1',
            'per_page' => 'sometimes|integer|min:1|max:100',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

                
        if (!$request->filled('item_offer_id') && !$request->filled('conversation_id')) {
            ResponseService::validationError('item_offer_id or conversation_id is required.');
        }
        try {

            $user = Auth::user();
            $conversation = null;
            $itemOffer = null;
        
            if ($request->filled('conversation_id')) {
                $conversation = Chat::with('itemOffer')->findOrFail($request->conversation_id);
        
                if (!$conversation->participants()->where('users.id', $user->id)->exists()) {
                    ResponseService::errorResponse('You are not allowed to view this conversation', null, 403);
                }
        
                $itemOffer = $conversation->itemOffer;
                if ($itemOffer && $itemOffer->seller_id !== $user->id && $itemOffer->buyer_id !== $user->id) {
                    ResponseService::errorResponse('You are not allowed to view this conversation', null, 403);
                }
            }
        
            if (!$itemOffer && $request->filled('item_offer_id')) {
                $itemOffer = ItemOffer::owner()->findOrFail($request->item_offer_id);
            }
        
            if ($conversation && $itemOffer && $conversation->item_offer_id !== $itemOffer->id) {
                ResponseService::errorResponse('Conversation does not belong to the supplied item offer.');
            }
        
            if (!$conversation && $itemOffer) {
                $conversation = Chat::where('item_offer_id', $itemOffer->id)->first();
            }
        
            $perPage = (int) $request->input('per_page', 15);


            $chatMessages = null;

            if ($conversation) {
                $chatMessages = ChatMessage::with(['sender:id,name,profile', 'conversation:id,item_offer_id'])
                    ->where('conversation_id', $conversation->id)
                    
                    ->orderBy('created_at', 'DESC')
                    ->paginate($perPage);
            }

            if (!$conversation || ($chatMessages && $chatMessages->total() === 0)) {
                if ($itemOffer) {
                    $conversation = $this->hydrateLegacyChatConversation($itemOffer, $conversation);

                    if ($conversation) {
                        $chatMessages = ChatMessage::with(['sender:id,name,profile', 'conversation:id,item_offer_id'])
                            ->where('conversation_id', $conversation->id)
                            ->orderBy('created_at', 'DESC')
                            ->paginate($perPage);
                    }
                }
            }

            if (!$conversation) {


                $empty = ChatMessage::whereRaw('1 = 0')->paginate($perPage);
                ResponseService::successResponse('Messages Fetched Successfully', $empty);
                return;
            }

            if (!$chatMessages) {
                $chatMessages = ChatMessage::whereRaw('1 = 0')->paginate($perPage);
            }

            ResponseService::successResponse('Messages Fetched Successfully', $chatMessages);
        
        
        
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getChatMessages');
            ResponseService::errorResponse();
        }
    }




   private function resolveLegacyLastMessageTimes(Collection $offerIds): Collection
    {
        if ($offerIds->isEmpty() || !Schema::hasTable('chats')) {
            return collect();
        }
    
        return DB::table('chats')
            ->whereIn('item_offer_id', $offerIds)
            ->select('item_offer_id', DB::raw('MAX(updated_at) as last_message_time'))
            ->groupBy('item_offer_id')
            ->pluck('last_message_time', 'item_offer_id');
    }
    
    private function enrichOfferWithChatData(
        ItemOffer $offer,
        User $user,
        Collection $authUserBlockList,
        Collection $otherUserBlockList,
        Collection $legacyLastMessageTimes,
        ?string $type = null,
        ?Chat $conversation = null
    ): ItemOffer {
        $type = $type ?: ($offer->seller_id === $user->id ? 'seller' : 'buyer');
    
        $userBlocked = false;
        if ($type === 'seller') {
            $userBlocked = $authUserBlockList->contains($offer->buyer_id)
                || $otherUserBlockList->contains($offer->seller_id);
        } else {
            $userBlocked = $authUserBlockList->contains($offer->seller_id)
                || $otherUserBlockList->contains($offer->buyer_id);
        }
    
        $offer->setAttribute('user_blocked', (bool) $userBlocked);
    
        $item = $offer->item;
        if ($item) {
            $item->is_purchased = 0;
            if ($item->sold_to == $user->id) {
                $item->is_purchased = 1;
            }
            $tempReview = $item->review;
            unset($item->review);
            $item->review = $tempReview[0] ?? null;
            $offer->setRelation('item', $item);
        }
    
        $chat = $conversation ?: $offer->chat;
    
        $needsHydration = false;
        if (!$chat) {
            $needsHydration = true;
        } elseif ($chat->relationLoaded('messages')) {
            $needsHydration = $chat->messages->isEmpty();
        } elseif (!$chat->messages()->exists()) {
            $needsHydration = true;
        }
    
        if ($needsHydration && $legacyLastMessageTimes->has($offer->id)) {
            $chat = $this->hydrateLegacyChatConversation($offer, $chat);
        }
    
        if ($chat) {
            $chat->loadMissing([
                'participants' => function ($participantQuery) {
                    $participantQuery->withTrashed()->select('users.id', 'users.name', 'users.profile');
                },
                'latestMessage' => function ($messageQuery) {
                    $messageQuery->with(['sender:id,name,profile', 'conversation:id,item_offer_id']);
                },
            ]);
        }
    
        $offer->setRelation('chat', $chat);
    
        $lastMessageTime = optional($chat)->updated_at;
        if (empty($lastMessageTime) && $legacyLastMessageTimes->has($offer->id)) {
            $legacyTime = $legacyLastMessageTimes->get($offer->id);
            $lastMessageTime = $legacyTime ? Carbon::parse($legacyTime) : null;
        }
    
        $offer->setAttribute('conversation_id', $chat?->id);
        $offer->setAttribute('last_message_time', $lastMessageTime ? $lastMessageTime->toDateTimeString() : null);
        $offer->setAttribute(
            'participants',
            $this->buildParticipantsPayload($offer, $chat, $user, $authUserBlockList, $otherUserBlockList)
        );
        $offer->setAttribute('last_message', $chat?->latestMessage ? $chat->latestMessage->toArray() : null);
    
        $unread = 0;
        if ($chat) {
            if (isset($chat->unread_messages_count)) {
                $unread = (int) $chat->unread_messages_count;
            } else {
                $unread = $chat->messages()
                    ->whereNull('read_at')
                    ->where(function ($query) use ($user) {
                        $query->whereNull('sender_id')
                            ->orWhere('sender_id', '!=', $user->id);
                    })->count();
            }
        }
        $offer->setAttribute('unread_messages_count', $unread);
    
        return $offer;
    }
    
    private function buildParticipantsPayload(
        ItemOffer $offer,
        ?Chat $conversation,
        User $user,
        Collection $authUserBlockList,
        Collection $otherUserBlockList
    ): array {
        $participants = collect();
    
        if ($conversation && $conversation->relationLoaded('participants')) {
            $participants = $conversation->participants->map(function (User $participant) use (
                $offer,
                $authUserBlockList,
                $otherUserBlockList
            ) {
                $role = $participant->id === $offer->seller_id
                    ? 'seller'
                    : ($participant->id === $offer->buyer_id ? 'buyer' : 'participant');
    
                $status = [
                    'is_online' => (bool) $participant->pivot->is_online,
                    'is_typing' => (bool) $participant->pivot->is_typing,
                    'last_seen' => optional($participant->pivot->last_seen_at)->toIso8601String(),
                    'last_typing_at' => optional($participant->pivot->last_typing_at)->toIso8601String(),
                    'is_blocked' => $authUserBlockList->contains($participant->id)
                        || $otherUserBlockList->contains($participant->id),
                ];
    
                return [
                    'user_id' => $participant->id,
                    'id' => $participant->id,
                    'name' => $participant->name,
                    'profile' => $participant->profile,
                    'role' => $role,
                    'status' => array_filter($status, function ($value) {
                        return $value !== null && $value !== '';
                    }),
                ];
            });
        }
    
        if ($participants->isEmpty()) {
            $fallback = collect();
    
            if ($offer->seller) {
                $fallback->push([
                    'user_id' => $offer->seller->id,
                    'id' => $offer->seller->id,
                    'name' => $offer->seller->name,
                    'profile' => $offer->seller->profile,
                    'role' => 'seller',
                    'status' => [
                        'is_online' => false,
                        'is_typing' => false,
                        'last_seen' => null,
                        'is_blocked' => $authUserBlockList->contains($offer->seller->id)
                            || $otherUserBlockList->contains($offer->seller->id),
                    ],
                ]);
            }
    
            if ($offer->buyer) {
                $fallback->push([
                    'user_id' => $offer->buyer->id,
                    'id' => $offer->buyer->id,
                    'name' => $offer->buyer->name,
                    'profile' => $offer->buyer->profile,
                    'role' => 'buyer',
                    'status' => [
                        'is_online' => false,
                        'is_typing' => false,
                        'last_seen' => null,
                        'is_blocked' => $authUserBlockList->contains($offer->buyer->id)
                            || $otherUserBlockList->contains($offer->buyer->id),
                    ],
                ]);
            }
    
            $participants = $fallback;
        }
    
        return $participants->values()->toArray();
    }


    private function hydrateLegacyChatConversation(ItemOffer $itemOffer, ?Chat $conversation = null): ?Chat
    {
        if (!Schema::hasTable('chats')) {
            return $conversation;
        }

        if ($conversation && $conversation->messages()->exists()) {
            return $conversation;
        }

        $legacyRows = DB::table('chats')
            ->where('item_offer_id', $itemOffer->id)
            ->orderBy('id')
            ->get();

        if ($legacyRows->isEmpty()) {
            return $conversation;
        }

        return DB::transaction(function () use ($legacyRows, $itemOffer, $conversation) {
            $conversationAttributes = [];
            $resolvedDepartment = $this->resolveSectionByCategoryId($itemOffer->item?->category_id);

            if ($resolvedDepartment !== null && $this->chatConversationsSupportsColumn('department')) {
                $conversationAttributes['department'] = $resolvedDepartment;
            }

            $conversation = $conversation ?: Chat::firstOrCreate(
                ['item_offer_id' => $itemOffer->id],
                $conversationAttributes
            );

            if ($conversation->messages()->exists()) {
                return $conversation;
            }

            $participantIds = collect([$itemOffer->seller_id, $itemOffer->buyer_id]);

            $messagesToInsert = [];

            foreach ($legacyRows as $row) {
                if (!empty($row->sender_id)) {
                    $participantIds->push($row->sender_id);
                }

                if (isset($row->receiver_id) && !empty($row->receiver_id)) {
                    $participantIds->push($row->receiver_id);
                }

                if (empty($row->sender_id)) {
                    continue;
                }

                $rowCreatedAt = !empty($row->created_at) ? Carbon::parse($row->created_at) : Carbon::now();
                $rowUpdatedAt = !empty($row->updated_at) ? Carbon::parse($row->updated_at) : $rowCreatedAt;

                $messageContent = $row->message === '' ? null : $row->message;

                $messagesToInsert[] = [
                    'conversation_id' => $conversation->id,
                    'sender_id' => $row->sender_id,
                    'message' => $messageContent,
                    'file' => $row->file ?: null,
                    'audio' => $row->audio ?: null,
                    'status' => ChatMessage::STATUS_SENT,
                    'created_at' => $rowCreatedAt->toDateTimeString(),
                    'updated_at' => $rowUpdatedAt->toDateTimeString(),
                ];
            }

            if (!empty($messagesToInsert)) {
                DB::table('chat_messages')->insert($messagesToInsert);
            }

            $uniqueParticipants = $participantIds->filter()->unique()->values();

            if ($uniqueParticipants->isNotEmpty()) {
                $conversation->participants()->syncWithoutDetaching($uniqueParticipants->all());
            }

            $createdAt = $legacyRows->pluck('created_at')
                ->filter()
                ->map(fn ($value) => Carbon::parse($value))
                ->min() ?? Carbon::now();

            $updatedAt = $legacyRows->pluck('updated_at')
                ->filter()
                ->map(fn ($value) => Carbon::parse($value))
                ->max() ?? $createdAt;

            DB::table('chat_conversations')
                ->where('id', $conversation->id)
                ->update([
                    'created_at' => $createdAt,
                    'updated_at' => $updatedAt,
                ]);

            $conversation->created_at = $createdAt;
            $conversation->updated_at = $updatedAt;

            return $conversation;
        });
    }



    public function markMessageDelivered(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'message_id'    => 'sometimes|integer|exists:chat_messages,id',
            'message_ids'   => 'sometimes|array|min:1',
            'message_ids.*' => 'integer|distinct|exists:chat_messages,id',
            'conversation_id' => 'sometimes|integer|exists:chat_conversations,id',
        
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }


        $messageIds = $this->extractMessageIdsFromRequest($request);

        if ($messageIds->isEmpty()) {
            ResponseService::validationError('message_id or message_ids is required.');
        }

        try {
            $user = Auth::user();
            $conversationId = $request->filled('conversation_id')
                ? (int) $request->input('conversation_id')
                : null;

            $messages = $this->resolveAuthorizedMessages($messageIds, $user, $conversationId);


            $timestamp = Carbon::now();
            $updatedMessages = collect();

            foreach ($messageIds as $messageId) {
                /** @var ChatMessage|null $message */
                $message = $messages->get($messageId);

                if (!$message) {
                    continue;
                }

                $conversation = $message->conversation;


                if (!$conversation) {
                    ResponseService::errorResponse('Conversation not found for the message', null, 404);
                }

                if (is_null($message->delivered_at)) {
                    $message->delivered_at = $timestamp;
                }

                if ($message->status !== ChatMessage::STATUS_READ) {
                    $message->status = ChatMessage::STATUS_DELIVERED;
                }

                $message->save();

                $message->refresh()->load('sender');

                try {
                    broadcast(new MessageDelivered($conversation, $message))->toOthers();
                } catch (Throwable $broadcastException) {
                    \Log::warning('Broadcast message delivered failed', [
                        'conversation_id' => $conversation->id,
                        'message_id' => $message->id,
                        'error' => $broadcastException->getMessage(),
                    ]);
                }

                $updatedMessages->push($message);
            }

            $responseMessage = $updatedMessages->count() > 1
                ? 'Messages marked as delivered successfully'
                : 'Message marked as delivered successfully';

            ResponseService::successResponse($responseMessage, $this->formatMessageUpdateResponse($updatedMessages));


        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> markMessageDelivered');
            ResponseService::errorResponse();
        }
    }

    public function markMessageRead(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'message_id'    => 'sometimes|integer|exists:chat_messages,id',
            'message_ids'   => 'sometimes|array|min:1',
            'message_ids.*' => 'integer|distinct|exists:chat_messages,id',
            'conversation_id' => 'sometimes|integer|exists:chat_conversations,id',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }


        $messageIds = $this->extractMessageIdsFromRequest($request);

        if ($messageIds->isEmpty()) {
            ResponseService::validationError('message_id or message_ids is required.');
        }

        try {
            $user = Auth::user();
            $conversationId = $request->filled('conversation_id')
                ? (int) $request->input('conversation_id')
                : null;

            $messages = $this->resolveAuthorizedMessages($messageIds, $user, $conversationId);


            $timestamp = Carbon::now();
            $updatedMessages = collect();

            foreach ($messageIds as $messageId) {
                /** @var ChatMessage|null $message */
                $message = $messages->get($messageId);

                if (!$message) {
                    continue;
                }

                $conversation = $message->conversation;


                if (!$conversation) {
                    ResponseService::errorResponse('Conversation not found for the message', null, 404);
                }

                if (is_null($message->delivered_at)) {
                    $message->delivered_at = $timestamp;
                }

                $message->status = ChatMessage::STATUS_READ;
                $message->read_at = $timestamp;

                $message->save();

                $message->refresh()->load('sender');

                try {
                    broadcast(new MessageRead($conversation, $message))->toOthers();
                } catch (Throwable $broadcastException) {
                    \Log::warning('Broadcast message read failed', [
                        'conversation_id' => $conversation->id,
                        'message_id' => $message->id,
                        'error' => $broadcastException->getMessage(),
                    ]);
                }

                $updatedMessages->push($message);
            }

            $responseMessage = $updatedMessages->count() > 1
                ? 'Messages marked as read successfully'
                : 'Message marked as read successfully';

            ResponseService::successResponse($responseMessage, $this->formatMessageUpdateResponse($updatedMessages));

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> markMessageRead');
            ResponseService::errorResponse();
        }
    }


    public function updateTypingStatus(Request $request, Chat $conversation)
    {
        $validator = Validator::make($request->all(), [
            'is_typing' => 'required|boolean',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $user = Auth::user();

            if (!$conversation->participants()->where('users.id', $user->id)->exists()) {
                ResponseService::errorResponse('You are not allowed to update this conversation', null, 403);
            }

            $timestamp = Carbon::now();
            $isTyping = $request->boolean('is_typing');

            $conversation->participants()->updateExistingPivot($user->id, [
                'is_typing' => $isTyping,
                'last_typing_at' => $timestamp,
                'updated_at' => $timestamp,
            ]);

            try {
                broadcast(new UserTyping($conversation, $user, $isTyping, $timestamp))->toOthers();
            } catch (Throwable $broadcastException) {
                \Log::warning('Broadcast typing status failed', [
                    'conversation_id' => $conversation->id,
                    'user_id' => $user->id,
                    'error' => $broadcastException->getMessage(),
                ]);
            }

            ResponseService::successResponse('Typing status updated successfully', [
                'conversation_id' => $conversation->id,
                'is_typing' => $isTyping,
                'last_typing_at' => $timestamp->toISOString(),
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> updateTypingStatus');
            ResponseService::errorResponse();
        }
    }

    public function updatePresenceStatus(Request $request, Chat $conversation)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:online,offline',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $user = Auth::user();

            if (!$conversation->participants()->where('users.id', $user->id)->exists()) {
                ResponseService::errorResponse('You are not allowed to update this conversation', null, 403);
            }

            $timestamp = Carbon::now();
            $isOnline = $request->status === 'online';

            $conversation->participants()->updateExistingPivot($user->id, [
                'is_online' => $isOnline,
                'last_seen_at' => $timestamp,
                'updated_at' => $timestamp,
            ]);

            try {
                broadcast(new UserPresenceUpdated($conversation, $user, $isOnline, $timestamp))->toOthers();
            } catch (Throwable $broadcastException) {
                \Log::warning('Broadcast presence status failed', [
                    'conversation_id' => $conversation->id,
                    'user_id' => $user->id,
                    'error' => $broadcastException->getMessage(),
                ]);
            }

            ResponseService::successResponse('Presence status updated successfully', [
                'conversation_id' => $conversation->id,
                'is_online' => $isOnline,
                'last_seen_at' => $timestamp->toISOString(),
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> updatePresenceStatus');
            ResponseService::errorResponse();
        }
    }



    public function deleteUser() {
        try {
            User::findOrFail(Auth::user()->id)->forceDelete();
            ResponseService::successResponse("User Deleted Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> deleteUser");
            ResponseService::errorResponse();
        }
    }

    public function inAppPurchase(Request $request) {
        $validator = Validator::make($request->all(), [
            'purchase_token' => 'required',
            'payment_method' => 'required|in:google,apple,wallet',
            'package_id'     => 'required|integer'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $user = Auth::user();

            
            $package = Package::findOrFail($request->package_id);
            $paymentMethod = $request->payment_method;

            DB::beginTransaction();

            $walletIdempotencyKey = null;
            $existingTransaction = null;

            if ($paymentMethod === 'wallet') {
                $walletIdempotencyKey = $this->buildWalletIdempotencyKey('package', $user->id, $package->id);

                $existingTransaction = $this->findWalletPaymentTransaction(
                    $user->id,
                    Package::class,
                    $package->id,
                    $walletIdempotencyKey
                );

                if ($existingTransaction && strtolower($existingTransaction->payment_status) === 'succeed') {
                    DB::commit();
                    ResponseService::successResponse('Package Purchased Successfully');
                }
            }

            $purchasedPackage = UserPurchasedPackage::query()
                ->where('user_id', $user->id)
                ->where('package_id', $package->id)
                ->lockForUpdate()
                ->first();
                
                
                
                if (!empty($purchasedPackage)) {
                if ($paymentMethod === 'wallet' && $walletIdempotencyKey) {
                    $existingTransaction ??= $this->findWalletPaymentTransaction(
                        $user->id,
                        Package::class,
                        $package->id,
                        $walletIdempotencyKey
                    );

                    if ($existingTransaction && strtolower($existingTransaction->payment_status) === 'succeed') {
                        DB::commit();
                        ResponseService::successResponse('Package Purchased Successfully');
                    }
                }

                DB::rollBack();
                ResponseService::errorResponse('You already have purchased this package');
            
            }

            if ($paymentMethod === 'wallet') {
                $transaction = $this->findOrCreateWalletTransaction(
                    $existingTransaction,
                    $user->id,
                    $package,
                    $walletIdempotencyKey,
                    $request->purchase_token
                );
            } else {
                $transaction = PaymentTransaction::create([
                    'user_id'         => $user->id,
                    'amount'          => $package->final_price,
                    'payment_gateway' => $paymentMethod,
                    'order_id'        => $request->purchase_token,
                    'payment_status'  => 'pending',
                ]);
            }



            $options = [
                'payment_gateway' => $paymentMethod,
            ];

            if ($paymentMethod === 'wallet') {
                $walletTransaction = $this->ensureWalletDebit(
                    $transaction,
                    $user,
                    $package,
                    $walletIdempotencyKey
                );

                $options['wallet_transaction'] = $walletTransaction;
                $options['meta']['wallet'] = [
                    'transaction_id' => $walletTransaction->getKey(),
                    'balance_after' => (float) $walletTransaction->balance_after,
                    'idempotency_key' => $walletTransaction->idempotency_key,
                    'purchase_token' => $request->purchase_token,
                ];
            }

            $result = $this->paymentFulfillmentService->fulfill(
                $transaction,
                Package::class,
                $package->id,
                $user->id,
                $options
            );

            if ($result['error']) {
                throw new RuntimeException($result['message']);
            }

            DB::commit();

            $message = $result['message'] === 'Transaction already processed'
                ? 'Transaction already processed'
                : 'Package Purchased Successfully';

            ResponseService::successResponse($message);
        } catch (RuntimeException $runtimeException) {
            DB::rollBack();
            ResponseService::errorResponse($runtimeException->getMessage());



        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, 'API Controller -> inAppPurchase');
            
            
            ResponseService::errorResponse();
        }
    }

    public function blockUser(Request $request) {
        $validator = Validator::make($request->all(), [
            'blocked_user_id' => 'required|integer',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            BlockUser::create([
                'user_id'         => Auth::user()->id,
                'blocked_user_id' => $request->blocked_user_id,
            ]);
            ResponseService::successResponse("User Blocked Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> blockUser");
            ResponseService::errorResponse();
        }
    }

    public function unblockUser(Request $request) {
        $validator = Validator::make($request->all(), [
            'blocked_user_id' => 'required|integer',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            BlockUser::where([
                'user_id'         => Auth::user()->id,
                'blocked_user_id' => $request->blocked_user_id,
            ])->delete();
            ResponseService::successResponse("User Unblocked Successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> unblockUser");
            ResponseService::errorResponse();
        }
    }

    public function getBlockedUsers() {
        try {
            $blockedUsers = BlockUser::where('user_id', Auth::user()->id)->pluck('blocked_user_id');
            $users = User::whereIn('id', $blockedUsers)->select(['id', 'name', 'profile'])->get();
            ResponseService::successResponse("User Unblocked Successfully", $users);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> unblockUser");
            ResponseService::errorResponse();
        }
    }





    private function applyWalletTransactionFilter(Builder $query, string $filter): void
    {
        switch ($filter) {
            case 'top-ups':
                $query->where('type', 'credit')
                    ->where(function (Builder $builder) {
                        $builder->whereNotNull('manual_payment_request_id')
                            ->orWhere('meta->reason', ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                            ->orWhere('meta->reason', 'wallet_top_up')
                            ->orWhere('meta->reason', 'admin_manual_credit');
                        
                        });
                break;
            case 'payments':
                $query->where('type', 'debit')
                    ->where(function (Builder $builder) {
                        $builder->whereNull('meta->reason')
                            ->orWhere('meta->reason', '!=', 'wallet_transfer');
                    });
                break;
            case 'transfers':
                $query->where(function (Builder $builder) {
                    $builder->where('meta->reason', 'wallet_transfer')
                        ->orWhere('meta->context', 'wallet_transfer');
                });


                break;
            case 'refunds':
                $query->where('type', 'credit')
                    ->where(function (Builder $builder) {
                        $builder->where('meta->reason', 'refund')
                            ->orWhere('meta->reason', 'wallet_refund');
                    });
                break;
            default:
                break;
        }
    }

    /**
     * @return array{available: array<int, array<string, string>>, applied?: string, default?: string}
     */
    private function buildWalletFilterPayload(?string $applied = null, bool $includeDefault = false): array
    {
        $available = array_map(function (string $value) {
            return [
                'value' => $value,
                'label' => $this->walletFilterLabel($value),
            ];
        }, self::WALLET_TRANSACTION_FILTERS);

        $payload = [
            'available' => $available,
        ];

        if ($applied !== null) {
            $payload['applied'] = $applied;
        }

        if ($includeDefault) {
            $payload['default'] = 'all';
        }

        return $payload;
    }

    private function walletFilterLabel(string $filter): string
    {
        return match ($filter) {
            'top-ups' => __('wallet.filters.top_ups'),
            'payments' => __('wallet.filters.payments'),
            'transfers' => __('wallet.filters.transfers'),
            'refunds' => __('wallet.filters.refunds'),
            default => __('wallet.filters.all'),
        };
    }


    private function performWalletTransfer(
        User $sender,
        User $recipient,
        float $amount,
        string $idempotencyKey,
        string $clientTag,
        ?string $currency = null,
        ?string $reference = null,
        ?string $notes = null
    ): array {
        return DB::transaction(function () use ($sender, $recipient, $amount, $idempotencyKey, $clientTag, $currency, $reference, $notes) {
            $debitKey = $this->buildDirectionalWalletTransferKey($idempotencyKey, 'debit');
            $creditKey = $this->buildDirectionalWalletTransferKey($idempotencyKey, 'credit');

            $existingDebit = WalletTransaction::query()
                ->where('idempotency_key', $debitKey)
                ->whereHas('account', static function ($query) use ($sender) {
                    $query->where('user_id', $sender->id);
                })
                ->lockForUpdate()
                ->first();

            $existingCredit = WalletTransaction::query()
                ->where('idempotency_key', $creditKey)
                ->whereHas('account', static function ($query) use ($recipient) {
                    $query->where('user_id', $recipient->id);
                })
                ->lockForUpdate()
                ->first();

            if ($existingDebit && $existingCredit) {
                return [$existingDebit->fresh(), $existingCredit->fresh(), true];
            }

            if (($existingDebit && !$existingCredit) || (!$existingDebit && $existingCredit)) {
                throw new RuntimeException('Wallet transfer is in an inconsistent state.');
            }

            $debitMeta = $this->buildWalletTransferMeta('outgoing', $idempotencyKey, $clientTag, $reference, $notes, $recipient);
            $creditMeta = $this->buildWalletTransferMeta('incoming', $idempotencyKey, $clientTag, $reference, $notes, $sender);

            $debitOptions = [
                'meta' => $debitMeta,
            ];

            if ($currency !== null) {
                $debitOptions['currency'] = $currency;
            }

            $debitTransaction = $this->walletService->debit($sender, $debitKey, $amount, $debitOptions);

            $creditOptions = [

                'meta' => $creditMeta,
            ];

            if ($currency !== null) {
                $creditOptions['currency'] = $currency;
            }

            $creditTransaction = $this->walletService->credit($recipient, $creditKey, $amount, $creditOptions);

            return [$debitTransaction, $creditTransaction, false];
        });
    }



    private function maskMobileNumber(?string $mobile): ?string
    {
        if ($mobile === null || $mobile === '') {
            return null;
        }

        $characters = preg_split('//u', $mobile, -1, PREG_SPLIT_NO_EMPTY);

        if ($characters === false || $characters === null) {
            return null;
        }

        $digitCount = 0;
        foreach ($characters as $character) {
            if (ctype_digit($character)) {
                $digitCount++;
            }
        }

        if ($digitCount <= 3) {
            return $mobile;
        }

        $digitsToMask = $digitCount - 3;
        $masked = 0;

        foreach ($characters as $index => $character) {
            if (!ctype_digit($character)) {
                continue;
            }

            if ($masked < $digitsToMask) {
                $characters[$index] = '*';
                $masked++;
            }
        }

        return implode('', $characters);
    }


    private function buildWalletTransferMeta(
        string $direction,
        string $transferKey,
        string $clientTag,
        ?string $reference,
        ?string $notes,
        User $counterparty
    ): array {
        $meta = [
            'context' => 'wallet_transfer',
            'direction' => $direction,
            'transfer_key' => $transferKey,
            'client_tag' => $clientTag,
            'reason' => 'wallet_transfer',
            'counterparty' => [
                'id' => $counterparty->id,
                'name' => $counterparty->name,
            ],
        ];

        if ($reference !== null && $reference !== '') {
            $meta['reference'] = $reference;
        }

        if ($notes !== null && $notes !== '') {
            $meta['notes'] = $notes;
        }

        return $meta;
    }

    private function buildDirectionalWalletTransferKey(string $baseKey, string $direction): string
    {
        return sprintf('%s:%s', $baseKey, $direction);
    }

    private function buildWalletTransferIdempotencyKey(User $sender, User $recipient, float $amount, string $clientTag): string
    {
        $normalizedAmount = number_format($amount, 2, '.', '');

        return sprintf(
            'wallet_transfer:%d:%d:%s:%s',
            $sender->id,
            $recipient->id,
            $normalizedAmount,
            md5($clientTag)
        );
    }


    private function normalizeCurrencyCode(?string $currency): ?string
    {
        if ($currency === null) {
            return null;
        }

        $trimmed = trim($currency);

        if ($trimmed === '') {
            return null;
        }

        $lower = Str::lower($trimmed);

        if (isset(self::CURRENCY_SYNONYMS[$lower])) {
            return self::CURRENCY_SYNONYMS[$lower];
        }

        $tokens = preg_split('/[\s\-_/\\()]+/u', $trimmed, -1, PREG_SPLIT_NO_EMPTY) ?: [];

        foreach ($tokens as $token) {
            $tokenLower = Str::lower($token);

            if (isset(self::CURRENCY_SYNONYMS[$tokenLower])) {
                return self::CURRENCY_SYNONYMS[$tokenLower];
            }
        }

        if (preg_match('/[A-Z]{3}/i', strtoupper($trimmed), $matches) === 1) {
            return strtoupper($matches[0]);
        }

        return null;
    }




    private function buildWalletIdempotencyKey(string $context, int $userId, int|string $subjectId): string
    {
        return sprintf('wallet:%s:%d:%s', $context, $userId, $subjectId);
    }

    private function buildManualPaymentWalletIdempotencyKey(User $user, ?string $payableType, ?int $payableId, float $amount, ?string $currency = null): string
    {
        if (is_string($payableType) && class_exists($payableType)) {
            $normalizedType = Str::of($payableType)->lower()->replace('\\', '_')->toString();
        } elseif (is_string($payableType)) {
            $normalizedType = Str::of($payableType)->lower()->toString();
        } else {
            $normalizedType = 'none';
        }

        $subjectParts = [
            $normalizedType,
            $payableId !== null ? (string) $payableId : 'none',
            number_format($amount, 2, '.', ''),
        ];

        if ($currency) {
            $subjectParts[] = strtoupper($currency);
        }

        return $this->buildWalletIdempotencyKey('manual_payment', $user->id, implode(':', $subjectParts));
    }

    private function findWalletPaymentTransaction(int $userId, ?string $payableType, ?int $payableId, string $idempotencyKey): ?PaymentTransaction


    {
        return PaymentTransaction::query()
            ->where('user_id', $userId)
            ->where('payment_gateway', 'wallet')
            ->where('order_id', $idempotencyKey)
            ->when($payableType !== null, static function ($query) use ($payableType) {
                $query->where('payable_type', $payableType);
            }, static function ($query) {
                $query->whereNull('payable_type');
            })
            ->when($payableId !== null, static function ($query) use ($payableId) {
                $query->where('payable_id', $payableId);
            }, static function ($query) {
                $query->whereNull('payable_id');
            })


            ->lockForUpdate()
            ->first();
    }

    private function findOrCreateWalletTransaction(?PaymentTransaction $existingTransaction, int $userId, Package $package, string $idempotencyKey, string $purchaseToken): PaymentTransaction
    {
        if ($existingTransaction) {
            $existingTransaction->forceFill([
                'amount' => $package->final_price,
            ])->save();

            return $existingTransaction->fresh();
        }

        return PaymentTransaction::create([
            'user_id' => $userId,
            'amount' => $package->final_price,
            'payment_gateway' => 'wallet',
            'order_id' => $idempotencyKey,
            'payment_status' => 'pending',
            'payable_type' => Package::class,
            'payable_id' => $package->id,
            'meta' => [
                'wallet' => [
                    'idempotency_key' => $idempotencyKey,
                    'purchase_token' => $purchaseToken,
                ],
            ],
        ]);
    }

    private function ensureWalletDebit(PaymentTransaction $transaction, User $user, Package $package, string $idempotencyKey): WalletTransaction


    {
        return $this->debitWalletTransaction($transaction, $user, $idempotencyKey, (float) $package->final_price, [
            'meta' => [
                'context' => 'package_purchase',
                'package_id' => $package->id,
            ],
        ]);
    }

    private function debitWalletTransaction(PaymentTransaction $transaction, User $user, string $idempotencyKey, float $amount, array $options = []): WalletTransaction


    {
        $walletTransactionId = data_get($transaction->meta, 'wallet.transaction_id');

        if ($walletTransactionId) {
            $walletTransaction = WalletTransaction::query()
                ->whereKey($walletTransactionId)
                ->lockForUpdate()
                ->first();

            if ($walletTransaction) {
                return $walletTransaction;
            }
        }

        try {
            return $this->walletService->debit($user, $idempotencyKey, $amount, array_merge([
                'payment_transaction' => $transaction,

            ], $options));

        } catch (RuntimeException $runtimeException) {
            if (str_contains(strtolower($runtimeException->getMessage()), 'insufficient wallet balance')) {
                DB::rollBack();
                ResponseService::errorResponse('Insufficient wallet balance');
            }

            $walletTransaction = $this->resolveWalletTransaction($user, $idempotencyKey);

            if (!$walletTransaction) {
                throw $runtimeException;
            }

            return $walletTransaction;
        }
    }

    private function resolveWalletTransaction(User $user, string $idempotencyKey): ?WalletTransaction
    {
        return WalletTransaction::query()
            ->where('idempotency_key', $idempotencyKey)
            ->whereHas('account', static function ($query) use ($user) {
                $query->where('user_id', $user->id);
            })
            ->lockForUpdate()
            ->first();
    }



    public function getBlog(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'category_id' => 'nullable|integer|exists:categories,id',
                'blog_id'     => 'nullable|integer|exists:blogs,id',
                'sort_by'     => 'nullable|in:new-to-old,old-to-new,popular',
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            $blogs = Blog::when(!empty($request->id), static function ($q) use ($request) {
                $q->where('id', $request->id);
                Blog::where('id', $request->id)->increment('views');
            })
                ->when(!empty($request->slug), function ($q) use ($request) {
                    $q->where('slug', $request->slug);
                    Blog::where('slug', $request->slug)->increment('views');
                })
                ->when(!empty($request->sort_by), function ($q) use ($request) {
                    if ($request->sort_by === 'new-to-old') {
                        $q->orderByDesc('created_at');
                    } elseif ($request->sort_by === 'old-to-new') {
                        $q->orderBy('created_at');
                    } else if ($request->sort_by === 'popular') {
                        $q->orderByDesc('views');
                    }
                })
                ->when(!empty($request->tag), function ($q) use ($request) {
                    $q->where('tags', 'like', "%" . $request->tag . "%");
                })->paginate();

            $otherBlogs = [];
            if (!empty($request->id) || !empty($request->slug)) {
                $otherBlogs = Blog::orderByDesc('id')->limit(3)->get();
            }
            // Return success response with the fetched blogs
            ResponseService::successResponse("Blogs fetched successfully", $blogs, ['other_blogs' => $otherBlogs]);
        } catch (Throwable $th) {
            // Log and handle exceptions
            ResponseService::logErrorResponse($th, 'API Controller -> getBlog');
            ResponseService::errorResponse("Failed to fetch blogs");
        }
    }

    public function getCountries(Request $request) {
        try {
            $searchQuery = $request->search ?? '';
            $countries = Country::withCount('states')->where('name', 'LIKE', "%{$searchQuery}%")->orderBy('name', 'ASC')->paginate();
            ResponseService::successResponse("Countries Fetched Successfully", $countries);
        } catch (Throwable $th) {
            // Log and handle any exceptions
            ResponseService::logErrorResponse($th, "API Controller -> getCountries");
            ResponseService::errorResponse("Failed to fetch countries");
        }
    }

    public function getStates(Request $request) {
        $validator = Validator::make($request->all(), [
            'country_id' => 'nullable|integer',
            'search'     => 'nullable|string'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $searchQuery = $request->search ?? '';
            $statesQuery = State::withCount('cities')
                ->where('name', 'LIKE', "%{$searchQuery}%")
                ->orderBy('name', 'ASC');

            if (isset($request->country_id)) {
                $statesQuery->where('country_id', $request->country_id);
            }

            $states = $statesQuery->paginate();

            ResponseService::successResponse("States Fetched Successfully", $states);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller->getStates");
            ResponseService::errorResponse("Failed to fetch states");
        }
    }

    public function getCities(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'state_id' => 'nullable|integer',
                'search'   => 'nullable|string'
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            $searchQuery = $request->search ?? '';
            $citiesQuery = City::withCount('areas')
                ->where('name', 'LIKE', "%{$searchQuery}%")
                ->orderBy('name', 'ASC');

            if (isset($request->state_id)) {
                $citiesQuery->where('state_id', $request->state_id);
            }

            $cities = $citiesQuery->paginate();

            ResponseService::successResponse("Cities Fetched Successfully", $cities);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller->getCities");
            ResponseService::errorResponse("Failed to fetch cities");
        }
    }

    public function getAreas(Request $request) {
        $validator = Validator::make($request->all(), [
            'city_id' => 'nullable|integer',
            'search'  => 'nullable'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $searchQuery = $request->search ?? '';
            $data = Area::search($searchQuery)->orderBy('name', 'ASC');
            if (isset($request->city_id)) {
                $data->where('city_id', $request->city_id);
            }

            $data = $data->paginate();
            ResponseService::successResponse("Area fetched Successfully", $data);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getAreas');
            ResponseService::errorResponse();
        }
    }

    public function getFaqs() {
        try {
            $faqs = Faq::get();
            ResponseService::successResponse("FAQ Data fetched Successfully", $faqs);
        } catch (Throwable $th) {
            // Log and handle exceptions
            ResponseService::logErrorResponse($th, 'API Controller -> getFaqs');
            ResponseService::errorResponse("Failed to fetch Faqs");
        }
    }

    public function getAllBlogTags() {
        try {
            $tagsArray = [];
            Blog::select('tags')->chunk(100, function ($blogs) use (&$tagsArray) {
                foreach ($blogs as $blog) {
                    foreach ($blog->tags as $tags) {
                        $tagsArray[] = $tags;
                    }
                }
            });
            $tagsArray = array_unique($tagsArray);
            ResponseService::successResponse("Blog Tags Successfully", $tagsArray);
        } catch (Throwable $th) {
            // Log and handle exceptions
            ResponseService::logErrorResponse($th, 'API Controller -> getAllBlogTags');
            ResponseService::errorResponse("Failed to fetch Tags");
        }
    }

    public function storeContactUs(Request $request) {
        $validator = Validator::make($request->all(), [
            'name'    => 'required',
            'email'   => 'required',
            'subject' => 'required',
            'message' => 'required'
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            ContactUs::create($request->all());
            ResponseService::successResponse("Contact Us Stored Successfully");

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> storeContactUs');
            ResponseService::errorResponse();
        }
    }

    public function addItemReview(Request $request) {
        $validator = Validator::make($request->all(), [
            'review'  => 'nullable|string',
            'ratings' => 'required|numeric|between:0,5',
            'item_id' => 'required',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $item = Item::with('user')->notOwner()->findOrFail($request->item_id);
            if ($item->sold_to !== Auth::id()) {
                ResponseService::errorResponse("You can only review items that you have purchased.");
            }
            if ($item->status !== 'sold out') {
                ResponseService::errorResponse("The item must be marked as 'sold out' before you can review it.");
            }
            $existingReview = SellerRating::where('item_id', $request->item_id)->where('buyer_id', Auth::id())->first();
            if ($existingReview) {
                ResponseService::errorResponse("You have already reviewed this item.");
            }
            $review = SellerRating::create([
                'item_id'   => $request->item_id,
                'buyer_id'  => Auth::user()->id,
                'seller_id' => $item->user_id,
                'ratings'   => $request->ratings,
                'review'    => $request->review ?? '',
            ]);

            ResponseService::successResponse("Your review has been submitted successfully.", $review);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> storeContactUs');
            ResponseService::errorResponse();
        }
    }

    public function getSeller(Request $request) {
        $request->validate([
            'id' => 'required|integer'
        ]);

        try {
            // Fetch seller by ID
            $seller = User::findOrFail($request->id);

            // Fetch seller ratings
            $ratings = SellerRating::where('seller_id', $seller->id)->with('buyer:id,name,profile')->paginate(10);
            $averageRating = $ratings->avg('ratings');

            // Response structure
            $response = [
                'seller'  => [
                    ...$seller->toArray(),
                    'average_rating' => $averageRating,
                ],
                'ratings' => $ratings,
            ];

            // Send success response
            ResponseService::successResponse("Seller Details Fetched Successfully", $response);

        } catch (Throwable $th) {
            // Log and handle error response
            ResponseService::logErrorResponse($th, "API Controller -> getSeller");
            ResponseService::errorResponse();
        }
    }


    public function renewItem(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'item_id' => 'required|exists:items,id',


            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }



             DB::beginTransaction();

            $user = Auth::user();
            $item = Item::where('user_id', $user->id)->findOrFail($request->item_id);
            


          $userPackage = UserPurchasedPackage::onlyActive()
                ->where('user_id', $user->id)
                ->whereHas('package', static function ($query) {
                    $query->where('type', 'item_listing');
                })
                ->with('package')
                ->lockForUpdate()
                ->first();

            if (empty($userPackage)) {
                DB::rollBack();
                ResponseService::errorResponse("No Active Package found for Item Renewal");
            }

            $currentDate = Carbon::now();
            if (!empty($item->expiry_date) && Carbon::parse($item->expiry_date)->gt($currentDate)) {
                DB::rollBack();
                ResponseService::errorResponse("Item has not expired yet, so it cannot be renewed");
            }

            $package = $userPackage->package ?? $userPackage->load('package')->package;
            if (empty($package)) {
                DB::rollBack();
                ResponseService::errorResponse("Package details not found");
            }

            $rawStatus = $item->getAttributes()['status'];

            if ($package->duration === 'unlimited') {
                $item->expiry_date = null;
            } else {
                $expiryDays = (int)$package->duration;
                $item->expiry_date = $currentDate->copy()->addDays($expiryDays);
            }

            $item->status = $rawStatus;



            $item->save();

            ResponseService::successResponse("Item renewed successfully (Free renewal)", $item);
            

            ++$userPackage->used_limit;
            $userPackage->save();

            DB::commit();

            ResponseService::successResponse("Item renewed successfully", $item->fresh());




        } catch (Throwable $th) {

                        DB::rollBack();

            ResponseService::logErrorResponse($th, "API Controller -> renewItem");
            ResponseService::errorResponse();
        }
    }

    public function getMyReview(Request $request) {
        try {
            $ratings = SellerRating::where('seller_id', Auth::user()->id)->with('seller:id,name,profile', 'buyer:id,name,profile', 'item:id,name,price,image,description')->paginate(10);
            $averageRating = $ratings->avg('ratings');
            $response = [
                'average_rating' => $averageRating,
                'ratings'        => $ratings,
            ];

            ResponseService::successResponse("Seller Details Fetched Successfully", $response);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getSeller");
            ResponseService::errorResponse();
        }
    }

    public function addReviewReport(Request $request) {
        $validator = Validator::make($request->all(), [
            'report_reason'    => 'required|string',
            'seller_review_id' => 'required',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $ratings = SellerRating::where('seller_id', Auth::user()->id)->findOrFail($request->seller_review_id);
            $ratings->update([
                'report_status' => 'reported',
                'report_reason' => $request->report_reason
            ]);

            ResponseService::successResponse("Your report has been submitted successfully.", $ratings);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> addReviewReport');
            ResponseService::errorResponse();
        }
    }


        public function addServiceReview(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'service_id' => 'required|exists:services,id',
            'rating'     => 'required|integer|min:1|max:5',
            'review'     => 'nullable|string|max:2000',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            /** @var User $user */
            $user = Auth::user();
            $service = Service::findOrFail($request->service_id);

            if (!$this->userCanReviewService($user, $service)) {
                ResponseService::errorResponse('You are not allowed to review this service.');
            }

            $existingReview = ServiceReview::where('service_id', $service->id)
                ->where('user_id', $user->id)
                ->first();

            if ($existingReview) {
                ResponseService::errorResponse('You have already reviewed this service.');
            }

            $review = ServiceReview::create([
                'service_id' => $service->id,
                'user_id'    => $user->id,
                'rating'     => (int) $request->rating,
                'review'     => $request->review !== null ? trim((string) $request->review) : null,
                'status'     => ServiceReview::STATUS_PENDING,
            ])->load('user:id,name,profile');

            $this->notifyServiceOwnerAboutReview($service, $review, $user);



            ResponseService::successResponse('Service review submitted successfully.', $review);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> addServiceReview');
            ResponseService::errorResponse();
        }
    }

    public function getMyServiceReviews(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'service_id' => 'required|exists:services,id',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            /** @var User $user */
            $user = Auth::user();

            $review = ServiceReview::query()
                ->with('service:id,title')
                ->where('service_id', $request->service_id)
                ->where('user_id', $user->id)
                ->first();

            $payload = [];

            if ($review) {
                $payload[] = [
                    'id' => $review->id,
                    'service_id' => $review->service_id,
                    'rating' => $review->rating,
                    'review' => $review->review,
                    'status' => $review->status,
                    'service_title' => $review->service?->title,
                    'created_at' => optional($review->created_at)->toDateTimeString(),
                    'updated_at' => optional($review->updated_at)->toDateTimeString(),
                ];
            }

            ResponseService::successResponse('Service review fetched successfully.', $payload);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getMyServiceReviews');
            ResponseService::errorResponse();
        }
    }

    public function getServiceReviews(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'service_id' => 'required|exists:services,id',
            'status'     => 'nullable|string|in:pending,approved,rejected,all',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $service = Service::findOrFail($request->service_id);
            $authenticatedUser = Auth::user();

            $requestedStatus = $request->input('status');
            $isOwner = $authenticatedUser && (int) ($service->owner_id ?? 0) === (int) $authenticatedUser->id;
            $canManageService = $authenticatedUser
                ? $this->serviceAuthorizationService->userCanManageService($authenticatedUser, $service)
                : false;

            $canAccessAllStatuses = $authenticatedUser && ($isOwner || $canManageService);
            $status = $canAccessAllStatuses
                ? ($requestedStatus ?? ServiceReview::STATUS_APPROVED)
                : ServiceReview::STATUS_APPROVED;


            $reviewsQuery = ServiceReview::where('service_id', $service->id)
                ->with('user:id,name,profile')
                ->orderByDesc('created_at');

            if ($status !== 'all') {
                $reviewsQuery->where('status', $status ?: ServiceReview::STATUS_APPROVED);
            }

            $reviews = $reviewsQuery->get();

            $average = ServiceReview::where('service_id', $service->id)
                ->where('status', ServiceReview::STATUS_APPROVED)
                ->avg('rating');


            $response = [
                'service_id'     => $service->id,
                'average_rating' => $average !== null ? round((float) $average, 2) : null,
                'total_reviews'  => $reviews->count(),
                'reviews'        => $reviews,
            ];

            if ($authenticatedUser) {
                $response['can_review'] = $this->userCanReviewService($authenticatedUser, $service)
                    && !ServiceReview::where('service_id', $service->id)
                        ->where('user_id', $authenticatedUser->id)
                        ->exists();
            }

            ResponseService::successResponse('Service reviews fetched successfully.', $response);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getServiceReviews');
            ResponseService::errorResponse();
        }
    }


    public function addServiceReviewReport(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'review_id' => 'required|exists:service_reviews,id',
            'message' => 'nullable|string|max:2000',
            'details' => 'nullable|string|max:2000',
            'reason' => 'nullable|string|max:255',
            'type' => 'nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            /** @var User $user */
            $user = Auth::user();
            $review = ServiceReview::with('service')->findOrFail($request->review_id);

            if ((int) $review->user_id === (int) $user->id) {
                ResponseService::errorResponse(__('You cannot report your own review.'));
            }

            $alreadyReported = ServiceReviewReport::query()
                ->where('service_review_id', $review->id)
                ->where('reporter_id', $user->id)
                ->exists();

            if ($alreadyReported) {
                ResponseService::errorResponse(__('You have already reported this review.'));
            }

            $message = $request->input('message');
            if ($message === null || trim((string) $message) === '') {
                $message = $request->input('details');
            }

            $reason = $request->input('reason');
            if ($reason === null || trim((string) $reason) === '') {
                $reason = $request->input('type');
            }

            $report = ServiceReviewReport::create([
                'service_review_id' => $review->id,
                'reporter_id' => $user->id,
                'reason' => $reason !== null ? trim((string) $reason) ?: null : null,
                'message' => $message !== null ? trim((string) $message) ?: null : null,
                'status' => 'pending',
            ]);

            ResponseService::successResponse(__('Your report has been submitted successfully.'), [
                'id' => $report->id,
                'status' => $report->status,
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> addServiceReviewReport');
            ResponseService::errorResponse();
        }
    }

    protected function userCanReviewService(User $user, Service $service): bool
    {
        if ((int) $service->direct_user_id === (int) $user->id && $service->direct_to_user) {
            return true;
        }

        if (Schema::hasTable('service_requests')) {
            $hasQualifiedRequest = ServiceRequest::where('service_id', $service->id)
                ->where('user_id', $user->id)
                ->whereNull('deleted_at')
                ->where(function ($query) {
                    $query->whereNull('status')
                        ->orWhereIn('status', ['approved', 'review', 'completed', 'closed']);
                })
                ->exists();

            if ($hasQualifiedRequest) {
                return true;
            }
        }

        return false;
    }



    protected function notifyServiceOwnerAboutReview(Service $service, ServiceReview $review, User $reviewer): void
    {
        $ownerId = (int) ($service->owner_id ?? 0);

        if ($ownerId <= 0) {
            return;
        }

        $owner = User::find($ownerId);

        if (!$owner) {
            return;
        }

        $title = __('New service review received');
        $message = __(':user left a new review on ":service".', [
            'user'    => $reviewer->name ?? __('A user'),
            'service' => $service->title ?? __('your service'),
        ]);

        $payload = [
            'service_id'    => $service->id,
            'service_title' => $service->title,
            'review_id'     => $review->id,
            'reviewer_id'   => $reviewer->id,
            'rating'        => $review->rating,
            'review_status' => $review->status,
            'comment'       => $review->review,
        ];

        try {
            $tokens = UserFcmToken::where('user_id', $ownerId)
                ->pluck('fcm_token')
                ->filter()
                ->unique()
                ->values()
                ->all();

            if (!empty($tokens) && ($owner->notification ?? true)) {
                $response = NotificationService::sendFcmNotification(
                    $tokens,
                    $title,
                    $message,
                    'service-review',
                    $payload
                );

                if (is_array($response) && ($response['error'] ?? false)) {
                    Log::warning('service_reviews.notification_failed', [
                        'service_id'        => $service->id,
                        'review_id'         => $review->id,
                        'owner_id'          => $ownerId,
                        'response_message'  => $response['message'] ?? null,
                        'response_details'  => $response['details'] ?? null,
                        'response_code'     => $response['code'] ?? null,
                    ]);
                }
            }
        } catch (Throwable $e) {
            Log::error('service_reviews.notification_exception', [
                'service_id'     => $service->id,
                'review_id'      => $review->id,
                'owner_id'       => $ownerId,
                'error'          => $e->getMessage(),
                'exception_class'=> get_class($e),
            ]);
        }

        try {
            Notifications::create([
                'title'   => $title,
                'message' => $message,
                'image'   => '',
                'item_id' => null,
                'send_to' => 'selected',
                'user_id' => (string) $ownerId,
            ]);
        } catch (Throwable $e) {
            Log::error('service_reviews.notification_log_failed', [
                'service_id'     => $service->id,
                'review_id'      => $review->id,
                'owner_id'       => $ownerId,
                'error'          => $e->getMessage(),
                'exception_class'=> get_class($e),
            ]);
        }
    }

    public function getVerificationFields(Request $request)
    {
        try {
            $accountType = $this->normalizeAccountTypeSlug($request->get('account_type'));

            if (!$accountType) {
                $user = auth()->user();
                if ($user && $user->account_type) {
                    $accountType = $this->mapAccountTypeIntToSlug((int) $user->account_type);
                }
            }

            $fields = VerificationField::query()
                ->when($accountType, static fn($query) => $query->where('account_type', $accountType))
                ->whereNull('deleted_at')
                ->orderBy('id')
                ->get()
                ->map(fn(VerificationField $field) => $this->serializeVerificationField($field))
                ->values();

            ResponseService::successResponse('Verification Field Fetched Successfully', $fields);

        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getVerificationFields');
            ResponseService::errorResponse('Failed to fetch verification fields.');
        }
    }

    public function getVerificationMetadata(Request $request)
    {
        try {
            $accountType = $this->normalizeAccountTypeSlug($request->get('account_type'));

            $fields = VerificationField::query()
                ->whereNull('deleted_at')
                ->when($accountType, static fn($query) => $query->where('account_type', $accountType))
                ->orderBy('id')
                ->get();

            $plans = VerificationPlan::query()
                ->where('is_active', true)
                ->when($accountType, static fn($query) => $query->where('account_type', $accountType))
                ->orderByDesc('id')
                ->get()
                ->keyBy('account_type');

            $accountTypes = $accountType ? [$accountType] : ['individual', 'commercial', 'realestate'];

            $payload = collect($accountTypes)->map(function (string $type) use ($fields, $plans) {
                $typeFields = $fields->where('account_type', $type)->values();
                $plan = $plans->get($type);

                return [
                    'account_type' => $type,
                    'pricing' => [
                        'amount' => $plan?->price ?? 0.0,
                        'currency' => $plan?->currency ?? 'SAR',
                        'duration_days' => $plan?->duration_days,
                    ],
                    'benefits' => $this->buildVerificationBenefits($type, $plan),
                    'required_fields' => $typeFields->map(fn(VerificationField $field) => $this->serializeVerificationField($field))->values(),
                    'updated_at' => optional($typeFields->max('updated_at'))?->toDateTimeString() ?? now()->toDateTimeString(),
                ];
            })->values();

            ResponseService::successResponse('Verification metadata fetched successfully.', [
                'updated_at' => now()->toIso8601String(),
                'account_types' => $payload,
            ]);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getVerificationMetadata');
            ResponseService::errorResponse('Failed to fetch verification metadata.');
        }
    }

    public function sendVerificationRequest(Request $request) {
        try {

            $validator = Validator::make($request->all(), [
                'verification_field'         => 'sometimes|array',
                'verification_field.*'       => 'sometimes',
                'verification_field_files'   => 'nullable|array',
                'verification_field_files.*' => 'nullable|mimes:jpeg,png,jpg,pdf,doc|max:4096',
                'account_type'               => 'nullable|string'
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }

            $user = Auth::user();
            $accountTypeSlug = $this->resolveAccountTypeSlug($user, $request->get('account_type'));
            $missingRequired = $this->validateRequiredVerificationFields($accountTypeSlug, $request);

            if (!empty($missingRequired)) {
                ResponseService::validationError(
                    __('الحقول التالية إلزامية: :fields', ['fields' => implode(', ', $missingRequired)])
                );
            }

            DB::beginTransaction();

            $verificationRequest = VerificationRequest::updateOrCreate([
                'user_id' => $user->id,
            ], ['status' => 'pending']);

            $user = auth()->user();
            if ($request->verification_field) {
                $itemCustomFieldValues = [];
                foreach ($request->verification_field as $id => $value) {
                    $fieldId = (int) $id;

                    if ($fieldId <= 0) {
                        continue;
                    }

                    $normalizedValue = $this->normalizeVerificationFieldValue($value);

                    $itemCustomFieldValues[] = [
                        'user_id'                 => $user->id,
                        'verification_field_id'   => $fieldId,
                        'verification_request_id' => $verificationRequest->id,
                        'value'                   => $normalizedValue,
                        'created_at'              => now(),
                        'updated_at'              => now()
                    ];
                }

                if (!empty($itemCustomFieldValues)) {
                    VerificationFieldValue::upsert(
                        $itemCustomFieldValues,
                        ['user_id', 'verification_field_id'],
                        ['value', 'updated_at', 'verification_request_id']
                    );
                }
            }

            if ($request->verification_field_files) {
                $itemCustomFieldValues = [];
                foreach ($request->verification_field_files as $fieldId => $file) {

                    $normalizedFieldId = (int) $fieldId;

                    if ($normalizedFieldId <= 0) {
                        continue;
                    }



                    $itemCustomFieldValues[] = [
                        'user_id'                 => $user->id,
                        'verification_field_id'   => $normalizedFieldId,
                        'verification_request_id' => $verificationRequest->id,
                        'value'                   => !empty($file) ? FileService::upload($file, 'verification_field_files') : null,
                        'created_at'              => now(),
                        'updated_at'              => now()
                    ];
                }

                if (!empty($itemCustomFieldValues)) {
                    VerificationFieldValue::upsert(
                        $itemCustomFieldValues,
                        ['user_id', 'verification_field_id'],
                        ['value', 'updated_at', 'verification_request_id']
                    );
                }
            }
            DB::commit();

            ResponseService::successResponse("Verification request submitted successfully.");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> SendVerificationRequest");
            ResponseService::errorResponse();
        }
    }




    protected function serializeVerificationField(VerificationField $field): array
    {
        return [
            'id' => $field->id,
            'name' => $field->name,
            'type' => $field->type,
            'account_type' => $field->account_type ?? 'individual',
            'required' => $field->is_required ? 1 : 0,
            'min_length' => $field->min_length,
            'max_length' => $field->max_length,
            'status' => $field->deleted_at ? 0 : 1,
            'values' => is_array($field->values)
                ? $field->values
                : (empty($field->values) ? [] : [(string) $field->values]),
        ];
    }

    protected function buildVerificationBenefits(string $accountType, ?VerificationPlan $plan): array
    {
        $baseBenefits = [
            'individual' => [
                'شارة موثقة أمام اسمك',
                'ثقة أعلى لدى المشترين',
                'أولوية في البحث والإعلانات',
            ],
            'commercial' => [
                'شارات توثيق للمتاجر والشركات',
                'تعزيز ظهور المنتجات والخدمات',
                'إمكانية متابعة التغطية الإعلانية',
            ],
            'realestate' => [
                'تمييز عروض العقارات الموثوقة',
                'جذب العملاء الجادين أولاً',
                'أولوية مراجعة الطلبات العقارية',
            ],
        ];

        $benefits = $baseBenefits[$accountType] ?? $baseBenefits['individual'];

        if (!empty($plan?->duration_days)) {
            $benefits[] = __('صلاحية التوثيق :days يوم', ['days' => $plan->duration_days]);
        }

        if (!empty($plan?->price) && $plan->price > 0) {
            $benefits[] = __('رسوم الاشتراك :price :currency', [
                'price' => number_format((float) $plan->price, 2),
                'currency' => $plan->currency ?? 'SAR',
            ]);
        } else {
            $benefits[] = __('توثيق مجاني للحسابات المؤهلة');
        }

        return array_values(array_unique(array_filter($benefits)));
    }

    protected function resolveAccountTypeSlug(?User $user, ?string $requested = null): string
    {
        $normalizedRequest = $this->normalizeAccountTypeSlug($requested);

        if ($normalizedRequest !== null) {
            return $normalizedRequest;
        }

        if ($user && $user->account_type) {
            return $this->mapAccountTypeIntToSlug((int) $user->account_type);
        }

        return 'individual';
    }

    protected function normalizeAccountTypeSlug($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $normalized = strtolower(trim((string) $value));

        return match ($normalized) {
            '1', 'individual', 'personal', 'customer', 'private' => 'individual',
            '2', 'realestate', 'real_estate', 'property' => 'realestate',
            '3', 'commercial', 'business', 'merchant', 'seller' => 'commercial',
            default => null,
        };
    }

    protected function mapAccountTypeIntToSlug(int $accountType): string
    {
        return match ($accountType) {
            User::ACCOUNT_TYPE_REAL_ESTATE => 'realestate',
            User::ACCOUNT_TYPE_SELLER => 'commercial',
            default => 'individual',
        };
    }

    protected function validateRequiredVerificationFields(string $accountType, Request $request): array
    {
        $requiredFields = VerificationField::query()
            ->where('account_type', $accountType)
            ->where('is_required', true)
            ->whereNull('deleted_at')
            ->pluck('name', 'id');

        $providedFields = $request->get('verification_field', []);
        $providedFiles = $request->file('verification_field_files', []);

        $missing = [];

        foreach ($requiredFields as $id => $name) {
            $hasValue = $this->hasVerificationInput($providedFields[$id] ?? null)
                || $this->hasVerificationInput($providedFiles[$id] ?? null);

            if (!$hasValue) {
                $missing[] = $name ?? ('field_' . $id);
            }
        }

        return $missing;
    }

    protected function hasVerificationInput($value): bool
    {
        if ($value instanceof UploadedFile) {
            return true;
        }

        if (is_array($value)) {
            return collect($value)->filter(fn($entry) => !empty($this->normalizeVerificationFieldValue($entry)))->isNotEmpty();
        }

        return !empty($this->normalizeVerificationFieldValue($value));
    }

    protected function normalizeVerificationFieldValue(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $normalized = trim($value);

            return $normalized === '' ? null : $normalized;
        }

        if (is_scalar($value)) {
            $normalized = trim((string) $value);

            return $normalized === '' ? null : $normalized;
        }

        if (is_iterable($value)) {
            $parts = [];

            foreach ($value as $part) {
                if ($part === null) {
                    continue;
                }

                if (!is_scalar($part)) {
                    continue;
                }

                $normalizedPart = trim((string) $part);

                if ($normalizedPart === '') {
                    continue;
                }

                $parts[] = $normalizedPart;
            }

            if (empty($parts)) {
                return null;
            }

            return implode(',', $parts);
        }

        return null;
    }



    public function getVerificationRequest(Request $request) {
        try {
            $verificationRequest = VerificationRequest::with(['verification_field_values.verification_field'])
                ->owner()
                ->first();

            if (empty($verificationRequest)) {
                ResponseService::errorResponse("No Request found");
            }
            $response = $verificationRequest->toArray();
            $response['verification_fields'] = [];

            foreach ($verificationRequest->verification_field_values as $verificationFieldValue) {
                if (!$verificationFieldValue->relationLoaded('verification_field')) {
                    continue;
                }


                $verificationField = $verificationFieldValue->verification_field;

                if (empty($verificationField)) {
                    continue;
                }

                $fieldData = $verificationField->toArray();
                $valueData = $verificationFieldValue->toArray();

                unset($valueData['verification_field']);


                if ($verificationField->type === 'fileinput') {
                    $fileUrl = $verificationFieldValue->value;

                    $fieldData['value'] = !empty($fileUrl) ? [$fileUrl] : [];
                    $valueData['value'] = !empty($fileUrl) ? [$fileUrl] : [];
                } else {
                    $fieldData['value'] = $verificationFieldValue->value ?? '';
                    $valueData['value'] = $verificationFieldValue->value ?? '';
                }

                $response['verification_fields'][] = $fieldData + ['verification_field_value' => $valueData];

                
            }
            ResponseService::successResponse("Verification request fetched successfully.", $response);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> SendVerificationRequest");
            ResponseService::errorResponse();
        }
    }


    public function seoSettings(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'page' => 'nullable',
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }
            $perPage = $this->resolvePerPage($request, 15, 100);


            $settings = new SeoSetting();
            if (!empty($request->page)) {
                $settings = $settings->where('page', $request->page);
            }

            $settings = $settings->orderBy('id')
                ->paginate($perPage)
                ->appends($request->query());


            ResponseService::successResponse("SEO settings fetched successfully.", $settings);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> seoSettings");
            ResponseService::errorResponse();
        }
    }

    /**
     * Get services based on category and is_main flag
     *
     * @param Request $request
     * @return void
     */


    public function getManagedService(Request $request, Service $service)
    {
        $user = $request->user();

        if (!$user) {
            return ResponseService::errorResponse('User not authenticated', null, 401);
        }

        if (!$this->serviceAuthorizationService->userCanManageService($user, $service)) {
            return ResponseService::errorResponse('أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آµ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ±.', null, 403);
        }

        $service->load([
            'category',
            'serviceCustomFields.value',
            'serviceCustomFieldValues',
            'owner',
        ]);


        $payload = $this->mapService($service, true);

        ResponseService::successResponse('Service fetched successfully.', $payload);
    }



    public function getOwnedServices(Request $request)
    {
        $user = $request->user();

        if (!$user) {
            return ResponseService::errorResponse('User not authenticated', null, 401);
        }

        $services = Service::with([
                'category',
                'serviceCustomFields.value',
                'serviceCustomFieldValues',
                'owner',
            ])
            
            ->where('owner_id', $user->id)
            ->get()
            ->map(fn(Service $service) => $this->mapService($service, true))
            ->values()
            ->all();

        ResponseService::successResponse('Services fetched successfully.', $services);
    }

    public function updateOwnedService(Request $request, Service $service)
    {
        $user = $request->user();

        if (!$user) {
            return ResponseService::errorResponse('User not authenticated', null, 401);
        }

        if ((int) $service->owner_id !== (int) $user->id) {
            return ResponseService::errorResponse('أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آµ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ±.', null, 403);
        }

        $validator = Validator::make($request->all(), [
            'status'      => 'sometimes|boolean',
            'expiry_date' => 'nullable|date',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $payload = $validator->validated();

        if (empty($payload)) {
            ResponseService::validationError('أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ±.');
        }

        if ($request->has('status')) {
            $service->status = (bool) $request->boolean('status');
        }

        if ($request->exists('expiry_date')) {
            $service->expiry_date = $payload['expiry_date'] ?? null;
        }

        $service->save();

        $service->load([
            'category',
            'serviceCustomFields.value',
            'serviceCustomFieldValues',
            'owner',
        ]);


        ResponseService::successResponse('Service updated successfully.', $this->mapService($service, true));
    }

    public function deleteOwnedService(Request $request, Service $service)
    {
        $user = $request->user();

        if (!$user) {
            return ResponseService::errorResponse('User not authenticated', null, 401);
        }

        if ((int) $service->owner_id !== (int) $user->id) {
            return ResponseService::errorResponse('أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آµ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ±.', null, 403);
        }

        DB::beginTransaction();

        try {
            $service->customFields()->detach();

            $this->deleteServiceMedia($service);

            $service->delete();

            DB::commit();

            ResponseService::successResponse('Service deleted successfully.');
        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, 'API Controller -> deleteOwnedService');
            ResponseService::errorResponse('Failed to delete service');
        }
    }


    public function getServices(Request $request)



{
    try {
        $validator = Validator::make($request->all(), [
            'id'          => 'nullable|integer|exists:services,id',
            'category_id' => 'nullable|exists:categories,id',
            'categories'  => 'nullable|string', // ids comma separated
            'is_main'     => 'nullable|boolean',
            'service_type'=> 'nullable|string',
            'per_page'    => 'nullable|integer|min:1|max:100',
            'limit'       => 'nullable|integer|min:1|max:100',
            'offset'      => 'nullable|integer|min:0',
            'page'        => 'nullable|integer|min:1',



        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        // أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط¸â€کأ¢â€‌ع©ط¢ظ¾ (أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢عˆأ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°)
        if ($request->filled('id')) {
            $s = Service::where('status', true)
                ->where(function($q){
                    $q->whereNull('expiry_date')->orWhere('expiry_date','>',now());
                })
                ->with([
                    'category',
                    'serviceCustomFields.value',
                    'serviceCustomFieldValues',
                    'owner',
                ])
                ->withAvg(['reviews as avg_rating' => function ($q) {
                    $q->where('status', ServiceReview::STATUS_APPROVED);
                }], 'rating')
                ->withCount(['reviews as reviews_count' => function ($q) {
                    $q->where('status', ServiceReview::STATUS_APPROVED);
                }])
                
                ->findOrFail($request->id);

            $payload = $this->mapService($s);
            ResponseService::successResponse('Service fetched successfully.', $payload);
        }

        // أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ®أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²
        $query = Service::with([
                'category',
                'serviceCustomFields.value',
                'serviceCustomFieldValues',
                'owner',
            ])
            ->withAvg(['reviews as avg_rating' => function ($q) {
                $q->where('status', ServiceReview::STATUS_APPROVED);
            }], 'rating')
            ->withCount(['reviews as reviews_count' => function ($q) {
                $q->where('status', ServiceReview::STATUS_APPROVED);
            }])
            
            ->where('status', true)
            ->where(function($q){
                $q->whereNull('expiry_date')->orWhere('expiry_date','>',now());
            });

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        if ($request->filled('categories')) {
            $ids = collect(explode(',', $request->categories))
                ->map(fn($v)=> (int) trim($v))
                ->filter()->values()->all();
            if (!empty($ids)) $query->whereIn('category_id', $ids);
        }

        if ($request->filled('is_main')) {
            $query->where('is_main', (bool)$request->is_main);
        }

        if ($request->filled('service_type')) {
            $query->where('service_type', $request->service_type);
        }

        $perPageInput = $request->input('per_page', $request->input('limit'));
        $perPage = is_numeric($perPageInput) ? (int) $perPageInput : 15;

        if ($perPage <= 0) {
            $perPage = 15;
        }

        if ($perPage > 100) {
            $perPage = 100;
        }

        $pageInput = $request->input('page');
        $page = is_numeric($pageInput) ? max((int) $pageInput, 1) : null;

        if ($page === null && $request->filled('offset')) {
            $offsetRaw = $request->input('offset');
            $offset = is_numeric($offsetRaw) ? max((int) $offsetRaw, 0) : 0;
            $page = intdiv($offset, $perPage) + 1;
        }

        $services = $query
            ->paginate($perPage, ['*'], 'page', $page)

            ->through(fn(Service $service) => $this->mapService($service));

        $paginationLinks = [
            'first' => $services->url(1),
            'last'  => $services->url($services->lastPage()),
            'prev'  => $services->previousPageUrl(),
            'next'  => $services->nextPageUrl(),
        ];

        $paginationMeta = [
            'current_page' => $services->currentPage(),
            'from'         => $services->firstItem(),
            'last_page'    => $services->lastPage(),
            'path'         => $services->path(),
            'per_page'     => $services->perPage(),
            'to'           => $services->lastItem(),
            'total'        => $services->total(),
        ];

        ResponseService::successResponse(
            'Services fetched successfully.',
            $services->items(),
            [
                'links' => $paginationLinks,
                'meta'  => $paginationMeta,
                'total' => $services->total(),


            ]
        );
    
    
    } catch (Throwable $th) {
        ResponseService::logErrorResponse($th, 'API Controller -> getServices');
        ResponseService::errorResponse();
    }
}

/**
 * أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¸â€کأ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ®أ¢â€‌ع©ط¢â€  Service أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ± JSON أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€œأ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢â€“أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ©.
 *  *
 * @param  Service  $s
 * @param  bool     $includeOwnerEmail أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ¨ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ§
 */
private function mapService(Service $s, bool $includeOwnerEmail = false): array
{



    $url = function (?string $path) {
        if (!$path) return null;
        if (preg_match('#^https?://#', $path)) return $path;
        return asset('storage/' . ltrim($path, '/'));
    };


    $expiry = $s->expiry_date;
    if ($expiry instanceof DateTimeInterface) {
        $expiry = $expiry->format('Y-m-d');
    } elseif ($expiry !== null) {
        $expiry = (string) $expiry;
    }

    $owner = $s->relationLoaded('owner') ? $s->getRelation('owner') : null;
    $ownerId = $owner
        ? (int) $owner->id
        : ($s->owner_id !== null ? (int) $s->owner_id : null);

    $avgRating = $s->avg_rating ?? $s->reviews_avg_rating ?? null;
    $avgRating = $avgRating !== null ? round((float) $avgRating, 2) : null;
    $reviewsCount = isset($s->reviews_count) ? (int) $s->reviews_count : null;

    return [
        'id'                => (int) $s->id,
        'category_id'       => (int) $s->category_id,
        'title'             => (string) $s->title,
        'description'       => (string) ($s->description ?? ''),
        'is_main'           => (bool) $s->is_main,
        'service_type'      => $s->service_type,
        'status'            => (bool) $s->status,
        'owner_id'          => $ownerId,
        'user_id'           => $ownerId,
        'views'             => (int) ($s->views ?? 0),
        'expiry_date'       => $expiry,

        // ط·آ¸ط¢آ£ط£آ  أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢â€¢ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€¢â€“ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±
        'image'             => $url($s->image),
        'icon'              => $url($s->icon),

        // (أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨ أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ© أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢ظ¾)
        'image_url'         => $url($s->image),
        'icon_url'          => $url($s->icon),

        // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ±
        'is_paid'           => (bool) $s->is_paid,
        'price'             => $s->price !== null ? (float) $s->price : null,
        'currency'          => $s->currency,
        'price_note'        => $s->price_note,
        'has_custom_fields' => (bool) $s->has_custom_fields,
        'service_fields_schema' => $this->transformServiceFieldsSchema($s),


        'direct_to_user'    => (bool) $s->direct_to_user,
        'direct_user_id'    => $s->direct_user_id ? (int) $s->direct_user_id : null,
        'owner'             => $owner ? array_merge([
            'id'   => $ownerId,
            'name' => $owner->name,
        ], $includeOwnerEmail ? ['email' => $owner->email] : []) : null,


        'service_uid'       => $s->service_uid,

        // (أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨) أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ« أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط¢آ» أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢â€“أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ©
        'created_at'        => optional($s->created_at)->toISOString(),
        'updated_at'        => optional($s->updated_at)->toISOString(),
    ];

}




private function deleteServiceMedia(Service $service): void
{
    $disk = Storage::disk('public');

    foreach (['image', 'icon'] as $attribute) {
        $path = $service->{$attribute};

        if (empty($path) || preg_match('#^https?://#i', (string) $path)) {
            continue;
        }

        try {
            $disk->delete($path);
        } catch (Throwable) {
            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£آ¨ أ¢â€¢ع¾ط·آ«أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€¢â€“أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€“â€کأ¢â€‌ع©ط¢ظ¾ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€“â€œأ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ .
        }
    }
}


private function normalizeServiceFieldIconPath($path): ?string
{
    if ($path === null) {
        return null;
    }

    if (is_array($path)) {
        $path = Arr::first($path);
    }

    $path = trim((string) $path);

    if ($path === '' || strtolower($path) === 'null') {
        return null;
    }

    if (preg_match('#^https?://#i', $path)) {
        $parsed = parse_url($path, PHP_URL_PATH);
        if (is_string($parsed) && $parsed !== '') {
            $path = $parsed;
        }
    }

    $path = ltrim($path, '/');

    if (Str::startsWith($path, 'storage/')) {
        $path = substr($path, strlen('storage/'));
    }

    return $path !== '' ? $path : null;
}

private function buildPublicStorageUrl(?string $path): ?string
{
    if ($path === null || $path === '') {
        return null;
    }

    if (preg_match('#^https?://#i', $path)) {
        return $path;
    }

    $normalized = ltrim($path, '/');
    if ($normalized === '') {
        return null;
    }

    return Storage::disk('public')->url($normalized);
}


private function transformServiceFieldsSchema(Service $service): array
{

    $service->loadMissing(['serviceCustomFields.value', 'serviceCustomFieldValues']);


    $fields = $service->relationLoaded('serviceCustomFields')
        ? $service->getRelation('serviceCustomFields')->sortBy(function (ServiceCustomField $field) {
            $sequence = is_numeric($field->sequence) ? (int) $field->sequence : 0;
            return sprintf('%010d-%010d', $sequence, $field->id ?? 0);
        })->values()
        : $service->serviceCustomFields()->orderBy('sequence')->orderBy('id')->get();

    if ($fields->isNotEmpty()) {
        $valueIndex = $service->relationLoaded('serviceCustomFieldValues')
            ? $service->getRelation('serviceCustomFieldValues')->keyBy('service_custom_field_id')
            : $service->serviceCustomFieldValues()->get()->keyBy('service_custom_field_id');

        return $fields->map(function (ServiceCustomField $field) use ($valueIndex) {


            $payload = $field->toSchemaPayload();


            $fieldKey = is_string($payload['name'] ?? null)
                ? trim((string) $payload['name'])
                : '';
            $fieldLabel = is_string($payload['title'] ?? null)
                ? trim((string) $payload['title'])
                : '';

            if ($fieldLabel === '' && isset($payload['label'])) {
                $fieldLabel = trim((string) $payload['label']);
            }

            if ($fieldLabel === '' && $fieldKey !== '') {
                $fieldLabel = Str::headline(str_replace('_', ' ', $fieldKey));
            }

            if ($fieldLabel === '') {
                $fieldLabel = Str::headline('field_' . $field->id);
            }

            $fieldName = $fieldKey !== '' ? $fieldKey : 'field_' . $field->id;


            $properties = [];
            foreach (['min', 'max', 'min_length', 'max_length'] as $prop) {
                if (array_key_exists($prop, $payload) && $payload[$prop] !== null && $payload[$prop] !== '') {
                    $properties[$prop] = $payload[$prop];
                }
            }


            $status = array_key_exists('status', $payload)
                ? (bool) $payload['status']
                : (array_key_exists('active', $payload) ? (bool) $payload['active'] : true);

            $valueModel = $field->relationLoaded('value')
                ? $field->getRelation('value')
                : $valueIndex->get($field->id);

            $valuePayload = $this->formatServiceFieldValueForApi($field, $valueModel);
            $imagePath = $this->normalizeServiceFieldIconPath($payload['image'] ?? null);
            $imageUrl  = $this->buildPublicStorageUrl($imagePath);



            $noteValue = $payload['note'] ?? '';
            if (!is_string($noteValue)) {
                $noteValue = (string) $noteValue;
            }


            $fieldData = array_merge([

                'id'         => $field->id,
                'name'       => $fieldName,
                'key'        => $fieldKey !== '' ? $fieldKey : null,
                'form_key'   => $fieldKey !== '' ? $fieldKey : null,
                'title'      => $fieldLabel,
                'label'      => $fieldLabel,
                'type'       => $payload['type'],
                'required'   => (bool) ($payload['required'] ?? false),
                'note'       => $noteValue,
                'sequence'   => (int) ($payload['sequence'] ?? 0),
                'values'     => $payload['values'] ?? [],
                'properties' => $properties,
                'image'      => $imageUrl,
                'image_path' => $imagePath,
                
                'meta'       => $payload['meta'] ?? null,
                'status'     => $status,
                'active'     => $status,
            ], $valuePayload);


            $label = $payload['title'] ?? $payload['label'] ?? $payload['name'];
            if (!is_string($label) || $label === '') {
                $label = $fieldData['name'];
            }

            $fieldData['label'] = $label;
            $fieldData['display_name'] = $label;
            $fieldData['form_key'] = $fieldData['name'];
            $fieldData['note_text'] = $fieldData['note'];

            if ($fieldData['image'] === null) {
                unset($fieldData['image']);
            }
            if (array_key_exists('image_path', $fieldData) && ($fieldData['image_path'] === null || $fieldData['image_path'] === '')) {
                unset($fieldData['image_path']);
            }


            if (array_key_exists('key', $fieldData) && $fieldData['key'] === null) {
                unset($fieldData['key']);
            }
            if (array_key_exists('form_key', $fieldData) && $fieldData['form_key'] === null) {
                unset($fieldData['form_key']);
            }
            

            if ($fieldData['meta'] === null) {
                unset($fieldData['meta']);
            }
            if (empty($fieldData['properties'])) {
                unset($fieldData['properties']);
            }
            if (!is_array($fieldData['values'])) {
                $fieldData['values'] = [];
            }
            if (array_key_exists('file_urls', $fieldData) && empty($fieldData['file_urls'])) {
                unset($fieldData['file_urls']);
            }
            if (array_key_exists('file_url', $fieldData) && empty($fieldData['file_url'])) {
                unset($fieldData['file_url']);
            }
            if (array_key_exists('display_value', $fieldData) && ($fieldData['display_value'] === null || $fieldData['display_value'] === '')) {
                unset($fieldData['display_value']);
            }
            if (array_key_exists('value_raw', $fieldData) && ($fieldData['value_raw'] === null || $fieldData['value_raw'] === '')) {
                unset($fieldData['value_raw']);
            }
            if (array_key_exists('value_updated_at', $fieldData) && $fieldData['value_updated_at'] === null) {
                unset($fieldData['value_updated_at']);
            }
            if (array_key_exists('value_id', $fieldData) && $fieldData['value_id'] === null) {
                unset($fieldData['value_id']);
            }

            return $fieldData;
        })->values()->all();
    }


    $schema = $service->service_fields_schema ?? [];

    if (!is_array($schema) || $schema === []) {
        return [];
    }


    $service->loadMissing(['serviceCustomFields']);

    $serviceFieldModels = $service->serviceCustomFields ?? collect();
    $serviceFieldModelsById = $serviceFieldModels->keyBy('id');
    $serviceFieldModelsByKey = $serviceFieldModels->mapWithKeys(static function ($field) {
        /** @var \App\Models\ServiceCustomField $field */
        $key = $field->form_key;
        return $key !== '' ? [$key => $field] : [];
    });



    $normalized = [];
    $fallbackIndex = 1;

    foreach ($schema as $field) {
        if (!is_array($field)) {
            continue;
        }

        $sequence = (int) ($field['sequence'] ?? $fallbackIndex);
        $title    = trim((string) ($field['title'] ?? $field['label'] ?? ''));
        $name     = trim((string) ($field['name'] ?? $field['key'] ?? ''));
        if ($name === '') {
            $name = $title !== '' ? str_replace(' ', '_', strtolower($title)) : 'field_' . $fallbackIndex;
        }




        $serviceFieldModel = null;
        if (isset($field['id'])) {
            $serviceFieldModel = $serviceFieldModelsById->get((int) $field['id']);
        }

        if (!$serviceFieldModel && $name !== '' && $serviceFieldModelsByKey->has($name)) {
            $serviceFieldModel = $serviceFieldModelsByKey->get($name);
        }

        if ($title === '' && $serviceFieldModel) {
            $modelName = trim((string) ($serviceFieldModel->name ?? ''));
            if ($modelName !== '') {
                $title = $modelName;
            }
        }

        if ($title === '' && isset($field['meta']['label'])) {
            $metaLabel = trim((string) $field['meta']['label']);
            if ($metaLabel !== '') {
                $title = $metaLabel;
            }
        }



        $values = $field['values'] ?? [];
        if (!is_array($values)) {
            $values = [];
        }
        $values = array_values(array_map(static function ($value) {
            if (is_scalar($value) || (is_object($value) && method_exists($value, '__toString'))) {
                return (string) $value;
            }

            return $value;
        }, $values));


        $noteValue = $field['note'] ?? '';
        if (!is_string($noteValue)) {
            $noteValue = (string) $noteValue;
        }



        $properties = [];
        foreach (['min', 'max', 'min_length', 'max_length'] as $prop) {
            if (array_key_exists($prop, $field) && $field[$prop] !== null && $field[$prop] !== '') {
                $properties[$prop] = $field[$prop];
            }
        }


        $status = array_key_exists('status', $field)
            ? (bool) $field['status']
            : (array_key_exists('active', $field) ? (bool) $field['active'] : true);
        $type = (string) ($field['type'] ?? 'textbox');

        $imagePath = $this->normalizeServiceFieldIconPath($field['image'] ?? $field['image_path'] ?? null);
        $imageUrl = $this->buildPublicStorageUrl($imagePath);

        $entry = [
            
            'name'       => $name,
            'title'      => $title,
            'type'       => $type,
            'required'   => (bool) ($field['required'] ?? false),
            'note'       => $noteValue,
            'sequence'   => $sequence,
            'values'     => $values,
            'properties' => $properties,
            'image'      => $imageUrl,
            'image_path' => $imagePath,
            'status'     => $status,
            'active'     => $status,
            'value'      => $type === 'checkbox' ? [] : ($type === 'fileinput' ? [] : null),

        ];


        $label = $title !== '' ? $title : $name;
        $entry['title'] = $label;
        $entry['label'] = $label;
        $entry['display_name'] = $label;
        $entry['form_key'] = $name;
        $entry['note_text'] = $entry['note'];

        if ($entry['image'] === null) {
            unset($entry['image']);
        }
        if ($entry['image_path'] === null) {
            unset($entry['image_path']);
        }

        $normalized[] = $entry;

        $fallbackIndex++;
    }

    usort($normalized, static fn(array $a, array $b) => ($a['sequence'] ?? 0) <=> ($b['sequence'] ?? 0));

    return $normalized;
}


private function formatServiceFieldValueForApi(ServiceCustomField $field, ?ServiceCustomFieldValue $valueModel): array
{
    $type = $field->normalizedType();

    $result = [
        'value' => match ($type) {
            'checkbox' => [],
            'fileinput' => [],
            default => null,
        },
        'value_id' => null,
        'value_updated_at' => null,
    ];

    if (!$valueModel) {
        return $result;
    }

    $result['value_id'] = $valueModel->id;
    $result['value_updated_at'] = $valueModel->updated_at?->toISOString();

    $decoded = $valueModel->value;
    $rawOriginal = $valueModel->getRawOriginal('value');

    if ($type === 'checkbox') {
        $values = [];
        if (is_array($decoded)) {
            $values = array_values(array_filter($decoded, static fn($v) => $v !== null && $v !== ''));
        } elseif ($decoded !== null && $decoded !== '') {
            $values = [(string) $decoded];
        } elseif (is_string($rawOriginal) && $rawOriginal !== '') {
            $json = json_decode($rawOriginal, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($json)) {
                $values = array_values(array_filter($json, static fn($v) => $v !== null && $v !== ''));
            }
        }

        $result['value'] = $values;
        if (!empty($values)) {
            $result['display_value'] = implode(', ', $values);
        }
        if (!empty($values)) {
            $result['value_raw'] = $values;
        }

        return $result;
    }

    if ($type === 'fileinput') {
        $rawValues = [];
        if (is_array($decoded)) {
            $rawValues = array_values(array_filter($decoded, static fn($v) => $v !== null && $v !== ''));
        } elseif (is_string($decoded) && $decoded !== '') {
            $rawValues = [$decoded];
        } elseif (is_string($rawOriginal) && $rawOriginal !== '') {
            $json = json_decode($rawOriginal, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($json)) {
                $rawValues = array_values(array_filter($json, static fn($v) => $v !== null && $v !== ''));
            } else {
                $rawValues = [$rawOriginal];
            }
        }

        $fileUrls = array_values(array_filter(array_map(static function ($path) {
            if (!is_string($path) || $path === '') {
                return null;
            }

            if (preg_match('#^https?://#i', $path)) {
                return $path;
            }

            return asset('storage/' . ltrim($path, '/'));
        }, $rawValues)));

        $result['value'] = $fileUrls;
        if (!empty($rawValues)) {
            $result['value_raw'] = count($rawValues) === 1 ? $rawValues[0] : $rawValues;
        }
        if (!empty($fileUrls)) {
            $result['file_urls'] = $fileUrls;
            $result['file_url'] = $fileUrls[0];
        }

        return $result;
    }

    if (is_array($decoded)) {
        $filtered = array_values(array_filter($decoded, static fn($v) => $v !== null && $v !== ''));
        $value = $filtered[0] ?? null;
        $result['value'] = $value;
        if (!empty($filtered)) {
            $result['display_value'] = implode(', ', $filtered);
            $result['value_raw'] = $filtered;
        }
    } else {
        $value = ($decoded !== null && $decoded !== '') ? (string) $decoded : null;
        $result['value'] = $value;
        if ($value !== null) {
            $result['display_value'] = $value;
            $result['value_raw'] = $decoded;
        }
    }

    if ($result['value_raw'] === null && is_string($rawOriginal) && $rawOriginal !== '') {
        $json = json_decode($rawOriginal, true);
        $result['value_raw'] = json_last_error() === JSON_ERROR_NONE ? $json : $rawOriginal;
    }

    return $result;
}

    /**
     * Get currency rates
     *
     * @param Request $request
     * @return void
     */
    public function getCurrencyRates(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'currency_name' => 'nullable|string',
                'governorate_code' => 'nullable|string|exists:governorates,code',
            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }


            $requestedGovernorateCode = $request->input('governorate_code');

            $preferenceData = [
                'favorite_governorate_code' => null,
                'currency_watchlist' => [],
                'metal_watchlist' => [],
                'notification_frequency' => NotificationFrequency::DAILY->value,
            ];

            $currencyWatchlist = collect();
            $metalWatchlist = collect();

            if (Auth::check()) {
                $user = Auth::user();

                /** @var UserPreference|null $preference */
                $preference = $user->preference()->with('favoriteGovernorate')->first();

                if (!$preference) {
                    $preference = $user->preference()->create([
                        'currency_watchlist' => [],
                        'metal_watchlist' => [],
                        'notification_frequency' => NotificationFrequency::DAILY->value,
                    ])->fresh(['favoriteGovernorate']);
                }

                $preferenceResource = new UserPreferenceResource($preference);
                $preferenceData = $preferenceResource->resolve($request);

                if (!$requestedGovernorateCode && !empty($preferenceData['favorite_governorate_code'])) {
                    $requestedGovernorateCode = $preferenceData['favorite_governorate_code'];
                }

                $currencyWatchlist = collect($preferenceData['currency_watchlist'] ?? [])
                    ->map(static fn ($id) => (int) $id)
                    ->filter(static fn ($id) => $id > 0)
                    ->values();

                $metalWatchlist = collect($preferenceData['metal_watchlist'] ?? [])
                    ->map(static fn ($id) => (int) $id)
                    ->filter(static fn ($id) => $id > 0)
                    ->values();
            }


            $requestedGovernorate = null;
            if (!empty($requestedGovernorateCode)) {
                $requestedGovernorate = Governorate::where('code', $requestedGovernorateCode)->first();

                if ($requestedGovernorate && !$requestedGovernorate->is_active) {
                    $requestedGovernorate = null;
                }
            }

            $governorates = Governorate::query()
                ->where('is_active', true)
                ->orderBy('name')
                ->get();

            $query = CurrencyRate::with(['quotes.governorate']);

            if ($request->filled('currency_name')) {


                $query->where('currency_name', $request->currency_name);
            }

            $currencies = $query->get();

            $rates = [];
            $anyFallback = false;
            $appliedGovernorate = null;

            foreach ($currencies as $currency) {
                [$quote, $governorate, $usedFallback] = $currency->resolveQuoteForGovernorate($requestedGovernorate);

                if ($governorate && !$appliedGovernorate) {
                    $appliedGovernorate = $governorate;
                }

                $anyFallback = $anyFallback || $usedFallback;

                $rates[] = [
                    'id' => $currency->id,
                    'currency_name' => $currency->currency_name,
                    'sell_price' => $quote?->sell_price,
                    'buy_price' => $quote?->buy_price,
                    'icon_url' => $currency->icon_url,
                    'icon_alt' => $currency->icon_alt,
                    'last_updated_at' => optional($quote?->quoted_at ?? $currency->last_updated_at)->toIso8601String(),
                    'quote_governorate_code' => $governorate?->code,
                    'quote_governorate_name' => $governorate?->name,
                    'quote_source' => $quote?->source,
                    'quote_quoted_at' => optional($quote?->quoted_at)->toIso8601String(),
                    'quote_is_default' => (bool) ($quote?->is_default ?? false),
                    'quote_used_fallback' => $usedFallback,
                    'is_watchlisted' => $currencyWatchlist->contains((int) $currency->id),


                ];
            }

            $requestedGovernorateData = $requestedGovernorate ? [
                'code' => $requestedGovernorate->code,
                'name' => $requestedGovernorate->name,
            ] : null;

            $appliedGovernorateData = $appliedGovernorate ? [
                'code' => $appliedGovernorate->code,
                'name' => $appliedGovernorate->name,
            ] : null;
            $notificationOptions = collect(NotificationFrequency::cases())
                ->map(static fn (NotificationFrequency $frequency) => [
                    'value' => $frequency->value,
                    'label' => $frequency->label(),
                ])->values();

            ResponseService::successResponse(
                "Currency rates fetched successfully.",
                $rates,
                [
                    'governorates' => $governorates->map(fn (Governorate $governorate) => [
                        'code' => $governorate->code,
                        'name' => $governorate->name,
                    ])->values(),
                    'requested_governorate' => $requestedGovernorateData,
                    'applied_governorate' => $appliedGovernorateData,
                    'used_fallback' => $anyFallback,
                    'requested_governorate_code' => $requestedGovernorate?->code ?? $requestedGovernorateCode,
                    'preferences' => $preferenceData,
                    'preference_options' => [
                        'notification_frequencies' => $notificationOptions,
                    ],
                ]
            );


        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getCurrencyRates");
            ResponseService::errorResponse();
        }
    }
    
    /**
     * Add or update currency rate
     *
     * @param Request $request
     * @return void
     */
    public function updateCurrencyRate(Request $request) {
        try {
            $validator = Validator::make($request->all(), [
                'currency_name' => 'required|string',
                'sell_price' => 'required|numeric',
                'buy_price' => 'required|numeric',
                'governorate_code' => 'nullable|string|exists:governorates,code',
                'source' => 'nullable|string|max:255',
                'quoted_at' => 'nullable|date',
                'set_as_default' => 'nullable|boolean',

            ]);

            if ($validator->fails()) {
                ResponseService::validationError($validator->errors()->first());
            }

            $currencyRate = CurrencyRate::firstOrCreate(
                ['currency_name' => $request->currency_name],

                [
                    'sell_price' => 0,
                    'buy_price' => 0,
                    'last_updated_at' => now(),
                ]
            );

            $wasRecentlyCreated = $currencyRate->wasRecentlyCreated;

            $governorate = null;

            if ($request->filled('governorate_code')) {
                $governorate = Governorate::where('code', $request->governorate_code)->first();

                if ($governorate && !$governorate->is_active) {
                    ResponseService::validationError(__('The selected governorate is inactive.'));
                }
            }

            if (!$governorate) {
                $defaultQuoteGovernorate = optional(
                    $currencyRate->defaultQuote()->with('governorate')->first()
                )->governorate;

                if ($defaultQuoteGovernorate) {
                    $governorate = $defaultQuoteGovernorate;
                }
            }

            if (!$governorate) {
                $governorate = Governorate::where('code', 'NATL')->first();
            }

            if (!$governorate) {
                ResponseService::errorResponse('Governorate not found for the provided currency rate.');
            }

            $quotedAt = $request->filled('quoted_at')
                ? Carbon::parse($request->quoted_at)
                : now();

            $existingQuote = CurrencyRateQuote::where('currency_rate_id', $currencyRate->id)
                ->where('governorate_id', $governorate->id)
                ->first();

            $shouldBeDefault = $request->has('set_as_default')
                ? $request->boolean('set_as_default')
                : (bool) ($existingQuote?->is_default ?? false);

            $quote = CurrencyRateQuote::updateOrCreate(
                [
                    'currency_rate_id' => $currencyRate->id,
                    'governorate_id' => $governorate->id,
                ],

                [
                    'sell_price' => $request->sell_price,
                    'buy_price' => $request->buy_price,
                    'source' => $request->filled('source') ? trim((string) $request->input('source')) : null,
                    'quoted_at' => $quotedAt,
                    'is_default' => $shouldBeDefault,
                    
                    ]
            );


            if ($shouldBeDefault) {
                $currencyRate->quotes()
                    ->where('id', '!=', $quote->id)
                    ->update(['is_default' => false]);
            } elseif (!$currencyRate->quotes()->where('is_default', true)->exists()) {
                $quote->is_default = true;
                $quote->save();
                $shouldBeDefault = true;
            }

            $quote->refresh();

            if ($quote->is_default) {
                $currencyRate->applyDefaultQuoteSnapshot($quote);
            } else {
                $defaultQuote = $currencyRate->defaultQuote()->first();
                $currencyRate->applyDefaultQuoteSnapshot($defaultQuote);
            }

            $currencyRate->load('quotes.governorate');



            $quotesPayload = $currencyRate->quotes
                ->map(static function ($quote) {
                    $governorate = $quote->relationLoaded('governorate')
                        ? $quote->governorate
                        : $quote->governorate()->first();

                    return [
                        'governorate_id' => (int) $quote->governorate_id,
                        'governorate_code' => $governorate?->code
                            ? Str::upper((string) $governorate->code)
                            : null,
                        'governorate_name' => $governorate?->name,
                        'sell_price' => $quote->sell_price !== null
                            ? (string) $quote->sell_price
                            : null,
                        'buy_price' => $quote->buy_price !== null
                            ? (string) $quote->buy_price
                            : null,
                        'is_default' => (bool) $quote->is_default,
                    ];
                })
                ->values()
                ->all();

            if ($wasRecentlyCreated) {
                $defaultGovernorateId = (int) ($currencyRate->quotes
                        ->firstWhere('is_default', true)?->governorate_id
                    ?? $currencyRate->quotes->first()?->governorate_id
                    ?? 0);

                if ($defaultGovernorateId > 0) {
                    CurrencyCreated::dispatch(
                        $currencyRate->id,
                        $defaultGovernorateId
                    );
                }
            }

            if (!empty($quotesPayload)) {
                CurrencyRatesUpdated::dispatch(
                    $currencyRate->id,
                    $quotesPayload
                );
            }

            ResponseService::successResponse("Currency rate updated successfully.", $currencyRate);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> updateCurrencyRate");
            ResponseService::errorResponse();
        }
    }

    /**
     * Get specific categories if no category_id is provided
     *
     * @param Request $request
     * @return void
     */
    // public function getSpecificCategories(Request $request) {
    //     try {
    //         if (!$request->has('category_id') && !$request->has('categories')) {
    //             // Default categories from the request
    //             $defaultCategoryIds = [2, 8, 174, 175, 176, 114, 181, 180, 177];
    //             $query->whereIn('category_id', $defaultCategoryIds);
    //         } elseif ($request->has('categories')) {
    //             // If categories array is provided
    //             $categoryIds = explode(',', $request->categories);
    //             $query->whereIn('category_id', $categoryIds);
    //         }

    //         $services = $query->with('category')->paginate($request->per_page ?? 15);

    //         ResponseService::successResponse("Services Fetched Successfully", $services);
    //     } catch (Throwable $th) {
    //         ResponseService::logErrorResponse($th, "API Controller -> getServices");
    //         ResponseService::errorResponse();
    //     }
    // }
    
    /**
     * Get all active challenges
     * 
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */



    public function getChallenges(Request $request)
    {
        try {
            $challenges = Challenge::query()
                ->where('is_active', true)
                ->orderBy('required_referrals')
                ->get([
                    'id',
                    'title',
                    'description',
                    'required_referrals',
                    'points_per_referral',
                    'is_active',
                    'created_at',
                    'updated_at',
                ]);

            $totalRequiredReferrals = (int) $challenges->sum('required_referrals');
            $maxRequiredReferrals = (int) ($challenges->max('required_referrals') ?? 0);
            $totalPoints = (int) $challenges->reduce(
                static function (int $carry, Challenge $challenge): int {
                    return $carry + ($challenge->required_referrals * $challenge->points_per_referral);
                },
                0
            );

            $challengePayload = $challenges->map(static function (Challenge $challenge): array {
                return [
                    'id' => $challenge->id,
                    'title' => $challenge->title,
                    'description' => $challenge->description,
                    'required_referrals' => (int) $challenge->required_referrals,
                    'points_per_referral' => (int) $challenge->points_per_referral,
                    'is_active' => (bool) $challenge->is_active,
                    'created_at' => optional($challenge->created_at)?->toIso8601String(),
                    'updated_at' => optional($challenge->updated_at)?->toIso8601String(),
                ];
            })->values();

            ResponseService::successResponse(
                'Challenges retrieved successfully',
                [
                    'challenges' => $challengePayload,
                    'total_points' => $totalPoints,
                    'total_required_referrals' => $totalRequiredReferrals,
                    'max_points' => $maxRequiredReferrals,
                ]
            );
        } catch (\Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getChallenges', 'Failed to retrieve challenges');
            ResponseService::errorResponse('Failed to retrieve challenges');
        }
    }
    
    /**
     * Get user's referral points
     * 
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function getUserReferralPoints(Request $request)
    {
        try {
            $user = $request->user();

            if (! $user) {
                ResponseService::errorResponse('User not authenticated', null, HttpResponse::HTTP_UNAUTHORIZED);

                return;
            }
            

            if (empty($user->referral_code)) {
                $user->referral_code = User::generateReferralCode();
                $user->save();
            }

            $referralQuery = Referral::query()->where('referrer_id', $user->id);
            $referredUsersCount = (int) $referralQuery->count();
            $totalPoints = (int) $referralQuery->sum('points');

            $activeChallenges = Challenge::query()
                ->where('is_active', true)
                ->orderBy('required_referrals')
                ->get(['id', 'title', 'required_referrals', 'points_per_referral']);

            $maxRequiredReferrals = (int) ($activeChallenges->max('required_referrals') ?? 0);

            $nextChallenge = $activeChallenges->first(static function (Challenge $challenge) use ($referredUsersCount) {
                return $challenge->required_referrals > $referredUsersCount;
            });

            $remainingForNext = $nextChallenge
                ? max($nextChallenge->required_referrals - $referredUsersCount, 0)
                : 0;

            $nextRewardMessage = $nextChallenge
                ? __('Invite :count more friends to unlock ":title".', [
                    'count' => $remainingForNext,
                    'title' => $nextChallenge->title,
                ])
                : __('You have unlocked all available referral rewards.');



            $referralCode = $user->referral_code;
            
            $referralUrl = url('/referral/' . $referralCode);
            $inviteFriendMessage = __('Join me on the Marib app and use my referral code :code to earn rewards! :url', [
                'code' => $referralCode,
                'url' => $referralUrl,
            ]);

            ResponseService::successResponse(
                'User referral points retrieved successfully',
                [


                    'total_points' => $totalPoints,
                    'current_points' => $referredUsersCount,
                    'max_points' => $maxRequiredReferrals,

                    'referred_users_count' => $referredUsersCount,
                    'referral_code' => $referralCode,
                    'next_reward_message' => $nextRewardMessage,
                    'invite_friend_message' => $inviteFriendMessage,
                    'qr_code_data' => $referralUrl,
                ]
            );
        } catch (\Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getUserReferralPoints', 'Failed to retrieve user referral points');
            ResponseService::errorResponse('Failed to retrieve user referral points');
        }
    }
    
    /**
     * Get user orders
     * 
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function getUserOrders(Request $request)
    {
        try {
            $user = auth()->user();
            
            if (!$user) {
                return response()->json([
                    'status' => false,
                    'message' => 'User not authenticated',
                ], 401);
            }
            
            $query = Order::with([
                'items.item.category',
                'seller',
                'latestManualPaymentRequest.manualBank',
                'latestPaymentTransaction.manualPaymentRequest.manualBank',
            ])
            
            ->where('user_id', $user->id);
            
            // Filter by order status if provided
            if ($request->has('order_status')) {
                $query->where('order_status', $request->order_status);
            }
            
            // Filter by payment status if provided
            if ($request->has('payment_status')) {
                $query->where('payment_status', $request->payment_status);
            }
            
            // Sort by created_at in descending order (newest first)
            $query->orderBy('created_at', 'desc');
            
            // Paginate the results
            $perPage = $request->per_page ?? 10;
            $orders = $query->paginate($perPage);
            
            return response()->json([
                'status' => true,
                'message' => 'User orders retrieved successfully',
                'data' => $orders
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }
    
    /**
     * Get delivery prices
     * 
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function getDeliveryPrices(Request $request)
    {





        $departments = $this->departmentReportService->availableDepartments();

        $validator = Validator::make(
            $request->all(),
            [
                'department' => ['nullable', 'string', Rule::in(array_keys($departments))],
            ],
            [
                'department.in' => 'أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ .',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => $validator->errors()->first(),
            ], 422);
        }




        try {
            $department = $validator->validated()['department'] ?? null;
            $policy = ActivePricingPolicyCache::get($department);


            if (!$policy) {
                return response()->json([
                    'status' => false,
                    'message' => 'أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ³أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾أ¢â€¢â€“أ¢â€¢ع¾ط·آ±.',
                ], 404);


            }

            

            $policyData = [
                'id' => $policy->id,
                'name' => $policy->name,
                'code' => $policy->code,
                'mode' => $policy->mode,
                'currency' => $policy->currency,
                'department' => $policy->department,
                'free_shipping' => [
                    'enabled' => (bool) $policy->free_shipping_enabled,
                    'threshold' => $policy->free_shipping_threshold,
                ],

                'order_limits' => [
                    'min' => $policy->min_order_total,
                    'max' => $policy->max_order_total,
                ],
                'notes' => $policy->notes ?? $policy->description,



                'order_limits' => [
                    'min' => $policy->min_order_total,
                    'max' => $policy->max_order_total,
                ],
                'notes' => $policy->notes ?? $policy->description,


                'policy_rules' => $policy->distanceRules()
                    ->active()
                    ->orderBy('sort_order')
                    ->orderBy('min_distance')
                    ->orderBy('id')
                    ->get()
                    ->map(function (PricingDistanceRule $rule) {
                        return [
                            'id' => $rule->id,
                            'min_distance' => $rule->min_distance,
                            'max_distance' => $rule->max_distance,
                            'price' => $rule->price,
                            'currency' => $rule->currency,
                            'is_free_shipping' => (bool) $rule->is_free_shipping,
                            'sort_order' => $rule->sort_order,
                            'notes' => $rule->notes,
                            'price_type' => $rule->price_type,
                            'status' => (bool) $rule->status,
                            'applies_to' => $rule->applies_to,
                            'weight_tier_id' => $rule->pricing_weight_tier_id,

                        ];
                    })->values()->all(),



            ];

            $weightTiers = $policy->weightTiers->map(function (PricingWeightTier $tier) {
                return [
                    'id' => $tier->id,
                    'name' => $tier->name,
                    'min_weight' => $tier->min_weight,
                    'max_weight' => $tier->max_weight,
                    'base_price' => $tier->base_price,
                    'price_per_km' => $tier->price_per_km,
                    'flat_fee' => $tier->flat_fee,
                    'sort_order' => $tier->sort_order,
                    'notes' => $tier->notes,
                    'status' => (bool) $tier->status,

                    'distance_rules' => $tier->distanceRules->map(function (PricingDistanceRule $rule) {
                        return [
                            'id' => $rule->id,
                            'min_distance' => $rule->min_distance,
                            'max_distance' => $rule->max_distance,
                            'price' => $rule->price,
                            'currency' => $rule->currency,
                            'is_free_shipping' => (bool) $rule->is_free_shipping,
                            'notes' => $rule->notes,
                            'price_type' => $rule->price_type,
                            'status' => (bool) $rule->status,
                            
                            
                            'sort_order' => $rule->sort_order,
                            'applies_to' => $rule->applies_to,

                        ];
                    })->values()->all(),


                ];


                            })->values()->all();




            
            
            return response()->json([
                'status' => true,
                'message' => 'أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ.',
                'data' => [
                    'policy' => $policyData,
                    'weight_tiers' => $weightTiers,
                ],

                
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }




    public function getUsersByAccountType(Request $request) {
        try {
            $accountType = $request->integer('account_type');
            if ($accountType === null) {
                $accountType = User::ACCOUNT_TYPE_SELLER;
            }

        
            $allowedAccountTypes = [
                User::ACCOUNT_TYPE_CUSTOMER,
                User::ACCOUNT_TYPE_REAL_ESTATE,
                User::ACCOUNT_TYPE_SELLER,
            ];

            if (! in_array($accountType, $allowedAccountTypes, true)) {
                
                return response()->json([
                    'error' => true,
                    'message' => __('أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµ.'),
                ], 422);
            }


            $usersQuery = User::query()
                ->with(['store'])
                ->where('account_type', $accountType)
                ->orderByDesc('updated_at');

            // If per_page is not provided, return all matching users (with a reasonable cap).
            $perPage = $request->integer('per_page');
            if ($perPage === null || $perPage <= 0) {
                $perPage = (clone $usersQuery)->count();
            }
            if ($perPage <= 0) {
                $perPage = 50;
            }
            $perPage = (int) min($perPage, 500);

            $users = $usersQuery->paginate($perPage);

            // Enrich store data with media URLs/counts so client can render real cover/logo.
            $users->getCollection()->transform(function (User $user) {
                if ($user->relationLoaded('store') && $user->store) {
                    $store = $user->store;
                    if (! $store->getAttribute('banner_url')) {
                        $bannerPath = $store->getAttribute('banner_path');
                        $store->setAttribute(
                            'banner_url',
                            $bannerPath
                                ? (preg_match('#^https?://#i', $bannerPath) ? $bannerPath : Storage::url($bannerPath))
                                : null
                        );
                    }
                    if (! $store->getAttribute('logo_url')) {
                        $logoPath = $store->getAttribute('logo_path');
                        $store->setAttribute(
                            'logo_url',
                            $logoPath
                                ? (preg_match('#^https?://#i', $logoPath) ? $logoPath : Storage::url($logoPath))
                                : null
                        );
                    }
                    // Fallback: use logo as banner if no cover uploaded.
                    if (! $store->getAttribute('banner_url') && $store->getAttribute('logo_url')) {
                        $store->setAttribute('banner_url', $store->getAttribute('logo_url'));
                    }
                    $store->setAttribute(
                        'followers_count',
                        $store->getAttribute('followers_count') ?? $store->followers()->count()
                    );
                    $store->setAttribute(
                        'items_count',
                        $store->getAttribute('items_count') ?? $store->items()->count()
                    );
                }

                return $user;
            });

            return response()->json([
                'error' => false,
                'message' => __('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ.'),
                'data' => $users,
            ]);
        } catch (\Throwable $th) {
            return response()->json([
                'error' => true,
                'message' => $th->getMessage(),
            ], 500);
        }
    }



public function storeRequestDevice(Request $request)
{
    $validator = Validator::make($request->all(), [
        'phone'   => 'required|string',
        'subject' => 'required|string',
        'message' => 'required|string',

        'section' => 'nullable|string|in:computer,shein',
        'image'   => 'nullable|image|max:4096',
    ]);

    if ($validator->fails()) {
        return response()->json([
            'status' => false,
            'message' => $validator->errors()->first()
        ], 422);
    }

    $data = $request->only(['phone', 'subject', 'message']);
    $data['section'] = $request->input('section', 'computer');


    if ($request->hasFile('image')) {
        $data['image'] = $request->file('image')->store('request_device', 'public');
    }

    $requestDevice = RequestDevice::create($data);




    try {
        $this->delegateNotificationService->notifyRequestDevice($requestDevice);
    } catch (Throwable $exception) {
        Log::warning('api.request_device.notification_failed', [
            'request_device_id' => $requestDevice->getKey(),
            'section' => $requestDevice->section,
            'error' => $exception->getMessage(),
        ]);
    }




    return response()->json([
        'status' => true,
        'message' => 'أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ',
        'data' => $requestDevice
    ]);
}


  public function sendOtp(Request $request, EnjazatikWhatsAppService $whatsApp)
    {
        $settings = CachingService::getSystemSettings([
            'whatsapp_otp_enabled',
            'whatsapp_otp_message_new_user',
            'whatsapp_otp_message_forgot_password',
        ]);


        $otpEnabled = filter_var($settings['whatsapp_otp_enabled'] ?? false, FILTER_VALIDATE_BOOLEAN);

        if (!$otpEnabled) {
            return ResponseService::errorResponse('أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯.');
        }

        $phone = $request->country_code . $request->phone;


        $check = $whatsApp->checkNumber($phone);

        if (!($check['status'] ?? false)) {
            return ResponseService::errorResponse("أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¯أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط£آ® أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€¢â€“ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°.");
        }

        $otp = rand(100000, 999999);
        $type = $request->type === 'new_user' ? 'new_user' : 'forgot_password';


        OTP::create([
            'phone' => $phone,
            'otp' => $otp,
            'type' => $type,
            'expires_at' => now()->addMinutes(5)->timestamp,
        ]);

        $defaultNewUserMessage = "أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¯أ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢ أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨ *أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢*! أ¢â€°طŒط·آ§ط¢عکط£آ«\n\n"
            . "أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط¢â€  أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ®أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯.\n"
            . "أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ» أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¢ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط£آ® أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢طŒ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢:\n\n"
            . "*أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ©:* :otp\n\n"
            . "ط·آ¸ط·آ£ط·آ¨ط¸ظ¹أ¢â€¢â€¢ط¢عˆ *أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€¢â€¢أ¢â€¢ع¾ط·آ±:* أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¢ أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£آ¨ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€¢طŒ. أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œأ¢â€¢ع¾ط£آ® أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±.\n\n"
            . "أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¯أ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¢ *أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢* أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ« أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€œأ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·ع¾أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ±! أ¢â€°طŒط·آ§ط·طŒط£آ¨";

        $defaultForgotPasswordMessage = "أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¯أ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢ أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨ *أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢*! أ¢â€°طŒط·آ§ط¢عکط£آ«\n\n"
            . "أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ» أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¢ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط£آ® أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢طŒ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢:\n\n"
            . "*أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ©:* :otp\n\n"
            . "ط·آ¸ط·آ£ط·آ¨ط¸ظ¹أ¢â€¢â€¢ط¢عˆ *أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€¢â€¢أ¢â€¢ع¾ط·آ±:* أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¢ أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£آ¨ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€¢طŒ. أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œأ¢â€¢ع¾ط£آ® أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±.\n\n"
            . "أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¯أ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¢ *أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢* أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ« أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€œأ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·ع¾أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ±! أ¢â€°طŒط·آ§ط·طŒط£آ¨";

        $templates = [
            'new_user' => $settings['whatsapp_otp_message_new_user'] ?? $defaultNewUserMessage,
            'forgot_password' => $settings['whatsapp_otp_message_forgot_password'] ?? $defaultForgotPasswordMessage,
        ];


        $messageTemplate = $templates[$type];
        $message = str_replace(':otp', $otp, $messageTemplate);

        SendOtpWhatsAppJob::dispatch($phone, $message);


        return ResponseService::successResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€“â€™ WhatsApp أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ.');
    }


    public function verifyOtp(Request $request)
    {
        $request->validate([
            'country_code' => 'required|numeric',
            'phone' => 'required|numeric',
            'otp' => 'required|numeric',
        ]);

        $otpEnabled = filter_var(CachingService::getSystemSettings('whatsapp_otp_enabled') ?? false, FILTER_VALIDATE_BOOLEAN);
        $phone = $request->country_code . $request->phone;

        $user = User::where('mobile', $request->phone)->first();

        if (!$user) {
            return ResponseService::errorResponse(
                'أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ ',
                404
            );
        }

        if (!$otpEnabled) {
            $user->email_verified_at = now();
            $user->is_verified = 1;
            $user->save();

            return ResponseService::successResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ (أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯).');
        }

        $otpRecord = OTP::where('phone', $phone)


            ->where('otp', $request->otp)
            ->first();

        if (!$otpRecord) {
            return ResponseService::errorResponse(
                'أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµ أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾ أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ³أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ§',
                404
            );
        }

        if ($otpRecord->expires_at < now()->timestamp) {
            return ResponseService::errorResponse(
                'أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€œ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط£آ¨ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±',
                410
            );
        }

        $otpRecord->expires_at = $otpRecord->expires_at - 270;
        $otpRecord->save();


        $user->email_verified_at = now();
        $user->is_verified = 1;
        $user->save();

        return ResponseService::successResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ');

    }

    /**
     * أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€ 
     */
    public function completeRegistration(Request $request)
    {
        try {
            DB::beginTransaction();
            
            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµ
            \Log::info('Complete Registration Request:', $request->all());
            \Log::info('User Account Type:', ['account_type' => $request->account_type]);
            
            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ«أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ¨
            $validator = Validator::make($request->all(), [
                'phone_number' => 'nullable|string',
                'country_code' => 'nullable|string',
                'account_type' => 'required|in:1,2,3',
                'email' => 'nullable|email|unique:users,email,' . Auth::id(),
            ]);

            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢â€“ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° - أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
            // أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط£آ§أ¢â€‌ع©ط£آ¨ أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢â€¢أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯

            if ($validator->fails()) {
                return ResponseService::validationError($validator->errors()->first());
            }

            $user = Auth::user();
            
            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ«أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢â€“ أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ² أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±
            if ($request->has('phone_number') && !empty($request->phone_number)) {
                $user->mobile = $request->phone_number;
            }
            
            if ($request->has('country_code') && !empty($request->country_code)) {
                $user->country_code = $request->country_code;
            }
            
            $user->account_type = $request->account_type;
            if ((int) $user->account_type === User::ACCOUNT_TYPE_SELLER) {
                // For merchant accounts rely on store/business name instead of a personal username
                $user->name = $this->fallbackSellerName($request, $user->toArray(), $user);
            }
            
            if ($request->has('email') && !empty($request->email)) {
                $user->email = $request->email;
            }
            
            // أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢â€¢ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢â€“
            $additionalInfo = $user->additional_info ?: [];
            if (!is_array($additionalInfo)) {
                $additionalInfo = [];
            }
            
            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط¢آ» أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آµ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ«أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
            if (!isset($additionalInfo['contact_info'])) {
                $additionalInfo['contact_info'] = [];
            }
            if (!isset($additionalInfo['categories'])) {
                $additionalInfo['categories'] = [];
            }
            
            if ((int) $request->account_type === User::ACCOUNT_TYPE_REAL_ESTATE) {
                // أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨ - أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²
                // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢â€¢ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢â€“
                $contactInfo = $additionalInfo['contact_info'];

                if ((int) $user->account_type === User::ACCOUNT_TYPE_SELLER) {
                    $user->name = $this->fallbackSellerName($request, $user->toArray(), $user);
                }
                
                // أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨
                if ($request->has('office_name')) {
                    $contactInfo['office_name'] = $request->office_name;
                }
                
                if ($request->has('office_phone')) {
                    $contactInfo['office_phone'] = $request->office_phone;
                }
                
                if ($request->has('office_whatsapp')) {
                    $contactInfo['office_whatsapp'] = $request->office_whatsapp;
                }
                
                if ($request->has('office_location')) {
                    $contactInfo['office_location'] = $request->office_location;
                }
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾أ¢â€¢â€کأ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨
                if ($request->has('latitude') && $request->has('longitude')) {
                    $contactInfo['latitude'] = $request->latitude;
                    $contactInfo['longitude'] = $request->longitude;
                }
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ°
                if ($request->has('office_logo')) {
                    try {
                        $imageData = base64_decode($request->office_logo);
                        $imageName = 'office_logo_' . $user->id . '_' . time() . '.jpg';
                        $imagePath = 'uploads/office_logos/' . $imageName;
                        
                        // أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»
                        if (!file_exists(public_path('uploads/office_logos'))) {
                            mkdir(public_path('uploads/office_logos'), 0777, true);
                        }
                        
                        file_put_contents(public_path($imagePath), $imageData);
                        $contactInfo['office_logo'] = $imagePath;
                    } catch (Exception $e) {
                        \Log::error('Error saving office logo: ' . $e->getMessage());
                    }
                }
                
                $additionalInfo['contact_info'] = $contactInfo;
                
            } elseif ((int) $request->account_type === User::ACCOUNT_TYPE_SELLER) {
                // أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨ - أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ±
                // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢â€¢ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢â€“
                $contactInfo = $additionalInfo['contact_info'];
                
                // أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨
                if ($request->has('business_name')) {
                    $contactInfo['business_name'] = $request->business_name;
                }
                
                if ($request->has('business_phone')) {
                    $contactInfo['business_phone'] = $request->business_phone;
                }
                
                if ($request->has('business_whatsapp')) {
                    $contactInfo['business_whatsapp'] = $request->business_whatsapp;
                }
                
                if ($request->has('business_location')) {
                    $contactInfo['business_location'] = $request->business_location;
                }
                
                if ($request->has('commercial_register')) {
                    $contactInfo['commercial_register'] = $request->commercial_register;
                }
                
                if ($request->has('payment_methods')) {
                    $contactInfo['payment_methods'] = $request->payment_methods;
                }
                
                if ($request->has('payment_account_details')) {
                    $contactInfo['payment_account_details'] = $request->payment_account_details;
                }
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
                if ($request->has('opening_time')) {
                    $contactInfo['opening_time'] = $request->opening_time;
                }
                
                if ($request->has('closing_time')) {
                    $contactInfo['closing_time'] = $request->closing_time;
                }
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾أ¢â€¢â€کأ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨
                if ($request->has('latitude') && $request->has('longitude')) {
                    $contactInfo['latitude'] = $request->latitude;
                    $contactInfo['longitude'] = $request->longitude;
                }
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط¢â€‍
                if ($request->has('business_logo')) {
                    try {
                        $imageData = base64_decode($request->business_logo);
                        $imageName = 'business_logo_' . $user->id . '_' . time() . '.jpg';
                        $imagePath = 'uploads/business_logos/' . $imageName;
                        
                        // أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»
                        if (!file_exists(public_path('uploads/business_logos'))) {
                            mkdir(public_path('uploads/business_logos'), 0777, true);
                        }
                        
                        file_put_contents(public_path($imagePath), $imageData);
                        $contactInfo['business_logo'] = $imagePath;
                    } catch (Exception $e) {
                        \Log::error('Error saving business logo: ' . $e->getMessage());
                    }
                }
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢ظ¾ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨
                if ($request->has('commercial_register_file') && $request->has('commercial_register_filename')) {
                    try {
                        $fileData = base64_decode($request->commercial_register_file);
                        $fileName = 'commercial_register_' . $user->id . '_' . time() . '_' . $request->commercial_register_filename;
                        $filePath = 'uploads/commercial_registers/' . $fileName;
                        
                        // أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ»
                        if (!file_exists(public_path('uploads/commercial_registers'))) {
                            mkdir(public_path('uploads/commercial_registers'), 0777, true);
                        }
                        
                        file_put_contents(public_path($filePath), $fileData);
                        $contactInfo['commercial_register_file'] = $filePath;
                        $contactInfo['commercial_register_filename'] = $request->commercial_register_filename;
                    } catch (Exception $e) {
                        \Log::error('Error saving commercial register file: ' . $e->getMessage());
                    }
                }
                
                $additionalInfo['contact_info'] = $contactInfo;
                
                // أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ®أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
                if ($request->has('business_categories')) {
                    $categories = explode(',', $request->business_categories);
                    $additionalInfo['categories'] = array_map('trim', $categories);
                }
            }
            
            $user->additional_info = $additionalInfo;
            $user->save();
            
            DB::commit();
            
            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
            \Log::info('Complete Registration Success for User ID: ' . $user->id);
            \Log::info('Updated Additional Info:', ['additional_info' => $additionalInfo]);
            
            return ResponseService::successResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ', $user);
            
        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, "API Controller -> completeRegistration");
            ResponseService::errorResponse();
        }
    }

    /**
     * أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  OTP
     */
    public function updatePassword(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'phone' => 'required|string',
                'password' => 'required|string|min:6',
                'country_code' => 'required|string',
            ]);

            if ($validator->fails()) {
                return ResponseService::validationError($validator->errors()->first());
            }

            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ©أ¢â€‌ع©ط£آ¯ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾
            $user = User::where('mobile', $request->phone)
                       ->whereHas('roles', function ($q) {
                           $q->where('name', 'User');
                       })
                       ->first();

            if (!$user) {
                return ResponseService::errorResponse('أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ§أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾ أ¢â€¢ع¾أ¢â€¢â€کأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍.', null, 404);
            }

            if ($user->trashed()) {
                return ResponseService::errorResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢â€کأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¢. أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ±.', null, config('constants.RESPONSE_CODE.DEACTIVATED_ACCOUNT'));
            }

            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™
            $user->password = Hash::make($request->password);
            $user->save();

            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ®أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯
            Auth::guard('web')->login($user);
            
            // أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»
            $token = $user->createToken($user->name ?? '')->plainTextToken;

            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ FCM token أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€“â€کأ¢â€¢ع¾ط·آ¯ أ¢â€‌ع©ط£آ¢أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€  أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ¯
            if (!empty($request->fcm_id)) {
                UserFcmToken::updateOrCreate(
                    ['fcm_token' => $request->fcm_id],
                    [
                        'user_id'          => $user->id,
                        'platform_type'    => $request->platform_type ?? 'android',
                        'last_activity_at' => Carbon::now(),
                    ]
                );
            }

            return ResponseService::successResponse('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€“â€™أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍', $user, ['token' => $token]);
            
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> updatePassword");
            ResponseService::errorResponse();
        }
    }


    /**
     * @return array<string, mixed>
     */
    private function buildReferralLocationPayload(Request $request): array
    {
        $lat = $request->has('lat') ? $request->input('lat') : null;
        $lng = $request->has('lng') ? $request->input('lng') : null;

        return [
            'lat' => is_numeric($lat) ? (float) $lat : null,
            'lng' => is_numeric($lng) ? (float) $lng : null,
            'device_time' => $request->input('device_time'),
            'admin_area' => $request->input('admin_area'),
        ];
    }

    /**
     * Resolve a non-null display name for seller accounts.
     */
    private function fallbackSellerName(Request $request, array $userData = [], ?User $user = null): string
    {
        $candidate = $request->input('business_name')
            ?? ($userData['business_name'] ?? null)
            ?? ($userData['name'] ?? null)
            ?? ($user?->name ?? null);

        $candidate = is_string($candidate) ? trim($candidate) : '';
        if ($candidate !== '') {
            return $candidate;
        }

        $mobile = $request->mobile ?? ($userData['mobile'] ?? ($user?->mobile ?? ''));
        $normalizedMobile = preg_replace('/\D+/', '', (string) $mobile);
        if (!empty($normalizedMobile)) {
            return 'store_' . $normalizedMobile;
        }

        return 'store_' . Str::uuid()->toString();
    }



    private function buildReferralRequestMeta(Request $request): array
    {
        $meta = [
            'ip' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ];

        $requestId = $request->headers->get('X-Request-Id');

        if (!empty($requestId)) {
            $meta['request_id'] = $requestId;
        }

        return array_filter($meta, static fn ($value) => $value !== null && $value !== '');
    }


    /**
     * أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±
     * 
     * @param string $code أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±
     * @param User $user أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»
     * @param string $contactInfo أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢طŒأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍
     * @param array<string, mixed> $locationPayload
     * @return array<string, mixed>
     * 
     * 
     */
    private function handleReferralCode($code, $user, $contactInfo, array $locationPayload = [], array $requestMeta = [])
    {


        $lat = $locationPayload['lat'] ?? null;
        $lng = $locationPayload['lng'] ?? null;
        $deviceTimeRaw = $locationPayload['device_time'] ?? null;
        $adminArea = $locationPayload['admin_area'] ?? null;

        $requestIp = $requestMeta['ip'] ?? null;
        $userAgent = $requestMeta['user_agent'] ?? null;
        $additionalMeta = $requestMeta;
        unset($additionalMeta['ip'], $additionalMeta['user_agent']);


        $deviceTime = null;

        if ($deviceTimeRaw !== null && $deviceTimeRaw !== '') {
            try {
                $deviceTime = Carbon::parse($deviceTimeRaw)->toIso8601String();
            } catch (Throwable) {
                $deviceTime = (string) $deviceTimeRaw;
            }
        }

        $auditContext = [
            'code' => $code,
            'referrer_id' => null,
            'referred_user_id' => $user?->id,
            'contact' => $contactInfo,
            'lat' => $lat,
            'lng' => $lng,
            'device_time' => $deviceTime,
            'admin_area' => $adminArea,
            'request_ip' => $requestIp,
            'user_agent' => $userAgent,

        ];
        if (!empty($additionalMeta)) {
            $auditContext['meta'] = $additionalMeta;
        }



        $baseResponse = [
            'code' => $code,
            'referrer_id' => null,
            'referred_user_id' => $user?->id,
            'contact' => $contactInfo,
            'location' => [
                'lat' => $lat,
                'lng' => $lng,
                'device_time' => $deviceTime,
                'admin_area' => $adminArea,
            ],
            'request' => array_filter([
                'ip' => $requestIp,
                'user_agent' => $userAgent,
                'meta' => !empty($additionalMeta) ? $additionalMeta : null,
            ]),

        ];


        try {
            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ³ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€“â€کأ¢â€‌ع©ط£آ¨ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¢ أ¢â€‌ع©ط£آ¢أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±
            $referrer = User::where('referral_code', $code)->first();
            
            if (!$referrer) {
                $attempt = $this->referralAuditLogger->record('invalid_code', $auditContext);

                return array_merge($baseResponse, [
                    'status' => 'invalid_code',
                    'message' => 'Invalid referral code.',
                    'attempt' => $this->formatReferralAttempt($attempt),


                ]);
            
            
            }
            
            $auditContext['referrer_id'] = $referrer->id;
            $baseResponse['referrer_id'] = $referrer->id;

            if (Referral::where('referred_user_id', $user->id)->exists()) {
                $attempt = $this->referralAuditLogger->record('duplicate', $auditContext);

                return array_merge($baseResponse, [
                    'status' => 'duplicate',
                    'message' => 'Referral has already been processed for this user.',
                    'attempt' => $this->formatReferralAttempt($attempt),


                ]);


            }
            
            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨ أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾أ¢â€¢â€“


            if ($lat === null || $lng === null || $deviceTime === null) {
                $attempt = $this->referralAuditLogger->record('location_denied', $auditContext);

                return array_merge($baseResponse, [
                    'status' => 'location_denied',
                    'message' => 'Location permissions are required to apply referral rewards.',
                    'attempt' => $this->formatReferralAttempt($attempt),


                ]);
            }

            if (!$this->maribBoundaryService->contains($lat, $lng)) {

                $notificationMeta = $this->sendReferralStatusNotification(
                    $referrer,
                    $user,
                    'notifications.referral.outside_marib'
                );

                if (!empty($notificationMeta)) {
                    $auditContext['notification'] = $notificationMeta;
                }

                $attempt = $this->referralAuditLogger->record('outside_marib', $auditContext);

                return array_merge($baseResponse, [
                    'status' => 'outside_marib',
                    'message' => 'Referral attempt is outside the Marib service boundary.',
                    'attempt' => $this->formatReferralAttempt($attempt),


                ]);
            }

            $challenge = Challenge::where('is_active', true)
                ->where('required_referrals', '>', 0)
                ->orderBy('id', 'asc')
                ->first();
            
            if (!$challenge) {
                $attempt = $this->referralAuditLogger->record('no_active_challenge', $auditContext);

                return array_merge($baseResponse, [
                    'status' => 'no_active_challenge',
                    'message' => 'No active referral challenges are available.',
                    'attempt' => $this->formatReferralAttempt($attempt),


                ]);
                
            }
            
            // أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ© أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£ challenge_id أ¢â€‌ع©ط£ع¾ points
                 $referral = Referral::create([
                'referrer_id' => $referrer->id,
                'referred_user_id' => $user->id,
                'challenge_id' => $challenge->id,
                'points' => $challenge->points_per_referral,
            ]);
            
            // أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ©أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€“â€™ أ¢â€‌ع©ط£ع¾أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»
            $challenge->decrement('required_referrals');
            
            $auditContext['referral_id'] = $referral->id;
            $auditContext['challenge_id'] = $challenge->id;
            $auditContext['awarded_points'] = $challenge->points_per_referral;

            $notificationMeta = $this->sendReferralStatusNotification(
                $referrer,
                $user,
                'notifications.referral.accepted'
            );

            if (!empty($notificationMeta)) {
                $auditContext['notification'] = $notificationMeta;
            }


            $attempt = $this->referralAuditLogger->record('ok', $auditContext);

            return array_merge($baseResponse, [
                'status' => 'ok',
                'message' => 'Referral recorded successfully.',
                'referral_id' => $referral->id,
                'challenge_id' => $challenge->id,
                'awarded_points' => (int) $challenge->points_per_referral,
                'attempt' => $this->formatReferralAttempt($attempt),


            ]);
            
            
        } catch (Throwable $th) {
            $attempt = $this->referralAuditLogger->record('error', array_merge($auditContext, [
                'exception_message' => $th->getMessage(),
            ]));

            \Log::error('Error processing referral code: ' . $th->getMessage(), [
                'code' => $code,
                'user_id' => $user?->id,
            ]);

            return array_merge($baseResponse, [
                'status' => 'error',
                'message' => 'Unable to process referral code at this time.',
                'attempt' => $this->formatReferralAttempt($attempt),


            ]);
        
        
        }
    }
    


    private function sendReferralStatusNotification(?User $referrer, ?User $referredUser, string $messageTranslationKey): array
    {
        $recipientIds = collect([$referrer?->id, $referredUser?->id])
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (empty($recipientIds)) {
            return [
                'attempted' => false,
                'result' => 'failure',
                'reason' => 'missing_recipients',
            ];
        }

        $tokens = UserFcmToken::whereIn('user_id', $recipientIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (empty($tokens)) {
            return [
                'attempted' => false,
                'result' => 'failure',
                'recipients' => $recipientIds,
                'reason' => 'missing_tokens',
            ];
        }

        $title = __('notifications.referral.status_title');
        $body = __($messageTranslationKey);

        $response = NotificationService::sendFcmNotification($tokens, $title, $body, 'referral_status');

        $meta = [
            'attempted' => true,
            'recipients' => $recipientIds,
            'tokens' => count($tokens),
            'message_key' => $messageTranslationKey,
            'result' => 'success',
        ];

        if (is_array($response)) {
            $responseSummary = array_filter([
                'error' => $response['error'] ?? null,
                'message' => $response['message'] ?? null,
                'code' => $response['code'] ?? null,
            ], static fn ($value) => $value !== null && $value !== '');

            if (!empty($responseSummary)) {
                $meta['response'] = $responseSummary;
            }

            if (($response['error'] ?? false) === true) {
                $meta['result'] = 'failure';
            }
        } elseif ($response === false) {
            $meta['result'] = 'failure';
        }

        return $meta;
    }
    

    /**
     * Get user profile statistics
     */
    public function getUserProfileStats(Request $request)
    {
        try {
            $user = Auth::user();
            
            if (!$user) {
                return ResponseService::errorResponse('User not authenticated', null, 401);
            }
            
            // أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ­أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ²
            $totalAds = Item::where('user_id', $user->id)->count();
            $activeAds = Item::where('user_id', $user->id)->where('status', 'approved')->count();
            
            // أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢آ¢أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±
            $totalFavorites = Favourite::where('user_id', $user->id)->count();
            
            // أ¢â€¢ع¾أ¢â€¢آ£أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ³أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² (unique conversations)
            $totalChats = Chat::whereHas('itemOffer', function ($query) use ($user) {

                    $query->where('seller_id', $user->id)
                        ->orWhere('buyer_id', $user->id);

                })
                ->whereHas('messages')
                ->count();
            
            $stats = [
                'total_ads' => $totalAds,
                'active_ads' => $activeAds,
                'total_favorites' => $totalFavorites,
                'total_chats' => $totalChats,
            ];
            
            ResponseService::successResponse('User statistics retrieved successfully', $stats);
            
        } catch (\Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getUserProfileStats");
            ResponseService::errorResponse();
        }
    }

    /**
     * أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢â€¢ أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±
     */
    public function saveUserLocation(Request $request) {
        try {
            $user = Auth::user();
            if (!$user) {
                return response()->json([
                    'error' => true,
                    'message' => 'Unauthorized'
                ], 401);
            }

            // أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ© أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ° أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨
            if ($user->user_type != 1) {
                return response()->json([
                    'error' => true,
                    'message' => 'Location saving is only available for individual accounts'
                ], 400);
            }

            $request->validate([
                'latitude' => 'required|numeric',
                'longitude' => 'required|numeric',
                'area' => 'nullable|string',
                'city' => 'nullable|string',
                'state' => 'nullable|string',
                'country' => 'nullable|string',
            ]);

            // أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ³ أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ©أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€‌ع©ط¢ظ¾أ¢â€‌ع©ط£آ¨ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€‍
            $user->update([
                'latitude' => $request->latitude,
                'longitude' => $request->longitude,
                'area' => $request->area,
                'city' => $request->city,
                'state' => $request->state,
                'country' => $request->country,
                'updated_at' => now(),
            ]);

            return response()->json([
                'error' => false,
                'message' => 'Location saved successfully',
                'data' => [
                    'latitude' => $user->latitude,
                    'longitude' => $user->longitude,
                    'area' => $user->area,
                    'city' => $user->city,
                    'state' => $user->state,
                    'country' => $user->country,
                ]
            ]);

        } catch (ValidationException $e) {
            return response()->json([
                'error' => true,
                'message' => 'Validation failed',
                'errors' => $e->errors()
            ], 422);
        } catch (Exception $e) {
            return response()->json([
                'error' => true,
                'message' => 'An error occurred while saving location: ' . $e->getMessage()
            ], 500);
        }
    }




    private function resolveManualPayableType(?string $type): ?string {
        if (empty($type)) {
            return null;
        }

        $type = trim($type);

        if (class_exists($type) && is_subclass_of($type, EloquentModel::class)) {
            return $type;
        }

        $normalized = strtolower($type);

        if (ManualPaymentRequest::isOrderPayableType($type) || ManualPaymentRequest::isOrderPayableType($normalized)) {

            return Order::class;
        }

        $packageAliases = [
            'package',
            'packages',
            'app\\package',
            'app\\models\\package',
        ];

        if (in_array($normalized, $packageAliases, true)) {
            return Package::class;
        }

        $itemAliases = [
            'item',
            'items',
            'ad',
            'ads',
            'advertisement',
            'advertisements',
            'listing',
            'listings',
            'app\\item',
            'app\\models\\item',
        ];

        if (in_array($normalized, $itemAliases, true)) {
            return Item::class;
        }

        $serviceAliases = [
            'service',
            'services',
            'app\\models\\service',
        ];

        if (in_array($normalized, $serviceAliases, true)) {
            return Service::class;
        }

        $walletAliases = [
            



            
            ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
            'wallet-top-up',
            'wallet_top_up',
            'wallet',
            'wallettopup',
        ];

        if (in_array($normalized, $walletAliases, true)) {
            return ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;
        }


        return null;
    }

    private function getDefaultCurrencyCode(): ?string {
        $settingKeys = ['currency_code', 'currency', 'default_currency', 'currency_symbol'];

        foreach ($settingKeys as $key) {
            $value = Setting::where('name', $key)->value('value');

            if (!empty($value)) {
                return strtoupper($value);
            }
        }

        $fallback = $this->normalizeCurrencyCode(config('app.currency'));

        return $fallback ?? $this->getWalletCurrencyCode();
    }

    private function generateManualPaymentSignedUrl(?string $path): ?string {
        if (empty($path)) {
            return null;
        }

        $disk = Storage::disk('public');

        try {
            if (method_exists($disk, 'temporaryUrl')) {
                return $disk->temporaryUrl($path, now()->addMinutes(10));
            }
        } catch (Throwable) {
            // Driver may not support temporary URLs; fall back to standard URL below.
        }

        return url($disk->url($path));
    }







    public function getManualBanks(Request $request) {
        try {
            $perPage = $this->resolvePerPage($request, 15, 100);


            $availableColumns = Schema::getColumnListing('manual_banks');

            $columns = array_values(array_intersect($availableColumns, [
                'id',
                'name',
                'logo_path',
                'beneficiary_name',
                'account_name',
                'account_number',
                'iban',
                'swift',
                'branch',
                'note',
                'notes',
                'display_order',
                'status',
                'currency',
                'qr_code_path',
                'created_at',
                'updated_at',
            ]));

            if (!in_array('id', $columns, true)) {
                $columns[] = 'id';
            }


            $banks = ManualBank::active()
                ->select($columns)
                ->orderBy('display_order')
                ->orderBy('id')
                ->paginate($perPage)
                ->appends($request->query());

            $banks->getCollection()->transform(function (ManualBank $bank) {


                $bankData = $bank->toArray();

                if (empty($bankData['bank_name']) && isset($bankData['name'])) {
                    $bankData['bank_name'] = $bankData['name'];
                }

                if ((empty($bankData['account_name']) || ! is_string($bankData['account_name']))
                    && ! empty($bankData['beneficiary_name'])) {
                    $bankData['account_name'] = $bankData['beneficiary_name'];
                }

                if ((empty($bankData['beneficiary_name']) || ! is_string($bankData['beneficiary_name']))
                    && ! empty($bankData['account_name'])) {
                    $bankData['beneficiary_name'] = $bankData['account_name'];
                }

                if (empty($bankData['account_number']) && ! empty($bankData['iban'])) {
                    $bankData['account_number'] = $bankData['iban'];
                }

                foreach ($bankData as $key => $value) {
                    if (!is_string($value) || $value === '') {
                        continue;
                    }

                    if (str_contains($key, 'path') || str_contains($key, 'image') || str_contains($key, 'logo') || str_contains($key, 'qr')) {
                        $bankData[$key . '_url'] = $this->generateManualPaymentSignedUrl($value);
                    }
                }

                return $bankData;
            });

            ResponseService::successResponse("Manual Banks Fetched", $banks);
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "API Controller -> getManualBanks");
            ResponseService::errorResponse();
        }
    }

    public function storeManualPaymentRequest(Request $request) {
        if ($request->filled('bank_id') && !$request->filled('manual_bank_id')) {
            // أ¢â€‌ع©ط¢â€ أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€‍ bank_id أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢â€“أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€‍ أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ» أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€‌ع©ط£آ أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ§ أ¢â€¢ع¾ط·آ­أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ« manual_bank_id أ¢â€‌ع©ط£آ©أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€‍ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµأ¢â€‌ع©ط£آ©أ¢â€‌ع©ط£آ©.
            $request->merge(['manual_bank_id' => $request->input('bank_id')]);
        }



        $paymentMethod = $request->input('payment_method', 'manual_bank');

        $validator = Validator::make($request->all(), [
            'payment_method' => 'nullable|in:manual_bank,east_yemen_bank,wallet',
            'manual_bank_id' => 'required_if:payment_method,manual_bank|nullable|exists:manual_banks,id',
            
            'amount'         => 'required|numeric|min:0.01',
            'reference'      => 'nullable|string|max:255',
            'user_note'      => 'nullable|string',
            'receipt'        => 'required_if:payment_method,manual_bank|nullable|file|mimes:jpg,jpeg,png,pdf|max:5120',
            'payable_type'   => 'nullable|string',
            'payable_id'     => 'nullable|integer',
            'currency'       => 'nullable|string|max:8',
            'east_yemen_bank' => 'required_if:payment_method,east_yemen_bank|array',
            'east_yemen_bank.voucher_number' => 'required_if:payment_method,east_yemen_bank|string|max:255',
            'east_yemen_bank.payment_status' => 'nullable|string|max:255',
        
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $validated = $validator->validated();


        $payableTypeInput = $request->input('payable_type');
        $payableIdInput = $request->input('payable_id');

        $resolvedPayableType = null;
        $payableId = $payableIdInput;




        $isWalletTopUp = is_string($payableTypeInput)
            && strtolower(trim($payableTypeInput)) === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;

        if ($isWalletTopUp) {
            if ($request->filled('payable_id')) {
                ResponseService::validationError('Wallet top-up requests should not include a payable id.');
            }

            $walletAccount = WalletAccount::firstOrCreate(
                [
                    'user_id' => Auth::id(),
                ],
                [
                    'currency' => $this->getWalletCurrencyCode(),
                ]
            );
            $walletAccount = $this->ensureWalletAccountCurrency($walletAccount);

            $resolvedPayableType = ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;
            $payableId = $walletAccount->getKey();
        } elseif (!empty($payableTypeInput) || !empty($payableIdInput)) {
            if (empty($payableTypeInput) || empty($payableIdInput)) {




                ResponseService::validationError('Payable type and payable id are required together.');
            }

            $resolvedPayableType = $this->resolveManualPayableType($payableTypeInput);

            if (empty($resolvedPayableType)) {
                ResponseService::validationError('Invalid payable type supplied.');
            }

            if (!$resolvedPayableType::whereKey($payableIdInput)->exists()) {
                ResponseService::validationError('Unable to locate the selected payable record.');
            }
        }


        $manualBank = null;

        if ($paymentMethod === 'manual_bank' && $request->filled('manual_bank_id')) {
            $manualBank = ManualBank::query()->find((int) $request->input('manual_bank_id'));
        }

        $metaUpdates = $this->buildManualPaymentMetaUpdates(
            $request,
            is_string($paymentMethod) ? $paymentMethod : 'manual_bank',
            $isWalletTopUp,
            $manualBank
        );




        $requestedCurrency = $request->input('currency');
        $currency = filled($requestedCurrency)
            ? strtoupper($requestedCurrency)
            : $this->getDefaultCurrencyCode();
        $walletCurrency = $this->getWalletCurrencyCode();

        if ($isWalletTopUp || $paymentMethod === 'wallet') {
            if ($requestedCurrency !== null && strtoupper($requestedCurrency) !== $walletCurrency) {
                ResponseService::validationError(sprintf(
                    'Wallet transactions must use the %s currency.',
                    $walletCurrency
                ));
            }

            $currency = $walletCurrency;
        }

        $user = Auth::user();

        if ($paymentMethod === 'wallet' && $isWalletTopUp) {
            ResponseService::validationError('Wallet top-up requests cannot be paid using wallet balance.');
        }

        $walletIdempotencyKey = null;
        $existingTransaction = null;
        $existingManualPaymentRequest = null;


        try {
            DB::beginTransaction();



            if ($paymentMethod === 'wallet') {
                $walletIdempotencyKey = $this->buildManualPaymentWalletIdempotencyKey(
                    $user,
                    $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP ? $resolvedPayableType : null,
                    $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP ? $payableId : null,
                    (float) $request->amount,
                    $currency
                );

                $existingTransaction = $this->findWalletPaymentTransaction(
                    $user->id,
                    $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP ? $resolvedPayableType : null,
                    $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP ? $payableId : null,
                    $walletIdempotencyKey
                );

                if ($existingTransaction && $existingTransaction->manual_payment_request_id) {
                    $existingManualPaymentRequest = ManualPaymentRequest::query()
                        ->whereKey($existingTransaction->manual_payment_request_id)
                        ->lockForUpdate()
                        ->first();
                }

                if ($existingTransaction && strtolower($existingTransaction->payment_status) === 'succeed') {
                    DB::commit();

                    if ($existingManualPaymentRequest) {
                        $existingManualPaymentRequest->loadMissing('manualBank', 'payable', 'paymentTransaction');

                        ResponseService::successResponse(
                            'Transaction already processed',
                            ManualPaymentRequestResource::make($existingManualPaymentRequest)->resolve()
                        );
                    }

                    ResponseService::successResponse('Transaction already processed');
                }
            }



            $receiptPath = null;
            if ($request->hasFile('receipt')) {
                $receiptPath = $request->file('receipt')->store('manual_payments', 'public');
                
            } elseif ($existingManualPaymentRequest) {
                $receiptPath = $existingManualPaymentRequest->receipt_path;

            }

            $metaUpdates = $this->appendManualPaymentReceiptMeta($metaUpdates, $receiptPath);

            $existingMeta = $existingManualPaymentRequest?->meta;
            $metaPayload = $this->mergeManualPaymentMeta(
                is_array($existingMeta) ? $existingMeta : [],
                $metaUpdates
            );


            $department = $this->resolveManualPaymentDepartment(
                $resolvedPayableType,
                $payableId,
                $existingManualPaymentRequest
            );

            $serviceRequestId = null;
            if (is_numeric($payableId)) {
                $normalizedPayableType = is_string($resolvedPayableType)
                    ? strtolower(trim($resolvedPayableType, " \t\n\r\0\x0B\"'"))
                    : null;

                if ($normalizedPayableType !== null) {
                    $serviceAliases = [
                        strtolower(ServiceRequest::class),
                        strtolower('\\' . ServiceRequest::class),
                        'app\\models\\servicerequest',
                        'app\\servicerequest',
                        'service_request',
                        'service-request',
                    ];

                    if (in_array($normalizedPayableType, $serviceAliases, true)) {
                        $serviceRequestId = (int) $payableId;
                    }
                }
            }


            $manualPaymentAttributes = [
                'user_id'        => $user->id,

                'manual_bank_id' => $paymentMethod === 'manual_bank' ? $request->manual_bank_id : null,
                'amount'         => $request->amount,
                'currency'       => $currency,


                'reference'      => $request->reference,
                'user_note'      => $request->user_note,
                'receipt_path'   => $receiptPath,
                'status'         => ManualPaymentRequest::STATUS_PENDING,
                'payable_type'   => $resolvedPayableType,
                'payable_id'     => $payableId,
                'service_request_id' => $serviceRequestId,
                'department'     => $department,
                'meta'           => empty($metaPayload) ? null : $metaPayload,
            ];

            if ($existingManualPaymentRequest) {




                $existingManualPaymentRequest->forceFill($manualPaymentAttributes)->save();
                $manualPaymentRequest = $existingManualPaymentRequest->fresh();

                } else {


                $manualPaymentRequest = ManualPaymentRequest::create($manualPaymentAttributes);
            }

            if ($paymentMethod === 'wallet') {
                $transactionMeta = $existingTransaction?->meta ?? [];
                $transactionMeta = array_replace_recursive($transactionMeta, $metaPayload ?? []);
                data_set($transactionMeta, 'wallet.idempotency_key', $walletIdempotencyKey);

                if ($existingTransaction) {
                    $existingTransaction->forceFill([
                        'user_id' => $user->id,
                        'manual_payment_request_id' => $manualPaymentRequest->id,
                        'amount' => $manualPaymentRequest->amount,
                        'currency' => $currency,
                        'receipt_path' => $receiptPath,
                        'payment_gateway' => 'wallet',
                        'payable_type' => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                            ? $resolvedPayableType
                            : null,
                        'payable_id' => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                            ? $payableId
                            : null,
                        'order_id' => $walletIdempotencyKey,
                        'meta' => $transactionMeta,
                    ])->save();

                    $paymentTransaction = $existingTransaction->fresh();
                } else {
                    $paymentTransaction = PaymentTransaction::create([
                        'user_id'                   => $user->id,
                        'manual_payment_request_id' => $manualPaymentRequest->id,
                        'amount'                    => $manualPaymentRequest->amount,
                        'currency'                  => $currency,
                        'receipt_path'              => $receiptPath,
                        'payment_gateway'           => 'wallet',
                        'payment_status'            => 'pending',
                        'payable_type'              => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                            ? $resolvedPayableType
                            : null,
                        'payable_id'                => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                            ? $payableId
                            : null,
                        'order_id'                  => $walletIdempotencyKey,
                        'meta'                      => empty($transactionMeta) ? null : $transactionMeta,
                    ]);
                }

                $walletTransaction = $this->debitWalletTransaction(
                    $paymentTransaction->fresh(),
                    $user,
                    $walletIdempotencyKey,
                    (float) $manualPaymentRequest->amount,
                    [
                        'manual_payment_request_id' => $manualPaymentRequest->id,
                        'meta' => [
                            'context' => 'manual_payment',
                            'payable_type' => $manualPaymentRequest->payable_type,
                            'payable_id' => $manualPaymentRequest->payable_id,
                            'manual_payment_request_id' => $manualPaymentRequest->id,
                        ],
                    ]
                );

                $transactionMeta = $paymentTransaction->meta ?? [];
                data_set($transactionMeta, 'wallet.transaction_id', $walletTransaction->getKey());
                data_set($transactionMeta, 'wallet.balance_after', (float) $walletTransaction->balance_after);
                data_set($transactionMeta, 'wallet.idempotency_key', $walletTransaction->idempotency_key);

                $paymentTransaction->forceFill([
                    'meta' => $transactionMeta,
                ])->save();

                $requestMeta = array_replace_recursive($manualPaymentRequest->meta ?? [], [
                    'wallet' => [
                        'transaction_id' => $walletTransaction->getKey(),
                        'idempotency_key' => $walletTransaction->idempotency_key,
                        'balance_after' => (float) $walletTransaction->balance_after,
                    ],
                ]);

                $manualPaymentRequest->forceFill([
                    'status' => ManualPaymentRequest::STATUS_APPROVED,
                    'reviewed_at' => now(),
                    'meta' => $requestMeta,
                ])->save();

                $options = [
                    'payment_gateway' => 'wallet',
                    'manual_payment_request_id' => $manualPaymentRequest->id,
                    'wallet_transaction' => $walletTransaction,
                    'meta' => $transactionMeta,
                ];

                $shouldFulfill = !empty($manualPaymentRequest->payable_type)
                    && $manualPaymentRequest->payable_type !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;

                $message = 'Manual payment completed successfully';

                if ($shouldFulfill) {
                    $result = $this->paymentFulfillmentService->fulfill(
                        $paymentTransaction->fresh(),
                        $manualPaymentRequest->payable_type,
                        $manualPaymentRequest->payable_id,
                        $user->id,
                        $options
                    );

                    if ($result['error']) {
                        throw new RuntimeException($result['message']);
                    }

                    $message = $result['message'] === 'Transaction already processed'
                        ? 'Transaction already processed'
                        : 'Manual payment completed successfully';
                }

                DB::commit();

                $manualPaymentRequest->loadMissing('manualBank', 'payable', 'paymentTransaction');


                $message = $result['message'] === 'Transaction already processed'
                    ? 'Transaction already processed'
                    : 'Manual payment completed successfully';

                ResponseService::successResponse(
                    $message,
                    ManualPaymentRequestResource::make($manualPaymentRequest)->resolve()
                );
            } elseif ($paymentMethod === 'east_yemen_bank') {
                $eastYemenData = $validated['east_yemen_bank'] ?? [];
                if (!is_array($eastYemenData)) {
                    $eastYemenData = [];
                }

                $voucherNumber = Arr::get($eastYemenData, 'voucher_number');
                $paymentStatusValue = Arr::get($eastYemenData, 'payment_status');
                $recordedAt = now()->toIso8601String();

                $transactionMeta = array_replace_recursive($metaPayload ?? [], [
                    'east_yemen_bank' => array_filter([
                        'voucher_number' => $voucherNumber,
                        'payment_status' => $paymentStatusValue,
                        'recorded_at' => $recordedAt,
                    ], static fn($value) => $value !== null && $value !== ''),
                ]);

                $transactionMeta['provider'] = 'alsharq';
                $transactionMeta['channel'] = 'alsharq';


                if ($paymentStatusValue !== null && $paymentStatusValue !== '') {
                    $transactionMeta['east_yemen_bank_status'] = $paymentStatusValue;
                }

                $paymentTransaction = PaymentTransaction::create([
                    'user_id'                   => $user->id,
                    'manual_payment_request_id' => $manualPaymentRequest->id,
                    'amount'                    => $manualPaymentRequest->amount,
                    'currency'                  => $currency,
                    'receipt_path'              => $receiptPath,
                    'payment_gateway'           => 'east_yemen_bank',
                    'payment_status'            => 'succeed',
                    'payable_type'              => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                        ? $resolvedPayableType
                        : null,
                    'payable_id'                => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                        ? $payableId
                        : null,
                    'order_id'                  => $voucherNumber ?: null,
                    'meta'                      => empty($transactionMeta) ? null : $transactionMeta,
                ]);

                $requestMeta = array_replace_recursive($manualPaymentRequest->meta ?? [], [
                    'east_yemen_bank' => [
                        'auto_approval' => [
                            'recorded_at' => $recordedAt,
                            'payload' => array_filter([
                                'voucher_number' => $voucherNumber,
                            ], static fn($value) => $value !== null && $value !== ''),
                            'response' => array_filter([
                                'payment_status' => $paymentStatusValue,
                            ], static fn($value) => $value !== null && $value !== ''),
                        ],
                    ],
                ]);

                $manualPaymentRequest->forceFill([
                    'status' => ManualPaymentRequest::STATUS_APPROVED,
                    'reviewed_at' => now(),
                    'meta' => $requestMeta,
                ])->save();

                ManualPaymentRequestHistory::create([
                    'manual_payment_request_id' => $manualPaymentRequest->id,
                    'user_id' => $user->id,
                    'status' => ManualPaymentRequest::STATUS_APPROVED,
                    'meta' => [
                        'action' => 'east_yemen_bank_auto_approval',
                        'gateway' => 'east_yemen_bank',
                        'payload' => array_filter([
                            'voucher_number' => $voucherNumber,
                        ], static fn($value) => $value !== null && $value !== ''),
                        'response' => array_filter([
                            'payment_status' => $paymentStatusValue,
                        ], static fn($value) => $value !== null && $value !== ''),
                    ],
                ]);

                $transactionMetaForFulfillment = $paymentTransaction->meta ?? [];

                $options = [
                    'payment_gateway' => 'east_yemen_bank',
                    'manual_payment_request_id' => $manualPaymentRequest->id,
                    'meta' => $transactionMetaForFulfillment,
                ];

                $shouldFulfill = !empty($manualPaymentRequest->payable_type)
                    && $manualPaymentRequest->payable_type !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;

                $message = 'Manual payment completed successfully';

                if ($shouldFulfill) {
                    $result = $this->paymentFulfillmentService->fulfill(
                        $paymentTransaction->fresh(),
                        $manualPaymentRequest->payable_type,
                        $manualPaymentRequest->payable_id,
                        $user->id,
                        $options
                    );

                    if ($result['error']) {
                        throw new RuntimeException($result['message']);
                    }

                    $message = $result['message'] === 'Transaction already processed'
                        ? 'Transaction already processed'
                        : 'Manual payment completed successfully';
                }

                DB::commit();

                $freshTransaction = $paymentTransaction->fresh();
                $manualPaymentRequest->setRelation('paymentTransaction', $freshTransaction);
                $manualPaymentRequest->loadMissing('manualBank');
                if (!empty($resolvedPayableType)) {
                    $manualPaymentRequest->loadMissing('payable');
                }




                ResponseService::successResponse(
                    $message,
                    ManualPaymentRequestResource::make($manualPaymentRequest)->resolve()
                );
            }




            $paymentTransaction = PaymentTransaction::create([
                'user_id'                   => $user->id,
                'manual_payment_request_id' => $manualPaymentRequest->id,
                'amount'                    => $manualPaymentRequest->amount,
                'currency'                  => $currency,
                'receipt_path'              => $receiptPath,
                'payment_gateway'           => $paymentMethod,
                'payment_status'            => 'pending',
                'payable_type'              => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                    ? $resolvedPayableType
                    : null,
                'payable_id'                => ($resolvedPayableType && $resolvedPayableType !== ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP)
                    ? $payableId
                    : null,
                'meta'                      => empty($metaPayload) ? null : $metaPayload,

            ]);

            DB::commit();

            $manualPaymentRequest->setRelation('paymentTransaction', $paymentTransaction);
            $manualPaymentRequest->loadMissing('manualBank');
            if (!empty($resolvedPayableType)) {
                $manualPaymentRequest->loadMissing('payable');
            }

            ResponseService::successResponse(
                'Manual Payment Request Submitted',
                ManualPaymentRequestResource::make($manualPaymentRequest)->resolve()
            );

        } catch (RuntimeException $runtimeException) {
            DB::rollBack();
            ResponseService::errorResponse($runtimeException->getMessage());

        } catch (Throwable $th) {
            DB::rollBack();
            ResponseService::logErrorResponse($th, 'API Controller -> storeManualPaymentRequest');
            ResponseService::errorResponse();
        }
    }

    public function getManualPaymentRequests(Request $request) {
        $filters = $this->normalizeManualPaymentRequestFilters($request->all());


        $gatewayAliasMap = $this->manualPaymentGatewayAliasMap();
        $gatewayValidationValues = array_values(array_unique(array_merge(
            array_keys($gatewayAliasMap),
            array_merge(...array_values($gatewayAliasMap))
        )));


        $validator = Validator::make($filters, [
            'status' => ['nullable', Rule::in([
                ManualPaymentRequest::STATUS_PENDING,
                ManualPaymentRequest::STATUS_UNDER_REVIEW,
                ManualPaymentRequest::STATUS_APPROVED,
                ManualPaymentRequest::STATUS_REJECTED,
            ])],
            'payment_gateway' => ['nullable', Rule::in($gatewayValidationValues)],
            'department' => ['nullable', 'string'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],


        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        $validated = $validator->validated();


        $status = $validated['status'] ?? $filters['status'] ?? null;
        $paymentGateway = $this->normalizeManualPaymentGateway(
            $validated['payment_gateway'] ?? $filters['payment_gateway'] ?? null
        );
        
        $department = array_key_exists('department', $validated)
            ? $validated['department']
            : ($filters['department'] ?? null);

        $page = (int) ($validated['page'] ?? $filters['page'] ?? 1);
        $perPage = (int) ($validated['per_page'] ?? $filters['per_page'] ?? 15);

        if ($perPage < 1) {
            $perPage = 15;
        } elseif ($perPage > 100) {
            $perPage = 100;
        }


        try {
            $query = ManualPaymentRequest::query()
                ->with([
                    'manualBank',
                    'payable',
                    'paymentTransaction.order',
                ]);

            $this->applyManualPaymentRequestVisibilityScope($query, (int) Auth::id());

            $query
                ->when($status, static function ($builder, string $statusValue) {
                    $builder->where('manual_payment_requests.status', $statusValue);


                })
                ->when($paymentGateway, function ($builder, string $gateway) {
                    $aliases = $this->expandManualPaymentGatewayAliases($gateway);

                    $builder->where(static function ($query) use ($aliases, $gateway) {
                        $query->whereHas('paymentTransaction', static function ($transactionQuery) use ($aliases) {
                            $transactionQuery->whereIn('payment_gateway', $aliases);
                        });

                        if (in_array($gateway, ['manual_banks', 'manual_bank'], true)) {
                            $query->orWhereDoesntHave('paymentTransaction');
                        }
                    });
                })
                ->when(
                    $department !== null,
                    static function ($builder) use ($department) {
                        $builder->where(static function ($query) use ($department) {
                            $query->where('manual_payment_requests.department', $department)
                                ->orWhereNull('manual_payment_requests.department');
                        });
                    }
                )
                ->orderByDesc('manual_payment_requests.id');
            $stats = $this->summarizeManualPaymentRequests($query);

            $paginator = $query->paginate($perPage, ['manual_payment_requests.*'], 'page', $page);

            $requests = ManualPaymentRequestResource::collection(collect($paginator->items()))->resolve();

            $meta = [
                'total' => (int) $paginator->total(),
                'current_page' => (int) $paginator->currentPage(),
                'last_page' => (int) max($paginator->lastPage(), 1),
                'per_page' => (int) $paginator->perPage(),
            ];

            ResponseService::successResponse(
                'أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ´أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ° أ¢â€¢ع¾أ¢â€¢â€“أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آ² أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾أ¢â€¢آ£ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط£آ¨ أ¢â€¢ع¾ط·آ°أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط·آµ',
                [
                    'manual_payment_requests' => $requests,
                    'items' => $requests,
                    'meta' => $meta,
                    'stats' => $stats,

                ]
            );
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> getManualPaymentRequests');
            ResponseService::errorResponse();
        }
    }

    public function showManualPaymentRequest($manualPaymentRequestId) {
        try {
            $manualPaymentRequest = ManualPaymentRequest::with(['manualBank', 'paymentTransaction.order', 'payable'])
                ->where('user_id', Auth::user()->id)
                ->findOrFail($manualPaymentRequestId);

            ResponseService::successResponse(
                'Manual Payment Request Fetched',
                ManualPaymentRequestResource::make($manualPaymentRequest)->resolve()
            );
        } catch (ModelNotFoundException) {
            ResponseService::errorResponse('Manual payment request not found.');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'API Controller -> showManualPaymentRequest');
            ResponseService::errorResponse();
        }
    }


    private function buildManualPaymentMetaUpdates(
        Request $request,
        string $paymentMethod,
        bool $isWalletTopUp,
        ?ManualBank $manualBank
    ): array {
        $meta = [
            'source' => 'api.manual_payment_request',
            'submitted_at' => now()->toIso8601String(),
        ];

        $normalizedGateway = strtolower(trim($paymentMethod));
        if ($normalizedGateway !== '') {
            $meta['gateway'] = $normalizedGateway;
        }

        if ($isWalletTopUp) {
            $meta['wallet'] = [
                'purpose' => ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
            ];
        }

        $metadataPayload = $this->extractManualPaymentMetadataPayload($request);
        if ($metadataPayload !== null) {
            $meta['metadata'] = $metadataPayload;
            data_set($meta, 'manual.metadata', $metadataPayload);
        }

        $reference = $this->normalizeManualPaymentString($request->input('reference'));
        if ($reference !== null) {
            $meta['reference'] = $reference;
            data_set($meta, 'manual.reference', $reference);
            if (data_get($meta, 'metadata.reference') === null) {
                data_set($meta, 'metadata.reference', $reference);
            }
            if (data_get($meta, 'metadata.transfer_reference') === null) {
                data_set($meta, 'metadata.transfer_reference', $reference);
            }
        }

        $userNote = $this->normalizeManualPaymentString($request->input('user_note'));
        if ($userNote !== null) {
            $meta['note'] = $userNote;
            $meta['user_note'] = $userNote;
            data_set($meta, 'manual.note', $userNote);
            data_set($meta, 'manual.user_note', $userNote);
            if (data_get($meta, 'metadata.user_note') === null) {
                data_set($meta, 'metadata.user_note', $userNote);
            }
        }

        $transferredAt = $this->normalizeManualPaymentDateValue($request->input('transferred_at'));
        if ($transferredAt !== null) {
            if (data_get($meta, 'metadata.transferred_at') === null) {
                data_set($meta, 'metadata.transferred_at', $transferredAt);
            }
            data_set($meta, 'manual.transferred_at', $transferredAt);
        }

        $manualBankId = null;
        if ($manualBank instanceof ManualBank) {
            $manualBankId = $manualBank->getKey();
        } elseif ($request->filled('manual_bank_id')) {
            $manualBankId = (int) $request->input('manual_bank_id');
        }

        if ($manualBankId !== null && $manualBankId !== 0) {
            data_set($meta, 'bank.id', $manualBankId);
            data_set($meta, 'manual_bank.id', $manualBankId);
        }

        if ($manualBank instanceof ManualBank) {
            $bankName = $this->normalizeManualPaymentString($manualBank->name);
            $beneficiary = $this->normalizeManualPaymentString($manualBank->beneficiary_name);
            $accountNumber = $this->normalizeManualPaymentString($manualBank->account_number ?? $manualBank->iban);
            $currency = $this->normalizeManualPaymentString($manualBank->currency);

            if ($bankName !== null) {
                data_set($meta, 'bank.name', $bankName);
                data_set($meta, 'manual_bank.name', $bankName);
            }

            if ($beneficiary !== null) {
                data_set($meta, 'bank.beneficiary_name', $beneficiary);
                data_set($meta, 'manual_bank.beneficiary_name', $beneficiary);
            }

            if ($accountNumber !== null && data_get($meta, 'bank.account_number') === null) {
                data_set($meta, 'bank.account_number', $accountNumber);
            }

            if ($currency !== null && data_get($meta, 'bank.currency') === null) {
                data_set($meta, 'bank.currency', $currency);
            }
        }

        return $this->cleanupManualPaymentMeta($meta);
    }

    private function appendManualPaymentReceiptMeta(array $meta, ?string $receiptPath): array
    {
        if (! is_string($receiptPath) || trim($receiptPath) === '') {
            return $this->cleanupManualPaymentMeta($meta);
        }

        $normalizedPath = trim($receiptPath);

        $attachment = $this->sanitizeManualPaymentAttachment([
            'name' => 'receipt',
            'path' => $normalizedPath,
            'disk' => 'public',
        ]);

        if ($attachment !== []) {
            $attachments = $this->mergeManualPaymentAttachmentCollections(
                is_array(data_get($meta, 'attachments')) ? data_get($meta, 'attachments') : [],
                [$attachment]
            );
            if ($attachments !== []) {
                data_set($meta, 'attachments', $attachments);
            }

            $manualAttachments = $this->mergeManualPaymentAttachmentCollections(
                is_array(data_get($meta, 'manual.attachments')) ? data_get($meta, 'manual.attachments') : [],
                [$attachment]
            );
            if ($manualAttachments !== []) {
                data_set($meta, 'manual.attachments', $manualAttachments);
            }

            data_set($meta, 'receipt', array_filter([
                'path' => $normalizedPath,
                'disk' => 'public',
            ], static fn ($value) => $value !== null && $value !== ''));

            data_set($meta, 'manual.receipt', array_filter([
                'path' => $normalizedPath,
                'disk' => 'public',
            ], static fn ($value) => $value !== null && $value !== ''));
        }

        return $this->cleanupManualPaymentMeta($meta);
    }

    private function mergeManualPaymentMeta(array $existingMeta, array $updates): array
    {
        if ($updates === []) {
            return $this->cleanupManualPaymentMeta($existingMeta);
        }

        $merged = array_replace_recursive($existingMeta, $updates);

        $mergedAttachments = $this->mergeManualPaymentAttachmentCollections(
            is_array(data_get($existingMeta, 'attachments')) ? data_get($existingMeta, 'attachments') : [],
            is_array(data_get($updates, 'attachments')) ? data_get($updates, 'attachments') : []
        );

        if ($mergedAttachments !== []) {
            data_set($merged, 'attachments', $mergedAttachments);
        } else {
            Arr::forget($merged, 'attachments');
        }

        $mergedManualAttachments = $this->mergeManualPaymentAttachmentCollections(
            is_array(data_get($existingMeta, 'manual.attachments')) ? data_get($existingMeta, 'manual.attachments') : [],
            is_array(data_get($updates, 'manual.attachments')) ? data_get($updates, 'manual.attachments') : []
        );

        if ($mergedManualAttachments !== []) {
            data_set($merged, 'manual.attachments', $mergedManualAttachments);
        } else {
            Arr::forget($merged, 'manual.attachments');
        }

        return $this->cleanupManualPaymentMeta($merged);
    }

    private function mergeManualPaymentAttachmentCollections(array $existing, array $additional): array
    {
        $collection = [];

        $push = static function (array $source) use (&$collection): void {
            foreach ($source as $item) {
                if (! is_array($item)) {
                    continue;
                }

                $sanitized = array_filter($item, static function ($value) {
                    if ($value === null) {
                        return false;
                    }

                    if (is_string($value)) {
                        return trim($value) !== '';
                    }

                    if (is_array($value)) {
                        return $value !== [];
                    }

                    return true;
                });

                if ($sanitized === []) {
                    continue;
                }

                $path = array_key_exists('path', $sanitized)
                    ? trim((string) $sanitized['path'])
                    : '';
                $url = array_key_exists('url', $sanitized)
                    ? trim((string) $sanitized['url'])
                    : '';

                if ($path === '' && $url === '') {
                    continue;
                }

                $disk = array_key_exists('disk', $sanitized)
                    ? trim((string) $sanitized['disk'])
                    : '';

                $key = implode('|', array_filter([$disk, $path, $url]));

                $sanitized['path'] = $path;
                if ($disk !== '') {
                    $sanitized['disk'] = $disk;
                } else {
                    unset($sanitized['disk']);
                }

                if ($url !== '') {
                    $sanitized['url'] = $url;
                } else {
                    unset($sanitized['url']);
                }

                if ($path === '') {
                    unset($sanitized['path']);
                }

                if (! array_key_exists($key, $collection)) {
                    $collection[$key] = $sanitized;
                    continue;
                }

                $collection[$key] = array_replace($collection[$key], $sanitized);
            }
        };

        $push($existing);
        $push($additional);

        return array_values(array_filter($collection, static fn ($item) => is_array($item) && $item !== []));
    }

    private function sanitizeManualPaymentAttachment(array $attachment): array
    {
        return array_filter($attachment, static function ($value) {
            if ($value === null) {
                return false;
            }

            if (is_string($value)) {
                return trim($value) !== '';
            }

            if (is_array($value)) {
                return $value !== [];
            }

            return true;
        });
    }

    private function extractManualPaymentMetadataPayload(Request $request): ?array
    {
        $metadata = $request->input('metadata');

        if ($metadata instanceof Collection) {
            $metadata = $metadata->toArray();
        }

        if (is_string($metadata) && $metadata !== '') {
            try {
                $decoded = json_decode($metadata, true, 512, JSON_THROW_ON_ERROR);
                if (is_array($decoded)) {
                    $metadata = $decoded;
                }
            } catch (Throwable) {
                $metadata = [];
            }
        }

        if (! is_array($metadata)) {
            $metadata = [];
        }

        $metaInput = $request->input('meta');
        if ($metaInput instanceof Collection) {
            $metaInput = $metaInput->toArray();
        }

        if (is_array($metaInput)) {
            $metaMetadata = data_get($metaInput, 'metadata');
            if (is_array($metaMetadata)) {
                $metadata = array_replace_recursive($metaMetadata, $metadata);
            }
        }

        $normalized = $this->sanitizeManualPaymentMetadataArray($metadata);

        return $normalized === [] ? null : $normalized;
    }

    private function sanitizeManualPaymentMetadataArray($value): array
    {
        if ($value instanceof Collection) {
            $value = $value->toArray();
        }

        if (is_string($value)) {
            try {
                $decoded = json_decode($value, true, 512, JSON_THROW_ON_ERROR);
                if (is_array($decoded)) {
                    $value = $decoded;
                }
            } catch (Throwable) {
                return [];
            }
        }

        if (! is_array($value)) {
            return [];
        }

        $result = [];

        foreach ($value as $key => $item) {
            $normalizedKey = is_string($key) ? trim($key) : $key;

            if ($normalizedKey === '' || $normalizedKey === null) {
                continue;
            }

            if ($item instanceof Collection) {
                $item = $item->toArray();
            }

            if (is_array($item)) {
                $nested = $this->sanitizeManualPaymentMetadataArray($item);
                if ($nested !== []) {
                    $result[$normalizedKey] = $nested;
                }
                continue;
            }

            if ($item instanceof DateTimeInterface) {
                $result[$normalizedKey] = Carbon::createFromInterface($item)->toIso8601String();
                continue;
            }

            if (is_string($item)) {
                $trimmed = trim($item);
                if ($trimmed !== '') {
                    $result[$normalizedKey] = $trimmed;
                }
                continue;
            }

            if (is_numeric($item) || is_bool($item)) {
                $result[$normalizedKey] = $item;
                continue;
            }

            if ($item === null) {
                continue;
            }

            $stringified = trim((string) $item);
            if ($stringified !== '') {
                $result[$normalizedKey] = $stringified;
            }
        }

        return $result;
    }

    private function cleanupManualPaymentMeta(array $meta): array
    {
        foreach ($meta as $key => $value) {
            if (is_array($value)) {
                $normalized = $this->cleanupManualPaymentMeta($value);
                if ($normalized === []) {
                    unset($meta[$key]);
                } else {
                    $meta[$key] = $normalized;
                }
                continue;
            }

            if ($value === null) {
                unset($meta[$key]);
                continue;
            }

            if (is_string($value)) {
                $trimmed = trim($value);
                if ($trimmed === '') {
                    unset($meta[$key]);
                } else {
                    $meta[$key] = $trimmed;
                }
            }
        }

        return $meta;
    }

    private function normalizeManualPaymentString($value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function normalizeManualPaymentDateValue($value): ?string
    {
        if ($value instanceof DateTimeInterface) {
            return Carbon::createFromInterface($value)->toIso8601String();
        }

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '') {
            return null;
        }

        try {
            return Carbon::parse($trimmed)->toIso8601String();
        } catch (Throwable) {
            return $trimmed;
        }
    }


    private function normalizeManualPaymentRequestFilters(array $input): array
    {
        $filters = [
            'status' => $this->normalizeManualPaymentRequestStatus($input['status'] ?? null),
            'payment_gateway' => $this->normalizeManualPaymentGateway(
                $input['payment_gateway'] ?? ($input['gateway'] ?? null)
            ),
            'department' => null,
            'page' => $this->extractIntegerFromKeys($input, ['page', 'current_page']),
            'per_page' => $this->extractIntegerFromKeys($input, ['per_page', 'limit', 'page_size']),
        ];

        if (array_key_exists('department', $input)) {
            $rawDepartment = is_string($input['department']) ? trim($input['department']) : $input['department'];
            if (is_string($rawDepartment) && $rawDepartment !== '' && strtolower($rawDepartment) !== 'null') {
                $filters['department'] = $rawDepartment;
            }
        }

        return $filters;
    }

    private function normalizeManualPaymentRequestStatus($value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $normalized = strtolower(trim($value));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        $map = [
            'pending' => ManualPaymentRequest::STATUS_PENDING,
            'in_review' => ManualPaymentRequest::STATUS_UNDER_REVIEW,
            'in-review' => ManualPaymentRequest::STATUS_UNDER_REVIEW,
            'review' => ManualPaymentRequest::STATUS_UNDER_REVIEW,
            'reviewing' => ManualPaymentRequest::STATUS_UNDER_REVIEW,
            'under_review' => ManualPaymentRequest::STATUS_UNDER_REVIEW,
            'under-review' => ManualPaymentRequest::STATUS_UNDER_REVIEW,
            'approved' => ManualPaymentRequest::STATUS_APPROVED,
            'accepted' => ManualPaymentRequest::STATUS_APPROVED,
            'completed' => ManualPaymentRequest::STATUS_APPROVED,
            'rejected' => ManualPaymentRequest::STATUS_REJECTED,
            'declined' => ManualPaymentRequest::STATUS_REJECTED,
        ];

        return $map[$normalized] ?? ($normalized === ManualPaymentRequest::STATUS_PENDING
            || $normalized === ManualPaymentRequest::STATUS_UNDER_REVIEW
            || $normalized === ManualPaymentRequest::STATUS_APPROVED
            || $normalized === ManualPaymentRequest::STATUS_REJECTED
            ? $normalized
            : null);
    }

    private function normalizeManualPaymentGateway($value): ?string
    {
        if (!is_string($value)) {
            return null;
        }

        $normalized = strtolower(trim($value));

        if ($normalized === '') {
            return null;
        }

        foreach ($this->manualPaymentGatewayAliasMap() as $canonical => $aliases) {
            if (in_array($normalized, $aliases, true)) {
                return $canonical;
            }
        }

        return $normalized;
    }

    private function expandManualPaymentGatewayAliases(string $gateway): array
    {
        $canonical = $this->normalizeManualPaymentGateway($gateway);

        if ($canonical === null) {
            return [];
        }

        $aliases = $this->manualPaymentGatewayAliasMap()[$canonical] ?? [$canonical];

        return array_values(array_unique($aliases));
    }

    private function manualPaymentGatewayAliasMap(): array
    {
        return [
            'manual_banks' => [
                'manual_banks',
                'manual_bank',
                'manual',
                'manual-bank',
                'manual-banks',
                'manual bank',
                'manual banks',
                'manual_payment',
                'manual-payment',
                'manual payment',
                'manualpayment',
                'manualpayments',
                'manualbank',
                'manualbanking',
                'manualbanks',
                'manual_transfer',
                'manual-transfer',
                'manual transfers',
                'manual-transfers',
                'manualtransfers',
                'manualtransfer',
                'offline',
                'internal',
                'bank',
                'bank_transfer',
                'bank-transfer',
                'bank transfer',
                'banktransfer',

            ],
            'east_yemen_bank' => [
                'east_yemen_bank',
                'east-yemen-bank',
                'east yemen bank',
                'eastyemenbank',
                'east',
                'east_yemen',
                'east-yemen',
                'east yemen',
                'bankalsharq',
                'bank_alsharq',
                'bank-alsharq',
                'bank alsharq',
                'bankalsharqbank',
                'bank_alsharq_bank',
                'bank-alsharq-bank',
                'bank alsharq bank',
                'alsharq',
                'al-sharq',
                'al sharq',
            ],
            'wallet' => [
                'wallet',
                'wallet_balance',
                'wallet-balance',
                'wallet balance',
                'wallet_gateway',
                'wallet-gateway',
                'wallet gateway',
                'wallet_top_up',
                'wallet-top-up',
                'wallet top up',
                'wallet-topup',
                'wallet topup',
                'walletpayment',
                'wallet_payment',
                'wallet-payment',
                'wallet payment',
                'wallettopup',
            ],
            'cash' => [
                'cash',
                'cod',
                'cash_on_delivery',
                'cash-on-delivery',
                'cash on delivery',
                'cashcollection',
                'cash_collection',
                'cash-collection',
                'cash collection',
                'cashcollect',
                'cash_collect',
                'cash-collect',
            ],
        ];
    }





    private function applyManualPaymentRequestVisibilityScope(Builder $query, int $userId): Builder
    {
        $orderPayableTypes = ManualPaymentRequest::orderPayableTypeTokens();

        return $query->where(static function (Builder $builder) use ($userId, $orderPayableTypes) {
            
            $builder->where('manual_payment_requests.user_id', $userId)
                ->orWhere(static function (Builder $ordersScope) use ($userId, $orderPayableTypes) {
                    $ordersScope
                        ->whereIn(DB::raw('LOWER(manual_payment_requests.payable_type)'), $orderPayableTypes)

                        ->whereExists(static function ($subQuery) use ($userId) {
                            $subQuery
                                ->select(DB::raw('1'))
                                ->from('orders')
                                ->whereColumn('orders.id', 'manual_payment_requests.payable_id')
                                ->where(static function ($orderVisibility) use ($userId) {
                                    $orderVisibility
                                        ->where('orders.user_id', $userId)
                                        ->orWhere('orders.seller_id', $userId);
                                });
                        });
                })
                ->orWhereExists(static function ($subQuery) use ($userId, $orderPayableTypes) {
                    $subQuery
                        ->select(DB::raw('1'))
                        ->from('payment_transactions')
                        ->join('orders', static function ($join) use ($orderPayableTypes) {

                            $join
                                ->on('orders.id', '=', 'payment_transactions.payable_id')
                                ->whereIn(
                                    DB::raw('LOWER(payment_transactions.payable_type)'),
                                    $orderPayableTypes
                                );

                                
                        })
                        ->whereColumn('payment_transactions.manual_payment_request_id', 'manual_payment_requests.id')
                        ->where(static function ($orderVisibility) use ($userId) {
                            $orderVisibility
                                ->where('orders.user_id', $userId)
                                ->orWhere('orders.seller_id', $userId);
                        });
                });
        });
    }

    private function summarizeManualPaymentRequests(Builder $query): array
    {
        $summary = [
            'total' => [
                'count' => 0,
                'amount' => 0.0,
                'amounts' => [],
            ],
            'statuses' => [
                ManualPaymentRequest::STATUS_PENDING => [
                    'count' => 0,
                    'amount' => 0.0,
                    'amounts' => [],
                ],
                ManualPaymentRequest::STATUS_UNDER_REVIEW => [
                    'count' => 0,
                    'amount' => 0.0,
                    'amounts' => [],
                ],
                ManualPaymentRequest::STATUS_APPROVED => [
                    'count' => 0,
                    'amount' => 0.0,
                    'amounts' => [],
                ],
                ManualPaymentRequest::STATUS_REJECTED => [
                    'count' => 0,
                    'amount' => 0.0,
                    'amounts' => [],
                ],
            ],
        ];

        $rows = (clone $query)
            ->cloneWithout(['columns', 'orders'])
            ->selectRaw('COALESCE(manual_payment_requests.status, ?) as status', [ManualPaymentRequest::STATUS_PENDING])
            ->selectRaw('COALESCE(UPPER(manual_payment_requests.currency), \'\') as currency')
            ->selectRaw('COUNT(*) as total_count')
            ->selectRaw('COALESCE(SUM(manual_payment_requests.amount), 0) as total_amount')
            ->groupBy('status', 'currency')
            ->get();

        foreach ($rows as $row) {
            $status = $row->status ?? ManualPaymentRequest::STATUS_PENDING;
            if (!array_key_exists($status, $summary['statuses'])) {
                $summary['statuses'][$status] = [
                    'count' => 0,
                    'amount' => 0.0,
                    'amounts' => [],
                ];
            }

            $count = (int) $row->total_count;
            $amount = (float) $row->total_amount;
            $currency = is_string($row->currency) && $row->currency !== ''
                ? strtoupper($row->currency)
                : null;

            $summary['statuses'][$status]['count'] += $count;
            $summary['total']['count'] += $count;

            if ($currency !== null) {
                $statusAmounts = &$summary['statuses'][$status]['amounts'];
                $statusAmounts[$currency] = ($statusAmounts[$currency] ?? 0.0) + $amount;
                $summary['statuses'][$status]['amount'] = ($summary['statuses'][$status]['amount'] ?? 0.0) + $amount;

                $totalAmounts = &$summary['total']['amounts'];
                $totalAmounts[$currency] = ($totalAmounts[$currency] ?? 0.0) + $amount;
                $summary['total']['amount'] = ($summary['total']['amount'] ?? 0.0) + $amount;
                unset($statusAmounts, $totalAmounts);
            }
        }

        return $summary;
    }



    private function extractIntegerFromKeys(array $input, array $keys): ?int
    {
        foreach ($keys as $key) {
            if (!array_key_exists($key, $input)) {
                continue;
            }

            $value = $input[$key];

            if (is_numeric($value)) {
                $intValue = (int) $value;

                return $intValue > 0 ? $intValue : null;
            }
        }

        return null;
    }

    private function resolveManualPaymentDepartment(
        ?string $payableType,
        mixed $payableId,
        ?ManualPaymentRequest $existingManualPaymentRequest
    ): ?string {
        if (! ManualPaymentRequest::isOrderPayableType($payableType)) {
            return null;
        }

        $orderId = is_numeric($payableId) ? (int) $payableId : null;

        if ($orderId !== null) {
            $department = Order::query()->whereKey($orderId)->value('department');
            $normalized = $this->normalizeDepartmentValue($department);

            if ($normalized !== null) {
                return $normalized;
            }
        }

        if ($existingManualPaymentRequest !== null) {
            $normalized = $this->normalizeDepartmentValue($existingManualPaymentRequest->department);

            if ($normalized !== null) {
                return $normalized;
            }
        }

        return null;
    }


    private function normalizeDepartmentValue(mixed $department): ?string
    {
        if (! is_string($department)) {
            return null;
        }

        $trimmed = trim($department);

        return $trimmed === '' ? null : $trimmed;
    }






    

    private function chatConversationsSupportsColumn(string $column): bool
    {
        static $columnSupport = [];

        if (!array_key_exists($column, $columnSupport)) {
            $columnSupport[$column] = Schema::hasTable('chat_conversations')
                && Schema::hasColumn('chat_conversations', $column);
        }

        return $columnSupport[$column];
    }

    private function resolveConversationAssignedAgent(ItemOffer $itemOffer, array $delegates): ?int
    
    
    {
        if (empty($delegates)) {
            return null;
        }

        $possibleOwners = array_filter([
            $itemOffer->seller_id,
            $itemOffer->item?->user_id,
        ]);

        foreach ($possibleOwners as $ownerId) {
            if (in_array($ownerId, $delegates, true)) {
                return $ownerId;
            }
        }

        return $delegates[0] ?? null;
    }

    private function syncConversationDepartmentAndAssignment(Chat $conversation, ?string $department, ?int $assignedAgentId): bool
    {
        $updated = false;

        if (
            $department &&
            $this->chatConversationsSupportsColumn('department') &&
            empty($conversation->department)
        ) {
            
            
            $conversation->department = $department;
            $updated = true;
        }

        if (
            $assignedAgentId &&
            $this->chatConversationsSupportsColumn('assigned_to') &&
            empty($conversation->assigned_to)
        ) {
            
            
            $conversation->assigned_to = $assignedAgentId;
            $updated = true;
        }

        if ($updated) {
            $conversation->save();
        }

        return $updated;
    }

    private function handleSupportEscalation(Chat $conversation, ChatMessage $chatMessage, ?string $department, User $reporter): void
    {
        if (empty($department)) {
            return;
        }

        if (!empty($conversation->assigned_to)) {
            $this->notifySupportAgent($conversation, (int) $conversation->assigned_to, $chatMessage, $department, $reporter);

            return;
        }

        $this->openSupportTicket($conversation, $department, $chatMessage, $reporter);
    }

    private function notifySupportAgent(Chat $conversation, int $agentId, ChatMessage $chatMessage, string $department, User $reporter): void
    {
        $tokens = UserFcmToken::query()
            ->where('user_id', $agentId)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (empty($tokens)) {
            return;
        }

        $senderName = $chatMessage->sender?->name ?? $reporter->name ?? __('أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ ');
        $messagePreview = $chatMessage->message ?? __('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط£آ  أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ±.');

        $response = NotificationService::sendFcmNotification(
            $tokens,
            __('أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ³أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط£آ أ¢â€‌ع©ط¢â€  :name', ['name' => $senderName]),
            Str::limit($messagePreview, 120),
            'support_chat_assignment',
            [
                'conversation_id' => $conversation->id,
                'item_offer_id' => $conversation->item_offer_id,
                'department' => $department,
                'assigned_to' => $agentId,
                'message_id' => $chatMessage->id,
                'message_type' => $chatMessage->message_type,
            ]
        );

        if (is_array($response) && ($response['error'] ?? false)) {
            \Log::warning('ApiController: Failed to notify support agent via FCM', [
                'agent_id' => $agentId,
                'conversation_id' => $conversation->id,
                'message' => $response['message'] ?? null,
                'code' => $response['code'] ?? null,
            ]);
        }

    }

    private function openSupportTicket(Chat $conversation, string $department, ChatMessage $chatMessage, User $reporter): DepartmentTicket
    {
        return DepartmentTicket::firstOrCreate(
            [
                'chat_conversation_id' => $conversation->id,
                'department' => $department,
                'status' => DepartmentTicket::STATUS_OPEN,
            ],
            [
                'subject' => sprintf('أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ³أ¢â€¢ع¾ط·آ± #%d أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢â€¢أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾أ¢â€¢آ£أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط£آ¨أ¢â€‌ع©ط¢â€ ', $conversation->id),
                'description' => $this->buildSupportTicketDescription($chatMessage, $reporter),
                'reporter_id' => $reporter->id,
            ]
        );
    }

    private function buildSupportTicketDescription(ChatMessage $chatMessage, User $reporter): string
    {
        $senderName = $chatMessage->sender?->name ?? $reporter->name ?? __('أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ ');
        $messagePreview = $chatMessage->message
            ? Str::limit($chatMessage->message, 160)
            : __('أ¢â€¢ع¾ط·آ²أ¢â€‌ع©ط£آ  أ¢â€‌ع©ط¢ظ¾أ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط·آµ أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ³أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ°أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£ع¾أ¢â€‌ع©ط¢â€  أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ± أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€¢طŒأ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط·آ±.');

        return sprintf(
            'أ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€‌ع©ط£آ أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ²أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ  %s أ¢â€¢ع¾ط·آ«أ¢â€‌ع©ط¢â€ أ¢â€¢ع¾أ¢â€‌آ¤أ¢â€¢ع¾ط·آ« أ¢â€‌ع©ط£آ أ¢â€¢ع¾ط·آµأ¢â€¢ع¾ط·آ¯أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ³أ¢â€¢ع¾ط·آ± أ¢â€¢ع¾ط·آ´أ¢â€¢ع¾ط¢آ»أ¢â€‌ع©ط£آ¨أ¢â€¢ع¾ط¢آ»أ¢â€¢ع¾ط·آ±. أ¢â€¢ع¾ط·ع¾أ¢â€¢ع¾ط¢آ«أ¢â€¢ع¾أ¢â€“â€™ أ¢â€¢ع¾أ¢â€“â€™أ¢â€¢ع¾أ¢â€‌â€ڑأ¢â€¢ع¾ط·آ¯أ¢â€‌ع©ط¢â€‍أ¢â€¢ع¾ط·آ±: %s',
            $senderName,
            $messagePreview
        );
    }


    private function extractMessageIdsFromRequest(Request $request): Collection
    {
        $ids = collect();

        $bulkIds = $request->input('message_ids');

        if (is_array($bulkIds)) {
            foreach ($bulkIds as $id) {
                if (is_numeric($id)) {
                    $ids->push((int) $id);
                }
            }
        }

        if ($request->filled('message_id') && is_numeric($request->input('message_id'))) {
            $ids->push((int) $request->input('message_id'));
        }

        return $ids
            ->filter(static fn ($id) => is_int($id) && $id > 0)
            ->unique()
            ->values();
    }

    private function resolveAuthorizedMessages(Collection $messageIds, User $user, ?int $conversationId = null): Collection
    {
        if ($messageIds->isEmpty()) {
            return collect();
        }

        $messages = ChatMessage::with('conversation')
            ->whereIn('id', $messageIds->all())
            ->get()
            ->keyBy(static fn (ChatMessage $message) => (int) $message->id);

        if ($messages->count() !== $messageIds->count()) {
            ResponseService::errorResponse('One or more messages not found', null, 404);
        }

        if ($conversationId !== null) {
            $mismatched = $messages->first(static function (ChatMessage $message) use ($conversationId) {
                return (int) $message->conversation_id !== $conversationId;
            });

            if ($mismatched) {
                ResponseService::validationError('One or more messages do not belong to the provided conversation.');
            }
        }

        $conversationIds = $messages->pluck('conversation_id')
            ->filter()
            ->map(static fn ($id) => (int) $id)
            ->unique();

        if ($conversationIds->isNotEmpty()) {
            $authorizedConversationIds = Chat::whereIn('id', $conversationIds->all())
                ->whereHas('participants', function ($query) use ($user) {
                    $query->where('users.id', $user->id);
                })
                ->pluck('id')
                ->map(static fn ($id) => (int) $id);

            $unauthorized = $conversationIds->diff($authorizedConversationIds);

            if ($unauthorized->isNotEmpty()) {
                ResponseService::errorResponse('You are not allowed to update this message', null, 403);
            }
        }

        return $messages;
    }

    private function formatMessageUpdateResponse(Collection $messages)
    {
        if ($messages->count() <= 1) {
            return $messages->first();
        }

        return $messages->values();
    }


    private function isGeoDisabledCategory(int $categoryId): bool
    {
        return in_array($categoryId, $this->geoDisabledCategoryIds(), true);
    }

    private function isProductLinkRequiredCategory(int $categoryId): bool
    {
        return $this->shouldRequireProductLink($categoryId);
    }


    private function geoDisabledCategoryIds(): array
    {
        if ($this->geoDisabledCategoryCache !== null) {
            return $this->geoDisabledCategoryCache;
        }

        $raw = CachingService::getSystemSettings('geo_disabled_categories');
        $ids = $this->parseCategoryIdList($raw);

        $departmentService = app(DepartmentReportService::class);
        $alwaysDisabled = array_merge(
            $departmentService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_SHEIN),
            $departmentService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_COMPUTER),
            $departmentService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_STORE),
        );

        $normalized = [];


        foreach (array_merge($ids, $alwaysDisabled, [295]) as $value) {
            if (! is_int($value)) {
                if (is_numeric($value)) {
                    $value = (int) $value;
                } else {
                    continue;
                }


            }

             if ($value > 0) {
                $normalized[$value] = $value;
            }
        }
        return $this->geoDisabledCategoryCache = array_values($normalized);

    }


    private function productLinkRequiredCategoryIds(): array
    {
        if ($this->productLinkRequiredCategoryCache !== null) {
            return $this->productLinkRequiredCategoryCache;
        }

        $sections = $this->productLinkRequiredSections();


        if ($sections === []) {
            return $this->productLinkRequiredCategoryCache = [];
        }

        $ids = [];


        foreach ($sections as $section) {
            $ids = array_merge(
                $ids,
                $this->departmentReportService->resolveCategoryIds($section)
            );
        }

        $ids = array_filter($ids, static fn ($id) => is_int($id) && $id > 0);

        return $this->productLinkRequiredCategoryCache = array_values(array_unique($ids));
    }


    private function shouldRequireProductLink(?int $categoryId): bool
    {
        if ($categoryId === null) {
            return false;
        }

        if ($this->isGeoDisabledCategory($categoryId)) {
            return false;
        }


        $section = $this->resolveSectionByCategoryId($categoryId);

        if ($section === null) {
            return false;
        }

        $normalizedSection = strtolower($section);

        if (in_array($normalizedSection, [
            DepartmentReportService::DEPARTMENT_SHEIN,
            DepartmentReportService::DEPARTMENT_COMPUTER,
            DepartmentReportService::DEPARTMENT_STORE,
        ], true)) {
            return false;
        }

        return in_array($normalizedSection, $this->productLinkRequiredSections(), true);
    
    }


    private function productLinkRequiredSections(): array
    {
        if ($this->productLinkRequiredSectionCache !== null) {
            return $this->productLinkRequiredSectionCache;
        }

        $raw = CachingService::getSystemSettings('product_link_required_categories');
        $sections = [];

        $interfaceMap = array_change_key_case(config('cart.interface_map', []), CASE_LOWER);
        $interfaceMap = array_map(
            static fn ($value) => is_string($value) ? strtolower($value) : $value,
            $interfaceMap
        );
        $validSections = array_map('strtolower', config('cart.departments', []));

        $consume = function (mixed $value) use (&$sections, &$consume, $interfaceMap, $validSections): void {
            if ($value === null) {
                return;
            }

            if (is_int($value) || is_float($value)) {
                $section = $this->resolveSectionByCategoryId((int) $value);
                if ($section !== null && strtolower($section) === DepartmentReportService::DEPARTMENT_SHEIN) {
                    $sections[] = DepartmentReportService::DEPARTMENT_SHEIN;
                }
                return;
            }

            if (is_string($value)) {
                $trimmed = trim($value);
                if ($trimmed === '') {
                    return;
                }

                try {
                    $decoded = json_decode($trimmed, true, 512, JSON_THROW_ON_ERROR);
                    if ($decoded !== null && $decoded !== $trimmed) {
                        $consume($decoded);
                        return;
                    }
                } catch (Throwable) {
                    // ignore malformed JSON strings
                }

                if (preg_match_all('/\d+/', $trimmed, $matches) && isset($matches[0])) {
                    foreach ($matches[0] as $match) {
                        $consume((int) $match);
                    }
                }

                $normalized = strtolower($trimmed);
                if (isset($interfaceMap[$normalized]) && is_string($interfaceMap[$normalized])) {
                    $normalized = strtolower($interfaceMap[$normalized]);
                }

                if (in_array($normalized, $validSections, true)) {
                    $sections[] = $normalized;
                }
                return;
            }

            if (is_iterable($value)) {
                foreach ($value as $entry) {
                    $consume($entry);
                }
            }
        };

        $consume($raw);

        $sections = array_values(array_unique(array_filter(
            $sections,
            static fn ($section) => is_string($section) && in_array($section, $validSections, true)
        )));

        if ($sections === []) {
            $sections = [DepartmentReportService::DEPARTMENT_SHEIN];
        }

        return $this->productLinkRequiredSectionCache = $sections;
    }




    private function parseCategoryIdList(mixed $raw): array
    {
        $resolved = [];

        $consume = function (mixed $value) use (&$resolved, &$consume): void {
            if ($value === null) {
                return;
            }

            if (is_int($value) || is_float($value)) {
                $int = (int) $value;
                if ($int > 0) {
                    $resolved[] = $int;
                }
                return;
            }

            if (is_string($value)) {
                $trimmed = trim($value);
                if ($trimmed === '') {
                    return;
                }

                try {
                    $decoded = json_decode($trimmed, true, 512, JSON_THROW_ON_ERROR);
                    if ($decoded !== null && $decoded !== $trimmed) {
                        $consume($decoded);
                        return;
                    }
                } catch (Throwable) {
                    // ignore malformed JSON strings
                }

                if (preg_match_all('/\d+/', $trimmed, $matches)) {
                    foreach ($matches[0] as $match) {
                        $int = (int) $match;
                        if ($int > 0) {
                            $resolved[] = $int;
                        }
                    }
                }
                return;
            }

            if (is_iterable($value)) {
                foreach ($value as $entry) {
                    $consume($entry);
                }
            }
        };

        $consume($raw);

        return array_values(array_unique(array_filter(
            $resolved,
            static fn ($id) => is_int($id) && $id > 0
        )));
    }


    private function resolveSectionByCategoryId(?int $categoryId): ?string
    {
        if (empty($categoryId)) {
            return null;
        }

        foreach ($this->getDepartmentCategoryMap() as $section => $categoryIds) {
            if (in_array($categoryId, $categoryIds, true)) {
                return $section;
            }
        }

        return null;
    }

    /**
     * Resolve the reporting department for a given category id.
     */
    private function resolveReportDepartment(?int $categoryId): ?string
    {
        if (empty($categoryId)) {
            return null;
        }

        $map = [
            DepartmentReportService::DEPARTMENT_SHEIN =>
                $this->departmentReportService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_SHEIN),
            DepartmentReportService::DEPARTMENT_COMPUTER =>
                $this->departmentReportService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_COMPUTER),
            DepartmentReportService::DEPARTMENT_STORE =>
                $this->departmentReportService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_STORE),
            DepartmentReportService::DEPARTMENT_SERVICES =>
                $this->departmentReportService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_SERVICES),
        ];

        foreach ($map as $department => $categoryIds) {
            if (in_array($categoryId, $categoryIds, true)) {
                return $department;
            }
        }

        return null;
    }


    private function resolveInitialItemStatus(User $user, ?string $section): string
    {
        if ($this->shouldAutoApproveSection($section) || $this->shouldSkipReviewForVerifiedUser($user)) {
            return 'approved';
        }

        return 'review';
    }

    private function shouldSkipReviewForVerifiedUser(User $user): bool
    {
        if (! $this->hasVerifiedIndividualPrivileges($user)) {
            return false;
        }

        $limit = (int) config('items.auto_approve_verified_max_per_hour', 10);

        if ($limit > 0) {
            $recentCount = Item::query()
                ->where('user_id', $user->id)
                ->where('created_at', '>=', now()->subHour())
                ->count();

            if ($recentCount >= $limit) {
                return false;
            }
        }

        return true;
    }

    private function hasVerifiedIndividualPrivileges(User $user): bool
    {
        $eligibleTypes = [
            User::ACCOUNT_TYPE_CUSTOMER,
            User::ACCOUNT_TYPE_REAL_ESTATE,
        ];

        return in_array($user->account_type, $eligibleTypes, true) && $user->hasActiveVerification();
    }

    private function shouldAutoApproveSection(?string $section): bool
    {
        if ($section === null) {
            return false;
        }

        $autoApproved = array_filter(
            (array) config('delegates.auto_approve_departments', [])
        );

        return in_array($section, $autoApproved, true);
    }


    private function getDepartmentCategoryMap(): array
    {
        if ($this->departmentCategoryMap === []) {
            $this->departmentCategoryMap = [
                DepartmentReportService::DEPARTMENT_SHEIN => $this->departmentReportService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_SHEIN),
                DepartmentReportService::DEPARTMENT_COMPUTER => $this->departmentReportService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_COMPUTER),
                DepartmentReportService::DEPARTMENT_STORE => $this->departmentReportService->resolveCategoryIds(DepartmentReportService::DEPARTMENT_STORE),

            ];
        }

        return $this->departmentCategoryMap;
    }

    /**
     * Filter the item select columns to include only those that are available on the table.
     */
    private function filterItemSelectColumns(array $columns): array
    {
        $availability = $this->getItemColumnAvailability();

        return array_values(array_filter($columns, static function ($column) use ($availability) {
            $expression = $column;

            $aliasPosition = stripos($expression, ' as ');
            if ($aliasPosition !== false) {
                $expression = substr($expression, 0, $aliasPosition);
            }

            $expression = trim($expression);

            if ($expression === '') {
                return false;
            }

            if (! str_contains($expression, '.')) {
                return true;
            }

            [$table, $columnName] = explode('.', $expression, 2);

            if (strcasecmp($table, 'items') !== 0) {
                return true;
            }

            return isset($availability[$columnName]);
        }));
    }


    /**
     * Generate a fallback email address for phone-based signups.
     */
    private function generatePhoneSignupEmail(?string $countryCode, ?string $mobile): string
    {
        $numericCountryCode = preg_replace('/\D+/', '', (string) $countryCode);
        $numericMobile = preg_replace('/\D+/', '', (string) $mobile);

        $identifier = trim($numericCountryCode . $numericMobile);

        if ($identifier === '') {
            $identifier = 'user_' . Str::uuid()->toString();
        } else {
            $identifier = 'user_' . $identifier;
        }

        $baseIdentifier = Str::lower($identifier);
        $domain = 'phone.marib.app';
        $email = $baseIdentifier . '@' . $domain;

        if (! User::where('email', $email)->exists()) {
            return $email;
        }

        do {
            $email = $baseIdentifier . '_' . Str::lower(Str::random(6)) . '@' . $domain;
        } while (User::where('email', $email)->exists());

        return $email;
    }



    /**
     * Retrieve and cache the available columns on the items table.
     */
    private function getItemColumnAvailability(): array
    {
        if (self::$itemColumnAvailability !== null) {
            return self::$itemColumnAvailability;
        }

        $columns = [];

        try {
            if (Schema::hasTable('items')) {
                foreach (Schema::getColumnListing('items') as $column) {
                    $columns[$column] = true;
                }
            }
        } catch (Throwable $exception) {
            Log::warning('Failed to inspect items table columns.', [
                'exception' => $exception->getMessage(),
            ]);
        }

        return self::$itemColumnAvailability = $columns;
    }

    /**
     * Return the given category id plus all its descendants.
     */
    protected function collectCategoryTreeIds(int $rootCategoryId): array
    {
        $categories = Category::select('id', 'parent_category_id')->get();

        $children = [];
        foreach ($categories as $category) {
            $parentKey = $category->parent_category_id ?? 0;
            $children[$parentKey][] = $category->id;
        }

        $ids = [];
        $stack = [$rootCategoryId];

        while (! empty($stack)) {
            $current = array_pop($stack);

            if (in_array($current, $ids, true)) {
                continue;
            }

            $ids[] = $current;

            if (isset($children[$current])) {
                foreach ($children[$current] as $childId) {
                    $stack[] = $childId;
                }
            }
        }

        return $ids;
    }
}



