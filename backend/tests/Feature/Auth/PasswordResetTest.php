<?php

namespace Tests\Feature\Auth;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    private function user(): User
    {
        return User::factory()->create([
            'email' => 'asha@example.com',
            'password' => Hash::make('old-password-here'),
            'role' => UserRole::Customer,
        ]);
    }

    public function test_a_reset_link_is_emailed(): void
    {
        Notification::fake();
        $user = $this->user();

        $this->postJson('/api/auth/forgot-password', ['email' => 'asha@example.com'])
            ->assertOk()
            ->assertJsonPath('success', true);

        Notification::assertSentTo($user, ResetPassword::class);
    }

    public function test_an_unknown_email_returns_the_same_response(): void
    {
        // Otherwise this endpoint reveals which addresses have accounts.
        Notification::fake();
        $user = $this->user();

        $known = $this->postJson('/api/auth/forgot-password', ['email' => 'asha@example.com']);
        $unknown = $this->postJson('/api/auth/forgot-password', ['email' => 'nobody@example.com']);

        $known->assertOk();
        $unknown->assertOk();
        $this->assertSame($known->json('data.message'), $unknown->json('data.message'));
        $this->assertSame($known->status(), $unknown->status());

        // Exactly one mail went out — the unknown address produced none.
        Notification::assertSentToTimes($user, ResetPassword::class, 1);
        Notification::assertCount(1);
    }

    public function test_a_password_can_be_reset_with_a_valid_token(): void
    {
        $user = $this->user();
        $token = Password::createToken($user);

        $this->postJson('/api/auth/reset-password', [
            'token' => $token,
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'password_confirmation' => 'brand-new-password',
        ])->assertOk()->assertJsonPath('success', true);

        $this->assertTrue(Hash::check('brand-new-password', $user->fresh()->password));
    }

    public function test_the_new_password_works_for_login(): void
    {
        $user = $this->user();
        $token = Password::createToken($user);

        $this->postJson('/api/auth/reset-password', [
            'token' => $token,
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'password_confirmation' => 'brand-new-password',
        ])->assertOk();

        $this->postJson('/api/auth/login', [
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'device_name' => 'pixel-8',
        ])->assertOk();
    }

    public function test_a_reset_token_is_single_use(): void
    {
        $user = $this->user();
        $token = Password::createToken($user);

        $payload = [
            'token' => $token,
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'password_confirmation' => 'brand-new-password',
        ];

        $this->postJson('/api/auth/reset-password', $payload)->assertOk();

        // Second use of the same token must fail.
        $this->postJson('/api/auth/reset-password', $payload)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_RESET_TOKEN');
    }

    public function test_an_expired_token_is_rejected(): void
    {
        $user = $this->user();
        $token = Password::createToken($user);

        // config('auth.passwords.users.expire') is 15 minutes.
        $this->travel(16)->minutes();

        $this->postJson('/api/auth/reset-password', [
            'token' => $token,
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'password_confirmation' => 'brand-new-password',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_RESET_TOKEN');
    }

    public function test_a_token_is_still_valid_just_inside_the_window(): void
    {
        $user = $this->user();
        $token = Password::createToken($user);

        $this->travel(14)->minutes();

        $this->postJson('/api/auth/reset-password', [
            'token' => $token,
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'password_confirmation' => 'brand-new-password',
        ])->assertOk();
    }

    public function test_the_reset_expiry_is_configured_to_fifteen_minutes(): void
    {
        $this->assertSame(15, config('auth.passwords.users.expire'));
    }

    public function test_an_invalid_token_is_rejected(): void
    {
        $this->user();

        $this->postJson('/api/auth/reset-password', [
            'token' => 'not-a-real-token',
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'password_confirmation' => 'brand-new-password',
        ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_RESET_TOKEN');
    }

    public function test_resetting_revokes_every_existing_device_token(): void
    {
        $user = $this->user();
        $stale = $user->createToken('pixel-8')->plainTextToken;

        $this->postJson('/api/auth/reset-password', [
            'token' => Password::createToken($user),
            'email' => 'asha@example.com',
            'password' => 'brand-new-password',
            'password_confirmation' => 'brand-new-password',
        ])->assertOk();

        $this->assertSame(0, $user->tokens()->count());

        $this->app['auth']->forgetGuards();

        $this->withHeader('Authorization', 'Bearer '.$stale)
            ->getJson('/api/user')
            ->assertStatus(401);
    }
}
