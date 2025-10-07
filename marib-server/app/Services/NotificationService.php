<?php

namespace App\Services;
use App\Models\User;

use App\Models\Setting;
use App\Models\UserFcmToken;
use App\Models\WifiCode;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use Google\Client;
use Google\Exception;
use Illuminate\Support\Facades\Storage;
use GuzzleHttp\Client as GuzzleClient;

use Throwable;

class NotificationService {


    public static function validateHttpV1Configuration(): array
    {
        $projectIdSetting = Setting::select('value')->where('name', 'firebase_project_id')->first();

        if (empty($projectIdSetting?->value)) {
            return [
                'error'   => true,
                'message' => 'Firebase project ID is not configured.',
            ];
        }

        $serviceFileSetting = Setting::select('value')->where('name', 'service_file')->first();

        if (empty($serviceFileSetting?->value)) {
            return [
                'error'   => true,
                'message' => 'FCM service account file is not configured.',
            ];
        }

        $serviceFilePath = Storage::disk('public')->path($serviceFileSetting->value);

        if (!is_file($serviceFilePath) || !is_readable($serviceFilePath)) {
            return [
                'error'   => true,
                'message' => 'FCM service account file is missing or unreadable.',
            ];
        }

        if (config('services.fcm.verify_ssl')) {
            $caBundlePath = config('services.fcm.ca_path');

            if (empty($caBundlePath)) {
                \Log::error('NotificationService: FCM CA bundle path is not configured.');

                return [
                    'error'   => true,
                    'message' => 'FCM CA bundle path is not configured.',
                ];
            }

            $resolvedCaBundlePath = self::resolveAbsolutePath($caBundlePath);

            if (!is_file($resolvedCaBundlePath) || !is_readable($resolvedCaBundlePath)) {
                \Log::error('NotificationService: FCM CA bundle is missing or unreadable.', [
                    'path' => $resolvedCaBundlePath,
                ]);
                
                return [
                    'error'   => true,
                    'message' => 'FCM CA bundle not found at ' . $resolvedCaBundlePath,
                ];
            }
        }

        return [
            'error'   => false,
            'message' => 'FCM configuration is valid.',
        ];
    }

