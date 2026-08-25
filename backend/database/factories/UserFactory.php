<?php

namespace Database\Factories;

use App\Enums\Permission;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
            'role' => UserRole::Customer,
        ];
    }

    /**
     * Give the user a specific role.
     */
    public function role(UserRole $role): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => $role,

            // Admins get the wildcard by default. Permissions fail closed
            // (SPEC section 5.16), so an admin without them can open the
            // panel but reach nothing inside it — which would make every
            // resource test fail for a reason unrelated to what it is
            // testing. Tests that care about scoping pass permissions
            // explicitly; see PermissionTest.
            'permissions' => $role === UserRole::Admin ? [Permission::WILDCARD] : null,
        ]);
    }

    /**
     * An admin scoped to specific abilities rather than the wildcard.
     *
     * @param  array<int, string>  $permissions
     */
    public function subAdmin(array $permissions): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => UserRole::Admin,
            'permissions' => $permissions,
        ]);
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}
