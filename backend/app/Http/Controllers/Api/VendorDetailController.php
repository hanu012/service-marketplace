<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\ResolvesOptionalAuthUser;
use App\Http\Controllers\Controller;
use App\Http\Requests\Vendor\VendorDetailRequest;
use App\Http\Resources\ReviewResource;
use App\Http\Resources\VendorDetailResource;
use App\Http\Responses\ApiResponse;
use App\Models\Media;
use App\Models\Review;
use App\Models\Subcategory;
use App\Models\SubscriptionItem;
use App\Models\Vendor;
use Illuminate\Http\JsonResponse;

/**
 * Public vendor detail page (SPEC section 4 item 6, task 5.4) — the
 * screen the search-results list (task 5.3) leads into. Reviews (SPEC
 * section 9, task 5.5) filter out anything an admin has hidden — a
 * hidden review is never in the public response, only in the Filament
 * admin list.
 */
class VendorDetailController extends Controller
{
    use ResolvesOptionalAuthUser;

    public function show(int $vendorId, VendorDetailRequest $request): JsonResponse
    {
        // Optional: unauthenticated detail views still work exactly as
        // before (task 5.4), this only adds is_favorite when a valid
        // customer token happens to be presented (favorites task).
        $this->resolveOptionalUser($request);

        $vendor = Vendor::active()->find($vendorId);

        if ($vendor === null) {
            return ApiResponse::error('NOT_FOUND', 'This vendor is not available.', 404);
        }

        // Same visibility floor as vendor search (task 5.3): a vendor
        // without an active, unexpired subscription isn't customer-
        // visible at all, not even to browse.
        $subscription = $vendor->currentActiveSubscription();

        if ($subscription === null) {
            return ApiResponse::error('NOT_FOUND', 'This vendor is not available.', 404);
        }

        $subcategoryIds = SubscriptionItem::where('subscription_id', $subscription->id)
            ->where('item_type', 'subcategory')
            ->pluck('item_id');

        $services = Subcategory::with('category')
            ->whereIn('id', $subcategoryIds)
            ->get()
            ->map(fn (Subcategory $subcategory) => [
                'subcategory_id' => $subcategory->id,
                'name' => $subcategory->name,
                'category_id' => $subcategory->category_id,
                'category_name' => $subcategory->category?->name,
            ])
            ->all();

        $media = $vendor->media()
            ->where('moderation_status', 'approved')
            ->latest('created_at')
            ->get()
            ->map(fn (Media $item) => [
                'id' => $item->id,
                'type' => $item->type,
                'url' => $item->fileUrl(),
                'created_at' => $item->created_at?->toIso8601String(),
            ])
            ->all();

        $reviews = Review::where('vendor_id', $vendor->id)
            ->where('is_hidden', false)
            ->with('customer.user')
            ->latest('created_at')
            ->get()
            ->map(fn (Review $review) => (new ReviewResource($review))->resolve())
            ->all();

        $distanceKm = null;

        if ($request->hasPoint()) {
            $distanceKm = $this->distanceKm(
                (float) $request->input('latitude'),
                (float) $request->input('longitude'),
                (float) $vendor->latitude,
                (float) $vendor->longitude,
            );
        }

        return ApiResponse::success(new VendorDetailResource($vendor, $services, $media, $reviews, $distanceKm));
    }

    /**
     * Straight-line (Haversine) distance in km. Only one caller today —
     * not extracted to a shared class per "no premature abstraction";
     * move it out if a second caller ever needs it.
     */
    private function distanceKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadiusKm = 6371.0;

        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return round($earthRadiusKm * $c, 1);
    }
}
