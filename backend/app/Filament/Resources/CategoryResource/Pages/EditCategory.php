<?php

namespace App\Filament\Resources\CategoryResource\Pages;

use App\Filament\Resources\CategoryResource;
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
        return [];
    }
}
