<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Storage;

class Referral extends Model
{
    use HasFactory;

    protected $fillable = [
        'referrer_id',
        'referred_user_id',
        'challenge_id',
        'points'
    ];

    public function referrer()
    {
        return $this->belongsTo(User::class, 'referrer_id');
    }
    
    public function referred_user()
    {
        return $this->belongsTo(User::class, 'referred_user_id');
    }
    
    public function challenge()
    {
        return $this->belongsTo(Challenge::class);
    }
    

    public function attempts()
    {
        return $this->hasMany(ReferralAttempt::class);
    }

}
