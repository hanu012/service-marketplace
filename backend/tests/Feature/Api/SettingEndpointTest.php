<?php

namespace Tests\Feature\Api;

use App\Models\Setting;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SettingEndpointTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_is_public_and_needs_no_token(): void
    {
        $this->getJson('/api/settings')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('error', null);
    }

    public function test_it_returns_the_seeded_default(): void
    {
        Setting::updateOrCreate(
            ['key' => 'free_trial_max_days'],
            ['value' => '15', 'type' => 'integer'],
        );

        $this->getJson('/api/settings')
            ->assertOk()
            ->assertJsonPath('data.free_trial_max_days', 15);
    }

    /**
     * The whole reason this endpoint exists: "fetch it, don't hardcode" only
     * means something if changing the row actually changes the response.
     */
    public function test_it_reflects_a_changed_value_not_a_cached_one(): void
    {
        Setting::updateOrCreate(
            ['key' => 'free_trial_max_days'],
            ['value' => '15', 'type' => 'integer'],
        );

        $this->getJson('/api/settings')->assertJsonPath('data.free_trial_max_days', 15);

        Setting::where('key', 'free_trial_max_days')->update(['value' => '21']);

        $this->getJson('/api/settings')->assertJsonPath('data.free_trial_max_days', 21);
    }

    public function test_it_falls_back_to_15_when_unseeded(): void
    {
        // No Setting row at all — the endpoint must not 500 or return null.
        $this->getJson('/api/settings')
            ->assertOk()
            ->assertJsonPath('data.free_trial_max_days', 15);
    }

    public function test_only_the_whitelisted_key_is_exposed(): void
    {
        Setting::create([
            'key' => 'maintenance_mode',
            'value' => 'true',
            'type' => 'boolean',
        ]);

        $response = $this->getJson('/api/settings')->assertOk();

        $this->assertSame(['free_trial_max_days'], array_keys($response->json('data')));
    }
}
