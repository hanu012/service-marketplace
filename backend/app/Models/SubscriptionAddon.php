<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Quota purchased on top of a subscription's base plan (SPEC section 3
 * item 6 / section 6, task 4.7) — see the migration's own docblock for
 * why this is a dedicated table rather than counters on `subscriptions`.
 * Scoped to `subscription_id`; does not carry forward across a plan
 * change (`SubscriptionService::changePlan()`).
 */
class SubscriptionAddon extends Model
{
    protected $fillable = [
        'subscription_id',
        'resource',
        'quantity',
        'price_paise',
        'idempotency_key',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'price_paise' => 'integer',
        ];
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class);
    }
}
