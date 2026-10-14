<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\RequestPasswordResetRequest;
use App\Http\Responses\ApiResponse;
use App\Models\PasswordResetRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;

/**
 * "Forgot password?" from the apps.
 *
 * Files a request for an admin to issue a temporary password from the panel.
 * Nothing is emailed — the platform sends no mail — and no password changes
 * here: the admin's "Reset password" does that, and sets
 * must_change_password so the user picks their own on next sign-in.
 *
 * The response is identical for a known and an unknown email, so the
 * endpoint cannot be used to discover which addresses have accounts.
 */
class PasswordResetRequestController extends Controller
{
    public function __invoke(RequestPasswordResetRequest $request): JsonResponse
    {
        $user = User::query()
            // The column's collation is case-insensitive, so "Ravi@X.com"
            // still finds ravi@x.com without lowercasing either side.
            ->where('email', $request->string('email')->trim()->toString())
            ->first();

        // A tombstoned (deleted) account never matches — its email was
        // rewritten — so only live accounts can queue a request. One open
        // request per user is enough; asking again changes nothing.
        if ($user !== null && ! PasswordResetRequest::query()->where('user_id', $user->getKey())->pending()->exists()) {
            PasswordResetRequest::create([
                'user_id' => $user->getKey(),
                'ip_address' => $request->ip(),
            ]);
        }

        return ApiResponse::success([
            'message' => 'If an account exists for this email, our team will contact you with a temporary password.',
        ]);
    }
}
