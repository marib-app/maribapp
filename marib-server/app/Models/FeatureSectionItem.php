<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FeatureSectionItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'feature_section_id',
        'item_id',
        'position',
    ];

    public function section()
    {
        return $this->belongsTo(FeatureSection::class, 'feature_section_id');
    }

    public function item()
    {
        return $this->belongsTo(Item::class);
    }
}
