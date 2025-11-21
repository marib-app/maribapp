<?php

namespace App\Services;

use App\Data\Notifications\NotificationIntent;
use App\Enums\NotificationDispatchStatus;
use App\Enums\NotificationType;
use App\Models\Setting;
use App\Models\User;
use App\Models\UserFcmToken;
use Google\Client;
use Google\Exception;
use GuzzleHttp\Client as GuzzleClient;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

class NotificationService {


    public static function validateHttpV1Configuration(): array
    {
        $projectId = self::resolveFirebaseProjectId();

        if (empty($projectId)) {
            return [
                'error'   => true,
                'message' => 'Firebase project ID is not configured.',
            ];
        }

        $serviceFileValue = self::resolveServiceFileValue();

        if (empty($serviceFileValue)) {
            return [
                'error'   => true,
                'message' => 'FCM service account file is not configured.',
            ];
        }

        $serviceFilePath = self::resolveServiceFilePath($serviceFileValue);

        if (empty($serviceFilePath)) {
            \Log::error('NotificationService: FCM service account file path could not be resolved.', [
                'stored_value' => $serviceFileValue,
            ]);


            return [
                'error'   => true,
                'message' => 'FCM service account file is missing or unreadable.',
            ];
        }

        if (config('services.fcm.verify_ssl')) {
            $caBundleInfo = self::resolveCaBundleConfiguration();

            if ($caBundleInfo['path'] === null) {
                \Log::warning('NotificationService: No readable CA bundle configured for FCM; relying on system store.', [
                    'configured_path' => $caBundleInfo['configured_raw'],
                    'default_path' => $caBundleInfo['default_path'],
                ]);
            } elseif (
                $caBundleInfo['used_fallback']
                && is_string($caBundleInfo['configured_raw'])
                && trim($caBundleInfo['configured_raw']) !== ''
            ) {
                \Log::info('NotificationService: Falling back to default CA bundle for FCM.', [
                    'configured_path' => $caBundleInfo['configured_raw'],
                    'resolved_path' => $caBundleInfo['path'],
                    'default_path' => $caBundleInfo['default_path'],
                ]);
                

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
    public static function sendFcmNotification(array $registrationIDs, string|null $title = '', string|null $message = '', string $type = "default", array $customBodyFields = [], bool $skipDispatch = false): string|array|bool {
        if ($registrationIDs === []) {
            \Log::info('NotificationService: No registration IDs provided, skipping notification dispatch.', [
                'type' => $type,
            ]);

            return [
                'error'   => false,
                'message' => 'No registration tokens supplied.',
                'data'    => [],
            ];
        }

        $dispatched = false;
        if (!$skipDispatch) {
            try {
                $userIds = self::resolveUserIdsFromTokens($registrationIDs);
                if (!empty($userIds)) {
                    $dispatchService = app(NotificationDispatchService::class);
                    foreach ($userIds as $userId) {
                        $intent = new NotificationIntent(
                            userId: $userId,
                            type: self::normalizeLegacyType($type),
                            title: $title ?? '',
                            body: $message ?? '',
                            deeplink: self::resolveLegacyDeeplink($customBodyFields),
                            entity: self::resolveLegacyEntity($type, $customBodyFields),
                            entityId: self::resolveLegacyEntityId($customBodyFields),
                            data: array_merge($customBodyFields, [
                                'legacy_type' => $type,
                            ]),
                            meta: [
                                'legacy_bridge' => true,
                                'provided_tokens' => count($registrationIDs),
                            ],
                        );
                        $result = $dispatchService->dispatch($intent, true);
                        if ($result->status === NotificationDispatchStatus::Queued) {
                            $dispatched = true;
                        }
                    }

                    if ($dispatched) {
                        \Log::info('NotificationService: notifications queued via dispatch, continuing with direct FCM for compatibility.');
                    }
                }
            } catch (Throwable $exception) {
                \Log::warning('NotificationService: Failed to route notification through dispatch service, falling back to direct FCM.', [
                    'type' => $type,
                    'error' => $exception->getMessage(),
                ]);
            }
        }

        try {
            $configurationState = self::validateHttpV1Configuration();

            if ($configurationState['error']) {
                \Log::error('NotificationService: Invalid FCM configuration detected', [
                    'message' => $configurationState['message'] ?? null,
                ]);

                return $configurationState;
            }

            $project_id = self::resolveFirebaseProjectId();

            if (empty($project_id)) {


                \Log::error('NotificationService: Firebase project ID is not configured');
                return [
                    'error'   => true,
                    'message' => 'FCM configurations are not configured.'
                ];
            }

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

            [$reservedFields, $customBodyFields] = self::splitReservedBodyFields($customBodyFields);

            $notificationBody = is_string($message) ? trim($message) : $message;
            if (empty($notificationBody) && !empty($customBodyFields['message_preview'])) {
                $notificationBody = $customBodyFields['message_preview'];
            }
            if (empty($notificationBody) && !empty($customBodyFields['message'])) {
                $notificationBody = $customBodyFields['message'];
            }

            $sanitizedBodyFields = self::sanitizeDataPayload($customBodyFields);
            if (!empty($reservedFields['data']) && is_array($reservedFields['data'])) {
                $sanitizedBodyFields = array_merge(
                    $sanitizedBodyFields,
                    self::sanitizeDataPayload($reservedFields['data'])
                );
            }

            $navigationPayload = [
                'deeplink' => $sanitizedBodyFields['deeplink'] ?? $customBodyFields['deeplink'] ?? null,
                'click_action' => $sanitizedBodyFields['click_action'] ?? $customBodyFields['click_action'] ?? null,
            ];

            $ttl = self::resolveTtlValue($reservedFields['ttl_seconds'] ?? $reservedFields['ttl'] ?? null);
            $androidPriority = strtoupper((string) ($reservedFields['priority'] ?? 'HIGH'));
            if (!in_array($androidPriority, ['HIGH', 'NORMAL'], true)) {
                $androidPriority = 'HIGH';
            }

            $dataWithTitle = [
                ...$sanitizedBodyFields,
                "title" => $title,
                "body"  => $notificationBody,
                "type"  => $type,
                "notification_type" => $type,

                


            ];
            // \Log::info('NotificationService: Starting to send notifications', [
            //     'total_devices' => count($registrationIDs)
            // ]);
            

            $failedDeliveries = [];
            $invalidatedTokens = [];
            $successfulDeliveries = 0;

            $verifySsl = (bool) config('services.fcm.verify_ssl', true);
            $caBundleInfo = [
                'path' => null,
                'configured_raw' => null,
                'default_path' => null,
                'used_fallback' => false,
            ];

            if ($verifySsl) {
                $caBundleInfo = self::resolveCaBundleConfiguration();

                if ($caBundleInfo['path'] === null) {
                    \Log::warning('NotificationService: Proceeding without explicit CA bundle for curl; relying on system store.', [
                        'configured_path' => $caBundleInfo['configured_raw'],
                        'default_path' => $caBundleInfo['default_path'],
                    ]);
                } elseif (
                    $caBundleInfo['used_fallback']
                    && is_string($caBundleInfo['configured_raw'])
                    && trim($caBundleInfo['configured_raw']) !== ''
                ) {
                    \Log::info('NotificationService: Using default CA bundle for curl FCM requests.', [
                        'configured_path' => $caBundleInfo['configured_raw'],
                        'resolved_path' => $caBundleInfo['path'],
                        'default_path' => $caBundleInfo['default_path'],
                    ]);
                }
            }


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
                    "body"  => $notificationBody,
                ];




                $data = [
                        "message" => [
                            "token"        => $registrationID,
                            "data"         => self::convertToStringRecursively($dataWithTitle),
                            "notification" => $notificationPayload,
                            "android"      => [
                            "priority"       => $androidPriority,
                            "ttl"            => $ttl,
                            "direct_boot_ok" => true,
                            "notification"   => [
                                "title" => $title,
                                "body"  => $notificationBody,
            
                            ],
                        ],

                        "apns"         => [
                            "headers" => [
                                "apns-priority" => "10",
                                "apns-push-type" => "alert",
                            
                            ],
                            "payload" => [
                                "aps" => [
                                    "alert" => [
                                        "title" => $title,
                                        "body"  => $notificationBody,
                                    ],
                                    "sound"             => "default",
                                    "content-available" => 1,
                                ],
                            ],
                        ],
                        "webpush"      => [
                            "headers" => [
                                "Urgency" => "high",
                            ],
                            "notification" => [
                                "title" => $title,
                                "body"  => $notificationBody,
                            ],
                        ],
                    ],
                ];
                if (!empty($reservedFields['collapse_key'])) {
                    $data['message']['android']['collapse_key'] = $reservedFields['collapse_key'];
                    $data['message']['apns']['headers']['apns-collapse-id'] = $reservedFields['collapse_key'];
                }

                if (!empty($navigationPayload['deeplink'])) {
                    $data['message']['apns']['payload']['deeplink'] = $navigationPayload['deeplink'];
                    $data['message']['webpush']['fcm_options']['link'] = $navigationPayload['deeplink'];


                }

                if (!empty($navigationPayload['click_action'])) {
                    $data['message']['apns']['payload']['click_action'] = $navigationPayload['click_action'];
                    $data['message']['android']['notification']['click_action'] = $navigationPayload['click_action'];


                }

                $label = $reservedFields['analytics_label'] ?? null;
                if (!$label) {
                    $label = $type === 'chat' ? 'chat_message' : 'general_notification';
                }

                $data['message']['fcm_options'] = [
                    'analytics_label' => $label,
                ];
                

                if (is_string($platformType) && strcasecmp($platformType, 'Android') === 0) {
                    $data['message']['android']['notification']['title'] = $title;
                    $data['message']['android']['notification']['body'] = $notificationBody;
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
                curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);

                curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, $verifySsl ? 2 : 0);
                curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, $verifySsl);

                if ($verifySsl && !empty($caBundleInfo['path'])) {
                    curl_setopt($ch, CURLOPT_CAINFO, $caBundleInfo['path']);
                }

                
                curl_setopt($ch, CURLOPT_POSTFIELDS, $encodedData);

                // Execute post
                $result = curl_exec($ch);
                $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                $curlError = curl_error($ch);
                

                curl_close($ch);


                // \Log::info('NotificationService: FCM API response', [
                //     'device_index' => $index + 1,
                //     'http_code' => $httpCode,
                //     'curl_error' => $curlError ?: 'None',
                //     'response_preview' => substr($result, 0, 200)
                // ]);

                if ($result === false) {

                    \Log::error('NotificationService: Curl failed', [
                        'error' => $curlError,
                        'device_index' => $index + 1,
                        'token' => $registrationID,
                    ]);

                    $failedDeliveries[] = [
                        'token' => $registrationID,
                        'http_code' => $httpCode,
                        'message' => $curlError ?: 'Curl request failed.',
                    ];

                    continue;
                }

                $decodedResponse = json_decode($result, true);
                $hasResponseError = $httpCode >= 400 || (is_array($decodedResponse) && isset($decodedResponse['error']));

                if ($hasResponseError) {
                    $errorStatus = data_get($decodedResponse, 'error.status');
                    $errorMessage = data_get($decodedResponse, 'error.message', 'FCM request failed.');
                    $errorCode = self::extractFcmErrorCode(is_array($decodedResponse) ? $decodedResponse : []);

                    \Log::warning('NotificationService: FCM request failed', [
                        'token' => $registrationID,
                        'http_code' => $httpCode,
                        'status' => $errorStatus,
                        'error_code' => $errorCode,
                        'message' => $errorMessage,
                    ]);

                    $tokenRemoved = false;

                    if (self::shouldRemoveFcmToken($errorCode, $errorStatus)) {
                        self::removeInvalidFcmToken($registrationID);
                        $tokenRemoved = true;

                        $invalidatedTokens[] = [
                            'token' => $registrationID,
                            'http_code' => $httpCode,
                            'status' => $errorStatus,
                            'error_code' => $errorCode,
                        ];
                    }

                    if ($tokenRemoved && self::shouldIgnoreFcmFailure($errorCode, $errorStatus, $httpCode)) {
                        \Log::info('NotificationService: Ignoring FCM failure for invalid token', [
                            'token' => $registrationID,
                            'http_code' => $httpCode,
                            'status' => $errorStatus,
                            'error_code' => $errorCode,
                        ]);

                        continue;
                    }

                    $failedDeliveries[] = [
                        'token' => $registrationID,
                        'http_code' => $httpCode,
                        'status' => $errorStatus,
                        'error_code' => $errorCode,
                        'message' => $errorMessage,
                        'response' => $decodedResponse,
                    ];

                    continue;
                }
                $successfulDeliveries++;

            }

            $hasFailures = count($failedDeliveries) > 0;

            if ($hasFailures) {
                return [
                    'error' => true,
                    'message' => 'One or more notifications failed to send.',
                    'code' => $failedDeliveries[0]['http_code'] ?? null,
                    'details' => $failedDeliveries,
                    'data' => [
                        'success' => $successfulDeliveries,
                        'failure' => count($failedDeliveries),
                        'failures' => $failedDeliveries,
                        'invalid_tokens_removed' => $invalidatedTokens,
                        'invalid_tokens_removed_count' => count($invalidatedTokens),
                    ],
                ];
            }

            if ($successfulDeliveries === 0) {
                return [
                    'error' => true,
                    'message' => 'No notifications were delivered to any devices.',
                    'code' => 404,
                    'details' => [],
                    'data' => [
                        'success' => 0,
                        'failure' => 0,
                        'invalid_tokens_removed' => $invalidatedTokens,
                        'invalid_tokens_removed_count' => count($invalidatedTokens),
                    ],
                ];
            }


            \Log::info('NotificationService: FCM notification process completed successfully');
            return [
                'error'   => false,
                'message' => "Success",
                'code'    => 200,
                'data'    => [
                    'success' => $successfulDeliveries,
                    'failure' => 0,
                    'invalid_tokens_removed' => $invalidatedTokens,
                    'invalid_tokens_removed_count' => count($invalidatedTokens),

                ],
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
            
            $file_name = self::resolveServiceFileValue();
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
            $file_path = self::resolveServiceFilePath($file_name);
            \Log::info('NotificationService: Service file path check', [
                'file_name' => $file_name,
                'file_path' => $file_path,
                'file_exists' => !empty($file_path) && file_exists($file_path)
            ]);

            if (empty($file_path) || !file_exists($file_path)) {

                \Log::error('NotificationService: FCM Service File not found at path', [
                    'computed_path' => $file_path,
                    'stored_value' => $file_name,
                
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
                $caBundleInfo = self::resolveCaBundleConfiguration();

                if (!empty($caBundleInfo['path'])) {
                    $httpClientOptions['verify'] = $caBundleInfo['path'];

                    if (
                        $caBundleInfo['used_fallback']
                        && is_string($caBundleInfo['configured_raw'])
                        && trim($caBundleInfo['configured_raw']) !== ''
                    ) {
                        \Log::info('NotificationService: Using default CA bundle for FCM access token request.', [
                            'configured_path' => $caBundleInfo['configured_raw'],
                            'resolved_path' => $caBundleInfo['path'],
                            'default_path' => $caBundleInfo['default_path'],
                        ]);
                    }
                } else {
                    \Log::warning('NotificationService: No readable CA bundle configured for FCM access token; relying on system store.', [
                        'configured_path' => $caBundleInfo['configured_raw'],
                        'default_path' => $caBundleInfo['default_path'],
                    ]);

                }
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




    protected static function extractFcmErrorCode(array $response): ?string
    {
        $details = data_get($response, 'error.details');

        if (!is_array($details)) {
            return null;
        }

        foreach ($details as $detail) {
            if (!is_array($detail)) {
                continue;
            }

            $errorCode = $detail['errorCode'] ?? null;

            if (!empty($errorCode)) {
                return (string) $errorCode;
            }
        }

        return null;
    }

    protected static function shouldRemoveFcmToken(?string $errorCode, ?string $status): bool
    {
        if ($errorCode && in_array($errorCode, ['UNREGISTERED'], true)) {
            return true;
        }

        if ($status && in_array($status, ['NOT_FOUND'], true)) {
            return true;
        }

        return false;
    }


    protected static function shouldIgnoreFcmFailure(?string $errorCode, ?string $status, ?int $httpCode): bool
    {
        $invalidErrorCodes = ['UNREGISTERED'];
        $invalidStatuses = ['NOT_FOUND'];
        $invalidHttpCodes = [404, 410];

        if ($errorCode && in_array($errorCode, $invalidErrorCodes, true)) {
            return true;
        }

        if ($status && in_array($status, $invalidStatuses, true)) {
            return true;
        }

        if ($httpCode && in_array($httpCode, $invalidHttpCodes, true)) {
            return true;
        }

        return false;
    }


    protected static function removeInvalidFcmToken(string $token): void
    {
        UserFcmToken::where('fcm_token', $token)->delete();
    }

    
    protected static function splitReservedBodyFields(array $payload): array
    {
        $reservedKeys = [
            'ttl_seconds',
            'ttl',
            'priority',
            'collapse_key',
            'analytics_label',
            'data',
        ];

        $reserved = [];
        foreach ($reservedKeys as $key) {
            if (array_key_exists($key, $payload)) {
                $reserved[$key] = $payload[$key];
                unset($payload[$key]);
            }
        }

        return [$reserved, $payload];
    }

    protected static function resolveTtlValue(int|string|null $ttlSeconds): string
    {
        if (is_string($ttlSeconds)) {
            $trimmed = trim($ttlSeconds);

            if (preg_match('/^\d+s$/', $trimmed)) {
                return $trimmed;
            }

            if (is_numeric($trimmed)) {
                $ttlSeconds = (int) $trimmed;
            } else {
                $ttlSeconds = null;
            }
        }

        $seconds = is_numeric($ttlSeconds) ? (int) $ttlSeconds : null;
        if ($seconds === null || $seconds <= 0) {
            $configured = config('services.fcm.ttl', '3600s');
            if (is_string($configured) && preg_match('/^\d+s$/', $configured)) {
                return $configured;
            }

            $seconds = (int) config('services.fcm.ttl_seconds', 3600);
        }

        $seconds = max(1, min($seconds, 2419200));

        return sprintf('%ss', $seconds);
    }

    protected static function sanitizeDataPayload(array $payload): array
    {
        $reservedKeys = [
            'message_type' => 'msg_type',
        ];

        $sanitized = [];

        foreach ($payload as $key => $value) {
            $normalizedKey = $reservedKeys[$key] ?? $key;

            if (is_array($value)) {
                $sanitized[$normalizedKey] = self::sanitizeDataPayload($value);
                continue;
            }

            $sanitized[$normalizedKey] = $value;
        }

        return $sanitized;
    }



    public static function convertToStringRecursively($data, string $prefix = ''): array
    {
        $flattenedArray = [];
        
        foreach ($data as $key => $value) {
            $normalizedKey = $prefix === ''
                ? (string) $key
                : (string) $prefix . '_' . (string) $key;

            if (is_array($value)) {
                foreach (self::convertToStringRecursively($value, $normalizedKey) as $childKey => $childValue) {
                    $flattenedArray[$childKey] = $childValue;
                }
            
            } elseif (is_null($value)) {
                $flattenedArray[$normalizedKey] = '';
            } elseif (is_bool($value)) {
                $flattenedArray[$normalizedKey] = $value ? '1' : '0';
            
            } else {
                $flattenedArray[$normalizedKey] = (string) $value;
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

    protected static function resolveCaBundleConfiguration(): array
    {
        $configuredRaw = config('services.fcm.ca_path');
        $configured = is_string($configuredRaw) ? trim($configuredRaw) : '';
        $defaultPath = base_path('certs/cacert.pem');

        $candidates = [];

        if ($configured !== '') {
            $candidates[] = $configured;
        }

        if (!in_array($defaultPath, $candidates, true)) {
            $candidates[] = $defaultPath;
        }

        foreach ($candidates as $index => $candidate) {
            $resolved = self::resolveAbsolutePath($candidate);

            if (is_file($resolved) && is_readable($resolved)) {
                return [
                    'path' => $resolved,
                    'configured_raw' => $configuredRaw,
                    'default_path' => $defaultPath,
                    'used_fallback' => $index > 0,
                ];
            }
        }

        return [
            'path' => null,
            'configured_raw' => $configuredRaw,
            'default_path' => $defaultPath,
            'used_fallback' => false,
        ];
    }


    protected static function resolveServiceFilePath(?string $serviceFileValue): ?string
    {
        if (empty($serviceFileValue)) {
            return null;
        }

        $candidateValues = [];

        $trimmedValue = trim($serviceFileValue);

        if (self::isAbsolutePath($trimmedValue) && is_file($trimmedValue) && is_readable($trimmedValue)) {
            return realpath($trimmedValue) ?: $trimmedValue;
        }

        if (Str::startsWith($trimmedValue, ['http://', 'https://'])) {
            $parsedPath = parse_url($trimmedValue, PHP_URL_PATH);

            if (!empty($parsedPath)) {
                $trimmedValue = ltrim($parsedPath, '/');
            }
        }

        $normalizedValue = ltrim($trimmedValue, '/');

        foreach (['storage/', 'public/', 'app/public/'] as $prefix) {
            if (Str::startsWith($normalizedValue, $prefix)) {
                $normalizedValue = Str::after($normalizedValue, $prefix);
            }
        }

        if (!empty($normalizedValue)) {


            $disksToInspect = ['public'];

            $defaultDisk = config('filesystems.default');
            if (is_string($defaultDisk) && $defaultDisk !== '' && !in_array($defaultDisk, $disksToInspect, true)) {
                $disksToInspect[] = $defaultDisk;
            }

            if (!in_array('local', $disksToInspect, true)) {
                $disksToInspect[] = 'local';
            }

            foreach ($disksToInspect as $disk) {
                try {
                    $resolved = Storage::disk($disk)->path($normalizedValue);

                    if (!in_array($resolved, $candidateValues, true)) {
                        $candidateValues[] = $resolved;
                    }
                } catch (Throwable $exception) {
                    \Log::notice('NotificationService: Failed to resolve service file path via storage disk.', [
                        'disk' => $disk,
                        'stored_value' => $serviceFileValue,
                        'normalized_value' => $normalizedValue,
                        'exception' => $exception->getMessage(),
                    ]);
                }
            }


            try {
                $defaultStoragePath = Storage::path($normalizedValue);

                if (!in_array($defaultStoragePath, $candidateValues, true)) {
                    $candidateValues[] = $defaultStoragePath;
                }
            
            
            } catch (Throwable $exception) {
                \Log::notice('NotificationService: Failed to resolve service file path via default storage disk.', [
                    'stored_value' => $serviceFileValue,
                    'normalized_value' => $normalizedValue,
                    'exception' => $exception->getMessage(),
                ]);
            }

            foreach ([
                storage_path('app/' . $normalizedValue),
                storage_path('app/public/' . $normalizedValue),
                public_path('storage/' . $normalizedValue),
            ] as $pathCandidate) {
                if (!in_array($pathCandidate, $candidateValues, true)) {
                    $candidateValues[] = $pathCandidate;
                }
            }
        }

        $candidateValues[] = $trimmedValue;

        foreach ($candidateValues as $path) {
            if (empty($path)) {
                continue;
            }

            if (is_file($path) && is_readable($path)) {
                return realpath($path) ?: $path;
            }
        }

        return null;
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

    protected static function resolveUserIdsFromTokens(array $registrationIDs): array
    {
        if ($registrationIDs === []) {
            return [];
        }

        return UserFcmToken::query()
            ->whereIn('fcm_token', $registrationIDs)
            ->pluck('user_id')
            ->filter()
            ->unique()
            ->map(fn ($id) => (int) $id)
            ->values()
            ->all();
    }

    protected static function normalizeLegacyType(string $type): NotificationType|string
    {
        $normalized = strtolower(trim($type));
        $map = [
            'order-status-update' => NotificationType::OrderStatus,
            'wallet' => NotificationType::WalletAlert,
            'wallet_withdrawal' => NotificationType::WalletAlert,
            'payment' => NotificationType::WalletAlert,
            'payment.request' => NotificationType::PaymentRequest,
            'action-request' => NotificationType::ActionRequest,
        ];

        foreach ($map as $needle => $case) {
            if ($normalized === strtolower($needle)) {
                return $case;
            }
        }

        foreach (NotificationType::cases() as $case) {
            if ($case->value === $normalized || $case->value === $type) {
                return $case;
            }
        }

        return $type;
    }

    protected static function resolveLegacyDeeplink(array $customBodyFields): string
    {
        return (string) ($customBodyFields['deeplink'] ?? $customBodyFields['click_action'] ?? 'marib://inbox');
    }

    protected static function resolveLegacyEntity(string $type, array $customBodyFields): string
    {
        return (string) ($customBodyFields['entity'] ?? $customBodyFields['context'] ?? $type ?? 'notification');
    }

    protected static function resolveLegacyEntityId(array $customBodyFields): string|int|null
    {
        return $customBodyFields['entity_id']
            ?? $customBodyFields['order_id']
            ?? $customBodyFields['transaction_id']
            ?? $customBodyFields['manual_payment_request_id']
            ?? $customBodyFields['payment_transaction_id']
            ?? null;
    }

    protected static function resolveFirebaseProjectId(): ?string
    {
        $projectId = Setting::query()
            ->where('name', 'firebase_project_id')
            ->value('value');

        if (is_string($projectId) && trim($projectId) !== '') {
            return trim($projectId);
        }

        $candidates = [
            config('services.fcm.project_id'),
            env('FIREBASE_PROJECT_ID'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        return null;

    }
    protected static function resolveServiceFileValue(): ?string
    {
        $settingValue = Setting::query()
            ->where('name', 'service_file')
            ->value('value');

        if (is_string($settingValue) && trim($settingValue) !== '') {
            return trim($settingValue);
        }

        $candidates = [
            config('services.fcm.service_file'),
            env('FIREBASE_SERVICE_ACCOUNT'),
            env('GOOGLE_APPLICATION_CREDENTIALS'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return trim($candidate);
            }
        }

        return null;
    }

}
