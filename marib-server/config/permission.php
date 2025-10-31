<?php

return [

    'models' => [
        'permission' => Spatie\Permission\Models\Permission::class,
        'role' => Spatie\Permission\Models\Role::class,
    ],

    'table_names' => [
        'roles' => 'roles',
        'permissions' => 'permissions',
        'model_has_permissions' => 'model_has_permissions',
        'model_has_roles' => 'model_has_roles',
        'role_has_permissions' => 'role_has_permissions',
    ],

    'column_names' => [
        'role_pivot_key' => null,        // default 'role_id'
        'permission_pivot_key' => null,  // default 'permission_id'
        'model_morph_key' => 'model_id',
        'team_foreign_key' => 'team_id',
    ],

    'register_permission_check_method' => true,
    'register_octane_reset_listener' => false,

    // فرق الفريق (غير مفعّل)
    'teams' => false,

    // إن كنت تستخدم Passport client credentials
    'use_passport_client_credentials' => false,

    'display_permission_in_exception' => false,
    'display_role_in_exception' => false,

    // Wildcards للـ permissions (معطّل افتراضيًا)
    'enable_wildcard_permission' => false,
    // 'permission.wildcard_permission' => Spatie\Permission\WildcardPermission::class,

    /* Cache-specific settings */
    'cache' => [
        // يُنصح بخفض المدة أثناء التطوير لو احتجت
        'expiration_time' => \DateInterval::createFromDateString('24 hours'),

        // مفتاح الكاش
        'key' => 'spatie.permission.cache',

        /*
         * اختر متجر الكاش عبر ENV لتجنّب مشاكل التفريغ مع drivers لا تدعم tags.
         * محليًا:
         *   PERMISSION_CACHE_STORE=array
         * إنتاجيًا (مستحسن):
         *   PERMISSION_CACHE_STORE=redis
         * null يعني استخدام default من config/cache.php كما هو.
         */
        'store' => env('PERMISSION_CACHE_STORE', null),
    ],
];
