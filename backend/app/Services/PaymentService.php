<?php

namespace App\Services;

use App\Models\Payment;
use App\Models\Salesman;
use App\Models\Subscription;

/**
 * Records a payment against a subscription (SPEC section 6.5).
 *
 * No gateway calls here — CLAUDE.md: do not add a payment gateway SDK yet.
 * `gateway` stays "manual" (the column default) for every mode until a real
 * one is wired up, at which point only this class's internals change.
 *
 * STATUS/VERIFICATION RULES (payments migration docblock): `cash` is
 * captured immediately (the salesman has the money in hand) but left
 * unverified — `admin_verified_at` stays null, which is exactly what drives
 * the SPEC section 5.9 cash-reconciliation queue and gates the matching
 * commission from moving to `paid`. `online` and `free` have nothing to
 * reconcile without a real gateway, so both are captured AND verified
 * immediately.
 *
 * `amountPaise` is always explicit (task 4.7), not implicitly read from
 * `$subscription->price_paise` — that assumption broke the moment a
 * payment could be charged against an *existing* subscription for less
 * than its own `price_paise` (an add-on purchase, priced independently
 * via `plan_quotas`). Every caller states the amount it means to charge.
 */
class PaymentService
{
    public function payViaCash(Subscription $subscription, int $amountPaise, ?Salesman $collectedBy): Payment
    {
        return Payment::create([
            'subscription_id' => $subscription->id,
            'amount_paise' => $amountPaise,
            'mode' => 'cash',
            'status' => 'captured',
            'collected_by_salesman_id' => $collectedBy?->id,
            'admin_verified_at' => null,
        ]);
    }

    public function payOnline(Subscription $subscription, int $amountPaise): Payment
    {
        return Payment::create([
            'subscription_id' => $subscription->id,
            'amount_paise' => $amountPaise,
            'mode' => 'online',
            'status' => 'captured',
            'admin_verified_at' => now(),
        ]);
    }

    /**
     * A free-trial grant is still a real payment row — zero amount, nothing
     * to collect or reconcile, but the same audit trail every other mode
     * gets (SPEC section 5.14).
     */
    public function recordFreeTrial(Subscription $subscription): Payment
    {
        return Payment::create([
            'subscription_id' => $subscription->id,
            'amount_paise' => 0,
            'mode' => 'free',
            'status' => 'captured',
            'admin_verified_at' => now(),
        ]);
    }
}
