<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Models\Commission;
use App\Models\Plan;
use App\Models\Salesman;
use App\Models\Subscription;
use App\Models\SubscriptionAddon;
use App\Models\SubscriptionItem;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Support\Facades\DB;

/**
 * Subscribing a vendor to a plan (SPEC section 6) — salesman/admin-led
 * (source=salesman/admin) and vendor self-service (source=self, task 4.2).
 *
 * In app/Services because it spans five tables in one transaction, which
 * CLAUDE.md puts here regardless of whether repositories are used
 * elsewhere — same reasoning as VendorDraftService. A half-applied
 * subscribe is the specific failure to avoid: a subscription with no
 * payment row, or an activated vendor with no commission a salesman is
 * owed, are both worse than the request simply failing outright.
 */
class SubscriptionService
{
    public function __construct(private readonly PaymentService $payments) {}

    /**
     * An existing subscription for this Idempotency-Key, if the header has
     * been seen before. Looked up BEFORE the transaction — a retried
     * request (dropped response, not a genuine second sale) must return the
     * same row, never attempt a second insert.
     */
    public function findByIdempotencyKey(string $idempotencyKey): ?Subscription
    {
        return Subscription::query()
            ->where('idempotency_key', $idempotencyKey)
            ->first();
    }

    /**
     * Same reasoning as findByIdempotencyKey() — the add-on equivalent,
     * looked up by HandleIdempotentAddonPurchase before the transaction.
     */
    public function findAddonByIdempotencyKey(string $idempotencyKey): ?SubscriptionAddon
    {
        return SubscriptionAddon::query()
            ->where('idempotency_key', $idempotencyKey)
            ->first();
    }

    /**
     * @param  array<int, int>  $categoryIds
     * @param  array<int, int>  $subcategoryIds
     * @param  array<int, int>  $zoneIds
     * @return array{subscription: Subscription, temporary_password: ?string}
     */
    public function subscribe(
        Vendor $vendor,
        Plan $plan,
        array $categoryIds,
        array $subcategoryIds,
        array $zoneIds,
        string $paymentMode,
        ?int $freeTrialDays,
        User $actor,
        string $idempotencyKey,
    ): array {
        return DB::transaction(function () use (
            $vendor, $plan, $categoryIds, $subcategoryIds, $zoneIds,
            $paymentMode, $freeTrialDays, $actor, $idempotencyKey,
        ) {
            $isSalesman = $actor->role === UserRole::Salesman;
            $isVendorSelf = $actor->role === UserRole::Vendor;
            $salesman = $isSalesman ? $actor->salesman : null;

            $source = match (true) {
                $isSalesman => 'salesman',
                $isVendorSelf => 'self',
                default => 'admin',
            };

            $isFreeTrial = $paymentMode === 'free';

            // Server computes price and dates from the plan — never trusts
            // a client-sent amount or end_date (SPEC section 6.1). A free
            // trial overrides both: it costs nothing and runs for the
            // salesman-chosen (quota-capped) duration, not the plan's.
            $pricePaise = $isFreeTrial ? 0 : $plan->price_paise;
            $durationDays = $isFreeTrial ? $freeTrialDays : $plan->duration_days;

            $startDate = now()->startOfDay();
            $endDate = $startDate->copy()->addDays($durationDays);

            $subscription = Subscription::create([
                'vendor_id' => $vendor->id,
                'plan_id' => $plan->id,
                'salesman_id' => $salesman?->id,
                'source' => $source,
                'status' => 'active',
                'start_date' => $startDate,
                'end_date' => $endDate,
                'price_paise' => $pricePaise,
                'duration_days' => $durationDays,
                'free_trial_days' => $isFreeTrial ? $freeTrialDays : null,
                'idempotency_key' => $idempotencyKey,
            ]);

            $this->recordItems($subscription, 'category', $categoryIds);
            $this->recordItems($subscription, 'subcategory', $subcategoryIds);
            $this->recordItems($subscription, 'zone', $zoneIds);

            if ($isFreeTrial) {
                $this->payments->recordFreeTrial($subscription);
            } elseif ($paymentMode === 'cash') {
                $this->payments->payViaCash($subscription, $pricePaise, $salesman);
            } else {
                $this->payments->payOnline($subscription, $pricePaise);
            }

            // SPEC section 12: only a salesman-sourced, PAID sale earns
            // commission — never a free trial, never source = admin (the
            // subscriptions migration is explicit: salesman_id is null for
            // admin-created rows, so there is no salesman to credit).
            if ($isSalesman && ! $isFreeTrial && $salesman !== null) {
                $this->recordCommission($subscription, $salesman, $pricePaise);
            }

            // Salesman/admin-added vendors skip KYC review (SPEC section 7)
            // — met in person, straight to Active. A self-registered vendor
            // subscribing themselves has NOT been met in person, so SPEC
            // section 7 routes them to pending_verification instead, to be
            // approved through the Vendor Verification Queue.
            $vendor->update(['status' => $isVendorSelf ? 'pending_verification' : 'active']);

            // The draft-stage password is unusable by design (a random
            // string nobody was given — see VendorDraftService::create()),
            // ONLY for a vendor created via that flow (salesman/admin-led).
            // A self-registered vendor already has their own chosen
            // password (task 4.1) — resetting it here and forcing a
            // must_change_password would lock them out of the account they
            // just used to sign in and subscribe.
            $temporaryPassword = null;

            if (! $isVendorSelf) {
                $temporaryPassword = User::generateTemporaryPassword();
                $vendor->user->forceFill([
                    'password' => $temporaryPassword,
                    'must_change_password' => true,
                ])->save();
            }

            return [
                'subscription' => $subscription,
                'temporary_password' => $temporaryPassword,
            ];
        });
    }

