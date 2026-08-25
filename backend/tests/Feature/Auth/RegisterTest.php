<?php

namespace Tests\Feature\Auth;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class RegisterTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array<string, mixed>
     */
    private function payload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Asha Patel',
            'email' => 'asha@example.com',
            'password' => 'correct-horse-battery',
            'password_confirmation' => 'correct-horse-battery',
            'device_name' => 'pixel-8',
            'role' => 'customer',
        ], $overrides);
    }

    public function test_a_customer_can_register_and_receives_a_token(): void
    {
        $response = $this->postJson('/api/auth/register', $this->payload());

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('error', null)
            ->assertJsonPath('data.user.email', 'asha@example.com')
            ->assertJsonPath('data.user.role', 'customer')
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'name', 'email', 'role']]]);

        $this->assertDatabaseHas('users', ['email' => 'asha@example.com', 'role' => 'customer']);
    }

    public function test_a_vendor_can_register(): void
    {
        $this->postJson('/api/auth/register', $this->payload([
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
            'phone' => '9812345678',
        ]))
            ->assertCreated()
            ->assertJsonPath('data.user.role', 'vendor');
    }

    /**
     * Task 3.4 found self-registration created only a User row, leaving
     * self-service subscribe (task 4.2) nothing to attach a subscription
     * to. A vendor registration must also create a matching Vendor row,
     * in the same transaction, starting at the same `draft` status the
     * salesman-led flow starts at.
     */
    public function test_a_vendor_registration_creates_a_matching_vendor_row(): void
    {
        $this->postJson('/api/auth/register', $this->payload([
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
            'phone' => '9812345678',
        ]))->assertCreated();

        $user = User::where('email', 'asha@example.com')->firstOrFail();

        $this->assertDatabaseHas('vendors', [
            'user_id' => $user->id,
            'business_name' => 'Cool Air Services',
            // owner_name is not a separate field — it mirrors the account
            // name, same as the salesman-led flow already does.
            'owner_name' => 'Asha Patel',
            'phone' => '9812345678',
            'status' => 'draft',
            'created_by_salesman_id' => null,
        ]);
    }

    public function test_a_customer_registration_creates_no_vendor_row(): void
    {
        $this->postJson('/api/auth/register', $this->payload(['role' => 'customer']))
            ->assertCreated();

        $this->assertDatabaseCount('vendors', 0);
    }

    /**
     * Task 4.6 found self-registration created only a User row for a
     * customer too, leaving location detection (SPEC section 4.2) nothing
     * to attach to. A customer registration must also create a matching
     * Customer row, in the same transaction — every field but user_id
     * stays null, populated later via GPS or the pincode fallback.
     */
    public function test_a_customer_registration_creates_a_matching_customer_row(): void
    {
        $this->postJson('/api/auth/register', $this->payload(['role' => 'customer']))
            ->assertCreated();

        $user = User::where('email', 'asha@example.com')->firstOrFail();

        $this->assertDatabaseHas('customers', [
            'user_id' => $user->id,
            'phone' => null,
            'latitude' => null,
            'longitude' => null,
            'pincode' => null,
        ]);
    }

    public function test_a_vendor_registration_creates_no_customer_row(): void
    {
        $this->postJson('/api/auth/register', $this->payload([
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
            'phone' => '9812345678',
        ]))->assertCreated();

        $this->assertDatabaseCount('customers', 0);
    }

    public function test_vendor_registration_requires_a_business_name(): void
    {
        $this->postJson('/api/auth/register', $this->payload([
            'role' => 'vendor',
            'phone' => '9812345678',
        ]))
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertDatabaseMissing('users', ['email' => 'asha@example.com']);
    }

    public function test_vendor_registration_requires_a_phone(): void
    {
        $this->postJson('/api/auth/register', $this->payload([
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
        ]))
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertDatabaseMissing('users', ['email' => 'asha@example.com']);
    }

    public function test_a_duplicate_vendor_phone_is_rejected(): void
    {
        $this->postJson('/api/auth/register', $this->payload([
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
            'phone' => '9812345678',
        ]))->assertCreated();

        $this->postJson('/api/auth/register', $this->payload([
            'email' => 'other@example.com',
            'role' => 'vendor',
            'business_name' => 'Someone Elses Shop',
            'phone' => '9812345678',
        ]))
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_the_password_is_bcrypt_hashed_and_never_returned(): void
    {
        $response = $this->postJson('/api/auth/register', $this->payload());

        $user = User::where('email', 'asha@example.com')->firstOrFail();

        $this->assertNotSame('correct-horse-battery', $user->password);
        $this->assertStringStartsWith('$2y$', $user->password);
        $this->assertTrue(Hash::check('correct-horse-battery', $user->password));
        $response->assertJsonMissingPath('data.user.password');
    }

    public function test_registering_as_admin_is_rejected(): void
    {
        $this->postJson('/api/auth/register', $this->payload(['role' => 'admin']))
            ->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertDatabaseMissing('users', ['email' => 'asha@example.com']);
    }

    public function test_registering_as_salesman_is_rejected(): void
    {
        // SPEC section 1: salesmen are created by an admin, never self-served.
        $this->postJson('/api/auth/register', $this->payload(['role' => 'salesman']))
            ->assertStatus(422);

        $this->assertDatabaseMissing('users', ['email' => 'asha@example.com']);
    }

    public function test_duplicate_email_is_rejected(): void
    {
        User::factory()->create(['email' => 'asha@example.com']);

        $this->postJson('/api/auth/register', $this->payload())
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_a_soft_deleted_email_cannot_be_reused(): void
    {
        // The unique index still holds the row, so validation must reject it
        // rather than letting the insert fail at the database level.
        $user = User::factory()->create(['email' => 'asha@example.com']);
        $user->delete();

        $this->postJson('/api/auth/register', $this->payload())
            ->assertStatus(422);
    }

    public function test_password_confirmation_is_required(): void
    {
        $this->postJson('/api/auth/register', $this->payload(['password_confirmation' => 'mismatch']))
            ->assertStatus(422);
    }

    public function test_registration_errors_use_the_envelope(): void
    {
        $this->postJson('/api/auth/register', [])
            ->assertStatus(422)
            ->assertJsonStructure(['success', 'data', 'error' => ['code', 'message', 'fields']]);
    }

    public function test_the_issued_token_carries_the_role_ability(): void
    {
        // Registering as a customer, because a vendor is issued no token until
        // the email is verified — see LoginVerificationGateTest.
        $this->postJson('/api/auth/register', $this->payload(['role' => 'customer']))
            ->assertCreated();

        $user = User::where('email', 'asha@example.com')->firstOrFail();

        $this->assertSame(['role:customer'], $user->tokens()->first()->abilities);
        $this->assertSame(UserRole::Customer, $user->role);
    }

    public function test_a_verified_vendors_login_token_carries_the_vendor_ability(): void
    {
        $this->postJson('/api/auth/register', $this->payload([
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
            'phone' => '9812345678',
        ]))
            ->assertCreated();

        $user = User::where('email', 'asha@example.com')->firstOrFail();
        $user->markEmailAsVerified();

        $this->postJson('/api/auth/login', [
            'email' => 'asha@example.com',
            'password' => 'correct-horse-battery',
            'device_name' => 'pixel-8',
        ])->assertOk();

        $this->assertSame(['role:vendor'], $user->tokens()->first()->abilities);
    }
}
