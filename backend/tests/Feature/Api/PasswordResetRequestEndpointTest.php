<?php

namespace Tests\Feature\Api;

use App\Enums\UserRole;
use App\Models\PasswordResetRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PasswordResetRequestEndpointTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_known_email_files_a_pending_request(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->create(['email' => 'asha@example.com']);

        $this->postJson('/api/auth/password-reset-requests', ['email' => 'asha@example.com'])
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseHas('password_reset_requests', [
            'user_id' => $user->id,
            'status' => PasswordResetRequest::STATUS_PENDING,
        ]);
    }

    /**
     * Same response either way, or the endpoint would reveal which emails
     * have accounts.
     */
    public function test_an_unknown_email_gets_the_same_response_and_files_nothing(): void
    {
        $known = User::factory()->create(['email' => 'known@example.com']);

        $knownResponse = $this->postJson('/api/auth/password-reset-requests', ['email' => 'known@example.com'])->json();
        $unknownResponse = $this->postJson('/api/auth/password-reset-requests', ['email' => 'nobody@example.com'])->json();

        $this->assertSame($knownResponse, $unknownResponse);
        $this->assertSame(1, PasswordResetRequest::query()->count());
        $this->assertSame($known->id, PasswordResetRequest::query()->sole()->user_id);
    }

    public function test_asking_twice_keeps_one_open_request(): void
    {
        User::factory()->create(['email' => 'twice@example.com']);

        $this->postJson('/api/auth/password-reset-requests', ['email' => 'twice@example.com'])->assertOk();
        $this->postJson('/api/auth/password-reset-requests', ['email' => 'twice@example.com'])->assertOk();

        $this->assertSame(1, PasswordResetRequest::query()->pending()->count());
    }

    public function test_an_invalid_email_is_rejected(): void
    {
        $this->postJson('/api/auth/password-reset-requests', ['email' => 'not-an-email'])
            ->assertStatus(422);
    }

    public function test_it_changes_no_password(): void
    {
        $user = User::factory()->create(['email' => 'safe@example.com']);
        $hash = $user->password;

        $this->postJson('/api/auth/password-reset-requests', ['email' => 'safe@example.com'])->assertOk();

        $this->assertSame($hash, $user->fresh()->password);
        $this->assertFalse((bool) $user->fresh()->must_change_password);
    }

    public function test_it_is_rate_limited(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/password-reset-requests', ['email' => "n{$i}@example.com"])->assertOk();
        }

        $this->postJson('/api/auth/password-reset-requests', ['email' => 'n6@example.com'])
            ->assertStatus(429);
    }

    /** Issuing a temp password from the Users list closes the request too. */
    public function test_issuing_a_temporary_password_resolves_the_open_request(): void
    {
        $admin = User::factory()->role(UserRole::Admin)->create();
        $user = User::factory()->create(['email' => 'lost@example.com']);

        $this->postJson('/api/auth/password-reset-requests', ['email' => 'lost@example.com'])->assertOk();

        $user->issueTemporaryPassword($admin);

        $request = PasswordResetRequest::query()->sole();
        $this->assertSame(PasswordResetRequest::STATUS_RESOLVED, $request->status);
        $this->assertSame($admin->id, $request->resolved_by);
        $this->assertTrue((bool) $user->fresh()->must_change_password);
    }
}