    /**
     * @param array $registrationIDs
     * @param string|null $title
     * @param string|null $message
     * @param string $type
     * @param array $customBodyFields
     * @return string|array|bool
     */
    public static function sendFcmNotification(array $registrationIDs, string|null $title = '', string|null $message = '', string $type = "default", array $customBodyFields = []): string|array|bool {
        try {
            // \Log::info('NotificationService: Starting FCM notification process', [
            //     'tokens_count' => count($registrationIDs),
            //     'title' => $title,
            //     'message' => $message,
            //     'type' => $type
            // ]);
            
            //TODO : Use this from caching
            $project_id = Setting::select('value')->where('name', 'firebase_project_id')->first();
            // \Log::info('NotificationService: Firebase project ID check', [
            //     'project_id_exists' => !empty($project_id),
            //     'project_id_value' => $project_id->value ?? 'NULL'
            // ]);
            
            if (empty($project_id->value)) {
                \Log::error('NotificationService: Firebase project ID is not configured');
                return [
                    'error'   => true,
                    'message' => 'FCM configurations are not configured.'
                ];
            }

            $project_id = $project_id->value;
            $url = 'https://fcm.googleapis.com/v1/projects/' . $project_id . '/messages:send';

//            $registrationIDs_chunks = array_chunk($registrationIDs, 1000);

            $access_token = self::getAccessToken();
            \Log::info('NotificationService: Access token result', [
                'success' => !$access_token['error'],
                'message' => $access_token['message'] ?? 'No message'
            ]);
            
             if ($access_token['error']) {
                \Log::error('NotificationService: Failed to get access token', $access_token);
                return $access_token;
            }
            $result = [];


            $deviceInfo = UserFcmToken::select(['platform_type', 'fcm_token'])
                ->whereIn('fcm_token', $registrationIDs)
                ->get();

            //TODO : Add this process to queue for better performance

            $navigationPayload = [
                'deeplink' => $customBodyFields['deeplink'] ?? null,
                'click_action' => $customBodyFields['click_action'] ?? null,
            ];

            $dataWithTitle = [
                ...$customBodyFields,
                "title" => $title,
                "body"  => $message,
                "type"  => $type,
            ];
            // \Log::info('NotificationService: Starting to send notifications', [
            //     'total_devices' => count($registrationIDs)
            // ]);
            
            foreach ($registrationIDs as $index => $registrationID) {
                // \Log::info('NotificationService: Processing device', [
                //     'device_index' => $index + 1,
                //     'token_preview' => substr($registrationID, 0, 20) . '...'
                // ]);
                
                $platform = $deviceInfo->first(function ($q) use ($registrationID) {
                    return $q->fcm_token == $registrationID;
                });


                $platformType = $platform?->platform_type;

                $notificationPayload = [
                    "title" => $title,
                    "body"  => $message,
                ];

                if (!empty($navigationPayload['click_action'])) {
                    $notificationPayload['click_action'] = $navigationPayload['click_action'];
                }


                $data = [
                    "message" => [
                        "token"        => $registrationID,
                        "data"         => self::convertToStringRecursively($dataWithTitle),
                        "notification" => $notificationPayload,
                        "apns"         => [
                            "headers" => [
                                "apns-priority" => "10" // Set APNs priority to 10 (high) for immediate delivery
                            ],
                            "payload" => [
                                "aps" => [
                                    "alert" => [
                                        "title" => $title,
                                        "body"  => $message,
                                    ],
                                ]
                            ]
                        ]
                    ]
                ];
                if (!empty($navigationPayload['deeplink'])) {
                    $data['message']['notification']['deeplink'] = $navigationPayload['deeplink'];
                    $data['message']['apns']['payload']['deeplink'] = $navigationPayload['deeplink'];
                    $data['message']['fcm_options']['link'] = $navigationPayload['deeplink'];
                }

                if (!empty($navigationPayload['click_action'])) {
                    $data['message']['apns']['payload']['click_action'] = $navigationPayload['click_action'];
                }

                if (is_string($platformType) && strcasecmp($platformType, 'Android') === 0) {
                    $androidNotification = [


                        "title" => $title,
                        "body"  => $message,
                    ];


                    if (!empty($navigationPayload['click_action'])) {
                        $androidNotification['click_action'] = $navigationPayload['click_action'];
                    }

                    $data['message']['android']['notification'] = $androidNotification;

                }

                $encodedData = json_encode($data);
                $headers = [
                    'Authorization: Bearer ' . $access_token['data'],
                    'Content-Type: application/json',
                ];

                $ch = curl_init();
                curl_setopt($ch, CURLOPT_URL, $url);
                curl_setopt($ch, CURLOPT_POST, true);
                curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
                curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);

                // Disabling SSL Certificate support temporarily
                curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
                curl_setopt($ch, CURLOPT_POSTFIELDS, $encodedData);

                // Execute post
                $result = curl_exec($ch);
                $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                $curlError = curl_error($ch);
                
                // \Log::info('NotificationService: FCM API response', [
                //     'device_index' => $index + 1,
                //     'http_code' => $httpCode,
                //     'curl_error' => $curlError ?: 'None',
                //     'response_preview' => substr($result, 0, 200)
                // ]);

                if (!$result) {
                    \Log::error('NotificationService: Curl failed', [
                        'error' => $curlError,
                        'device_index' => $index + 1
                    ]);
                    curl_close($ch);
                    continue;
                }
                curl_close($ch);
            }
            \Log::info('NotificationService: FCM notification process completed successfully');
            return [
                'error'   => false,
                'message' => "Success",
                'data'    => $result
            ];
        } catch (Throwable $th) {
            \Log::error('NotificationService: Exception in sendFcmNotification', [
                'error' => $th->getMessage(),
                'file' => $th->getFile(),
                'line' => $th->getLine(),
                'code' => $th->getCode(),
            
            ]);
            return [
                'error' => true,
                'message' => $th->getMessage(),
                'code' => $th->getCode(),
            ];
        
        
        }
    }

    public static function getAccessToken() {
        try {
            // \Log::info('NotificationService: Starting getAccessToken process');
            
            $file_name = Setting::select('value')->where('name', 'service_file')->first();
            // \Log::info('NotificationService: Service file check', [
            //     'service_file_exists' => !empty($file_name),
            //     'service_file_value' => $file_name->value ?? 'NULL'
            // ]);
            
            if (empty($file_name)) {
                \Log::error('NotificationService: FCM Configuration not found');
                return [
                    'error'   => true,
                    'message' => 'FCM Configuration not found'
                ];
            }
            $file_name = $file_name->value;
            $file_path = Storage::disk('public')->path($file_name);
            \Log::info('NotificationService: Service file path check', [
                'file_name' => $file_name,
                'file_path' => $file_path,
                'file_exists' => file_exists($file_path)
            ]);

            if (!file_exists($file_path)) {
                \Log::error('NotificationService: FCM Service File not found at path', [
                    'computed_path' => $file_path
                ]);
                return [
                    'error'   => true,
                    'message' => 'FCM Service File not found'
                ];
            }
            // \Log::info('NotificationService: Creating Google Client and setting auth config');
            $client = new Client();
            $client->setAuthConfig($file_path);
            $client->setScopes(['https://www.googleapis.com/auth/firebase.messaging']);



            $httpClientOptions = [];

            $verifySsl = config('services.fcm.verify_ssl', true);
            if (!$verifySsl) {
                $httpClientOptions['verify'] = false;
            } else {
                $customCaPath = config('services.fcm.ca_path');

                if (empty($customCaPath)) {
                    \Log::error('NotificationService: FCM CA bundle path is not configured.');

                    return [
                        'error'   => true,
                        'message' => 'FCM CA bundle path is not configured.',
                    ];
                }

                $resolvedCaBundlePath = self::resolveAbsolutePath($customCaPath);

                if (!is_file($resolvedCaBundlePath) || !is_readable($resolvedCaBundlePath)) {
                    $message = 'FCM CA bundle not found at ' . $resolvedCaBundlePath;
                    \Log::error('NotificationService: FCM CA bundle is missing or unreadable.', [
                        'path' => $resolvedCaBundlePath,
                    ]);

                    return [
                        'error'   => true,
                        'message' => $message,
                    ];


                }
                $httpClientOptions['verify'] = $resolvedCaBundlePath;


            }

            if (!empty($httpClientOptions)) {
                $client->setHttpClient(new GuzzleClient($httpClientOptions));
            }


            // \Log::info('NotificationService: Google Client configured successfully');

            $access_token = $client->fetchAccessTokenWithAssertion()['access_token'];
            // \Log::info('NotificationService: Access token generated successfully', [
            //     'token_length' => strlen($access_token)
            // ]);
            
            return [
                'error'   => false,
                'message' => 'Access Token generated successfully',
                'data'    => $access_token
            ];

        } catch (Exception $e) {
            \Log::error('NotificationService: Exception in getAccessToken', [
                'error' => $e->getMessage(),
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'code' => $e->getCode(),
            
            ]);
            return [
                'error' => true,
                'message' => $e->getMessage(),
                'code' => $e->getCode(),
            ];
        
        }
    }



    public static function notifyWifiBuyerCodeReady(User $user, WifiNetwork $network, WifiPlan $plan, WifiCode $code): void
    {
        $tokens = UserFcmToken::where('user_id', $user->getKey())->pluck('fcm_token')->filter()->values()->all();

        if (empty($tokens)) {
            return;
        }

        $title = __('Wi-Fi code ready');
        $message = __('Your access code for :network (:plan) is ready.', [
            'network' => $network->name,
            'plan' => $plan->name,
        ]);

        $data = [
            'wifi_network_id' => $network->getKey(),
            'wifi_plan_id' => $plan->getKey(),
            'wifi_code_id' => $code->getKey(),
            'type' => 'wifi_code',
        ];

        self::sendFcmNotification($tokens, $title, $message, 'wifi_code', $data);
    }

    public static function notifyWifiOwnerPurchase(User $owner, User $buyer, WifiNetwork $network, WifiPlan $plan, WifiCode $code): void
    {
        $tokens = UserFcmToken::where('user_id', $owner->getKey())->pluck('fcm_token')->filter()->values()->all();

        if (empty($tokens)) {
            return;
        }

        $title = __('New Wi-Fi plan sold');
        $message = __(':buyer purchased the :plan plan on :network.', [
            'buyer' => $buyer->name ?? __('A customer'),
            'plan' => $plan->name,
            'network' => $network->name,
        ]);

        $data = [
            'wifi_network_id' => $network->getKey(),
            'wifi_plan_id' => $plan->getKey(),
            'wifi_code_id' => $code->getKey(),
            'type' => 'wifi_sale',
        ];

        self::sendFcmNotification($tokens, $title, $message, 'wifi_sale', $data);
    }


    public static function convertToStringRecursively($data, &$flattenedArray = []) {
        foreach ($data as $key => $value) {
            if (is_array($value)) {
                self::convertToStringRecursively($value, $flattenedArray);
            } elseif (is_null($value)) {
                $flattenedArray[$key] = '';
            } else {
                $flattenedArray[$key] = (string)$value;
            }
        }
        return $flattenedArray;
    }

    protected static function resolveAbsolutePath(string $path): string
    {
        if (self::isAbsolutePath($path)) {
            return realpath($path) ?: $path;
        }

        $absolutePath = base_path($path);

        return realpath($absolutePath) ?: $absolutePath;
    }

    protected static function isAbsolutePath(string $path): bool
    {
        if ($path === '') {
            return false;
        }

        if (str_starts_with($path, '\\')) {
            return true;
        }




        if (str_starts_with($path, DIRECTORY_SEPARATOR)) {
            return true;
        }

        if (strlen($path) > 2 && ctype_alpha($path[0]) && $path[1] === ':' && ($path[2] === '\\' || $path[2] === '/')) {
            return true;
        }

        return false;
    
    }


}
