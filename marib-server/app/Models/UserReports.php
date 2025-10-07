<?php

namespace App\Models;
use App\Models\AdminNotification;
use App\Models\Concerns\CreatesAdminNotificationOnCreation;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use function __;
use function url;
use function optional;


class UserReports extends Model {
    use HasFactory;
    use CreatesAdminNotificationOnCreation;

    protected $fillable = [
        'id',
        'report_reason_id',
        'item_id',
        
        'department',


        'user_id',
        'other_message',
        'reason'
    ];

    public function user() {
        return $this->belongsTo(User::class);
    }

    public function report_reason() {
        return $this->belongsTo(ReportReason::class);
    }

    public function item() {
        return $this->belongsTo(Item::class);
    }


    protected function getAdminNotificationType(): string
    {
        return AdminNotification::TYPE_USER_REPORT;
    }

    protected function getAdminNotificationTitle(): string
    {
        $itemName = $this->item?->name ?? __('Item #:id', ['id' => $this->item_id]);
        $reporter = $this->user?->name ?? __('User #:id', ['id' => $this->user_id]);

        return __('New report on :item by :user', [
            'item' => $itemName,
            'user' => $reporter,
        ]);
    }

    protected function getAdminNotificationLink(): ?string
    {
        return url('/reports/user-reports');
    }

    protected function getAdminNotificationMeta(): array
    {
        return [
            'item_id'     => $this->item_id,
            'user_id'     => $this->user_id,
            'department'  => $this->department,
            'reason'      => $this->reason,
            'created_at'  => optional($this->created_at)->toIso8601String(),
        ];
    }


    public function scopeSearch($query, $search) {
        $search = "%" . $search . "%";
        $query = $query->where(function ($q) use ($search) {
            $q->orWhere('report_reason_id', 'LIKE', $search)
                ->orWhere('item_id', 'LIKE', $search)
                ->orWhere('user_id', 'LIKE', $search)
                ->orWhere('other_message', 'LIKE', $search)
                ->orWhere('department', 'LIKE', $search)


                ->orWhere('reason', 'LIKE', $search)
                ->orWhere('created_at', 'LIKE', $search)
                ->orWhere('updated_at', 'LIKE', $search)
                ->orWhereHas('report_reason', function ($q) use ($search) {
                    $q->where('reason', 'LIKE', $search);
                })->orWhereHas('item', function ($q) use ($search) {
                    $q->where('name', 'LIKE', $search);
                })->orWhereHas('user', function ($q) use ($search) {
                    $q->where('name', 'LIKE', $search);
                });
        });
        return $query;
    }

    public function scopeSort($query, $column, $order) {
        if ($column == "item_name") {
            $query = $query->leftjoin('items', 'items.id', '=', 'user_reports.item_id')->orderBy('items.name', $order);
        } else if ($column == "user_name") {
            $query = $query->leftjoin('users', 'users.id', '=', 'user_reports.user_id')->orderBy('users.name', $order);
        } else if ($column == "report_reason_name") {
            $query = $query->leftjoin('report_reasons', 'report_reasons.id', '=', 'user_reports.report_reason_id')->orderBy('report_reasons.reason', $order);
        } else {
            $query = $query->orderBy($column, $order);
        }

        return $query->select('user_reports.*');
    }

    public function scopeFilter($query, $filterObject) {
        if (!empty($filterObject)) {
            foreach ($filterObject as $column => $value) {
                $query->where((string)$column, (string)$value);
            }
        }
        return $query;

    }

    public function scopeDepartment($query, ?string $department)
    {
        if (!empty($department)) {
            $query->where('department', $department);
        }

        return $query;
    }



    public function getStatusAttribute($value) {
        if ($this->deleted_at) {
            return "inactive";
        }

        return $value;
    }



}
