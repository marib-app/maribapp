<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NotificationPreference;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;

class NotificationPreferenceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $preferences = NotificationPreference::query()
            ->where('user_id', $request->user()->id)
            ->orderBy('type')
            ->get();

        return response()->json([
            'data' => $preferences->map(fn (NotificationPreference $preference) => $this->transform($preference)),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'preferences' => ['required', 'array', 'min:1'],
            'preferences.*.type' => ['required', 'string', 'max:64'],
            'preferences.*.enabled' => ['sometimes', 'boolean'],
            'preferences.*.sound' => ['sometimes', 'boolean'],
            'preferences.*.channel' => ['sometimes', 'string', 'max:32'],
            'preferences.*.frequency' => ['sometimes', 'string', 'max:32'],
            'preferences.*.quiet_hours' => ['sometimes', 'array'],
            'preferences.*.quiet_hours.start' => ['required_with:preferences.*.quiet_hours', 'string'],
            'preferences.*.quiet_hours.end' => ['required_with:preferences.*.quiet_hours', 'string'],
            'preferences.*.quiet_hours.tz' => ['required_with:preferences.*.quiet_hours', 'string', 'max:64'],
        ]);

        $user = $request->user();
        $upserted = [];

        foreach ($validated['preferences'] as $input) {
            $payload = [
                'enabled' => Arr::get($input, 'enabled', true),
                'sound' => Arr::get($input, 'sound', true),
                'channel' => Arr::get($input, 'channel', 'push'),
                'frequency' => Arr::get($input, 'frequency', 'instant'),
                'quiet_hours' => Arr::get($input, 'quiet_hours'),
            ];

            $preference = NotificationPreference::query()->updateOrCreate(
                [
                    'user_id' => $user->id,
                    'type' => $input['type'],
                ],
                $payload
            );

            $upserted[] = $this->transform($preference);
        }

        return response()->json([
            'updated' => count($upserted),
            'data' => $upserted,
        ]);
    }

    protected function transform(NotificationPreference $preference): array
    {
        return [
            'type' => $preference->type,
            'enabled' => (bool) $preference->enabled,
            'sound' => (bool) $preference->sound,
            'channel' => $preference->channel,
            'frequency' => $preference->frequency,
            'quiet_hours' => $preference->quiet_hours,
            'updated_at' => optional($preference->updated_at)->toIso8601String(),
        ];
    }
}
