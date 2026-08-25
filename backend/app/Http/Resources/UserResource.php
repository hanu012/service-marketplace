<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Explicit allow-list of user fields exposed over the API, so columns added
 * in later phases are never leaked to clients by default.
 */
class UserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role->value,
            // Drives the forced change-password screen on first login
            // (SPEC section 2.1). Enforced server-side too - see
            // RequirePasswordChange middleware.
            'must_change_password' => (bool) $this->must_change_password,
            'email_verified_at' => $this->email_verified_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
