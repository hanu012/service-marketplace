<?php

namespace App\Policies;

use App\Models\PasswordResetRequest;
use App\Models\User;

/**
 * Reset requests are user management, so they ride on the `users`
 * permissions rather than a module of their own.
 *
 * Acting on one is gated exactly like editing its user (UserPolicy::update):
 * a sub-admin with users.update can handle a vendor's request, but only a
 * super-admin can issue a password for an admin account — the same
 * escalation guard as the Users list's own Reset password.
 */
class PasswordResetRequestPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasPermission('users.viewAny');
    }

    public function view(User $user, PasswordResetRequest $request): bool
    {
        return $this->viewAny($user);
    }

    public function update(User $user, PasswordResetRequest $request): bool
    {
        return $request->user !== null && $user->can('update', $request->user);
    }
}
