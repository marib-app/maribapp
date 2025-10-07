<?php

namespace App\Services;
use App\Models\Category;

use App\Models\Service;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

class ServiceAuthorizationService
{
    public const ADMIN_ROLES = ['Super Admin', 'Admin'];

    public function userHasFullAccess(User $user): bool
    {
        return $user->hasAnyRole(self::ADMIN_ROLES) || $user->can('service-managers-manage');
    }

    /**
     * @param  Service|int|null  $service
     */
    public function userCanManageService(User $user, Service|int|null $service): bool
    {
        if ($this->userHasFullAccess($user)) {
            return true;
        }

        if ($service === null) {
            return false;
        }

        $serviceModel = $service instanceof Service ? $service : Service::find($service);

        if (!$serviceModel) {
            return false;
        }

        return $this->userCanManageCategory($user, $serviceModel->category_id);
    }

    public function ensureUserCanManageService(User $user, Service $service): void
    {
        if (!$this->userCanManageService($user, $service)) {
            abort(403, __('You are not authorized to manage this service.'));
        }
    }


    public function userCanManageCategory(User $user, Category|int|null $category): bool
    {
        if ($this->userHasFullAccess($user)) {
            return true;
        }

        if ($category === null) {
            return false;
        }

        $categoryModel = $category instanceof Category ? $category : Category::find($category);

        if (!$categoryModel) {
            return false;
        }

        return $user->managedCategories()
            ->where('categories.id', $categoryModel->id)
            ->exists();
    }

    public function ensureUserCanManageCategory(User $user, Category $category): void
    {
        if (!$this->userCanManageCategory($user, $category)) {
            abort(403, __('You are not authorized to manage this category.'));
        }
    }

    public function restrictServiceQuery(Builder $query, User $user, string $column = 'services.category_id'): Builder

    {
        if ($this->userHasFullAccess($user)) {
            return $query;
        }

        if ($column === 'services.id') {
            $serviceIds = $this->getManagedServiceIds($user);

            if (empty($serviceIds)) {
                return $query->whereRaw('1 = 0');
            }

            return $query->whereIn($column, $serviceIds);
        }

        $categoryIds = $this->getManagedCategoryIds($user);
        
        if (empty($categoryIds)) {
            return $query->whereRaw('1 = 0');
        }

        return $query->whereIn($column, $categoryIds);
    }

    public function restrictServiceRequestQuery(Builder $query, User $user): Builder
    {
        if ($this->userHasFullAccess($user)) {
            return $query;
        }

        $categoryIds = $this->getManagedCategoryIds($user);

        if (empty($categoryIds)) {
            return $query->whereRaw('1 = 0');
        }

               return $query->whereHas('service', static function (Builder $serviceQuery) use ($categoryIds) {
            $serviceQuery->whereIn('category_id', $categoryIds);
        });
    }

    public function getManagedServiceIds(User $user): array
    {
        $categoryIds = $this->getManagedCategoryIds($user);

        if (empty($categoryIds)) {
            return [];
        }

        return Service::query()
            ->whereIn('category_id', $categoryIds)
            ->pluck('id')


            ->filter()
            ->map(static fn ($id) => (int) $id)
            ->unique()
            ->values()
            ->all();
    }

    public function getManagedCategoryIds(User $user): array
    {
        return $user->managedCategories()
            ->pluck('categories.id')
            ->filter()
            ->map(static fn ($id) => (int) $id)
            ->unique()
            ->values()
            ->all();
    }
}