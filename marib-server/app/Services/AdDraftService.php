<?php

namespace App\Services;

use App\Models\AdDraft;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;

class AdDraftService
{
    /**
     * @param array{current_step: string, payload: array, step_payload?: array, temporary_media?: array} $attributes
     */
    public function saveDraft(?int $draftId, int $userId, array $attributes): AdDraft
    {
        $payload = Arr::get($attributes, 'payload', []);
        $stepPayload = Arr::get($attributes, 'step_payload', []);
        $temporaryMedia = Arr::get($attributes, 'temporary_media', []);

        $values = [
            'current_step' => $attributes['current_step'],
            'payload' => $payload,
            'step_payload' => $stepPayload,
            'temporary_media' => $temporaryMedia,
        ];

        return DB::transaction(function () use ($draftId, $userId, $values) {
            if ($draftId !== null) {
                $draft = AdDraft::query()
                    ->whereKey($draftId)
                    ->where('user_id', $userId)
                    ->lockForUpdate()
                    ->first();

                if (! $draft) {
                    throw (new ModelNotFoundException())->setModel(AdDraft::class, [$draftId]);
                }

                $draft->fill($values);
                $draft->save();

                return $draft->fresh();
            }

            return AdDraft::create(array_merge($values, [
                'user_id' => $userId,
            ]));
        });
    }

    public function getDraftForUser(int $draftId, int $userId): AdDraft
    {
        $draft = AdDraft::query()
            ->whereKey($draftId)
            ->where('user_id', $userId)
            ->first();

        if (! $draft) {
            throw (new ModelNotFoundException())->setModel(AdDraft::class, [$draftId]);
        }

        return $draft;
    }
}