<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OTP extends Model
{
    use HasFactory;
    protected $table = 'otps'; // <-- make sure this is correct
    protected $fillable = [
        'phone',
        'otp',
        'expires_at',
        'type'
    ];

    // تحديد الـ timestamps (created_at و updated_at)
    public $timestamps = true;
}
