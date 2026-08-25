<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SalesmanVendorResource;
use App\Http\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * A salesman's own records — My Vendors and Earnings (SPEC sections 2.3,
 * 2.4). The first `/me/...` routes in this API: everything here is scoped
 * to $request->user()->salesman, never to a route-bound id, so there is no
 * ownership check to get wrong.
 */
class SalesmanController extends Controller
{
    /**
     * My Vendors: name, plan, days to expiry. See SalesmanVendorResource
     * for why leads-this-month is absent and why this isn't filtered to
     * active-only.
     */
    public function vendors(Request $request): JsonResponse
    {
        $vendors = $request->user()->salesman->vendors()
            ->with(['subscriptions' => fn ($query) => $query->with('plan')->latest('end_date')])
            ->orderBy('business_name')
            ->get();

        return ApiResponse::success(SalesmanVendorResource::collection($vendors));
    }

    /**
     * Earnings: pending/paid commission totals only. SPEC section 2.4 also
     * lists "monthly target vs achieved" and "cash collected but not yet
     * reconciled" — both deliberately out of this endpoint. The target
     * comparison needs a policy decision (commission earned vs. revenue
     * sold this month aren't the same number) that hasn't been made yet;
     * the cash-reconciliation view is a separate, unrelated feature.
     */
    public function commissions(Request $request): JsonResponse
    {
        $commissions = $request->user()->salesman->commissions();

        return ApiResponse::success([
            'pending_amount_paise' => (int) (clone $commissions)->where('status', 'pending')->sum('amount_paise'),
            'paid_amount_paise' => (int) (clone $commissions)->where('status', 'paid')->sum('amount_paise'),
            'pending_count' => (clone $commissions)->where('status', 'pending')->count(),
            'paid_count' => (clone $commissions)->where('status', 'paid')->count(),
        ]);
    }
}
