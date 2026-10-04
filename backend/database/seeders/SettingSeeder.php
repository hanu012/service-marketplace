<?php

namespace Database\Seeders;

use App\Models\Setting;
use Illuminate\Database\Seeder;

/**
 * Admin-editable settings (SPEC section 5.17), matching the key list
 * documented on the settings migration.
 *
 * `free_trial_max_days` and `free_grants_per_salesman_month` are what
 * SubscriptionService actually reads today (Phase 3). The other three are
 * seeded now to complete the documented set in one pass, but nothing reads
 * them yet — grace_period_days is the daily expiry job (Phase 7),
 * force_update_version/maintenance_mode are app-gating (also later).
 *
 * Only free_trial_max_days has a SPEC-given default (15). The rest are
 * reasonable starting values, same as the seeded plan prices — an admin can
 * change any of them once the Settings admin screen exists.
 */
class SettingSeeder extends Seeder
{
    /**
     * @var array<int, array<string, mixed>>
     */
    private const SETTINGS = [
        [
            'key' => 'free_trial_max_days',
            'value' => '15',
            'type' => 'integer',
            'group' => 'subscriptions',
            'label' => 'Maximum free trial length (days)',
            'description' => 'SPEC section 2.2: capped free-trial duration a salesman can grant.',
        ],
        [
            'key' => 'free_grants_per_salesman_month',
            'value' => '10',
            'type' => 'integer',
            'group' => 'subscriptions',
            'label' => 'Free grants per salesman per month',
            'description' => 'Caps how many free trials one salesman can grant in a calendar month.',
        ],
        [
            'key' => 'grace_period_days',
            'value' => '7',
            'type' => 'integer',
            'group' => 'subscriptions',
            'label' => 'Grace period (days)',
            'description' => 'Active -> Grace -> Expired (SPEC section 7). Not yet read by any job.',
        ],
        [
            'key' => 'force_update_version',
            'value' => '1.0.0',
            'type' => 'string',
            'group' => 'app',
            'label' => 'Minimum app version',
            'description' => 'Below this version, the app is forced to update. Not yet enforced.',
        ],
        [
            'key' => 'maintenance_mode',
            'value' => 'false',
            'type' => 'boolean',
            'group' => 'app',
            'label' => 'Maintenance mode',
            'description' => 'Global app-side maintenance toggle. Not yet enforced.',
        ],
    ];

    public function run(): void
    {
        foreach (self::SETTINGS as $definition) {
            Setting::updateOrCreate(['key' => $definition['key']], $definition);
        }

        $this->command?->info('Settings: '.Setting::count().' keys seeded.');
    }
}
