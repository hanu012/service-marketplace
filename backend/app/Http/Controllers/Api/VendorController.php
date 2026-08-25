<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Subscription\AddSubscriptionItemsRequest;
use App\Http\Resources\VendorResource;
use App\Http\Responses\ApiResponse;
use App\Models\Category;
use App\Models\Media;
use App\Models\Subcategory;
use App\Models\SubscriptionItem;
use App\Models\Vendor;
use App\Models\Zone;
use App\Services\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

/**
 * A vendor's own record (SPEC section 3.2) — the first stop for the vendor
 * app on login: has_active_subscription decides plan-selection vs
 * dashboard, and when there is one, the dashboard needs its plan name,
 * quota used/total, and days remaining. Also owns addServices() (task 4.4)
 * — filling remaining quota on the same active subscription later.
 */
class VendorController extends Controller
{
    public function __construct(private readonly SubscriptionService $subscriptions)
    {
    }

    /**
     * 404 rather than an empty success: a vendor-role User with no Vendor
     * row is a real, if rare, possibility (e.g. one created outside this
     * flow, such as via User Management) — not a state the caller should
     * be able to mistake for "no subscription yet."
     */
    public function me(Request $request): JsonResponse
    {
        $vendor = $request->user()->vendor;

        if ($vendor === null) {
            return ApiResponse::error('NOT_FOUND', 'No vendor profile exists for this account.', 404);
        }

        return ApiResponse::success([
            'vendor' => new VendorResource($vendor->load('user')),
            'active_subscription' => $this->activeSubscriptionSummary($vendor),
        ]);
    }

    /**
     * Adds categories/subcategories/zones to the caller's own active
     * subscription, within whatever quota is still unused (SPEC section
     * 3.3, task 4.4) — distinct from POST /subscriptions, which only ever
     * creates a fresh subscription for a `draft` vendor. Never removes an
     * existing selection: AddSubscriptionItemsRequest only ever computes
     * ids to ADD, so there is no code path here that could drop one.
     */
    public function addServices(AddSubscriptionItemsRequest $request): JsonResponse
    {
        $vendor = $request->user()->vendor;

        $this->subscriptions->addItems(
            $request->subscription(),
            $request->newCategoryIds(),
            $request->newSubcategoryIds(),
            $request->newZoneIds(),
        );

        return ApiResponse::success([
            'active_subscription' => $this->activeSubscriptionSummary($vendor->fresh()),
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    private function activeSubscriptionSummary(Vendor $vendor): ?array
    {
        $subscription = $vendor->currentActiveSubscription();

        if ($subscription === null || $subscription->plan->quota === null) {
            return null;
        }

        $itemIdsByType = SubscriptionItem::query()
            ->where('subscription_id', $subscription->id)
            ->get(['item_type', 'item_id'])
            ->groupBy('item_type')
            ->map(fn (Collection $rows) => $rows->pluck('item_id')->all());

        $mediaCounts = $this->mediaCountsByType($vendor);

        return [
            'plan_name' => $subscription->plan->name,
            'end_date' => $subscription->end_date->toDateString(),
            'days_remaining' => now()->startOfDay()->diffInDays($subscription->end_date, absolute: false),
            // effectiveQuota() (task 4.7) folds in any purchased add-on
            // quantity on top of the bare plan limit — otherwise this
            // summary would show a "used" count over its displayed
            // "max" the moment an add-on lets a vendor exceed the bare
            // plan limit.
            'quota' => [
                'categories' => [
                    'used' => count($itemIdsByType['category'] ?? []),
                    'max' => $subscription->effectiveQuota('categories'),
                ],
                'subcategories' => [
                    'used' => count($itemIdsByType['subcategory'] ?? []),
                    'max' => $subscription->effectiveQuota('subcategories'),
                ],
                'zones' => [
                    'used' => count($itemIdsByType['zone'] ?? []),
                    'max' => $subscription->effectiveQuota('zones'),
                ],
                // task 4.5: pending + approved count as used, only a
                // rejected upload frees its slot back up (see
                // StorePortfolioMediaRequest).
                'photos' => [
                    'used' => $mediaCounts['image'] ?? 0,
                    'max' => $subscription->effectiveQuota('photos'),
                ],
                'videos' => [
                    'used' => $mediaCounts['video'] ?? 0,
                    'max' => $subscription->effectiveQuota('videos'),
                ],
            ],
            // Names, not just counts (task 4.4's Services tab needs to show
            // what's actually selected) — deliberately NOT filtered to
            // currently-active rows: deactivating a category/zone doesn't
            // retroactively drop a vendor's existing selection, same
            // reasoning CategoryResource documents for its own no-delete
            // stance.
            'items' => [
                'categories' => $this->namedItems(Category::class, $itemIdsByType['category'] ?? []),
                'subcategories' => $this->namedItems(Subcategory::class, $itemIdsByType['subcategory'] ?? []),
                'zones' => $this->namedItems(Zone::class, $itemIdsByType['zone'] ?? []),
            ],
        ];
    }

    /**
     * @param  class-string  $modelClass
     * @param  array<int, int>  $ids
     * @return array<int, array<string, mixed>>
     */
    private function namedItems(string $modelClass, array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        return $modelClass::query()
            ->whereIn('id', $ids)
            ->orderBy('name')
            ->get(['id', 'name'])
            ->map(fn ($model) => ['id' => $model->id, 'name' => $model->name])
            ->all();
    }

    /**
     * @return array<string, int>
     */
    private function mediaCountsByType(Vendor $vendor): array
    {
        return Media::query()
            ->where('mediable_type', $vendor->getMorphClass())
            ->where('mediable_id', $vendor->id)
            ->where('moderation_status', '!=', 'rejected')
            ->selectRaw('type, count(*) as total')
            ->groupBy('type')
            ->pluck('total', 'type')
            ->all();
    }
}
