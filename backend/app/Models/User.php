<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Enums\Permission;
use App\Enums\UserRole;
use App\Models\Concerns\RecordsAuditLog;
use Database\Factories\UserFactory;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Contracts\Auth\MustVerifyEmail as MustVerifyEmailContract;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\HasApiTokens;
use RuntimeException;

class User extends Authenticatable implements FilamentUser, MustVerifyEmailContract
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable, RecordsAuditLog, SoftDeletes;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'permissions',
        'must_change_password',
    ];

    /**
     * 1:1 profiles. Exactly one is populated, matching the user's role.
     */
    public function salesman(): HasOne
    {
        return $this->hasOne(Salesman::class);
    }

    public function vendor(): HasOne
    {
        return $this->hasOne(Vendor::class);
    }

    public function customer(): HasOne
    {
        return $this->hasOne(Customer::class);
    }

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'role' => UserRole::class,
            'permissions' => 'array',
            'must_change_password' => 'boolean',
        ];
    }

    /**
     * Deletes the account and frees its email address.
     *
     * SPEC section 4.10 requires account deletion for app store compliance,
     * and users.email carries a real unique index that a soft-deleted row
     * keeps occupying — so a plain delete() would bar that person from ever
     * signing up again. The address is rewritten to a tombstone first, and
     * the original is kept in original_email so a restore can put it back.
     *
     * All of it in one transaction: a half-applied delete would either leave
     * a live token against a deleted account or lose the original address.
     */
    public function deleteWithTombstone(): void
    {
        DB::transaction(function () {
            // Keep the real address before overwriting it, unless this row is
            // already tombstoned from an earlier cycle.
            if ($this->original_email === null) {
                $this->original_email = $this->email;
            }

            // id + timestamp makes this unique by construction, so the unique
            // index holds even if the same account is deleted, re-created and
            // deleted again. @deleted.local cannot receive mail, so no
            // notification can ever reach a tombstoned address by accident.
            $this->email = "deleted-{$this->id}-".now()->timestamp.'@deleted.local';

            // saveQuietly: the rename is bookkeeping, not a profile change, and
            // should not fire events that later phases may hang observers off.
            $this->saveQuietly();

            // Otherwise a token on another device keeps authenticating against
            // a deleted account — SoftDeletes hides the user from queries, but
            // an already-issued token does not care.
            $tokensRevoked = $this->tokens()->count();
            $this->tokens()->delete();

            $this->delete();

            // Written explicitly, NOT by the RecordsAuditLog events: the
            // rename above is saveQuietly() and therefore fires nothing, so
            // an event listener would never see the single most audit-worthy
            // change in the system. The values below are the real before and
            // after, which no listener could reconstruct after the fact.
            $this->writeAuditLog(
                'deleted',
                ['email' => $this->original_email, 'deleted_at' => null],
                [
                    'email' => $this->email,
                    'deleted_at' => (string) $this->deleted_at,
                    'tokens_revoked' => $tokensRevoked,
                ],
            );
        });
    }

    /**
     * Restores the account and puts its original email back.
     *
     * @throws RuntimeException when the original address has been taken by
     *                          someone else in the meantime
     */
    public function restoreWithOriginalEmail(): void
    {
        DB::transaction(function () {
            $original = $this->original_email;

            if ($original !== null && static::originalEmailIsTaken($original, $this->id)) {
                // Freeing the address is the point of the tombstone, so
                // someone else may legitimately hold it now. Restoring anyway
                // would violate the unique index; silently keeping the
                // tombstone would hand back an account nobody can sign in as.
                throw new RuntimeException(
                    "Cannot restore this account: {$original} has since been registered by "
                    .'another user. Change that account\'s email first, or restore this one '
                    .'and assign it a new address.'
                );
            }

            $tombstone = $this->email;

            if ($original !== null) {
                $this->email = $original;
                $this->original_email = null;
                $this->saveQuietly();
            }

            $this->restore();

            // Explicit for the same reason as the delete: by the time the
            // `restored` event fires, the email has already been swapped back
            // quietly and the tombstone value is gone, so a listener could not
            // record what it was restored from.
            $this->writeAuditLog(
                'restored',
                ['email' => $tombstone, 'deleted_at' => 'set'],
                ['email' => $this->email, 'deleted_at' => null],
            );
        });
    }

    /**
     * Whether a live or trashed row other than this one already holds the
     * address. Trashed rows count: the unique index does not exempt them.
     */
    public static function originalEmailIsTaken(string $email, ?int $exceptId = null): bool
    {
        return static::withTrashed()
            ->where('email', $email)
            ->when($exceptId, fn ($query) => $query->whereKeyNot($exceptId))
            ->exists();
    }

    public function isTombstoned(): bool
    {
        return str_ends_with((string) $this->email, '@deleted.local');
    }

    /**
     * Whether this user holds a scoped ability (SPEC section 5.16).
     *
     * FAILS CLOSED: null or an empty array grants nothing. Only the wildcard
     * or an exact match returns true, and only admins hold permissions at
     * all — the other three roles never touch the panel.
     */
    public function hasPermission(Permission|string $permission): bool
    {
        if ($this->role !== UserRole::Admin) {
            return false;
        }

        $permissions = $this->permissions ?? [];

        if (! is_array($permissions) || $permissions === []) {
            return false;
        }

        if (in_array(Permission::WILDCARD, $permissions, strict: true)) {
            return true;
        }

        $value = $permission instanceof Permission ? $permission->value : $permission;

        return in_array($value, $permissions, strict: true);
    }

    /**
     * A super-admin: unrestricted, and the only role permitted to grant
     * permissions or modify another admin.
     */
    public function isSuperAdmin(): bool
    {
        return $this->role === UserRole::Admin
            && is_array($this->permissions)
            && in_array(Permission::WILDCARD, $this->permissions, strict: true);
    }

    /**
     * Gate for the Filament admin panel.
     *
     * Filament calls this itself on every panel request. Implementing the
     * FilamentUser contract is not optional here: without it Filament allows
     * any authenticated user into the panel while APP_ENV=local.
     *
     * Reuses the existing UserRole enum rather than introducing a separate
     * admin flag or guard.
     */
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->role === UserRole::Admin;
    }

    /**
     * Whether this account must verify its email address before it is allowed
     * to log in.
     *
     * SPEC section 3.1 and section 7: a vendor who signed themselves up is
     * unproven and has to confirm the address. Salesman- and admin-created
     * accounts were met in person, so they skip this — those flows set
     * email_verified_at at creation time (Phase 2).
     *
     * Customers are deliberately not gated: SPEC section 4.1 asks only for
     * email + password self-registration, with no verification requirement.
     * They still receive the verification email and can verify.
     */
    public function requiresEmailVerification(): bool
    {
        if ($this->role !== UserRole::Vendor) {
            return false;
        }

        if ($this->hasVerifiedEmail()) {
            return false;
        }

        return ! $this->hasSalesmanAssignedActiveSubscription();
    }

    public function hasSalesmanAssignedActiveSubscription(): bool
    {
        $vendor = $this->vendor;

        if ($vendor === null) {
            return false;
        }

        return $vendor->subscriptions()
            ->where('source', 'salesman')
            ->where('end_date', '>=', now())
            ->exists();
    }

    /**
     * A temp password an admin/salesman shares out-of-band — SPEC section
     * 5.2 (account creation) and section 2.2 (shared via WhatsApp at
     * Subscribe). Never stored anywhere in plaintext; the caller holds it
     * only long enough to show or send it once.
     *
     * Unambiguous alphabet — no 0/O or 1/l/I — because these get read aloud
     * down a phone line or typed off a WhatsApp message.
     */
    public static function generateTemporaryPassword(int $length = 20): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
        $password = '';

        for ($i = 0; $i < $length; $i++) {
            $password .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        }

        return $password;
    }
}
