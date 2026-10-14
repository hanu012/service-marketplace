<?php

namespace Tests\Feature\Api;

use App\Enums\UserRole;
use App\Models\Customer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * GET/PATCH /api/customers/me — the customer app's Personal Details screen.
 */
class CustomerProfileEndpointTest extends TestCase
{
    use RefreshDatabase;

    private function customer(): Customer
    {
        $user = User::factory()->role(UserRole::Customer)->create(['name' => 'Asha']);

        return Customer::create(['user_id' => $user->id, 'phone' => '9876543210']);
    }

    public function test_returns_own_details(): void
    {
        $customer = $this->customer();

        $this->actingAs($customer->user)
            ->getJson('/api/customers/me')
            ->assertOk()
            ->assertJsonPath('data.customer.name', 'Asha')
            ->assertJsonPath('data.customer.email', $customer->user->email)
            ->assertJsonPath('data.customer.phone', '9876543210');
    }

    public function test_updates_name_and_phone(): void
    {
        $customer = $this->customer();

        $this->actingAs($customer->user)
            ->patchJson('/api/customers/me', ['name' => ' Asha Shah ', 'phone' => '9123456780'])
            ->assertOk()
            ->assertJsonPath('data.customer.name', 'Asha Shah');

        $this->assertSame('Asha Shah', $customer->user->fresh()->name);
        $this->assertSame('9123456780', $customer->fresh()->phone);
    }

    public function test_phone_can_be_cleared_and_name_alone_leaves_it(): void
    {
        $customer = $this->customer();

        $this->actingAs($customer->user)->patchJson('/api/customers/me', ['name' => 'Asha'])->assertOk();
        $this->assertSame('9876543210', $customer->fresh()->phone);

        $this->actingAs($customer->user)->patchJson('/api/customers/me', ['phone' => null])->assertOk();
        $this->assertNull($customer->fresh()->phone);
    }

    public function test_email_is_not_changeable(): void
    {
        $customer = $this->customer();
        $email = $customer->user->email;

        $this->actingAs($customer->user)
            ->patchJson('/api/customers/me', ['email' => 'new@example.com'])
            ->assertOk();

        $this->assertSame($email, $customer->user->fresh()->email);
    }

    public function test_rejects_blank_name_and_bad_phone(): void
    {
        $customer = $this->customer();

        $this->actingAs($customer->user)
            ->patchJson('/api/customers/me', ['name' => '', 'phone' => 'abc'])
            ->assertStatus(422);
    }

    public function test_other_roles_are_refused(): void
    {
        $vendor = User::factory()->role(UserRole::Vendor)->create();

        $this->actingAs($vendor)->getJson('/api/customers/me')->assertForbidden();
    }
}
