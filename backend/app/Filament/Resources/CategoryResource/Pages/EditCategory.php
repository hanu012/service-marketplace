<?php

namespace App\Filament\Resources\CategoryResource\Pages;

use App\Filament\Resources\CategoryResource;
use App\Filament\Support\RecordStatus;
use App\Models\Category;
use Filament\Actions\Action;
use Filament\Resources\Pages\EditRecord;

class EditCategory extends EditRecord
{
    protected static string $resource = CategoryResource::class;

    protected function getHeaderActions(): array
    {
        // No DeleteAction — SPEC section 10. This page previously
        // registered one directly, reintroducing a hard-delete path
        // the table already omits — confirmed CategoryResource::table()
        // and SubcategoriesRelationManager both correctly omit it, only
        // this header-actions method leaked one back in. See
        // CategoryResourceTest for the header-actions coverage that
        // now catches this specifically, not just the table.
        return [
            RecordStatus::configure(
                Action::make('changeStatus'),
                fn (Category $record): string => CategoryResource::statusEffects($record),
            ),
        ];
    }

    public function getSubheading(): ?string
    {
        return RecordStatus::summary(
            $this->getRecord(),
            'shown in the customer app and selectable by salesmen and vendors.',
            'hidden from the apps, with all its subcategories. Existing subscriptions keep running.',
        );
    }
}
