<?php

namespace App\Services\Audit;

use App\Services\TelemetryService;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Arr;

class AuditLogger
{
    /**
     * @param  array<int, string>  $fields
     * @param  array<string, mixed>  $context
     */
    public function logChanges(
        Model $model,
        string $event,
        array $fields,
        ?Authenticatable $actor = null,
        array $context = []
    ): void {
        $changes = [];

        foreach ($fields as $field) {
            $changes[$field] = [
                'old' => $model->getOriginal($field),
                'new' => $model->getAttribute($field),
            ];
        }

        $payload = array_merge($context, [
            'event' => $event,
            'model' => $model::class,
            'model_table' => $model->getTable(),
            'model_id' => $model->getKey(),
            'changes' => $changes,
            'snapshot' => Arr::only($model->getAttributes(), $fields),
            'timestamp' => now()->toIso8601String(),
        ]);

        if ($actor !== null) {
            $actorContext = [
                'id' => $actor->getAuthIdentifier(),
                'type' => $actor::class,
            ];

            if (method_exists($actor, 'getAttribute')) {
                $name = $actor->getAttribute('name');
                $email = $actor->getAttribute('email');
            } else {
                $name = $actor->name ?? null;
                $email = $actor->email ?? null;
            }

            $actorContext = array_merge($actorContext, array_filter([
                'name' => $name,
                'email' => $email,
            ], static fn ($value) => $value !== null && $value !== ''));

            $payload['actor'] = $actorContext;
        }

        app(TelemetryService::class)->record($event, $payload);
    }
}
