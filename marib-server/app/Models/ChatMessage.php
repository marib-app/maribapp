<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class ChatMessage extends Model
{
    use HasFactory;
    public const STATUS_SENT = 'sent';
    public const STATUS_DELIVERED = 'delivered';
    public const STATUS_READ = 'read';


    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'conversation_id',
        'sender_id',
        'message',
        'file',
        'audio',
        'status',
        'delivered_at',
        'read_at',
    ];

    protected $appends = ['message_type', 'item_offer_id'];


        /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'delivered_at' => 'datetime',
        'read_at' => 'datetime',
    ];

    protected $attributes = [
        'status' => self::STATUS_SENT,
    ];


    /**
     * The conversation the message belongs to.
     */
    public function conversation()
    {
        return $this->belongsTo(Chat::class, 'conversation_id');
    }

    /**
     * The sender of the message.
     */
    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function getFileAttribute($value)
    {
        if (!empty($value)) {
            return url(Storage::url($value));
        }

        return $value;
    }

    public function getAudioAttribute($value)
    {
        if (!empty($value)) {
            return url(Storage::url($value));
        }

        return $value;
    }

    public function getMessageTypeAttribute(): string
    {
        $message = $this->getRawOriginal('message');

        if (!empty($this->audio)) {
            return 'audio';
        }

        if (!empty($this->file) && ($message === null || $message === '')) {
            return 'file';
        }

        if (!empty($this->file) && $message !== null && $message !== '') {
            return 'file_and_text';
        }

        return 'text';
    }
    public function getItemOfferIdAttribute(): ?int
    {
        return $this->conversation?->item_offer_id;
    }
}