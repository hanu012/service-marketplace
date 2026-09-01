<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Http\Responses\ApiResponse;
use App\Models\Customer;
use App\Models\Setting;
use App\Models\User;
use App\Models\Vendor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;

class AuthController extends Controller
{
    /** Failed login attempts allowed per email + IP before locking out. */
    private const MAX_LOGIN_ATTEMPTS = 5;

    /** How long the lockout lasts, in seconds. */
    private const LOGIN_DECAY_SECONDS = 15 * 60;

    /**
     * Self-registration. RegisterRequest restricts the role to vendor or
     * customer — admin and salesman accounts are created by an admin.
     *
     * A vendor registration also creates a minimal Vendor row in the same
     * transaction — task 3.4 found self-registration created only a User
     * row, leaving self-service subscribe (task 4.2) nothing to attach a
     * subscription to. Same half-applied-create risk VendorDraftService
     * already guards against: a users row with no vendors row is an
     * account nobody can subscribe, and the unique email/phone indexes
     * still hold it.
     *
     * A customer registration creates a matching Customer row the same
     * way (task 4.6) — location (SPEC section 4.2) is captured later via
     * GPS or a pincode fallback, but needs a row to land on.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = DB::transaction(function () use ($request) {
            $user = User::create($request->safe()->only([
                'name', 'email', 'password', 'role',
            ]));

            if ($request->string('role')->toString() === 'vendor') {
                Vendor::create([
                    'user_id' => $user->id,
                    'business_name' => $request->string('business_name')->toString(),
                    // Not a separate field — the salesman-led flow already
                    // treats the account name as the owner's name.
                    'owner_name' => $request->string('name')->toString(),
                    'phone' => $request->string('phone')->toString(),
                    'status' => 'draft',
                ]);
            } elseif ($request->string('role')->toString() === 'customer') {
                Customer::create(['user_id' => $user->id]);
            }

            return $user;
        });

        // Local stopgap until real SMTP is wired up: when the
        // bypass_email_verification setting is on, no email goes out. The
        // account is still created unverified and still gated at login —
        // an admin verifies it by hand from the Users list.
        $bypassVerification = Setting::get('bypass_email_verification', false);

        if (! $bypassVerification) {
            $user->sendEmailVerificationNotification();
        }

        // A vendor who must verify before logging in is not handed a token
        // here — issuing one would let them straight past the very gate
        // login enforces. Customers are not gated, so they sign straight in.
        if ($user->requiresEmailVerification()) {
            return ApiResponse::success([
                'user' => new UserResource($user),
                'token' => null,
                'message' => $bypassVerification
                    ? 'Your account has been created. An administrator will verify it before you can sign in.'
                    : 'Please verify your email address before signing in. '
                        .'A verification link has been sent to you.',
            ], 201);
        }

        return ApiResponse::success([
            'user' => new UserResource($user),
            'token' => $this->issueToken($user, $request->string('device_name')->toString()),
        ], 201);
    }

    /**
     * Verifies credentials and issues a device-scoped token.
     *
     * Rate limiting is applied here rather than by throttle middleware so that
     * only failed attempts count against the budget — a user signing in
     * legitimately across several devices never locks themselves out.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $throttleKey = $this->throttleKey($request);

        if (RateLimiter::tooManyAttempts($throttleKey, self::MAX_LOGIN_ATTEMPTS)) {
            return ApiResponse::error(
                'TOO_MANY_ATTEMPTS',
                'Too many login attempts. Please try again in '
                    .RateLimiter::availableIn($throttleKey).' seconds.',
                429
            );
        }

        $user = User::where('email', $request->string('email')->toString())->first();

        // Hash::check runs even when no user matched, so a missing account and
        // a wrong password take the same time and cannot be told apart.
        $passwordValid = Hash::check(
            $request->string('password')->toString(),
            $user?->password ?? ''
        );

        if (! $user || ! $passwordValid) {
            RateLimiter::hit($throttleKey, self::LOGIN_DECAY_SECONDS);

            return ApiResponse::error(
                'INVALID_CREDENTIALS',
                'These credentials do not match our records.',
                401
            );
        }

        // A successful sign-in wipes the slate for this email + IP.
        RateLimiter::clear($throttleKey);

        // SPEC section 3.1 / section 7: a self-registered vendor stays locked
        // out until the address is confirmed. Checked only after the password
        // is verified, so it never reveals anything about an account to
        // someone who does not already hold the credentials.
        if ($user->requiresEmailVerification()) {
            return ApiResponse::error(
                'EMAIL_NOT_VERIFIED',
                'Please verify your email address before signing in.',
                403
            );
        }

        return ApiResponse::success([
            'user' => new UserResource($user),
            'token' => $this->issueToken($user, $request->string('device_name')->toString()),
        ]);
    }

    /**
     * Revokes only the token used for this request, leaving the user's other
     * devices signed in.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return ApiResponse::success(null);
    }

    /**
     * CLAUDE.md: one personal access token per device. Re-authenticating on a
     * device replaces that device's token rather than accumulating a new one
     * on every login.
     */
    private function issueToken(User $user, string $deviceName): string
    {
        $user->tokens()->where('name', $deviceName)->delete();

        return $user->createToken($deviceName, ['role:'.$user->role->value])->plainTextToken;
    }

    /**
     * Keyed on email + IP: keying on IP alone would let one attacker behind a
     * shared NAT lock out everyone on it, and email alone would let an
     * attacker lock out a known victim at will.
     */
    private function throttleKey(Request $request): string
    {
        return 'login|'
            .mb_strtolower($request->string('email')->toString())
            .'|'.$request->ip();
    }
}
