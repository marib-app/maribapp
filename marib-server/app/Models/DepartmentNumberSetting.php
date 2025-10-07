<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DepartmentNumberSetting extends Model
{
    public const DEFAULT_DEPARTMENT = 'default';

    protected $fillable = [
        'department',
        'legal_numbering_enabled',
        'order_prefix',
        'invoice_prefix',
        'next_order_number',
        'next_invoice_number',
    ];

    protected $casts = [
        'legal_numbering_enabled' => 'bool',
        'next_order_number' => 'int',
        'next_invoice_number' => 'int',
    ];
}