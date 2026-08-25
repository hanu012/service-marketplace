<?php

namespace Tests\Feature\Admin;

use App\Enums\UserRole;
use App\Filament\Resources\UserResource;
use App\Filament\Resources\UserResource\Pages\CreateUser;
use App\Filament\Resources\UserResource\Pages\EditUser;
use App\Filament\Resources\UserResource\Pages\ListUsers;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;
use Tests\TestCase;

class UserResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->role(UserRole::Admin)->create());
    }

    public function test_the_list_page_renders(): void
    {
        User::factory()->count(3)->create();

        Livewire::test(ListUsers::class)->assertSuccessful();
    }

    /**
     * SPEC section 5.2 asks for CRUD across all four roles. This is the
     * admin-creates-directly path, distinct from self-registration.
     */
    public function test_an_admin_can_create_a_salesman(): void
    {
        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Ravi Salesman',
                'email' => 'ravi@example.com',
                'role' => 'salesman',
                'salesman' => [
                    'employee_code' => 'EMP-001',
                    'phone' => '9900000001',
                    'monthly_target_paise' => 5000000,
                    'commission_rate_bps' => 1200,
                    'is_active' => true,
                ],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $user = User::where('email', 'ravi@example.com')->sole();

        $this->assertSame(UserRole::Salesman, $user->role);
        $this->assertNotNull($user->salesman);
        $this->assertSame('EMP-001', $user->salesman->employee_code);
        $this->assertSame(1200, $user->salesman->commission_rate_bps);
    }

    public function test_a_salesman_must_change_their_password_on_first_login(): void
    {
        // SPEC section 2.1.
        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Ravi', 'email' => 'ravi2@example.com', 'role' => 'salesman',
                'salesman' => ['employee_code' => 'EMP-002', 'phone' => '9900000002'],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        // The flag lives on `users`, not `salesmen`: UserResource issues a
        // temporary password to every role it creates, so the forced change
        // has to apply to all of them, not just salesmen.
        $this->assertTrue(User::where('email', 'ravi2@example.com')->sole()->must_change_password);
    }

    public function test_every_created_role_must_change_its_temp_password(): void
    {
        $roles = [
            'admin' => [],
            'customer' => ['customer' => []],
            'vendor' => ['vendor' => [
                'business_name' => 'Cool Air', 'owner_name' => 'B', 'phone' => '9900000099',
            ]],
        ];

        foreach ($roles as $role => $profile) {
            $email = $role.'-temp@example.com';

            Livewire::test(CreateUser::class)
                ->fillForm(array_merge(['name' => ucfirst($role), 'email' => $email, 'role' => $role], $profile))
                ->call('create')
                ->assertHasNoFormErrors();

            $this->assertTrue(
                User::where('email', $email)->sole()->must_change_password,
                "{$role} was not flagged for a password change"
            );
        }
    }

    public function test_an_admin_created_vendor_starts_as_a_draft(): void
    {
        // SPEC section 7 reserves pending_verification for self-registered
        // vendors; an admin-created one has no subscription yet.
        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Cool Air', 'email' => 'vendor@example.com', 'role' => 'vendor',
                'vendor' => [
                    'business_name' => 'Cool Air Services',
                    'owner_name' => 'Bhavin',
                    'phone' => '9900000010',
                ],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $vendor = User::where('email', 'vendor@example.com')->sole()->vendor;

        $this->assertNotNull($vendor);
        $this->assertSame('draft', $vendor->status);
        $this->assertFalse($vendor->is_suspended);
    }

    public function test_an_admin_can_create_a_customer(): void
    {
        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Meera', 'email' => 'meera@example.com', 'role' => 'customer',
                'customer' => ['phone' => '9900000020', 'pincode' => '380009'],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $customer = User::where('email', 'meera@example.com')->sole()->customer;

        $this->assertNotNull($customer);
        $this->assertSame('380009', $customer->pincode);
    }

    public function test_only_the_matching_profile_row_is_created(): void
    {
        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Meera', 'email' => 'meera2@example.com', 'role' => 'customer',
                'customer' => ['phone' => '9900000021'],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $user = User::where('email', 'meera2@example.com')->sole();

        $this->assertNotNull($user->customer);
        $this->assertNull($user->salesman);
        $this->assertNull($user->vendor);
    }

    public function test_created_accounts_are_marked_email_verified(): void
    {
        // The admin vouches for them — the behaviour
        // User::requiresEmailVerification() documents.
        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Meera', 'email' => 'meera3@example.com', 'role' => 'customer',
                'customer' => [],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $this->assertTrue(User::where('email', 'meera3@example.com')->sole()->hasVerifiedEmail());
    }

    public function test_a_temp_password_is_generated_and_usable(): void
    {
        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Meera', 'email' => 'meera4@example.com', 'role' => 'customer',
                'customer' => [],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $user = User::where('email', 'meera4@example.com')->sole();

        // Stored hashed, never plaintext.
        $this->assertNotEmpty($user->password);
        $this->assertStringStartsWith('$2y$', $user->password);
    }

    public function test_the_generated_password_avoids_ambiguous_characters(): void
    {
        // Read aloud down a phone line or typed off a WhatsApp message.
        for ($i = 0; $i < 50; $i++) {
            $password = CreateUser::generatePassword();

            $this->assertSame(20, strlen($password));
            $this->assertDoesNotMatchRegularExpression('/[0O1lI]/', $password);
        }
    }

    public function test_the_role_cannot_be_changed_after_creation(): void
    {
        $user = User::factory()->role(UserRole::Customer)->create();

        Livewire::test(EditUser::class, ['record' => $user->getKey()])
            ->assertFormFieldIsDisabled('role');
    }

    /**
     * The assertion above only checks how the field RENDERS. A disabled field
     * whose value is still dehydrated round-trips through the request, so a
     * crafted submission could set it regardless of what the UI shows — this
     * was exploitable until the field was made dehydrated-on-create-only.
     *
     * Promoting a customer this way would also bypass UserPolicy::create(),
     * which restricts making admins to super-admins.
     */
    public function test_a_crafted_submission_cannot_change_the_role(): void
    {
        $victim = User::factory()->role(UserRole::Customer)->create();

        Livewire::test(EditUser::class, ['record' => $victim->getKey()])
            ->fillForm(['role' => UserRole::Admin->value])
            ->call('save');

        $this->assertSame(UserRole::Customer, $victim->fresh()->role);
    }

    public function test_a_crafted_submission_cannot_grant_permissions(): void
    {
        // The same round-trip attack against the permissions field, which is
        // hidden rather than disabled for exactly this reason.
        $subAdmin = User::factory()->subAdmin(['users.viewAny', 'users.update'])->create();
        $victim = User::factory()->role(UserRole::Vendor)->create();

        $this->actingAs($subAdmin);

        Livewire::test(EditUser::class, ['record' => $victim->getKey()])
            ->fillForm(['permissions' => ['*']])
            ->call('save');

        $this->assertNull($victim->fresh()->permissions);
    }

    public function test_deleting_from_the_panel_tombstones_the_email(): void
    {
        $user = User::factory()->role(UserRole::Customer)->create(['email' => 'gone@example.com']);

        Livewire::test(EditUser::class, ['record' => $user->getKey()])
            ->callAction('deleteWithTombstone');

        $reloaded = User::withTrashed()->find($user->id);

        $this->assertTrue($reloaded->trashed());
        $this->assertTrue($reloaded->isTombstoned());
        $this->assertSame('gone@example.com', $reloaded->original_email);
    }

    public function test_restoring_from_the_panel_returns_the_original_email(): void
    {
        $user = User::factory()->role(UserRole::Customer)->create(['email' => 'back@example.com']);
        $user->deleteWithTombstone();

        Livewire::test(EditUser::class, ['record' => $user->getKey()])
            ->callAction('restoreWithOriginalEmail');

        $reloaded = User::withTrashed()->find($user->id);

        $this->assertFalse($reloaded->trashed());
        $this->assertSame('back@example.com', $reloaded->email);
        $this->assertNull($reloaded->original_email);
    }

    public function test_restore_is_hidden_for_a_live_account_and_delete_for_a_deleted_one(): void
    {
        $live = User::factory()->role(UserRole::Customer)->create();

        Livewire::test(EditUser::class, ['record' => $live->getKey()])
            ->assertActionVisible('deleteWithTombstone')
            ->assertActionHidden('restoreWithOriginalEmail');

        $live->deleteWithTombstone();

        Livewire::test(EditUser::class, ['record' => $live->getKey()])
            ->assertActionHidden('deleteWithTombstone')
            ->assertActionVisible('restoreWithOriginalEmail');
    }

    public function test_there_is_no_bulk_delete(): void
    {
        // Each deletion rewrites an email and revokes tokens — not something
        // to do to a checkbox selection by accident.
        Livewire::test(ListUsers::class)
            ->assertTableBulkActionDoesNotExist(\Filament\Tables\Actions\DeleteBulkAction::class);
    }

    public function test_a_duplicate_email_is_rejected(): void
    {
        User::factory()->create(['email' => 'taken@example.com']);

        Livewire::test(CreateUser::class)
            ->fillForm([
                'name' => 'Dup', 'email' => 'taken@example.com', 'role' => 'customer',
                'customer' => [],
            ])
            ->call('create')
            ->assertHasFormErrors(['email']);
    }

    public function test_a_non_admin_cannot_reach_the_resource(): void
    {
        $this->actingAs(User::factory()->role(UserRole::Vendor)->create());

        $this->get(UserResource::getUrl('index'))->assertForbidden();
    }

    /**
     * The two rules must not drift into each other: the panel may create any
     * role, the public API may not.
     */
    public function test_the_api_still_refuses_self_registration_as_salesman(): void
    {
        $this->postJson('/api/auth/register', [
            'name' => 'Sneaky',
            'email' => 'sneaky@example.com',
            'password' => 'correct-horse-battery',
            'password_confirmation' => 'correct-horse-battery',
            'device_name' => 'pixel-8',
            'role' => 'salesman',
        ])->assertStatus(422);

        $this->assertDatabaseMissing('users', ['email' => 'sneaky@example.com']);
    }

    public function test_the_panel_may_create_an_admin(): void
    {
        Livewire::test(CreateUser::class)
            ->fillForm(['name' => 'Second Admin', 'email' => 'admin2@example.com', 'role' => 'admin'])
            ->call('create')
            ->assertHasNoFormErrors();

        $this->assertSame(UserRole::Admin, User::where('email', 'admin2@example.com')->sole()->role);
    }
}
