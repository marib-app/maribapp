<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use JsonException;

class ServiceCustomFieldValue extends Model
{
    use HasFactory;

    protected $fillable = [
        'service_id',
        'service_custom_field_id',
        'value',
    ];

    public function service()
    {
        return $this->belongsTo(Service::class);
    }

    public function customField()
    {
        return $this->belongsTo(ServiceCustomField::class, 'service_custom_field_id');
    }

    public function getValueAttribute($value)
    {
        try {
            $decoded = json_decode($value, true, 512, JSON_THROW_ON_ERROR);
            return is_array($decoded) ? array_values($decoded) : $decoded;
        } catch (JsonException) {
            return $value;
        }
    }
}