<?php

namespace App\Services;

use App\Models\DepartmentNotice;

class DepartmentNoticeService
{
    public function getActiveNotice(?string $department): ?array
    {
        if ($department === null || $department === '') {
            return null;
        }

        $notice = DepartmentNotice::query()
            ->active()
            ->where('department', $department)
            ->orderByDesc('starts_at')
            ->orderByDesc('created_at')
            ->first();

        if ($notice === null) {
            return null;
        }

        return [
            'id' => $notice->getKey(),
            'department' => $notice->department,
            'title' => $notice->title,
            'body' => $notice->body,
            'severity' => $notice->severity,
            'starts_at' => $notice->starts_at?->toIso8601String(),
            'ends_at' => $notice->ends_at?->toIso8601String(),
            'metadata' => $this->normalizeMetadata($notice->metadata),
        ];
    }

    /**
     * @param array<string, mixed>|null $metadata
     * @return array<string, mixed>
     */
    private function normalizeMetadata(?array $metadata): array
    {
        return $metadata ?? [];
    }
}