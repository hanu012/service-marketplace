<?php

namespace Tests\Feature\Admin;

use App\Enums\UserRole;
use App\Filament\Resources\PasswordResetRequestResource\Pages\ListPasswordResetRequests;
use App\Models\PasswordResetRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;
use Tests\TestCase;

class PasswordResetRequestResourceTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->role(UserRole::Admin)->create();
        $this->actingAs($this->admin);
    }

    private function pendingRequestFor(User $user): PasswordResetRequest
    {
        return PasswordResetRequest::create(['user_id' => $user->id]);
    }

    public function test_the_list_opens_on_pending_requests(): void
    {
        $pending = $this->pendingRequestFor(User::factory()->create());
        $done = $this->pendingRequestFor(User::factory()->create());
        $done->dismiss($this->admin);

        Livewire::test(ListPasswordResetRequests::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$pending])
            ->assertCanNotSeeTableRecords([$done]);
    }

    public function test_reset_password_issues_a_temporary_password_and_resolves(): void
    {
        $user = User::factory()->role(UserRole::Vendor)->create();
        $oldHash = $user->password;
        $request = $this->pendingRequestFor($user);

        Livewire::test(ListPasswordResetRequests::class)
            ->callTableAction('resetPassword', $request)
            ->assertHasNoTableActionErrors();

        $user->refresh();
        $this->assertNotSame($oldHash, $user->password);
        $this->assertTrue((bool) $user->must_change_password);
        $this->assertSame(PasswordResetRequest::STATUS_RESOLVED, $request->fresh()->status);
        $this->assertSame($this->admin->id, $request->fresh()->resolved_by);
    }

    public function test_dismiss_closes_the_request_without_touching_the_password(): void
    {
        $user = User::factory()->create(['password' => Hash::make('original-password')]);
        $request = $this->pendingRequestFor($user);

        Livewire::test(ListPasswordResetRequests::class)
            ->callTableAction('dismiss', $request)
            ->assertHasNoTableActionErrors();

        $this->assertSame(PasswordResetRequest::STATUS_DISMISSED, $request->fresh()->status);
        $this->assertTrue(Hash::check('original-password', $user->fresh()->password));
    }

    /** Same escalation guard as the Users list's own Reset password. */
    public function test_a_sub_admin_cannot_reset_an_admin_password_from_a_request(): void
    {
        $subAdmin = User::factory()->subAdmin(['users.viewAny', 'users.update'])->create();
        $this->actingAs($subAdmin);

        $otherAdmin = User::factory()->role(UserRole::Admin)->create();
        $adminRequest = $this->pendingRequestFor($otherAdmin);
        $vendorRequest = $this->pendingRequestFor(User::factory()->role(UserRole::Vendor)->create());

        Livewire::test(ListPasswordResetRequests::class)
            ->assertTableActionHidden('resetPassword', $adminRequest)
            ->assertTableActionVisible('resetPassword', $vendorRequest);
    }

    public function test_requests_cannot_be_created_by_hand(): void
    {
        Livewire::test(ListPasswordResetRequests::class)
            ->assertActionDoesNotExist('create');
    }
}
