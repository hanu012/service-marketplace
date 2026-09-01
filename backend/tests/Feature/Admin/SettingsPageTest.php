<?php

namespace Tests\Feature\Admin;

use App\Enums\Permission;
use App\Enums\UserRole;
use App\Filament\Pages\SettingsPage;
use App\Models\AuditLog;
use App\Models\Setting;
use App\Models\User;
use Database\Seeders\SettingSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * Settings (SPEC section 5 item 17) — the missing write side of
 * Setting::get() (task 3.4).
 */
class SettingsPageTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(SettingSeeder::class);

        $this->admin = User::factory()->role(UserRole::Admin)->create();
        $this->actingAs($this->admin);
    }

    public function test_the_page_renders_with_seeded_values_prefilled(): void
    {
        Livewire::test(SettingsPage::class)
            ->assertFormSet([
                'free_trial_max_days' => 15,
                'free_grants_per_salesman_month' => 10,
                'grace_period_days' => 7,
                'force_update_version' => '1.0.0',
                'maintenance_mode' => false,
            ]);
    }

    public function test_saving_updates_all_five_keys_with_a_correct_type_round_trip(): void
    {
        Livewire::test(SettingsPage::class)
            ->fillForm([
                'free_trial_max_days' => 20,
                'free_grants_per_salesman_month' => 12,
                'grace_period_days' => 10,
                'force_update_version' => '2.1.0',
                'maintenance_mode' => true,
            ])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame(20, Setting::get('free_trial_max_days'));
        $this->assertSame(12, Setting::get('free_grants_per_salesman_month'));
        $this->assertSame(10, Setting::get('grace_period_days'));
        $this->assertSame('2.1.0', Setting::get('force_update_version'));
        $this->assertTrue(Setting::get('maintenance_mode'));
    }

    public function test_force_update_version_rejects_a_malformed_version_string(): void
    {
        Livewire::test(SettingsPage::class)
            ->fillForm(['force_update_version' => 'not-a-version'])
            ->call('save')
            ->assertHasFormErrors(['force_update_version']);

        $this->assertSame('1.0.0', Setting::get('force_update_version'));
    }

    public function test_saving_writes_a_real_audit_log_entry_for_a_changed_key(): void
    {
        $setting = Setting::where('key', 'free_trial_max_days')->sole();

        // Seeding itself (RecordsAuditLog now sits on Setting) already
        // wrote one 'created' entry per row — this asserts no 'updated'
        // entry exists yet, not that the table is empty.
        $this->assertSame(0, AuditLog::where('auditable_type', $setting->getMorphClass())
            ->where('auditable_id', $setting->id)
            ->where('action', 'updated')
            ->count());

        Livewire::test(SettingsPage::class)
            ->fillForm(['free_trial_max_days' => 25])
            ->call('save');

        $entry = AuditLog::where('auditable_type', $setting->getMorphClass())
            ->where('auditable_id', $setting->id)
            ->where('action', 'updated')
            ->sole();

        $this->assertSame($this->admin->id, $entry->user_id);
        $this->assertSame('25', $entry->new_values['value']);
    }

    public function test_saving_with_nothing_changed_writes_no_new_audit_log_entries(): void
    {
        $baseline = AuditLog::count();

        Livewire::test(SettingsPage::class)->call('save');

        $this->assertSame($baseline, AuditLog::count());
    }

    // ── Permission gate ──────────────────────────────────────────────────

    public function test_a_sub_admin_without_the_settings_permission_cannot_access_the_page(): void
    {
        $subAdmin = User::factory()->role(UserRole::Admin)->create(['permissions' => []]);
        $this->actingAs($subAdmin);

        $this->get(SettingsPage::getUrl())->assertForbidden();
    }

    public function test_a_sub_admin_with_view_only_cannot_save(): void
    {
        $subAdmin = User::factory()->role(UserRole::Admin)->create([
            'permissions' => [Permission::SettingsViewAny->value],
        ]);
        $this->actingAs($subAdmin);

        // Livewire absorbs the abort_unless(403) into its own AJAX-style
        // response rather than letting it propagate to the test as a
        // catchable exception — so the real assertion is the one that
        // matters operationally: the value never actually moved.
        Livewire::test(SettingsPage::class)
            ->fillForm(['free_trial_max_days' => 30])
            ->call('save');

        $this->assertSame(15, Setting::get('free_trial_max_days'));
    }

    public function test_a_sub_admin_with_the_update_permission_can_save(): void
    {
        $subAdmin = User::factory()->role(UserRole::Admin)->create([
            'permissions' => [
                Permission::SettingsViewAny->value,
                Permission::SettingsUpdate->value,
            ],
        ]);
        $this->actingAs($subAdmin);

        Livewire::test(SettingsPage::class)
            ->fillForm(['free_trial_max_days' => 30])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame(30, Setting::get('free_trial_max_days'));
    }
}
