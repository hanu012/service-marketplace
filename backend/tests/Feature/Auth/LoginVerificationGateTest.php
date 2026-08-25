<?php

namespace Tests\Feature\Auth;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class LoginVerificationGateTest extends TestCase
{
    use RefreshDatabase;

    private function login(string $email = 'asha@example.com'): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/auth/login', [
            'email' => $email,
            'password' => 'correct-horse-battery',
            'device_name' => 'pixel-8',
        ]);
    }

    private function make(UserRole $role, bool $verified): User
    {
        return User::factory()
            ->role($role)
            ->when(! $verified, fn ($f) => $f->unverified())
            ->create([
                'email' => 'asha@example.com',
                'password' => Hash::make('correct-horse-battery'),
            ]);
    }

    public function test_an_unverified_vendor_cannot_log_in(): void
    {
        $this->make(UserRole::Vendor, verified: false);

        $this->login()
            ->assertStatus(403)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'EMAIL_NOT_VERIFIED');
    }

    public function test_a_verified_vendor_can_log_in(): void
    {
        $this->make(UserRole::Vendor, verified: true);

        $this->login()->assertOk()->assertJsonPath('data.user.role', 'vendor');
    }

    public function test_a_vendor_can_log_in_after_verifying(): void
    {
        $user = $this->make(UserRole::Vendor, verified: false);

        $this->login()->assertStatus(403);

        $user->markEmailAsVerified();

        $this->login()->assertOk();
    }

    public function test_an_unverified_customer_can_still_log_in(): void
    {
        // SPEC section 4.1 asks only for email + password self-registration;
        // verification is not a precondition on the customer side.
        $this->make(UserRole::Customer, verified: false);

        $this->login()->assertOk()->assertJsonPath('data.user.role', 'customer');
    }

    public function test_an_unverified_salesman_can_log_in(): void
    {
        // Created by an admin in person — never gated.
        $this->make(UserRole::Salesman, verified: false);

        $this->login()->assertOk();
    }

    public function test_an_unverified_admin_can_log_in(): void
    {
        $this->make(UserRole::Admin, verified: false);

        $this->login()->assertOk();
    }

    public function test_a_vendor_with_a_salesman_assigned_subscription_skips_the_gate(): void
    {
        // Exercises requiresEmailVerification()'s own delegation, independent
        // of hasSalesmanAssignedActiveSubscription()'s query — that query is
        // covered directly below by
        // test_the_real_query_finds_a_salesman_sourced_active_subscription
        // and its sibling.
        $user = new class extends User
        {
            protected $table = 'users';

            public function hasSalesmanAssignedActiveSubscription(): bool
            {
                return true;
            }
        };

        $user->forceFill([
            'name' => 'Salesman Added',
            'email' => 'vendor@example.com',
            'password' => Hash::make('correct-horse-battery'),
            'role' => UserRole::Vendor,
            'email_verified_at' => null,
        ])->save();

        $this->assertFalse($user->requiresEmailVerification());
    }

    public function test_the_real_query_finds_a_salesman_sourced_active_subscription(): void
    {
        $user = $this->make(UserRole::Vendor, verified: false);
        $vendor = \App\Models\Vendor::create([
            'user_id' => $user->id,
            'business_name' => 'Cool Air',
            'owner_name' => 'Bhavin',
            'phone' => '9812340001',
            'status' => 'active',
        ]);

        \App\Models\Subscription::create([
            'vendor_id' => $vendor->id,
            'plan_id' => \App\Models\Plan::factory()->create()->id,
            'source' => 'salesman',
            'status' => 'active',
            'start_date' => now(),
            'end_date' => now()->addDays(30),
            'price_paise' => 99_900,
            'duration_days' => 30,
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
        ]);

        $this->assertTrue($user->fresh()->hasSalesmanAssignedActiveSubscription());
        $this->assertFalse($user->fresh()->requiresEmailVerification());
    }

    public function test_the_real_query_ignores_an_expired_or_self_service_subscription(): void
    {
        $user = $this->make(UserRole::Vendor, verified: false);
        $vendor = \App\Models\Vendor::create([
            'user_id' => $user->id,
            'business_name' => 'Cool Air',
            'owner_name' => 'Bhavin',
            'phone' => '9812340002',
            'status' => 'active',
        ]);

        // Expired: end_date in the past.
        \App\Models\Subscription::create([
            'vendor_id' => $vendor->id,
            'plan_id' => \App\Models\Plan::factory()->create()->id,
            'source' => 'salesman',
            'status' => 'expired',
            'start_date' => now()->subDays(60),
            'end_date' => now()->subDays(30),
            'price_paise' => 99_900,
            'duration_days' => 30,
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
        ]);

        // Active, but self-service, not salesman.
        \App\Models\Subscription::create([
            'vendor_id' => $vendor->id,
            'plan_id' => \App\Models\Plan::factory()->create()->id,
            'source' => 'self',
            'status' => 'active',
            'start_date' => now(),
            'end_date' => now()->addDays(30),
            'price_paise' => 99_900,
            'duration_days' => 30,
            'idempotency_key' => (string) \Illuminate\Support\Str::uuid(),
        ]);

        $this->assertFalse($user->fresh()->hasSalesmanAssignedActiveSubscription());
        $this->assertTrue($user->fresh()->requiresEmailVerification());
    }

    public function test_the_gate_is_checked_only_after_the_password_is_correct(): void
    {
        // A wrong password on an unverified vendor must look like any other
        // bad credential, not leak that the account exists but is unverified.
        $this->make(UserRole::Vendor, verified: false);

        $this->postJson('/api/auth/login', [
            'email' => 'asha@example.com',
            'password' => 'WRONG',
            'device_name' => 'pixel-8',
        ])
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'INVALID_CREDENTIALS');
    }

    public function test_registering_as_a_vendor_returns_no_token(): void
    {
        // Otherwise the register response hands out exactly what the login
        // gate is there to withhold.
        $this->postJson('/api/auth/register', [
            'name' => 'Asha Patel',
            'email' => 'newvendor@example.com',
            'password' => 'correct-horse-battery',
            'password_confirmation' => 'correct-horse-battery',
            'device_name' => 'pixel-8',
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
            'phone' => '9812345678',
        ])
            ->assertCreated()
            ->assertJsonPath('data.token', null);

        $this->assertSame(0, User::whereEmail('newvendor@example.com')->firstOrFail()->tokens()->count());
    }

    public function test_registering_as_a_customer_still_returns_a_token(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Asha Patel',
            'email' => 'newcustomer@example.com',
            'password' => 'correct-horse-battery',
            'password_confirmation' => 'correct-horse-battery',
            'device_name' => 'pixel-8',
            'role' => 'customer',
        ])->assertCreated();

        $this->assertNotNull($response->json('data.token'));
    }
}
