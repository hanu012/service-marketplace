<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Subscription\ChangeSubscriptionPlanRequest;
use App\Http\Requests\Subscription\PurchaseAddOnRequest;
use App\Http\Requests\Subscription\StoreSubscriptionRequest;
use App\Http\Resources\SubscriptionAddonResource;
use App\Http\Resources\SubscriptionResource;
use App\Http\Responses\ApiResponse;
use App\Models\Plan;
use App\Models\Subscription;
use App\Models\Vendor;
use App\Services\SubscriptionService;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;

class SubscriptionController extends Controller
{
    public function __construct(private readonly SubscriptionService $subscriptions) {}

    /**
     * Subscribes a vendor to a plan (SPEC section 6) — salesman/admin-led
     * only. By the time this runs, HandleIdempotentSubscription has already
     * confirmed the Idempotency-Key header is valid and unused, so a fresh
     * subscription is always the right thing to create here.
     */
    public function store(StoreSubscriptionRequest $request): JsonResponse
    {
        $data = $request->validated();

        $vendor = Vendor::findOrFail($data['vendor_id']);
        $plan = Plan::findOrFail($data['plan_id']);

        try {
            $result = $this->subscriptions->subscribe(
                vendor: $vendor,
                plan: $plan,
                categoryIds: $data['category_ids'],
                subcategoryIds: $data['subcategory_ids'],
                zoneIds: $data['zone_ids'],
                paymentMode: $data['payment_mode'],
                freeTrialDays: $data['free_trial_days'] ?? null,
                actor: $request->user(),
                idempotencyKey: $request->header('Idempotency-Key'),
            );
        } catch (QueryException $e) {
            // The race HandleIdempotentSubscription's pre-check cannot
            // close on its own: two near-simultaneous requests with the
            // same new key can both pass that check before either has
            // inserted. The unique column is the real guarantee; this is
            // just turning its violation into the same replay response
            // instead of a raw 500.
            if (! $this->isDuplicateIdempotencyKey($e)) {
                throw $e;
            }

            $existing = $this->subscriptions->findByIdempotencyKey($request->header('Idempotency-Key'));

            return ApiResponse::success([
                'subscription' => new SubscriptionResource(
                    $existing->load(['plan', 'items', 'payments', 'commission'])
                ),
            ]);
        }

        $subscription = $result['subscription']->load(['plan', 'items', 'payments', 'commission']);
        $vendor = $vendor->fresh();

        return ApiResponse::success([
            'subscription' => new SubscriptionResource($subscription),
            'vendor' => ['id' => $vendor->id, 'status' => $vendor->status],
            // Shown exactly once, per SPEC section 2.2 — the salesman
            // shares this via a WhatsApp share action right now, since it
            // cannot be recovered afterward.
            'temporary_password' => $result['temporary_password'],
        ], 201);
    }

    /**
     * Upgrade/downgrade (SPEC section 3 item 6 / section 6, task 4.7).
     * `$subscription` is the OLD, still-active row (route-bound) — by
     * the time this runs it has already passed
     * ChangeSubscriptionPlanRequest's ownership/quota/downgrade-blocking
     * checks.
     */
    public function changePlan(ChangeSubscriptionPlanRequest $request, Subscription $subscription): JsonResponse
    {
        $data = $request->validated();
        $newPlan = Plan::findOrFail($data['plan_id']);

        try {
            $result = $this->subscriptions->changePlan(
                current: $subscription,
                newPlan: $newPlan,
                categoryIds: $data['category_ids'],
                subcategoryIds: $data['subcategory_ids'],
                zoneIds: $data['zone_ids'],
                paymentMode: $data['payment_mode'],
                freeTrialDays: $data['free_trial_days'] ?? null,
                actor: $request->user(),
                idempotencyKey: $request->header('Idempotency-Key'),
            );
        } catch (QueryException $e) {
            if (! $this->isDuplicateIdempotencyKey($e)) {
                throw $e;
            }

            $existing = $this->subscriptions->findByIdempotencyKey($request->header('Idempotency-Key'));

            return ApiResponse::success([
                'subscription' => new SubscriptionResource(
                    $existing->load(['plan', 'items', 'payments', 'commission'])
                ),
            ]);
        }

        $newSubscription = $result['subscription']->load(['plan', 'items', 'payments', 'commission']);
        $previousSubscription = $result['previous_subscription']->fresh();

        return ApiResponse::success([
            'subscription' => new SubscriptionResource($newSubscription),
            'previous_subscription' => [
                'id' => $previousSubscription->id,
                'status' => $previousSubscription->status,
                'end_date' => $previousSubscription->end_date?->toDateString(),
            ],
        ], 201);
    }

    /**
     * Buying quota on top of the base plan (SPEC section 3 item 6 /
     * section 6, task 4.7).
     */
    public function addOns(PurchaseAddOnRequest $request, Subscription $subscription): JsonResponse
    {
        $data = $request->validated();

        try {
            $addon = $this->subscriptions->purchaseAddOn(
                subscription: $subscription,
                resource: $data['resource'],
                quantity: $data['quantity'],
                paymentMode: $data['payment_mode'],
                idempotencyKey: $request->header('Idempotency-Key'),
            );
        } catch (QueryException $e) {
            if (! str_contains($e->getMessage(), 'idempotency_key')) {
                throw $e;
            }

            $existing = $this->subscriptions->findAddonByIdempotencyKey($request->header('Idempotency-Key'));

            return ApiResponse::success(['addon' => new SubscriptionAddonResource($existing)]);
        }

        return ApiResponse::success(['addon' => new SubscriptionAddonResource($addon)], 201);
    }

    private function isDuplicateIdempotencyKey(QueryException $e): bool
    {
        return str_contains($e->getMessage(), 'idempotency_key');
    }
}
