<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Storage;

class Challenge extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'description',
        'required_referrals',
        'points_per_referral',
        'is_active'
    ];

    public function referrals()
    {
        return $this->hasMany(Referral::class);
    }
    


    public function referralAttempts()
    {
        return $this->hasMany(ReferralAttempt::class);
    }

}
