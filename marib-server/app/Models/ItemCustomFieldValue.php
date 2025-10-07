<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use JsonException;

/**
 * @method static create(array $itemCustomFieldValues)
 * @method static insert(array $itemCustomFieldValues)
 */
class ItemCustomFieldValue extends Model {
    use HasFactory;

    protected $fillable = [
        'item_id',
        'custom_field_id',
        'value'
    ];

    public function custom_field() {
        return $this->belongsTo(CustomField::class);
    }

    public function item()
    {
        return $this->belongsTo(Item::class, 'item_id');
    }

    public function getValueAttribute($value) {
        try {
            $decoded = json_decode($value, true, 512, JSON_THROW_ON_ERROR);
            // Check if the decoded value is an array before using array_values
            if (is_array($decoded)) {
                return array_values($decoded);
            }
            return $decoded;
        } catch (JsonException) {
            return $value;
        }
    }
}