    /**
     * Upgrade/downgrade (SPEC section 3 item 6 / section 6, task 4.7) —
     * replaces the caller's active subscription with a fresh one on a
     * different plan, crediting the old subscription's unused days as a
     * price reduction (never a duration extension). The old row is
     * marked `superseded` (a real terminal state, distinct from
     * `cancelled` so admin reporting can tell an upsell apart from
     * churn), `end_date` moved to today, and the new row's
     * `previous_subscription_id` points back to it.
     *
     * One formula, both directions: the same proration math runs
     * whether the new plan is pricier or cheaper. A downgrade can
     * produce a credit larger than the new plan's price — the amount
     * charged floors at 0, and the excess is never refunded (no refund
     * mechanism exists without a real payment gateway; see SPEC section
     * 13). Quota-fit (the actual downgrade block) was already checked
     * by ChangeSubscriptionPlanRequest before this ever runs.
     *
     * `subscriptions.price_paise` on the NEW row is set to the amount
     * actually charged this time (the discounted amount), not the
     * plan's list price — consistent with how a free trial already sets
     * it to 0 rather than the plan's price. Commission is computed off
     * this same discounted amount.
     *
     * @param  array<int, int>  $categoryIds
     * @param  array<int, int>  $subcategoryIds
     * @param  array<int, int>  $zoneIds
     * @return array{subscription: Subscription, previous_subscription: Subscription}
     */
    public function changePlan(
        Subscription $current,
        Plan $newPlan,
        array $categoryIds,
        array $subcategoryIds,
        array $zoneIds,
        string $paymentMode,
        ?int $freeTrialDays,
        User $actor,
        string $idempotencyKey,
    ): array {
        return DB::transaction(function () use (
            $current, $newPlan, $categoryIds, $subcategoryIds, $zoneIds,
            $paymentMode, $freeTrialDays, $actor, $idempotencyKey,
        ) {
            $isSalesman = $actor->role === UserRole::Salesman;
            $isVendorSelf = $actor->role === UserRole::Vendor;
            $salesman = $isSalesman ? $actor->salesman : null;

            $source = match (true) {
                $isSalesman => 'salesman',
                $isVendorSelf => 'self',
                default => 'admin',
            };

            $isFreeTrial = $paymentMode === 'free';
            $today = now()->startOfDay();

            // Decision 1: the credit is a price reduction, never a
            // duration extension — the new subscription always runs the
            // new plan's own standard duration_days.
            $unusedDays = $today->lt($current->end_date) ? $today->diffInDays($current->end_date) : 0;
            $remainingValuePaise = (int) round($current->price_paise * $unusedDays / $current->duration_days);

            $newPlanPricePaise = $isFreeTrial ? 0 : $newPlan->price_paise;
            $amountDuePaise = $isFreeTrial ? 0 : max(0, $newPlanPricePaise - $remainingValuePaise);

            $durationDays = $isFreeTrial ? $freeTrialDays : $newPlan->duration_days;
            $endDate = $today->copy()->addDays($durationDays);

            $newSubscription = Subscription::create([
                'vendor_id' => $current->vendor_id,
                'plan_id' => $newPlan->id,
                'salesman_id' => $salesman?->id,
                'source' => $source,
                'status' => 'active',
                'start_date' => $today,
                'end_date' => $endDate,
                'price_paise' => $amountDuePaise,
                'duration_days' => $durationDays,
                'free_trial_days' => $isFreeTrial ? $freeTrialDays : null,
                'previous_subscription_id' => $current->id,
                'idempotency_key' => $idempotencyKey,
            ]);

            $this->recordItems($newSubscription, 'category', $categoryIds);
            $this->recordItems($newSubscription, 'subcategory', $subcategoryIds);
            $this->recordItems($newSubscription, 'zone', $zoneIds);

            if ($isFreeTrial) {
                $this->payments->recordFreeTrial($newSubscription);
            } elseif ($paymentMode === 'cash') {
                $this->payments->payViaCash($newSubscription, $amountDuePaise, $salesman);
            } else {
                $this->payments->payOnline($newSubscription, $amountDuePaise);
            }

            if ($isSalesman && ! $isFreeTrial && $salesman !== null) {
                $this->recordCommission($newSubscription, $salesman, $amountDuePaise);
            }

            // Decision 6: a distinct terminal state from `cancelled` —
            // this row wasn't churn, it was replaced.
            $current->update(['status' => 'superseded', 'end_date' => $today]);

            return [
                'subscription' => $newSubscription,
                'previous_subscription' => $current,
            ];
        });
    }

