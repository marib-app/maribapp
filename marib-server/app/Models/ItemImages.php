<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class ItemImages extends Model {
    use HasFactory;

    protected $fillable = [
        'item_id',
        'image',
        'thumbnail_url',
        'detail_image_url',

    ];

    public function getImageAttribute($image) {
        if (!empty($image)) {
            return url(Storage::url($image));
        }
        return $image;
    }

    public function getThumbnailUrlAttribute($image)
    {
        return !empty($image) ? url(Storage::url($image)) : null;
    }

    public function getDetailImageUrlAttribute($image)
    {
        return !empty($image) ? url(Storage::url($image)) : null;
    }

}
