<?php

namespace App\Http\Controllers;

use App\Models\ManualBank;
use App\Models\Setting;
use App\Models\PaymentConfiguration;
use App\Services\CachingService;
use App\Services\FileService;
use App\Services\HelperService;
use App\Services\ResponseService;
use File;
use App\Support\Currency;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Validator;
use Throwable;

class SettingController extends Controller {
    private string $uploadFolder;
    private string $manualBankUploadFolder;
    private string $eastYemenBankUploadFolder;

    protected $helperService;

    public function __construct() {
        $this->uploadFolder = 'settings';
        $this->manualBankUploadFolder = 'manual-banks';
        $this->eastYemenBankUploadFolder = 'payment-configurations/east-yemen-bank';

    }

    public function index() {
        ResponseService::noPermissionThenRedirect('settings-update');
        return view('settings.index');
    }

    public function page() {
        ResponseService::noPermissionThenSendJson('settings-update');
        $type = last(request()->segments());
        $settings = CachingService::getSystemSettings()->toArray();
        if (!empty($settings['place_api_key']) && config('app.demo_mode')) {
            $settings['place_api_key'] = "**************************";
        }
        $stripe_currencies = ["USD", "AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZN", "BAM", "BBD", "BDT", "BGN", "BIF", "BMD", "BND", "BOB", "BRL", "BSD", "BWP", "BYN", "BZD", "CAD", "CDF", "CHF", "CLP", "CNY", "COP", "CRC", "CVE", "CZK", "DJF", "DKK", "DOP", "DZD", "EGP", "ETB", "EUR", "FJD", "FKP", "GBP", "GEL", "GIP", "GMD", "GNF", "GTQ", "GYD", "HKD", "HNL", "HTG", "HUF", "IDR", "ILS", "INR", "ISK", "JMD", "JPY", "KES", "KGS", "KHR", "KMF", "KRW", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LSL", "MAD", "MDL", "MGA", "MKD", "MMK", "MNT", "MOP", "MRO", "MUR", "MVR", "MWK", "MXN", "MYR", "MZN", "NAD", "NGN", "NIO", "NOK", "NPR", "NZD", "PAB", "PEN", "PGK", "PHP", "PKR", "PLN", "PYG", "QAR", "RON", "RSD", "RUB", "RWF", "SAR", "SBD", "SCR", "SEK", "SGD", "SHP", "SLE", "SOS", "SRD", "STD", "SZL", "THB", "TJS", "TOP", "TTD", "TWD", "TZS", "UAH", "UGX", "UYU", "UZS", "VND", "VUV", "WST", "XAF", "XCD", "XOF", "XPF", "YER", "ZAR", "ZMW"];
        $languages = CachingService::getLanguages();
        return view('settings.' . $type, compact('settings', 'type', 'languages', 'stripe_currencies'));
    }

    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('settings-update');
        $validator = Validator::make($request->all(), [
            "company_name"           => "nullable",
            "company_email"          => "nullable",
            "company_tel1"           => "nullable",
            "company_tel2"           => "nullable",
            "company_address"        => "nullable",
            "invoice_company_name"   => "nullable|string",
            "invoice_company_tax_id" => "nullable|string",
            "invoice_company_address" => "nullable|string",
            "invoice_company_email"  => "nullable|email",
            "invoice_company_phone"  => "nullable|string",
            "invoice_footer_note"    => "nullable|string",
            "default_language"       => "nullable",
            "currency_symbol"        => "nullable",
            "android_version"        => "nullable",
            "play_store_link"        => "nullable",
            "ios_version"            => "nullable",
            "app_store_link"         => "nullable",
            "maintenance_mode"       => "nullable",
            "force_update"           => "nullable",
            "number_with_suffix"     => "nullable",
            "firebase_project_id"    => "nullable",
            "service_file"           => "nullable",
            "favicon_icon"           => "nullable|mimes:jpg,jpeg,png,svg|max:2048",
            "company_logo"           => "nullable|mimes:jpg,jpeg,png,svg|max:4096",
            "login_image"            => "nullable|mimes:jpg,jpeg,png,svg|max:4096",
            "watermark_image"        => 'nullable|mimes:jpg,jpeg,png|max:2048',
            "invoice_logo"           => "nullable|mimes:jpg,jpeg,png,svg|max:4096",
            "web_theme_color"        => "nullable",
            "place_api_key"          => "nullable",
            "header_logo"            => "nullable|mimes:jpg,jpeg,png,svg|max:2048",
            "footer_logo"            => "nullable|mimes:jpg,jpeg,png,svg|max:2048",
            "placeholder_image"      => "nullable|mimes:jpg,jpeg,png,svg|max:2048",
            "footer_description"     => "nullable",
            "usage_guide"            => "nullable",
            "google_map_iframe_link" => "nullable",
            "default_latitude"       => "nullable",
            "default_longitude"      => "nullable",
            "instagram_link"         => "nullable|url",
            "x_link"                 => "nullable|url",
            "facebook_link"          => "nullable|url",
            "linkedin_link"          => "nullable|url",
            "pinterest_link"         => "nullable|url",
            "whatsapp_number"        => "nullable|string",
            "whatsapp_number_shein"  => "nullable",
            "whatsapp_enabled_shein" => "nullable|boolean",
            "whatsapp_number_computer"  => "nullable",
            "whatsapp_enabled_computer" => "nullable|boolean",

            "whatsapp_otp_enabled" => "nullable|boolean",
            "whatsapp_otp_message_new_user" => "nullable|string",
            "whatsapp_otp_message_forgot_password" => "nullable|string",
            "whatsapp_otp_token" => "nullable|string",

            "department_return_policy_shein" => "nullable|string",
            "department_return_policy_computer" => "nullable|string",
            "orders_deposit_shein_ratio" => "nullable|numeric|min:0|max:100",
            "orders_deposit_shein_minimum" => "nullable|numeric|min:0",
            "orders_deposit_computer_ratio" => "nullable|numeric|min:0|max:100",
            "orders_deposit_computer_minimum" => "nullable|numeric|min:0",
            "orders_shein_settlement_reminder_pre_ship_hours" => "nullable|numeric|min:0",
            "orders_shein_settlement_reminder_arrival_hours" => "nullable|numeric|min:0",
            "orders_computer_settlement_reminder_pre_ship_hours" => "nullable|numeric|min:0",
            "orders_computer_settlement_reminder_arrival_hours" => "nullable|numeric|min:0",

            "deep_link_text_file"    => "nullable",
            "deep_link_json_file"    => "nullable|mimes:json|max:2048",
            "mobile_authentication"    => "nullable",
            "google_authentication"    => "nullable",
            "email_authentication"    => "nullable",
            "apple_authenticaion"    =>"nullable",
        ]);
        
        // Only check authentication methods if any of them are present in the request
        // This avoids validation errors when updating other settings like terms and privacy policy
        if (
            $request->has('mobile_authentication') || 
            $request->has('google_authentication') || 
            $request->has('email_authentication') || 
            $request->has('apple_authentication')
        ) {
            if (
                !$request->mobile_authentication &&
                !$request->google_authentication &&
                !$request->email_authentication &&
                !$request->apple_authentication
            ) {
                ResponseService::validationError('At least one authentication method must be enabled.');
            }
        }
        
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {

            $inputs = $request->input();

            if (array_key_exists('currency_symbol', $inputs)) {
                $inputs['currency_symbol'] = Currency::preferredSymbol(
                    $inputs['currency_symbol'],
                    $inputs['currency_code'] ?? config('app.currency')
                );
            }


            unset($inputs['_token']);
            if (config('app.demo_mode')) {
                unset($inputs['place_api_key']);
            }

            foreach ([
                'department_return_policy_shein',
                'department_return_policy_computer',
            ] as $policyKey) {
                if (array_key_exists($policyKey, $inputs)) {
                    $inputs[$policyKey] = $this->normalizeReturnPolicy($inputs[$policyKey]);
                }
            }




            foreach ([
                'orders_deposit_shein_ratio',
                'orders_deposit_computer_ratio',
            ] as $ratioKey) {
                if (array_key_exists($ratioKey, $inputs) && $inputs[$ratioKey] !== null && $inputs[$ratioKey] !== '') {
                    $value = (float) $inputs[$ratioKey];

                    if ($value > 1) {
                        $value = $value / 100;
                    }

                    $inputs[$ratioKey] = $value;
                }
            }




            foreach ([
                'whatsapp_enabled_shein',
                'whatsapp_enabled_computer',
                'whatsapp_otp_enabled',
            ] as $booleanKey) {
                if (array_key_exists($booleanKey, $inputs)) {
                    $inputs[$booleanKey] = filter_var($inputs[$booleanKey], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ? 1 : 0;
                }
            }


            $data = [];
            foreach ($inputs as $key => $input) {
                $data[] = [
                    'name'  => $key,
                    'value' => $input,
                    'type'  => 'string'
                ];
            }

            //Fetch old images to delete from the disk storage
            $oldSettingFiles = Setting::whereIn('name', collect($request->files)->keys())->get();
            foreach ($request->files as $key => $file) {

                if (in_array($key, ['deep_link_json_file', 'deep_link_text_file'])) {
                    $filenameMap = [
                        'deep_link_json_file' => 'assetlinks.json',
                        'deep_link_text_file' => 'apple-app-site-association',
                    ];

                    $filename = $filenameMap[$key];
                    $fileContents = File::get($file);
                    $publicWellKnownPath = public_path('.well-known');
                    if (!File::exists($publicWellKnownPath)) {
                        File::makeDirectory($publicWellKnownPath, 0755, true);
                    }

                    $publicPath = public_path('.well-known/' . $filename);
                    File::put($publicPath, $fileContents);

                    $rootPath = base_path('.well-known/' . $filename);
                    File::put($rootPath, $fileContents);
                } else {

                    $data[] = [
                        'name'  => $key,
                        'value' =>FileService::compressAndUpload($request->file($key),$this->uploadFolder),
                        // 'value' => $request->file($key)->store($this->uploadFolder, 'public'),
                        'type'  => 'file'
                    ];
                    $oldFile = $oldSettingFiles->first(function ($old) use ($key) {
                        return $old->name == $key;
                    });
                    if (!empty($oldFile)) {
                        FileService::delete($oldFile->getRawOriginal('value'));
                    }
                }
            }
            Setting::upsert($data, 'name', ['value']);

            if (!empty($inputs['company_name']) && config('app.name') != $inputs['company_name']) {
                HelperService::changeEnv([
                    'APP_NAME' => $inputs['company_name'],
                ]);
            }
            CachingService::removeCache(config('constants.CACHE.SETTINGS'));
            ResponseService::successResponse('Settings Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Setting Controller -> store");
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function updateFirebaseSettings(Request $request) {
        ResponseService::noPermissionThenSendJson('settings-update');
        $validator = Validator::make($request->all(), [
            'apiKey'            => 'required',
            'authDomain'        => 'required',
            'projectId'         => 'required',
            'storageBucket'     => 'required',
            'messagingSenderId' => 'required',
            'appId'             => 'required',
            'measurementId'     => 'required',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $inputs = $request->input();
            unset($inputs['_token']);
            $data = [];
            foreach ($inputs as $key => $input) {
                $data[] = [
                    'name'  => $key,
                    'value' => $input,
                    'type'  => 'string'
                ];
            }
            Setting::upsert($data, 'name', ['value']);
            //Service worker file will be copied here
            File::copy(public_path('assets/dummy-firebase-messaging-sw.js'), public_path('firebase-messaging-sw.js'));
            $serviceWorkerFile = file_get_contents(public_path('firebase-messaging-sw.js'));

            $updateFileStrings = [
                "apiKeyValue"            => '"' . $request->apiKey . '"',
                "authDomainValue"        => '"' . $request->authDomain . '"',
                "projectIdValue"         => '"' . $request->projectId . '"',
                "storageBucketValue"     => '"' . $request->storageBucket . '"',
                "messagingSenderIdValue" => '"' . $request->messagingSenderId . '"',
                "appIdValue"             => '"' . $request->appId . '"',
                "measurementIdValue"     => '"' . $request->measurementId . '"'
            ];
            $serviceWorkerFile = str_replace(array_keys($updateFileStrings), $updateFileStrings, $serviceWorkerFile);
            file_put_contents(public_path('firebase-messaging-sw.js'), $serviceWorkerFile);
            CachingService::removeCache(config('constants.CACHE.SETTINGS'));
            ResponseService::successResponse('Settings Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Settings Controller -> updateFirebaseSettings");
            ResponseService::errorResponse();
        }
    }

    public function paymentSettingsIndex() {
        ResponseService::noPermissionThenRedirect('settings-update');
        
        $manualBanks = ManualBank::orderBy('display_order')->orderBy('name')->get();

        $eastYemenGateway = PaymentConfiguration::firstOrNew([
            'payment_method' => 'east_yemen_bank',
        ]);

        return view('settings.payment-gateway', compact('manualBanks', 'eastYemenGateway'));
    }

    public function paymentSettingsStore(Request $request) {
        ResponseService::noPermissionThenSendJson('settings-update');
        $validator = Validator::make($request->all(), [
            'name'             => 'required|string|max:255',
            'beneficiary_name' => 'nullable|string|max:255',
            'note'             => 'nullable|string',
            'display_order'    => 'nullable|integer|min:0',
            'status'           => 'nullable|boolean',
            'logo'             => 'nullable|mimes:jpg,jpeg,png,svg|max:4096',
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $data = $validator->validated();
            $data['status'] = $request->boolean('status');
            $data['display_order'] = $data['display_order'] ?? 0;

            if ($request->hasFile('logo')) {
                $data['logo_path'] = FileService::compressAndUpload($request->file('logo'), $this->manualBankUploadFolder);
            }

            ManualBank::create($data);

            ResponseService::successResponse('Manual bank saved successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Settings Controller -> paymentSettingsStore");
            ResponseService::errorResponse();
        }
            }

    public function paymentSettingsUpdate(Request $request, ManualBank $manualBank) {
        ResponseService::noPermissionThenSendJson('settings-update');
        $validator = Validator::make($request->all(), [
            'name'             => 'required|string|max:255',
            'beneficiary_name' => 'nullable|string|max:255',
            'note'             => 'nullable|string',
            'display_order'    => 'nullable|integer|min:0',
            'status'           => 'nullable|boolean',
            'logo'             => 'nullable|mimes:jpg,jpeg,png,svg|max:4096',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $data = $validator->validated();
            $data['status'] = $request->boolean('status');
            $data['display_order'] = $data['display_order'] ?? 0;

            if ($request->hasFile('logo')) {
                $data['logo_path'] = FileService::compressAndReplace(
                    $request->file('logo'),
                    $this->manualBankUploadFolder,
                    $manualBank->getRawOriginal('logo_path')
                );
            }
                        $manualBank->update($data);


            ResponseService::successResponse('Manual bank updated successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Settings Controller -> paymentSettingsUpdate");
            ResponseService::errorResponse();
        }
    }

    public function paymentSettingsDestroy(ManualBank $manualBank) {
        ResponseService::noPermissionThenSendJson('settings-update');

        try {
            FileService::delete($manualBank->getRawOriginal('logo_path'));
            $manualBank->delete();

            ResponseService::successResponse('Manual bank deleted successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Settings Controller -> paymentSettingsDestroy");
            
            ResponseService::errorResponse();
        }
    }





    
    public function eastYemenBankSettings(Request $request)
    {
        ResponseService::noPermissionThenSendJson('settings-update');

        $validator = Validator::make($request->all(), [
            'app_key'       => 'nullable|string|max:255',
            'api_key'       => 'nullable|string|max:255',
            'display_name'  => 'nullable|string|max:255',
            'note'          => 'nullable|string',
            'status'        => 'nullable|boolean',
            'logo'          => 'nullable|mimes:jpg,jpeg,png,svg|max:4096',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $data = $validator->validated();

            $configuration = PaymentConfiguration::firstOrNew([
                'payment_method' => 'east_yemen_bank',
            ]);


            $status = $request->boolean('status');

            $appKeyInput = array_key_exists('app_key', $data) ? trim((string) $data['app_key']) : null;
            $apiKeyInput = array_key_exists('api_key', $data) ? trim((string) $data['api_key']) : null;
            $displayNameInput = array_key_exists('display_name', $data) ? trim((string) $data['display_name']) : null;
            $noteInput = array_key_exists('note', $data) ? trim((string) $data['note']) : null;


            $appKeyInput = $appKeyInput === '' ? null : $appKeyInput;
            $apiKeyInput = $apiKeyInput === '' ? null : $apiKeyInput;
            $displayNameInput = $displayNameInput === '' ? null : $displayNameInput;
            $noteInput = $noteInput === '' ? null : $noteInput;


            $finalAppKey = $appKeyInput ?? $configuration->secret_key;
            $finalApiKey = $apiKeyInput ?? $configuration->api_key;

            if (
                $status && (
                    ($finalAppKey === null || $finalAppKey === '') ||
                    ($finalApiKey === null || $finalApiKey === '')
                )
            ) {
                ResponseService::validationError('App key and API key are required when enabling the East Yemen Bank gateway.');
            }

            $updateData = [
                'api_key'      => $finalApiKey ?? '',
                'secret_key'   => $finalAppKey ?? '',
                'status'       => $status,
                'display_name' => $displayNameInput,
                'note'         => $noteInput,
            ];


            if ($request->hasFile('logo')) {
                $updateData['logo_path'] = $configuration->exists
                    ? FileService::compressAndReplace(
                        $request->file('logo'),
                        $this->eastYemenBankUploadFolder,
                        $configuration->getRawOriginal('logo_path')
                    )
                    : FileService::compressAndUpload(
                        $request->file('logo'),
                        $this->eastYemenBankUploadFolder
                    );
            }

            $configuration->fill($updateData);

            if (!$configuration->exists) {
                $configuration->webhook_secret_key = '';
            }

            $configuration->save();

            $configuration->refresh();

            ResponseService::successResponse(
                'East Yemen Bank gateway settings updated successfully',
                null,
                [
                    'gateway' => [
                        'status'       => (bool) $configuration->status,
                        'app_key'      => $configuration->secret_key ?? '',
                        'api_key'      => $configuration->api_key ?? '',
                        'display_name' => $configuration->display_name ?? '',
                        'note'         => $configuration->note ?? '',
                        'logo_url'     => $configuration->logo_url,
                        'logo_path'    => $configuration->logo_path,
                        'updated_at'   => $configuration->updated_at?->toIso8601String(),
                    ],
                ]
            );




        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'Settings Controller -> eastYemenBankSettings');
            ResponseService::errorResponse('Unable to update East Yemen Bank gateway settings.');
        }
    }


    private function normalizeReturnPolicy($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $lines = preg_split("/(\r\n|\r|\n)/", (string) $value);

        $normalizedLines = array_map(static function ($line) {
            $line = trim($line);
            return preg_replace('/[ \t]{2,}/u', ' ', $line);
        }, $lines);

        $normalized = implode(PHP_EOL, $normalizedLines);

        return trim($normalized);
    }



    
    // public function syatemStatusIndex() {
    //     return view('settings.system-status');
    // }
    public function toggleStorageLink()
    {
        $linkPath = public_path('storage');

        if (file_exists($linkPath)) {
            if (is_link($linkPath)) {
                if (unlink($linkPath)) {
                    return back()->with('message', 'Storage link unlinked successfully!');
                } else {
                    return back()->with('message', 'Failed to unlink the storage link.');
                }
            } else {
                return back()->with('message', 'Storage link is not a symbolic link.');
            }
        } else {
            Artisan::call('storage:link');

            if (file_exists($linkPath) && is_link($linkPath)) {
                return back()->with('message', 'Storage link created successfully!');
            } else {
                return back()->with('message', 'Failed to create the storage link.');
            }
        }
    }


    public function systemStatus() {
        $linkPath = public_path('storage');
        $isLinked = file_exists($linkPath) && is_dir($linkPath);

        return view('settings.system-status', compact('isLinked'));
    }

    public function fileManagerSettingStore(Request $request) {
        ResponseService::noPermissionThenSendJson('settings-update');
        $validator = Validator::make($request->all(), [
            "file_manager"    => "required|in:public,s3",
            "S3_aws_access_key_id"    => "required_if:file_manager,==,s3",
            "s3_aws_secret_access_key"    => "required_if:file_manager,==,s3",
            "s3_aws_default_region"    => "required_if:file_manager,==,s3",
            "s3_aws_bucket"    => "required_if:file_manager,==,s3",
            "s3_aws_url"    => "required_if:file_manager,==,s3",
        ]);
        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            $inputs = $request->input();
            $data = [];
            foreach ($inputs as $key => $input) {
                $data[] = [
                    'name'  => $key,
                    'value' => $input,
                    'type'  => 'string'
                ];
            }
            Setting::upsert($data, 'name', ['value']);

            $env = [
                'FILESYSTEM_DISK' => $inputs['file_manager'],
                'AWS_ACCESS_KEY_ID' => $inputs['S3_aws_access_key_id'] ?? null,
                'AWS_SECRET_ACCESS_KEY' => $inputs['s3_aws_secret_access_key'] ?? null,
                'AWS_DEFAULT_REGION' => $inputs['s3_aws_default_region'] ?? null,
                'AWS_BUCKET' => $inputs['s3_aws_bucket'] ?? null,
                'AWS_URL' => $inputs['s3_aws_url'] ?? null,
            ];

            HelperService::changeEnv($env);
            ResponseService::successResponse('File Manager Settings Updated Successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "Setting Controller -> fileManagerSettingStore");
            ResponseService::errorResponse('Something Went Wrong');
        }
    }
    public function paystackPaymentSucesss(){
        return view('payment.paystack');
    }
    public function phonepePaymentSucesss(){
        return view('payment.phonepe');
    }
    public function webPageURL($slug){
        $appStoreLink = CachingService::getSystemSettings('app_store_link');
        $playStoreLink = CachingService::getSystemSettings('play_store_link');
        $appName = CachingService::getSystemSettings('company_name');
        return view('deep-link.deep_link',compact('appStoreLink','playStoreLink','appName'));
    }
}
