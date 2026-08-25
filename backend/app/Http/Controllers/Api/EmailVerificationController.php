<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ResendVerificationRequest;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EmailVerificationController extends Controller
{
    /**
     * Consumes the signed verification link.
     *
     * The route carries the `signed` middleware, so a tampered or expired URL
     * never reaches this method. The hash check below additionally ties the
     * link to the address it was issued for, so a link stays invalid if the
     * user changed their email after it was sent.
     */
    public function verify(Request $request, string $id, string $hash): JsonResponse
    {
        $user = User::find($id);

        if (! $user || ! hash_equals($hash, sha1($user->getEmailForVerification()))) {
            return ApiResponse::error(
                'INVALID_VERIFICATION_LINK',
                'This verification link is invalid or has expired.',
                422
            );
        }

        if ($user->hasVerifiedEmail()) {
            return ApiResponse::success([
                'message' => 'This email address is already verified.',
                'already_verified' => true,
            ]);
        }

        $user->markEmailAsVerified();

        event(new Verified($user));

        return ApiResponse::success([
            'message' => 'Your email address has been verified. You can now sign in.',
            'already_verified' => false,
        ]);
    }

    /**
     * Re-sends the verification email.
     *
     * Deliberately works without a token. A vendor who never received the
     * first email cannot log in (SPEC section 3.1 blocks unverified vendors),
     * so requiring authentication here would leave them with no way out.
     * An authenticated caller is used when present; otherwise the address in
     * the body is used.
     *
     * The response is identical whether or not the account exists, and whether
     * or not it is already verified, so this cannot enumerate users.
     */
    public function resend(ResendVerificationRequest $request): JsonResponse
    {
        $user = $request->user()
            ?? User::where('email', $request->string('email')->toString())->first();

        if ($user && ! $user->hasVerifiedEmail()) {
            $user->sendEmailVerificationNotification();
        }

        return ApiResponse::success([
            'message' => 'If that email address needs verification, a new link has been sent.',
        ]);
    }
}
