<?php

namespace App\Http\Requests\Subscription;

use App\Models\Subscription;
use App\Models\SubscriptionItem;
use App\Support\ServiceSelectionValidator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * Adding categories/subcategories/zones to the caller's OWN active
 * subscription, within whatever quota is still unused (SPEC section 3.3,
 * task 4.4) — distinct from StoreSubscriptionRequest, which only ever
 * creates a brand-new subscription for a `draft` vendor.
 *
 * `vendor_id`/`plan_id` are never accepted here: everything resolves from
 * `$request->user()->vendor->currentActiveSubscription()`, the same
 * "never trust a client-supplied id" shape /vendors/me and /salesmen/me/*
 * already use.
 *
 * PURELY ADDITIVE BY CONSTRUCTION: only ids submitted that are NOT already
 * on the subscription ever reach the service layer (newCategoryIds() etc.
 * below already exclude anything the vendor picked earlier). There is no
 * removal code path here at all — resubmitting the vendor's full current
 * selection (locked ids the reused Flutter picker pre-checks, plus
 * whatever new ones were toggled) is what the client actually sends, and
 * anything already selected is simply a no-op, not re-validated or
 * re-inserted.
 */
class AddSubscriptionItemsRequest extends FormRequest
{
    private ?Subscription $subscription = null;

    /** @var array<int, int> */
    private array $newCategoryIds = [];

    /** @var array<int, int> */
    private array $newSubcategoryIds = [];

    /** @var array<int, int> */
    private array $newZoneIds = [];

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'category_ids' => ['sometimes', 'array'],
            'category_ids.*' => ['integer'],

            'subcategory_ids' => ['sometimes', 'array'],
            'subcategory_ids.*' => ['integer'],

            'zone_ids' => ['sometimes', 'array'],
            'zone_ids.*' => ['integer'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            $vendor = $this->user()->vendor;

            if ($vendor === null) {
                $validator->errors()->add('subscription', 'No vendor profile exists for this account.');

                return;
            }

            $subscription = $vendor->currentActiveSubscription();

            if ($subscription === null || $subscription->plan->quota === null) {
                $validator->errors()->add(
                    'subscription',
                    'You do not have an active subscription to add services to.'
                );

                return;
            }

            $this->subscription = $subscription;

            $existing = $this->existingIdsByType($subscription);

            $submittedCategoryIds = array_unique(array_map('intval', (array) $this->input('category_ids', [])));
            $submittedSubcategoryIds = array_unique(array_map('intval', (array) $this->input('subcategory_ids', [])));
            $submittedZoneIds = array_unique(array_map('intval', (array) $this->input('zone_ids', [])));

            // Only genuinely new ids ever reach validation or the service —
            // an already-selected id (even one that later became inactive)
            // is simply dropped from consideration here, never re-checked.
            $this->newCategoryIds = array_values(array_diff($submittedCategoryIds, $existing['category']));
            $this->newSubcategoryIds = array_values(array_diff($submittedSubcategoryIds, $existing['subcategory']));
            $this->newZoneIds = array_values(array_diff($submittedZoneIds, $existing['zone']));

            ServiceSelectionValidator::validate(
                $validator,
                $this->newCategoryIds,
                $this->newSubcategoryIds,
                $this->newZoneIds,
                // A newly added subcategory may belong to a category the
                // vendor already selected in an earlier request, not one
                // being added just now.
                allowedCategoryIds: array_values(array_unique(
                    array_merge($existing['category'], $this->newCategoryIds)
                )),
            );

            // effectiveQuota() (task 4.7) folds in any purchased add-on
            // quantity on top of the bare plan limit — a vendor who
            // bought "+2 categories" must be honored here too, not just
            // by the endpoint that sold them the extra room.
            $this->validateRemainingQuota(
                $validator,
                'category_ids',
                count($existing['category']),
                count($this->newCategoryIds),
                $subscription->effectiveQuota('categories'),
                'categories',
            );

            $this->validateRemainingQuota(
                $validator,
                'subcategory_ids',
                count($existing['subcategory']),
                count($this->newSubcategoryIds),
                $subscription->effectiveQuota('subcategories'),
                'subcategories',
            );

            $this->validateRemainingQuota(
                $validator,
                'zone_ids',
                count($existing['zone']),
                count($this->newZoneIds),
                $subscription->effectiveQuota('zones'),
                'zones',
            );
        });
    }

    private function validateRemainingQuota(
        Validator $validator,
        string $field,
        int $usedCount,
        int $newCount,
        int $max,
        string $label,
    ): void {
        if ($usedCount + $newCount > $max) {
            $remaining = max(0, $max - $usedCount);

            $validator->errors()->add(
                $field,
                "This plan allows at most {$max} {$label} — {$remaining} remaining, "
                ."but {$newCount} new ".($newCount === 1 ? 'was' : 'were')." selected."
            );
        }
    }

    /**
     * @return array{category: array<int,int>, subcategory: array<int,int>, zone: array<int,int>}
     */
    private function existingIdsByType(Subscription $subscription): array
    {
        $rows = SubscriptionItem::query()
            ->where('subscription_id', $subscription->id)
            ->get(['item_type', 'item_id']);

        return [
            'category' => $rows->where('item_type', 'category')->pluck('item_id')->all(),
            'subcategory' => $rows->where('item_type', 'subcategory')->pluck('item_id')->all(),
            'zone' => $rows->where('item_type', 'zone')->pluck('item_id')->all(),
        ];
    }

    /**
     * Populated during validation — only meaningful after the request has
     * passed. The controller resolves the subscription here rather than
     * re-querying, so it acts on the exact row validation already checked.
     */
    public function subscription(): Subscription
    {
        return $this->subscription;
    }

    /**
     * @return array<int, int>
     */
    public function newCategoryIds(): array
    {
        return $this->newCategoryIds;
    }

    /**
     * @return array<int, int>
     */
    public function newSubcategoryIds(): array
    {
        return $this->newSubcategoryIds;
    }

    /**
     * @return array<int, int>
     */
    public function newZoneIds(): array
    {
        return $this->newZoneIds;
    }
}