    /**
     * Buying quota on top of the base plan (SPEC section 3 item 6 /
     * section 6, task 4.7) — attaches to the CURRENT subscription (no
     * new subscription row, no vendor-status change), price computed
     * server-side from `plan_quotas`' per-resource unit price, never
     * trusted from the client.
     *
     * NO COMMISSION IS RECORDED HERE, even for a salesman actor — a
     * real limitation, not an oversight: `commissions.subscription_id`
     * is UNIQUE (one commission per subscription, tied to its original
     * sale), so a second `Commission::create()` against the same
     * subscription an add-on attaches to would throw a constraint
     * violation. Extending commissions to also credit ongoing add-on
     * purchases would need a schema change (drop the uniqueness, add
     * add-on linkage) that's out of scope for this task — flagged here
     * and in PROGRESS.md, not silently dropped. `purchaseAddOn()` still
     * requires the same role/ownership gate as `changePlan()`
     * (decision 3) for consistency and the upsell reasoning there, even
     * though no commission is earned on the sale today.
     */
    public function purchaseAddOn(
        Subscription $subscription,
        string $resource,
        int $quantity,
        string $paymentMode,
        string $idempotencyKey,
    ): SubscriptionAddon {
        return DB::transaction(function () use ($subscription, $resource, $quantity, $paymentMode, $idempotencyKey) {
            $unitPricePaise = $subscription->plan->quota->addonPricePerUnit($resource);
            $pricePaise = $unitPricePaise * $quantity;

            $addon = SubscriptionAddon::create([
                'subscription_id' => $subscription->id,
                'resource' => $resource,
                'quantity' => $quantity,
                'price_paise' => $pricePaise,
                'idempotency_key' => $idempotencyKey,
            ]);

            if ($paymentMode === 'cash') {
                $this->payments->payViaCash($subscription, $pricePaise, $subscription->salesman);
            } else {
                $this->payments->payOnline($subscription, $pricePaise);
            }

            return $addon;
        });
    }

    /**
     * Shared by subscribe(), changePlan() and purchaseAddOn() — SPEC
     * section 12: only a salesman-sourced, paid sale earns commission.
     * Callers already check `$isFreeTrial`/`$salesman !== null` before
     * calling this; kept explicit at each call site rather than folded
     * in here, since "when is commission owed" reads more clearly next
     * to the code that just decided how much money changed hands.
     */
    private function recordCommission(Subscription $subscription, Salesman $salesman, int $amountPaise): void
    {
        Commission::create([
            'subscription_id' => $subscription->id,
            'salesman_id' => $salesman->id,
            // Integer-only, round-half-up. amount_paise * rate_bps
            // divided by 10000 as a float can misround the same way
            // Plan::rupeesToPaise() guards against — 1/10000 has no
            // exact binary representation, so this stays in integers
            // throughout rather than trusting round() on a float.
            'amount_paise' => intdiv($amountPaise * $salesman->commission_rate_bps + 5000, 10000),
            // Snapshot, not a live read — a later rate change must not
            // rewrite what this sale actually earned (same reasoning as
            // Plan's audit snapshot).
            'rate_bps' => $salesman->commission_rate_bps,
            'status' => 'pending',
        ]);
    }

    /**
     * Adds categories/subcategories/zones to an already-active subscription,
     * within whatever quota is still unused (SPEC section 3.3, task 4.4) —
     * distinct from subscribe(), which only ever creates a fresh
     * subscription. The caller (AddSubscriptionItemsRequest) has already
     * computed which ids are genuinely new and validated them against
     * remaining quota; this method just inserts them, same insert-only
     * shape recordItems() already has. No commission, no payment, no
     * vendor-status change — this is purely additive to an existing,
     * already-paid-for subscription.
     *
     * @param  array<int, int>  $newCategoryIds
     * @param  array<int, int>  $newSubcategoryIds
     * @param  array<int, int>  $newZoneIds
     */
    public function addItems(
        Subscription $subscription,
        array $newCategoryIds,
        array $newSubcategoryIds,
        array $newZoneIds,
    ): Subscription {
        return DB::transaction(function () use ($subscription, $newCategoryIds, $newSubcategoryIds, $newZoneIds) {
            $this->recordItems($subscription, 'category', $newCategoryIds);
            $this->recordItems($subscription, 'subcategory', $newSubcategoryIds);
            $this->recordItems($subscription, 'zone', $newZoneIds);

            return $subscription->fresh();
        });
    }

    /**
     * @param  array<int, int>  $ids
     */
    private function recordItems(Subscription $subscription, string $itemType, array $ids): void
    {
        $rows = array_map(fn (int $id) => [
            'subscription_id' => $subscription->id,
            'item_type' => $itemType,
            'item_id' => $id,
            'created_at' => now(),
            'updated_at' => now(),
        ], $ids);

        if ($rows !== []) {
            SubscriptionItem::insert($rows);
        }
    }
}
