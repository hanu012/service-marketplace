<?php

namespace App\Services;

use App\Models\Vendor;
use App\Models\Zone;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

/**
 * SPEC section 4 item 4's match query: `subcategory = X AND zone contains
 * customer_location AND vendor.status = active AND subscription.end_date
 * >= today`, sorted per section 4 item 5.
 *
 * Zone resolution is delegated to ZoneMatcher (task 4.6) — this class only
 * adds the subcategory/zone coverage join against subscription_items and
 * the sort.
 */
class VendorSearchService
{
    /**
     * SPEC leaves the exact review-count floor unspecified beyond "a
     * minimum threshold so one 5-star doesn't outrank a 4.6 with 80
     * reviews" — 5 is a placeholder default until there's a real product
     * answer. Live since task 5.5: `RecalculatesVendorRating` keeps
     * `vendors.rating_avg`/`rating_count` current on every review
     * write/hide/unhide, so this constant actively gates the sort now.
     */
    public const MIN_REVIEWS_FOR_RATING_SORT = 5;

    public function __construct(private readonly ZoneMatcher $zoneMatcher)
    {
    }

    /**
     * @return array{zone: ?Zone, paginator: ?LengthAwarePaginator}
     */
    public function search(
        int $subcategoryId,
        ?float $lat,
        ?float $lng,
        ?string $pincode,
        int $perPage = 15,
    ): array {
        $zone = null;

        if ($lat !== null && $lng !== null) {
            $zone = $this->zoneMatcher->matchPoint($lat, $lng);
        }

        if ($zone === null && $pincode !== null) {
            $zone = $this->zoneMatcher->matchPincode($pincode);
        }

        if ($zone === null) {
            // Not an error — mirrors CustomerController::updateLocation()'s
            // same "no match" outcome.
            return ['zone' => null, 'paginator' => null];
        }

        // A vendor has at most one active+unexpired subscription at a
        // time (renewal creates a fresh row; the old one is superseded,
        // never left running alongside it — see Subscription's own
        // docblock), so this join can't multiply rows per vendor and
        // needs no distinct()/groupBy().
        $paginator = Vendor::query()
            // Vendor::scopeActive() leaves 'status'/'is_suspended'
            // unqualified, which becomes ambiguous once subscriptions
            // (its own 'status' column) is joined in — qualified here
            // instead, same predicate the scope itself uses.
            ->where('vendors.status', 'active')
            ->where('vendors.is_suspended', false)
            ->join('subscriptions', 'subscriptions.vendor_id', '=', 'vendors.id')
            ->join('plan_quotas', 'plan_quotas.plan_id', '=', 'subscriptions.plan_id')
            ->where('subscriptions.status', 'active')
            ->where('subscriptions.end_date', '>=', now())
            // A raw join bypasses Subscription's own SoftDeletes global
            // scope, so it's re-applied explicitly here.
            ->whereNull('subscriptions.deleted_at')
            ->whereExists(fn ($query) => $query->selectRaw(1)
                ->from('subscription_items')
                ->whereColumn('subscription_items.subscription_id', 'subscriptions.id')
                ->where('subscription_items.item_type', 'subcategory')
                ->where('subscription_items.item_id', $subcategoryId))
            ->whereExists(fn ($query) => $query->selectRaw(1)
                ->from('subscription_items')
                ->whereColumn('subscription_items.subscription_id', 'subscriptions.id')
                ->where('subscription_items.item_type', 'zone')
                ->where('subscription_items.item_id', $zone->id))
            ->select('vendors.*')
            ->orderBy('plan_quotas.priority_rank')
            ->orderByRaw(
                'CASE WHEN vendors.rating_count >= ? THEN vendors.rating_avg ELSE 0 END DESC',
                [self::MIN_REVIEWS_FOR_RATING_SORT]
            )
            ->orderByDesc('vendors.created_at')
            ->paginate($perPage);

        return ['zone' => $zone, 'paginator' => $paginator];
    }
}
