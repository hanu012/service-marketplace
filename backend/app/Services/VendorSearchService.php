<?php

namespace App\Services;

use App\Models\Setting;
use App\Models\Vendor;
use App\Models\Zone;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Carbon;

/**
 * SPEC section 4 item 4's match query: `subcategory = X AND zone contains
 * customer_location AND vendor.status = active AND subscription.end_date
 * >= today`, sorted per section 4 item 5.
 *
 * WIDENED beyond that literal wording (task 7.1): SPEC section 7 and
 * BUILD_PLAN 7.1/8.2 both make clear that Grace is a still-visible
 * renewal window — only Expired actually drops a vendor from search.
 * A flat `end_date >= today` can never be true once a subscription is
 * genuinely in `grace` (its end_date is, by definition, already in
 * the past), so the bound below is conditional on status instead:
 * `active` rows still need `end_date >= today` (a same-day safety net
 * for the gap before the nightly expiry job runs), `grace` rows are
 * bounded by `end_date >= today - grace_period_days` instead.
 * `Vendor::currentActiveSubscription()` applies the identical bound —
 * see that method's docblock — since it backs the vendor detail page,
 * which is meant to stay in lockstep with this query.
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

        $today = Carbon::today();
        $gracePeriodDays = (int) Setting::get('grace_period_days', 7);
        $graceCutoff = $today->copy()->subDays($gracePeriodDays);

        // A vendor has at most one active+unexpired subscription at a
        // time (renewal creates a fresh row; the old one is superseded,
        // never left running alongside it — see Subscription's own
        // docblock), so this join can't multiply rows per vendor and
        // needs no distinct()/groupBy().
        $paginator = Vendor::query()
            // Vendor::scopeActive() leaves 'status'/'is_suspended'
            // unqualified, which becomes ambiguous once subscriptions
            // (its own 'status' column) is joined in — qualified here
            // instead. Widened to include 'grace' — see class docblock.
            ->whereIn('vendors.status', ['active', 'grace'])
            ->where('vendors.is_suspended', false)
            ->join('subscriptions', 'subscriptions.vendor_id', '=', 'vendors.id')
            ->join('plan_quotas', 'plan_quotas.plan_id', '=', 'subscriptions.plan_id')
            ->whereIn('subscriptions.status', ['active', 'grace'])
            ->where(function ($query) use ($today, $graceCutoff) {
                $query->where(function ($active) use ($today) {
                    $active->where('subscriptions.status', 'active')
                        ->where('subscriptions.end_date', '>=', $today);
                })->orWhere(function ($grace) use ($graceCutoff) {
                    $grace->where('subscriptions.status', 'grace')
                        ->where('subscriptions.end_date', '>=', $graceCutoff);
                });
            })
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
