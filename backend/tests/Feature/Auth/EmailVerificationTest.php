<?php

namespace Tests\Feature\Auth;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\URL;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    private function verificationUrl(User $user): string
    {
        // Built the same way the notification builds it, so these tests track
        // the configured window rather than a hardcoded one.
        return URL::temporarySignedRoute(
            'verification.verify',
            now()->addMinutes((int) config('auth.verification.expire')),
            ['id' => $user->getKey(), 'hash' => sha1($user->getEmailForVerification())]
        );
    }

    private function registerVendor(array $overrides = []): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/auth/register', array_merge([
            'name' => 'Asha Patel',
            'email' => 'asha@example.com',
            'password' => 'correct-horse-battery',
            'password_confirmation' => 'correct-horse-battery',
            'device_name' => 'pixel-8',
            'role' => 'vendor',
            'business_name' => 'Cool Air Services',
            'phone' => '9812345678',
        ], $overrides));
    }

    public function test_registration_sends_a_verification_email(): void
    {
        Notification::fake();

        $this->registerVendor()->assertCreated();

        Notification::assertSentTo(
            User::whereEmail('asha@example.com')->firstOrFail(),
            VerifyEmail::class
        );
    }

    public function test_a_customer_also_receives_a_verification_email(): void
    {
        Notification::fake();

        $this->registerVendor(['role' => 'customer'])->assertCreated();

        Notification::assertSentTo(
            User::whereEmail('asha@example.com')->firstOrFail(),
            VerifyEmail::class
        );
    }

    public function test_a_signed_link_verifies_the_address(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();

        $this->getJson($this->verificationUrl($user))
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.already_verified', false);

        $this->assertTrue($user->fresh()->hasVerifiedEmail());
    }

    public function test_an_unsigned_link_is_rejected(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();

        $this->getJson('/api/auth/verify-email/'.$user->id.'/'.sha1($user->email))
            ->assertStatus(403);

        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_a_tampered_hash_is_rejected(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();

        $url = URL::temporarySignedRoute(
            'verification.verify',
            now()->addMinutes(60),
            ['id' => $user->getKey(), 'hash' => sha1('someone-else@example.com')]
        );

        $this->getJson($url)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'INVALID_VERIFICATION_LINK');

        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_the_verification_expiry_is_configured_to_24_hours(): void
    {
        $this->assertSame(60 * 24, (int) config('auth.verification.expire'));
    }

    public function test_a_link_is_still_valid_at_23_hours(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();
        $url = $this->verificationUrl($user);

        $this->travel(23)->hours();

        $this->getJson($url)->assertOk();
        $this->assertTrue($user->fresh()->hasVerifiedEmail());
    }

    public function test_a_link_is_rejected_after_24_hours(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();
        $url = $this->verificationUrl($user);

        $this->travel(24 * 60 + 1)->minutes();

        $this->getJson($url)->assertStatus(403);
        $this->assertFalse($user->fresh()->hasVerifiedEmail());
    }

    public function test_a_link_that_would_have_died_under_the_old_60_minute_window_still_works(): void
    {
        // Guards the change itself: 61 minutes used to be expired.
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();
        $url = $this->verificationUrl($user);

        $this->travel(61)->minutes();

        $this->getJson($url)->assertOk();
    }

    public function test_the_email_states_the_24_hour_window(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();

        $mail = (new VerifyEmail)->toMail($user);

        // Lines added after ->action() land in outroLines, so check both.
        $this->assertContains(
            'This verification link will expire in 24 hours.',
            array_merge($mail->introLines, $mail->outroLines)
        );
    }

    public function test_verifying_twice_is_harmless(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create();
        $url = $this->verificationUrl($user);

        $this->getJson($url)->assertOk()->assertJsonPath('data.already_verified', false);
        $this->getJson($url)->assertOk()->assertJsonPath('data.already_verified', true);
    }

    public function test_verification_can_be_resent_without_a_token(): void
    {
        // A blocked vendor has no token, so this must work unauthenticated.
        Notification::fake();
        $user = User::factory()->role(UserRole::Vendor)->unverified()->create([
            'email' => 'asha@example.com',
        ]);

        $this->postJson('/api/auth/resend-verification', ['email' => 'asha@example.com'])
            ->assertOk();

        Notification::assertSentTo($user, VerifyEmail::class);
    }

    public function test_resend_does_not_reveal_whether_an_account_exists(): void
    {
        Notification::fake();
        User::factory()->role(UserRole::Vendor)->unverified()->create([
            'email' => 'asha@example.com',
        ]);

        $known = $this->postJson('/api/auth/resend-verification', ['email' => 'asha@example.com']);
        $unknown = $this->postJson('/api/auth/resend-verification', ['email' => 'nobody@example.com']);

        $known->assertOk();
        $unknown->assertOk();
        $this->assertSame($known->json('data.message'), $unknown->json('data.message'));
    }

    public function test_resend_for_an_already_verified_account_sends_nothing(): void
    {
        Notification::fake();
        $user = User::factory()->role(UserRole::Vendor)->create(); // verified

        $this->postJson('/api/auth/resend-verification', ['email' => $user->email])
            ->assertOk();

        Notification::assertNotSentTo($user, VerifyEmail::class);
    }
}
