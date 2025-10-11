<?php

namespace App\Jobs;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Arr;

class UpdateDelegateBadge implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function __construct(
        protected int $userId,
        protected string $section,
        protected bool $assigned
    ) {
    }

    public function handle(): void
    {
        $user = User::find($this->userId);

        if (! $user) {
            return;
        }

        $additionalInfo = $user->additional_info;
        $sections = collect(Arr::get($additionalInfo, 'delegate_sections', []))
            ->filter(static fn ($value) => is_string($value) && $value !== '');

        if ($this->assigned) {
            $sections->push($this->section);
        } else {
            $sections = $sections->reject(fn ($value) => $value === $this->section);
        }

        $additionalInfo['delegate_sections'] = $sections->unique()->values()->all();

        $user->additional_info = $additionalInfo;
        $user->save();
    }
}