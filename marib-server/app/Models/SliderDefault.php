<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;


class SliderDefault extends Model
{
    use HasFactory;

    public const STATUS_ACTIVE = 'active';
    public const STATUS_INACTIVE = 'inactive';

    protected $fillable = [
        'interface_type',
        'image_path',
        'status',
    ];

    protected $casts = [
        'interface_type' => 'string',
        'image_path'     => 'string',
        'status'         => 'string',
    ];

    protected $appends = [
        'image_url',
    ];

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function getImageUrlAttribute(): ?string
    {
        if (! $this->image_path) {
            return null;
        }

        $storageUrl = Storage::url($this->image_path);

        if (Str::startsWith($storageUrl, ['http://', 'https://'])) {
            return $storageUrl;
        }

        $normalizedPath = '/' . ltrim($storageUrl, '/');

        if (! app()->runningInConsole()) {
            $request = request();

            if ($request && $request->getHost()) {
                return rtrim($request->getSchemeAndHttpHost(), '/') . $normalizedPath;
            }
        }

        return URL::to($normalizedPath);
    }
}