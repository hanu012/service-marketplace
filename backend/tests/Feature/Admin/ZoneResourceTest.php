<?php

namespace Tests\Feature\Admin;

use App\Enums\UserRole;
use App\Filament\Resources\ZoneResource;
use App\Filament\Resources\ZoneResource\Pages\CreateZone;
use App\Filament\Resources\ZoneResource\Pages\EditZone;
use App\Filament\Resources\ZoneResource\Pages\ListZones;
use App\Models\User;
use App\Models\Zone;
use Database\Factories\ZoneFactory;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Livewire\Livewire;
use Tests\TestCase;

class ZoneResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->role(UserRole::Admin)->create());
    }

    public function test_the_list_page_renders(): void
    {
        Zone::factory()->count(3)->create();

        Livewire::test(ListZones::class)->assertSuccessful();
    }

    /**
     * SPEC section 10 — asserting absence, not merely that it is disabled.
     */
    public function test_no_delete_action_is_registered(): void
    {
        $zone = Zone::factory()->create();

        Livewire::test(ListZones::class)
            ->assertTableActionDoesNotExist(DeleteAction::class, record: $zone)
            ->assertTableBulkActionDoesNotExist(DeleteBulkAction::class);
    }

    /**
     * A DeleteAction can reappear in two different places: the table's
     * row actions (checked above) and the Edit page's own header
     * actions — a genuinely separate registration. This is exactly
     * where CategoryResource's equivalent page leaked one back in while
     * its table stayed clean (see CategoryResourceTest), undetected
     * because nothing tested its Edit page at all. ZoneResourceTest
     * already covers that second spot below — confirming EditZone
     * never had the same leak, and why: this test already existed here.
     */
    public function test_the_edit_page_offers_no_delete_either(): void
    {
        $zone = Zone::factory()->create();

        Livewire::test(EditZone::class, ['record' => $zone->getKey()])
            ->assertSuccessful()
            ->assertActionDoesNotExist('delete');
    }

    /**
     * Same shape as CategoryResourceTest: drive updateTableColumnState, then
     * read the value back from the database rather than trusting the
     * component.
     */
    public function test_the_active_toggle_flips_the_record(): void
    {
        $zone = Zone::factory()->create();

        $this->assertFalse($zone->is_active);

        Livewire::test(ListZones::class)
            ->assertTableColumnStateSet('is_active', false, $zone)
            ->call('updateTableColumnState', 'is_active', (string) $zone->getKey(), true);

        $this->assertTrue($zone->fresh()->is_active);
    }

    public function test_a_zone_can_be_drawn_and_saved_as_a_draft(): void
    {
        Livewire::test(CreateZone::class)
            ->fillForm([
                'name' => 'Gota',
                'slug' => 'gota',
                'pincode' => '382481',
                'polygon_points' => ZoneFactory::square(23.09, 72.52),
                'is_active' => false,
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $zone = Zone::where('slug', 'gota')->firstOrFail();

        $this->assertFalse($zone->is_active);

        // The boundary really landed in Ahmedabad, not a transposed location.
        $inside = DB::table('zones')
            ->selectRaw('ST_Contains(polygon, ST_GeomFromText(?, 4326)) as inside', ['POINT(72.53 23.10)'])
            ->where('id', $zone->getKey())
            ->value('inside');

        $this->assertSame(1, (int) $inside);
    }

    public function test_a_zone_cannot_be_saved_without_a_boundary(): void
    {
        // polygon is NOT NULL (SPEC section 11), so the form must refuse.
        Livewire::test(CreateZone::class)
            ->fillForm([
                'name' => 'No Shape',
                'slug' => 'no-shape',
                'polygon_points' => [],
            ])
            ->call('create')
            ->assertHasFormErrors(['polygon_points']);

        $this->assertDatabaseMissing('zones', ['slug' => 'no-shape']);
    }

    public function test_editing_loads_the_existing_boundary_into_the_form(): void
    {
        $zone = Zone::factory()->withBoundary([
            ['lat' => 23.09, 'lng' => 72.52],
            ['lat' => 23.09, 'lng' => 72.58],
            ['lat' => 23.13, 'lng' => 72.58],
            ['lat' => 23.13, 'lng' => 72.52],
        ])->create();

        Livewire::test(EditZone::class, ['record' => $zone->getKey()])
            ->assertFormSet(function (array $state): bool {
                $points = $state['polygon_points'] ?? [];

                return count($points) === 4
                    && abs($points[0]['lat'] - 23.09) < 0.0001
                    && abs($points[0]['lng'] - 72.52) < 0.0001;
            });
    }

    public function test_a_sub_zone_can_reuse_a_slug_under_a_different_parent(): void
    {
        $ahmedabad = Zone::factory()->create(['name' => 'Ahmedabad', 'slug' => 'ahmedabad']);
        $surat = Zone::factory()->create(['name' => 'Surat', 'slug' => 'surat']);

        Zone::factory()->create(['parent_id' => $ahmedabad->id, 'slug' => 'central']);

        Livewire::test(CreateZone::class)
            ->fillForm([
                'name' => 'Central',
                'slug' => 'central',
                'parent_id' => $surat->id,
                'polygon_points' => ZoneFactory::square(21.17, 72.83),
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $this->assertSame(2, Zone::where('slug', 'central')->count());
    }

    public function test_a_duplicate_slug_under_the_same_parent_is_rejected(): void
    {
        $parent = Zone::factory()->create();
        Zone::factory()->create(['parent_id' => $parent->id, 'slug' => 'central']);

        Livewire::test(CreateZone::class)
            ->fillForm([
                'name' => 'Central',
                'slug' => 'central',
                'parent_id' => $parent->id,
                'polygon_points' => ZoneFactory::square(23.2, 72.6),
            ])
            ->call('create')
            ->assertHasFormErrors(['slug']);
    }

    /**
     * SPEC section 8 caps the hierarchy at two levels (city -> sub-zone).
     * At exactly two levels, "effective active checks one level up" and
     * "in use counts every descendant" are the same statement, so they cannot
     * disagree — a third level would silently break that equivalence.
     */
    public function test_a_grandchild_zone_is_rejected(): void
    {
        $city = Zone::factory()->create(['name' => 'Ahmedabad']);
        $subZone = Zone::factory()->create(['parent_id' => $city->id, 'name' => 'Gota']);

        Livewire::test(CreateZone::class)
            ->fillForm([
                'name' => 'Gota North',
                'slug' => 'gota-north',
                'parent_id' => $subZone->id,
                'polygon_points' => ZoneFactory::square(23.10, 72.53),
            ])
            ->call('create')
            ->assertHasFormErrors(['parent_id']);

        $this->assertDatabaseMissing('zones', ['slug' => 'gota-north']);
    }

    public function test_a_sub_zone_under_a_top_level_zone_is_allowed(): void
    {
        $city = Zone::factory()->create(['name' => 'Ahmedabad']);

        Livewire::test(CreateZone::class)
            ->fillForm([
                'name' => 'Ranip',
                'slug' => 'ranip',
                'parent_id' => $city->id,
                'polygon_points' => ZoneFactory::square(23.07, 72.55),
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $this->assertDatabaseHas('zones', ['slug' => 'ranip', 'parent_id' => $city->id]);
    }

    public function test_a_zone_with_children_cannot_be_given_a_parent(): void
    {
        // The same three-level tree, built from the other direction. SPEC
        // section 8 only names the forward case, but leaving this open would
        // let an admin reach depth 3 by editing instead of creating.
        $city = Zone::factory()->create(['name' => 'Ahmedabad']);
        Zone::factory()->create(['parent_id' => $city->id, 'name' => 'Gota']);

        $other = Zone::factory()->create(['name' => 'Gujarat']);

        Livewire::test(EditZone::class, ['record' => $city->getKey()])
            ->fillForm(['parent_id' => $other->id])
            ->call('save')
            ->assertHasFormErrors(['parent_id']);

        $this->assertNull($city->fresh()->parent_id);
    }

    public function test_the_parent_dropdown_offers_only_top_level_zones(): void
    {
        $city = Zone::factory()->create(['name' => 'Ahmedabad']);
        $subZone = Zone::factory()->create(['parent_id' => $city->id, 'name' => 'Gota']);

        Livewire::test(CreateZone::class)
            ->assertFormFieldExists('parent_id', function ($field) use ($city, $subZone): bool {
                $options = $field->getOptions();

                return array_key_exists($city->id, $options)
                    && ! array_key_exists($subZone->id, $options);
            });
    }

    public function test_the_map_field_renders_with_the_configured_tile_url(): void
    {
        // Proves the whole chain: the custom field's Blade view compiles, the
        // Alpine component is wired up, and config/map.php reaches the page.
        config()->set('map.tile_url', 'https://tiles.example.test/{z}/{x}/{y}.png');

        Livewire::test(CreateZone::class)
            ->assertSuccessful()
            ->assertSee('polygonMap(', escape: false)
            ->assertSee('tiles.example.test', escape: false);
    }

    public function test_the_map_field_is_disabled_free_of_leaflet_cdn_references(): void
    {
        // Leaflet is vendored; nothing in the panel should reach out to a CDN.
        $html = Livewire::test(CreateZone::class)->assertSuccessful()->html();

        $this->assertStringNotContainsString('unpkg.com', $html);
        $this->assertStringNotContainsString('cdn.jsdelivr.net', $html);
    }

    public function test_a_non_admin_cannot_reach_the_resource(): void
    {
        $this->actingAs(User::factory()->role(UserRole::Vendor)->create());

        $this->get(ZoneResource::getUrl('index'))->assertForbidden();
    }
}
