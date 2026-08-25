<?php

namespace App\Providers;

use App\Http\Responses\ApiResponse;
use Filament\Resources\Resource;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;

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
        $this->configureNotificationUrls();
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

    /**
     * Points reset and verification links at FRONTEND_URL when it is set, so
     * the emails can be aimed at a deep link or web page later without any
     * code change. Falls back to APP_URL, which keeps the links resolvable
     * against the API itself during local development.
     */
    private function configureNotificationUrls(): void
    {
        $frontend = rtrim((string) config('app.frontend_url'), '/');

        ResetPassword::createUrlUsing(function (object $notifiable, string $token) use ($frontend) {
            $query = http_build_query([
                'token' => $token,
                'email' => $notifiable->getEmailForPasswordReset(),
            ]);

            return $frontend
                ? $frontend.'/reset-password?'.$query
                : url('/api/auth/reset-password?'.$query);
        });

        // Laravel's stock verification email says nothing about expiry. State
        // it, and derive the wording from the config so the two cannot drift
        // apart if the window is ever changed.
        VerifyEmail::toMailUsing(function (object $notifiable, string $url) {
            $minutes = (int) config('auth.verification.expire', 60);

            // Built by hand rather than with Str::plural()'s count-prefix
            // mode, which routes through Number::format and hard-requires the
            // intl extension — not loaded on the XAMPP PHP this runs on.
            $window = $minutes % 60 === 0
                ? ($hours = intdiv($minutes, 60)).' '.Str::plural('hour', $hours)
                : $minutes.' '.Str::plural('minute', $minutes);

            return (new MailMessage)
                ->subject('Verify Email Address')
                ->line('Please click the button below to verify your email address.')
                ->action('Verify Email Address', $url)
                ->line("This verification link will expire in {$window}.")
                ->line('If you did not create an account, no further action is required.');
        });

        VerifyEmail::createUrlUsing(function (object $notifiable) use ($frontend) {
            // Always a signed URL — the route rejects anything tampered with
            // or past its expiry.
            $signed = URL::temporarySignedRoute(
                'verification.verify',
                now()->addMinutes((int) config('auth.verification.expire', 60)),
                [
                    'id' => $notifiable->getKey(),
                    'hash' => sha1($notifiable->getEmailForVerification()),
                ]
            );

            if (! $frontend) {
                return $signed;
            }

            // Hand the signed URL to the frontend intact so it can forward the
            // call to the API after showing the user something friendlier.
            return $frontend.'/verify-email?'.http_build_query(['url' => $signed]);
        });
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

        // Caps outbound reset mail so the endpoint cannot be used to flood a
        // third party's inbox. Keyed on email + IP like the login limiter.
        RateLimiter::for('password-email', function (Request $request) {
            $key = mb_strtolower((string) $request->input('email')).'|'.$request->ip();

            return Limit::perHour(6)
                ->by($key)
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again later.',
                    429
                ));
        });

        // Changing your own password. Keyed on the authenticated user, not
        // on email+IP like the reset limiters: the request carries no email,
        // and the caller is already identified by their token. Caps brute
        // forcing of current_password from a stolen device.
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

        // Same reasoning for verification mail.
        RateLimiter::for('verification', function (Request $request) {
            $key = mb_strtolower((string) $request->input('email')).'|'.$request->ip();

            return Limit::perHour(6)
                ->by($key)
                ->response(fn () => ApiResponse::error(
                    'TOO_MANY_ATTEMPTS',
                    'Too many attempts. Please try again later.',
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
