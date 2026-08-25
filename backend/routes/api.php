<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BannerController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\ChangePasswordController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\Api\DeleteAccountController;
use App\Http\Controllers\Api\EmailVerificationController;
use App\Http\Controllers\Api\FavoriteController;
use App\Http\Controllers\Api\LeadController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\PlanController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Controllers\Api\SalesmanController;
use App\Http\Controllers\Api\SettingController;
use App\Http\Controllers\Api\SubscriptionController;
use App\Http\Controllers\Api\VendorController;
use App\Http\Controllers\Api\VendorDetailController;
use App\Http\Controllers\Api\VendorDraftController;
use App\Http\Controllers\Api\VendorLeadController;
use App\Http\Controllers\Api\VendorPortfolioController;
use App\Http\Controllers\Api\VendorReviewController;
use App\Http\Controllers\Api\VendorSearchController;
use App\Http\Controllers\Api\ZoneController;
use App\Http\Middleware\HandleIdempotentAddonPurchase;
use App\Http\Middleware\HandleIdempotentSubscription;
use App\Http\Resources\UserResource;
use App\Http\Responses\ApiResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register'])
        ->middleware('throttle:register');

    // No throttle middleware here on purpose: the limiter is applied inside
    // AuthController::login so that only *failed* attempts are counted.
    Route::post('/login', [AuthController::class, 'login']);

    Route::post('/logout', [AuthController::class, 'logout'])
        ->middleware('auth:sanctum');

    // Changing your own password while signed in, as opposed to the emailed
    // reset flow. This is the way out of a forced change (SPEC section 2.1),
    // so RequirePasswordChange deliberately lets it through.
    Route::post('/change-password', ChangePasswordController::class)
        ->middleware(['auth:sanctum', 'throttle:change-password']);

    Route::post('/forgot-password', [PasswordResetController::class, 'forgotPassword'])
        ->middleware('throttle:password-email');

    Route::post('/reset-password', [PasswordResetController::class, 'resetPassword'])
        ->middleware('throttle:password-email');

    // `signed` rejects tampered or expired links before the controller runs.
    Route::get('/verify-email/{id}/{hash}', [EmailVerificationController::class, 'verify'])
        ->middleware(['signed', 'throttle:verification'])
        ->name('verification.verify');

    // Intentionally unauthenticated: a vendor blocked from logging in for
    // want of verification still needs a way to request a fresh link.
    Route::post('/resend-verification', [EmailVerificationController::class, 'resend'])
        ->middleware('throttle:verification');
});

// Public master data. No token: customers browse categories before signing
// in, and the vendor/salesman apps need the tree to render plan selection.
Route::get('/categories', [CategoryController::class, 'index'])
    ->middleware('throttle:public-read');

Route::get('/plans', [PlanController::class, 'index'])
    ->middleware('throttle:public-read');

Route::get('/zones', [ZoneController::class, 'index'])
    ->middleware('throttle:public-read');

Route::get('/settings', [SettingController::class, 'index'])
    ->middleware('throttle:public-read');

// Banner serving + click tracking (SPEC section 5 item 5). Public,
// same reasoning as the master-data reads above — no Flutter display
// work exists yet to consume this (SPEC never specifies where/how a
// banner renders in any app flow); this is the minimal API that makes
// click_count a real counter instead of a decorative admin field.
Route::get('/banners', [BannerController::class, 'index'])
    ->middleware('throttle:public-read');

Route::post('/banners/{banner}/click', [BannerController::class, 'click'])
    ->middleware('throttle:banner-click');

// The core customer vendor-matching query (SPEC section 4 item 4, task
// 5.3). Public, not scoped to a caller — location is always an explicit
// param, never resolved from a stored profile. MUST be registered before
// GET /vendors/{vendor} below, same wildcard-shadowing reason as
// /vendors/me.
Route::get('/vendors/search', [VendorSearchController::class, 'index'])
    ->middleware('throttle:public-read');

// Public vendor detail page (SPEC section 4 item 6, task 5.4) — same
// "explicit param, not self-resolved" location reasoning as
// /vendors/search above. No ordering hazard with /vendors/{vendor}
// below: different path depth, same as /vendors/{vendor}/kyc already
// coexisting with it.
Route::get('/vendors/{vendor}/detail', [VendorDetailController::class, 'show'])
    ->middleware('throttle:public-read');

// A vendor's own record (SPEC section 3.2) — MUST be registered before
// GET /vendors/{vendor} below, or "me" would be matched as a vendor id by
// that wildcard route instead of ever reaching this one.
Route::middleware(['auth:sanctum', 'role:vendor'])->group(function () {
    Route::get('/vendors/me', [VendorController::class, 'me']);

    // Adding within remaining quota on the vendor's own active subscription
    // (SPEC section 3.3, task 4.4) — distinct from POST /subscriptions,
    // which only ever creates a fresh one for a `draft` vendor. No
    // Idempotency-Key: unlike subscribe, there's no payment/commission
    // side effect, and the diff-based insert is naturally idempotent.
    Route::post('/vendors/me/services', [VendorController::class, 'addServices']);

    // Portfolio media (SPEC section 3 item 5, task 4.5) — photos/videos of
    // completed work, quota-capped by the active subscription's plan, same
    // "resolve everything from the caller" shape as the two routes above.
    Route::get('/vendors/me/portfolio', [VendorPortfolioController::class, 'index']);
    Route::post('/vendors/me/portfolio', [VendorPortfolioController::class, 'store']);

    // A vendor's right of reply on a review of their own listing (SPEC
    // section 4 item 9, task 5.5), and the vendor's own unfiltered
    // Reviews tab (SPEC section 3 item 8, task 4.8).
    Route::get('/vendors/me/reviews', [VendorReviewController::class, 'index']);
    Route::post('/vendors/me/reviews/{review}/reply', [VendorReviewController::class, 'reply'])
        ->middleware('throttle:reviews');

    // The Leads tab (SPEC section 3 item 7) and "Request a review"
    // (SPEC section 3 item 8), task 4.8. Neither is money-bearing, so
    // no Idempotency-Key/throttle beyond the standard sanctum guard —
    // same shape as /vendors/me/services and /vendors/me/portfolio.
    Route::get('/vendors/me/leads', [VendorLeadController::class, 'index']);
    Route::post('/vendors/me/leads/{lead}/request-review', [VendorLeadController::class, 'requestReview']);
});

