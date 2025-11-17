<?php

use App\Services\DepartmentReportService;

return [
    'admin_roles' => [
        'Super Admin',
        'Admin',
    ],

    'restricted_departments' => [
        DepartmentReportService::DEPARTMENT_SHEIN,
        DepartmentReportService::DEPARTMENT_COMPUTER,
    ],

    'auto_approve_departments' => [
        DepartmentReportService::DEPARTMENT_SHEIN,
        DepartmentReportService::DEPARTMENT_COMPUTER,
        DepartmentReportService::DEPARTMENT_STORE,
    ],

    'cache_prefix' => 'delegates',

    'cache_ttl' => (int) env('DELEGATE_CACHE_TTL', 120),
];
