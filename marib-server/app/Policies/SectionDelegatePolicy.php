<?php

namespace App\Policies;

use App\Models\User;
use App\Services\DelegateAuthorizationService;
use Illuminate\Auth\Access\Response;

class SectionDelegatePolicy
{
    public const FORBIDDEN_MESSAGE = 'غير مصرح لك بتنفيذ هذه العملية على هذا القسم.';

    public function __construct(private readonly DelegateAuthorizationService $delegateAuthorizationService)
    {
    }

    public function publish(User $user, ?string $section = null): Response
    {
        return $this->authorizeForSection($user, $section);
    }

    public function update(User $user, ?string $section = null): Response
    {
        return $this->authorizeForSection($user, $section);
    }

    public function copy(User $user, ?string $sourceSection = null, ?string $targetSection = null): Response
    {
        return $this->authorizeForSections($user, [$sourceSection, $targetSection]);
    }

    public function changeSection(User $user, ?string $fromSection = null, ?string $toSection = null): Response
    {
        return $this->authorizeForSections($user, [$fromSection, $toSection]);
    }

    public function batchImport(User $user, ?string $section = null): Response
    {
        return $this->authorizeForSection($user, $section);
    }

    private function authorizeForSections(User $user, array $sections): Response
    {
        foreach (array_unique(array_filter($sections)) as $section) {
            $response = $this->authorizeForSection($user, $section);

            if ($response->denied()) {
                return $response;
            }
        }

        return Response::allow();
    }

    private function authorizeForSection(User $user, ?string $section): Response
    {
        if ($section === null || ! $this->delegateAuthorizationService->isSectionRestricted($section)) {
            return Response::allow();
        }

        if ($this->delegateAuthorizationService->userCanManageSection($user, $section)) {
            return Response::allow();
        }

        return Response::denyWithStatus(403, self::FORBIDDEN_MESSAGE);
    }
}