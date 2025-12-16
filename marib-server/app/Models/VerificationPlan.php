<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VerificationPlan extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'account_type',
        'duration_days',
        'price',
        'currency',
        'is_active',
    ];

    public function payments()
    {
        return $this->hasMany(VerificationPayment::class);
    }
}
