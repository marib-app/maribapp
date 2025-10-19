<?php

namespace App\Http\Controllers\Api;

use App\Enums\NotificationFrequency;
use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateUserPreferenceRequest;
use App\Http\Resources\UserPreferenceResource;
use App\Models\Governorate;
use App\Models\UserPreference;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class UserPreferenceController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user();

        /** @var UserPreference|null $preference */
        $preference = $user->preference()->with('favoriteGovernorate')->first();

        if (!$preference) {
            $preference = $user->preference()->create([
                'currency_watchlist' => [],
                'metal_watchlist' => [],
                'notification_frequency' => NotificationFrequency::DAILY->value,
            ])->fresh(['favoriteGovernorate']);
        }

        $resource = new UserPreferenceResource($preference);

        ResponseService::successResponse(
            'تم جلب تفضيلات المستخدم بنجاح.',
            $resource->resolve($request),
            [
                'preference_options' => [
                    'notification_frequencies' => $this->notificationFrequencyOptions(),
                ],
            ]
        );
    }

    public function update(UpdateUserPreferenceRequest $request)
    {
        $user = $request->user();
        $validated = $request->validated();

        /** @var UserPreference $preference */
        $preference = $user->preference()->firstOrNew([]);

        if (array_key_exists('favorite_governorate_code', $validated)) {
            $code = $validated['favorite_governorate_code'];
            $governorateId = null;

            if ($code) {
                $governorateId = Governorate::where('code', $code)->value('id');
            }

            $preference->favorite_governorate_id = $governorateId;
        }

        if (array_key_exists('currency_watchlist', $validated)) {
            $preference->currency_watchlist = $validated['currency_watchlist'] ?? [];
        }

        if (array_key_exists('metal_watchlist', $validated)) {
            $preference->metal_watchlist = $validated['metal_watchlist'] ?? [];
        }


        if (array_key_exists('currency_notification_regions', $validated)) {
            $preference->currency_notification_regions = $validated['currency_notification_regions'] ?? [];
        }

        if (array_key_exists('notification_frequency', $validated)) {
            $preference->notification_frequency = $validated['notification_frequency'] ?? NotificationFrequency::DAILY->value;
        }

        $preference->user()->associate($user);

        DB::transaction(function () use ($preference) {
            $preference->save();
        });

        $resource = new UserPreferenceResource($preference->fresh(['favoriteGovernorate']));

        ResponseService::successResponse(
            'تم تحديث التفضيلات بنجاح.',
            $resource->resolve($request),
            [
                'preference_options' => [
                    'notification_frequencies' => $this->notificationFrequencyOptions(),
                ],
            ]
        );
    }

    private function notificationFrequencyOptions(): array
    {
        return collect(NotificationFrequency::cases())
            ->map(static fn (NotificationFrequency $frequency) => [
                'value' => $frequency->value,
                'label' => $frequency->label(),
            ])
            ->values()
            ->all();
    }
}