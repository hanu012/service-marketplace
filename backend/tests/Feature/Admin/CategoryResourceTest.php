<?php

namespace Tests\Feature\Admin;

use App\Enums\UserRole;
use App\Filament\Resources\CategoryResource;
use App\Filament\Resources\CategoryResource\Pages\EditCategory;
use App\Filament\Resources\CategoryResource\Pages\ListCategories;
use App\Filament\Resources\CategoryResource\RelationManagers\SubcategoriesRelationManager;
use App\Models\Category;
use App\Models\Subcategory;
use App\Models\User;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class CategoryResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->role(UserRole::Admin)->create());
    }

    public function test_the_list_page_renders(): void
    {
        Category::factory()->count(3)->create();

        Livewire::test(ListCategories::class)->assertSuccessful();
    }

    public function test_categories_are_listed_in_sort_order(): void
    {
        $third = Category::factory()->sortedAt(30)->create();
        $first = Category::factory()->sortedAt(10)->create();
        $second = Category::factory()->sortedAt(20)->create();

        Livewire::test(ListCategories::class)
            ->assertCanSeeTableRecords([$first, $second, $third], inOrder: true);
    }

    /**
     * SPEC section 10: hard deletion of selectable master data must not be
     * offered at all. Asserting the actions are absent - not merely disabled -
     * is what stops a later edit quietly reintroducing them.
     */
    public function test_no_delete_action_is_registered_on_categories(): void
    {
        $category = Category::factory()->create();

        Livewire::test(ListCategories::class)
            ->assertTableActionDoesNotExist(DeleteAction::class, record: $category)
            ->assertTableBulkActionDoesNotExist(DeleteBulkAction::class);
    }

    /**
     * A DeleteAction can reappear in two different places on a Resource:
     * the table's row actions (checked above) and the Edit page's own
     * header actions — a genuinely separate registration Filament
     * exposes via a different method entirely. This is not a
     * hypothetical: EditCategory::getHeaderActions() once registered a
     * DeleteAction directly, reintroducing exactly the hard-delete path
     * SPEC section 10 forbids, and the table-only test above did not
     * catch it because it never exercises the Edit page at all.
     */
    public function test_no_delete_action_is_registered_on_the_category_edit_page(): void
    {
        $category = Category::factory()->create();

        Livewire::test(EditCategory::class, ['record' => $category->getKey()])
            ->assertActionDoesNotExist(DeleteAction::class);
    }

    public function test_no_delete_action_is_registered_on_subcategories(): void
    {
        $category = Category::factory()->create();
        $subcategory = Subcategory::factory()->for($category)->create();

        Livewire::test(SubcategoriesRelationManager::class, [
            'ownerRecord' => $category,
            'pageClass' => \App\Filament\Resources\CategoryResource\Pages\EditCategory::class,
        ])
            ->assertTableActionDoesNotExist(DeleteAction::class, record: $subcategory)
            ->assertTableBulkActionDoesNotExist(DeleteBulkAction::class);
    }

    public function test_the_active_toggle_flips_the_record(): void
    {
        $category = Category::factory()->create(['is_active' => true]);

        // ToggleColumn is not an action — it calls updateTableColumnState on
        // the Livewire component, so the test drives that directly.
        Livewire::test(ListCategories::class)
            ->assertTableColumnStateSet('is_active', true, $category)
            ->call('updateTableColumnState', 'is_active', (string) $category->getKey(), false);

        $this->assertFalse($category->fresh()->is_active);
    }

    public function test_reordering_writes_sort_order(): void
    {
        $a = Category::factory()->sortedAt(1)->create();
        $b = Category::factory()->sortedAt(2)->create();
        $c = Category::factory()->sortedAt(3)->create();

        // reorderTable is a component method, not a chainable test helper.
        Livewire::test(ListCategories::class)
            ->call('reorderTable', [$c->getKey(), $a->getKey(), $b->getKey()]);

        $this->assertSame(1, $c->fresh()->sort_order);
        $this->assertSame(2, $a->fresh()->sort_order);
        $this->assertSame(3, $b->fresh()->sort_order);
    }

    public function test_a_category_can_be_created(): void
    {
        Livewire::test(CategoryResource\Pages\CreateCategory::class)
            ->fillForm([
                'name' => 'Pest Control',
                'slug' => 'pest-control',
                'is_active' => true,
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $this->assertDatabaseHas('categories', ['slug' => 'pest-control']);
    }

    public function test_a_duplicate_slug_is_rejected(): void
    {
        Category::factory()->create(['slug' => 'plumbing']);

        Livewire::test(CategoryResource\Pages\CreateCategory::class)
            ->fillForm([
                'name' => 'Plumbing',
                'slug' => 'plumbing',
            ])
            ->call('create')
            ->assertHasFormErrors(['slug']);
    }

    public function test_the_relation_manager_lists_only_its_own_subcategories(): void
    {
        $category = Category::factory()->create();
        $mine = Subcategory::factory()->for($category)->create();
        $theirs = Subcategory::factory()->for(Category::factory()->create())->create();

        Livewire::test(SubcategoriesRelationManager::class, [
            'ownerRecord' => $category,
            'pageClass' => \App\Filament\Resources\CategoryResource\Pages\EditCategory::class,
        ])
            ->assertCanSeeTableRecords([$mine])
            ->assertCanNotSeeTableRecords([$theirs]);
    }

    public function test_a_non_admin_cannot_reach_the_resource(): void
    {
        $this->actingAs(User::factory()->role(UserRole::Vendor)->create());

        $this->get(CategoryResource::getUrl('index'))->assertForbidden();
    }
}
