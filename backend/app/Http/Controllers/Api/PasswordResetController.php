<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;

class PasswordResetController extends Controller
{
    /**
     * Emails a reset link.
     *
     * Always answers with the same message, whether or not the address has an
     * account, so this endpoint cannot be used to enumerate registered users.
     * The same reasoning governs the login endpoint.
     */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        Password::sendResetLink($request->only('email'));

        return ApiResponse::success([
            'message' => 'If that email address has an account, a reset link has been sent.',
        ]);
    }

    /**
     * Consumes a reset token and sets the new password.
     *
     * Tokens are single-use — Laravel's broker deletes the row on success —
     * and expire after config('auth.passwords.users.expire') minutes, set to
     * 15 for this project.
     */
    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password) {
                $user->forceFill([
                    'password' => $password,
                    'remember_token' => Str::random(60),
                ])->save();

                // A password reset is the standard response to a suspected
                // compromise, so every existing device token is revoked. The
                // user signs in again to get a fresh one.
                $user->tokens()->delete();

                event(new PasswordReset($user));
            }
        );

        if ($status !== Password::PasswordReset) {
            return ApiResponse::error(
                'INVALID_RESET_TOKEN',
                'This password reset link is invalid or has expired.',
                422
            );
        }

        return ApiResponse::success([
            'message' => 'Your password has been reset. Please sign in again.',
        ]);
    }
}