// A customer's own record (SPEC section 4.2, task 4.6) — location
// detection for the home screen header, GPS point or pincode fallback.
Route::middleware(['auth:sanctum', 'role:customer'])->group(function () {
    Route::post('/customers/me/location', [CustomerController::class, 'updateLocation']);

    // SPEC section 4 item 7, task 5.4 — the write the vendor-detail
    // screen's Call/WhatsApp buttons must complete and confirm BEFORE
    // opening the dialer/WhatsApp intent.
    Route::post('/leads', [LeadController::class, 'store'])
        ->middleware('throttle:leads');

    // SPEC section 9, task 5.5 — write and 24-hour edit window. Both
    // routes resolve everything from the caller's token (never a
    // client-sent customer_id), same "resolve everything from the
    // caller" shape as /vendors/me/*.
    Route::post('/reviews', [ReviewController::class, 'store'])
        ->middleware('throttle:reviews');
    Route::patch('/reviews/{review}', [ReviewController::class, 'update'])
        ->middleware('throttle:reviews');

    // Favorites (SPEC section 4 item 10). A toggle rather than separate
    // favorite/unfavorite routes — the caller only ever needs "is it
    // favorited now." is_favorite itself surfaces on the public
    // /vendors/search and /vendors/{vendor}/detail responses too, via
    // ResolvesOptionalAuthUser — those two stay outside this group since
    // they must keep working for a guest.
    Route::post('/vendors/{vendor}/favorite', [FavoriteController::class, 'toggle'])
        ->middleware('throttle:favorites');
    Route::get('/customers/me/favorites', [FavoriteController::class, 'index']);

    // Report vendor (SPEC section 4 item 10 / section 5.15) — minimal,
    // see ReportController's own docblock. Not the full Support Tickets
    // module (Phase 6).
    Route::post('/vendors/{vendor}/report', [ReportController::class, 'store'])
        ->middleware('throttle:reports');
});

// Salesman add-vendor flow (SPEC section 2.2). Admin included because
// User Management can create vendors too (SPEC section 5.2). Vendor
// deliberately NOT included here — these three routes act on a vendor
// someone else is managing, not the caller's own record.
Route::middleware(['auth:sanctum', 'role:salesman,admin'])->group(function () {
    Route::post('/vendors/draft', [VendorDraftController::class, 'store']);
    Route::post('/vendors/{vendor}/kyc', [VendorDraftController::class, 'storeKyc']);
    Route::get('/vendors/{vendor}', [VendorDraftController::class, 'show']);
});

// Subscribe (SPEC section 6) — salesman/admin-led (source=salesman/admin)
// AND vendor self-service (source=self, task 4.2). A vendor caller is
// restricted to payment_mode=online and can only subscribe their own
// vendor_id — both enforced in StoreSubscriptionRequest, not by the role
// gate here. HandleIdempotentSubscription runs before StoreSubscriptionRequest
// is ever resolved, so a replayed Idempotency-Key never touches validation
// rules that the first, successful call itself invalidated.
Route::middleware(['auth:sanctum', 'role:salesman,admin,vendor'])->group(function () {
    Route::post('/subscriptions', [SubscriptionController::class, 'store'])
        ->middleware(['throttle:subscribe', HandleIdempotentSubscription::class]);

    // Upgrade/downgrade and add-on (SPEC section 3 item 6 / section 6,
    // task 4.7) — same dual-path role gate as fresh subscribe, since
    // both are money-bearing (unlike task 4.4's free add-services,
    // which stays vendor-only). Ownership/payment-mode restrictions are
    // enforced in the request classes, not this gate, same shape as
    // StoreSubscriptionRequest.
    Route::post('/subscriptions/{subscription}/change-plan', [SubscriptionController::class, 'changePlan'])
        ->middleware(['throttle:subscribe', HandleIdempotentSubscription::class]);
    Route::post('/subscriptions/{subscription}/add-ons', [SubscriptionController::class, 'addOns'])
        ->middleware(['throttle:subscribe', HandleIdempotentAddonPurchase::class]);
});

// A salesman's own records (SPEC sections 2.3, 2.4) — never admin, since
// there is no "own vendors" concept for an admin here.
Route::middleware(['auth:sanctum', 'role:salesman'])->group(function () {
    Route::get('/salesmen/me/vendors', [SalesmanController::class, 'vendors']);
    Route::get('/salesmen/me/commissions', [SalesmanController::class, 'commissions']);
});

Route::get('/user', function (Request $request) {
    return ApiResponse::success(new UserResource($request->user()));
})->middleware('auth:sanctum');

// Self-service account deletion (SPEC section 4 item 10, "required for
// app store compliance"). Deliberately excludes admin — closed by
// decision, not by omission, even though no admin self-delete path
// exists today.
Route::delete('/user', DeleteAccountController::class)
    ->middleware(['auth:sanctum', 'role:vendor,salesman,customer']);
