<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;


class Chat extends Model {
    use HasFactory;

     protected $table = 'chat_conversations';


    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     * 
     */
    protected $fillable = [

        'item_offer_id',

        'department',
        'assigned_to',
 
    ];
 

    /**
     * علاقة المستخدمين المشاركين في المحادثة
     */
    public function itemOffer()
    {
        return $this->belongsTo(ItemOffer::class);


    }


        public function assignedAgent()
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }


    /**
     * علاقة الرسائل المرتبطة بالمحادثة
     */
    public function messages()
    {
        return $this->hasMany(ChatMessage::class, 'conversation_id');


    }





        public function tickets()
    {
        return $this->hasMany(DepartmentTicket::class, 'chat_conversation_id');
    }

    public function scopeDepartment($query, ?string $department)
    {
        if (!empty($department)) {
            $query->where('department', $department);
        }

        return $query;
    }


    
    /**
     * علاقة آخر رسالة في المحادثة
     */
    public function latestMessage()
    {
        return $this->hasOne(ChatMessage::class, 'conversation_id')->latestOfMany();

    }

    /**
     * Users participating in the conversation.
     */
    public function participants()
    {
        return $this->belongsToMany(User::class, 'chat_conversation_user', 'conversation_id', 'user_id')

            ->withPivot([
                'is_online',
                'last_seen_at',
                'is_typing',
                'last_typing_at',
            ])



            ->withTimestamps();
            
    }
}
