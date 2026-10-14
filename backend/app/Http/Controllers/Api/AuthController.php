<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Http\Responses\ApiResponse;
use App\Models\Customer;
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

        // A token is issued even though the account is not approved yet,
        // and that is the point: the app has to be able to sign in far
        // enough to show the "awaiting verification" screen and to offer a
        // way out. Withholding it would leave the user at the login screen
        // with no explanation of why their new account does not work.
        //
        // The token is not a loophole — RequireApprovedAccount rejects
        // every call it can make except logout, reading its own profile,
        // registering for push, and deleting the account.
        return ApiResponse::success([
            'user' => new UserResource($user),
            'token' => $this->issueToken($user, $request->string('device_name')->toString()),
            'message' => 'Your account has been created and is awaiting verification by an administrator.',
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

        // No approval check here, deliberately. An unapproved account signs
        // in and receives a working token so the app can show it the
        // pending screen; RequireApprovedAccount is what actually holds the
        // line on every other route. Refusing the token here instead would
        // put us back to a user who cannot be told why they are stuck.
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
