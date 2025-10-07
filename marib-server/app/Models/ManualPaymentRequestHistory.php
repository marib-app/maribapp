<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class ManualPaymentRequestHistory extends Model
{
    use HasFactory;

    protected $table = 'manual_payment_request_histories';

    protected $fillable = [
        'manual_payment_request_id',
        'user_id',
        'status',
        'note',
        'meta',
    ];

    protected $casts = [
        'meta' => 'array',
    ];

    public function manualPaymentRequest(): BelongsTo
    {
        return $this->belongsTo(ManualPaymentRequest::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }



        public function getAttachmentUrlAttribute(): ?string
    {
        $path = data_get($this->meta, 'attachment_path');

        if (empty($path)) {
            return null;
        }

        if (filter_var($path, FILTER_VALIDATE_URL)) {
            return $path;
        }

        $disk = data_get($this->meta, 'attachment_disk', 'public');

        try {
            $storage = Storage::disk($disk);
        } catch (\Throwable) {
            $storage = Storage::disk(config('filesystems.default'));
        }

        if ($storage->exists($path)) {
            return $storage->url($path);
        }

        if (Storage::exists($path)) {
            return Storage::url($path);
        }

        return $path;
    }
}