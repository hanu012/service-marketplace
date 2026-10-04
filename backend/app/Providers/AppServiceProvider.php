<?php

namespace App\Providers;

use App\Http\Responses\ApiResponse;
use Filament\Resources\Resource;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiters();
        $this->configureAuthorization();
    }

    /**
     * Makes a missing policy DENY rather than allow.
     *
     * Filament's default is the opposite: `Filament\authorize()` with
     * shouldCheckPolicyExistence = true falls through to before-callbacks
     * when no policy exists, which permits the action. That means a resource
     * added without a policy is silently open to every sub-admin, and nothing
     * in the panel indicates it.
     *
     * With this off, Filament goes straight to Gate, where a model with no
     * policy is denied. A new resource without a policy is then visibly
     * broken for everyone — including whoever is building it — instead of
     * quietly ungoverned. PolicyCoverageTest asserts none are missing.
     */
    private function configureAuthorization(): void
    {
        Resource::checkPolicyExistence(false);
    }

    private function configureRateLimiters(): void
    {
        // Note: login is deliberately NOT limited here. Throttle middleware
        // counts every request, including successful sign-ins; the login
        // limiter lives in AuthController so only failed attempts count.

        // Looser cap on signups to blunt automated account creation.
        RateLimiter::for('register', function (Request $request) {
            return Limit::perHour(10)
                ->by($request->ip())
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many registration attempts. Please try again later.',
                    429
                ));
        });

        // Changing your own password — the only password route left now
        // that there is no emailed reset. Keyed on the authenticated user
        // rather than email+IP: the request carries no email, and the
        // caller is already identified by their token. Caps brute forcing
        // of current_password from a stolen device.
        RateLimiter::for('change-password', function (Request $request) {
            return Limit::perHour(6)
                ->by((string) ($request->user()?->getKey() ?? $request->ip()))
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again later.',
                    429
                ));
        });

        // Unauthenticated read endpoints such as the category tree. Generous,
        // because the apps fetch this on launch and it is cheap to serve —
        // the cap exists to blunt scraping, not to ration normal use.
        RateLimiter::for('public-read', function (Request $request) {
            return Limit::perMinute(60)
                ->by($request->ip())
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many requests. Please try again shortly.',
                    429
                ));
        });

        // Keyed on the authenticated actor, not IP: a salesman legitimately
        // retries the same sale on a bad connection (idempotency handles
        // dedup), so this exists to blunt abuse, not field retries.
        RateLimiter::for('subscribe', function (Request $request) {
            return Limit::perMinute(20)
                ->by((string) ($request->user()?->getKey() ?? $request->ip()))
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again shortly.',
                    429
                ));
        });

        // Keyed on the authenticated customer, same reasoning as
        // 'subscribe' — a legitimate retry after a dropped response should
        // not be blocked, this exists to blunt a customer flooding the
        // leads table by mashing Call/WhatsApp, not to ration normal use.
        RateLimiter::for('leads', function (Request $request) {
            return Limit::perMinute(20)
                ->by((string) ($request->user()?->getKey() ?? $request->ip()))
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again shortly.',
                    429
                ));
        });

        // Same shape as 'leads' — covers review create/edit and vendor
        // reply, keyed on the authenticated actor.
        RateLimiter::for('reviews', function (Request $request) {
            return Limit::perMinute(20)
                ->by((string) ($request->user()?->getKey() ?? $request->ip()))
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again shortly.',
                    429
                ));
        });

        // A toggle a customer could tap repeatedly — same reasoning and
        // shape as 'leads'/'reviews', blunts abuse without rationing
        // normal use.
        RateLimiter::for('favorites', function (Request $request) {
            return Limit::perMinute(30)
                ->by((string) ($request->user()?->getKey() ?? $request->ip()))
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again shortly.',
                    429
                ));
        });

        // Tighter than 'favorites': reporting is rarer and the unique
        // (customer_id, vendor_id) pair already caps repeats against the
        // same vendor, so this only needs to blunt a burst across many
        // vendors.
        RateLimiter::for('reports', function (Request $request) {
            return Limit::perMinute(10)
                ->by((string) ($request->user()?->getKey() ?? $request->ip()))
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again shortly.',
                    429
                ));
        });

        // Clicks are anonymous by nature (no token to key on, unlike
        // leads/reviews), so per-IP like public-read — generous enough
        // for genuine repeat taps across several banners, tight enough
        // to blunt a script inflating one banner's count.
        RateLimiter::for('banner-click', function (Request $request) {
            return Limit::perMinute(30)
                ->by($request->ip())
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many requests. Please try again shortly.',
                    429
                ));
        });
    }
}
